// State Management
import 'dart:convert';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:invoicer/dialogs/file_detail_dialog.dart';
import 'package:invoicer/extractor.dart';
import 'package:invoicer/models.dart';
import 'package:invoicer/services/filename_template_service.dart';
import 'package:macos_ui/macos_ui.dart';
import 'package:path/path.dart' as path;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:signals/signals.dart';

class AppState {
  static final AppState _instance = AppState._internal();

  factory AppState() => _instance;

  AppState._internal();

  // Legacy single folder support (for backwards compatibility)
  final selectedFolder = signal<String?>(null);

  // New multi-folder support
  final projectFolders = listSignal<ProjectFolder>([]);
  final currentlySelectedFolder = signal<ProjectFolder?>(null);

  // UI state
  final currentView = signal<String>('overview'); // 'overview', 'folder', or 'all_files'

  final pdfFiles = listSignal<PdfDocument>([]);
  final individualFiles = listSignal<PdfDocument>(
    [],
  ); // Files added individually
  final apiKey = signal<String>("");
  final aiModel = signal<String>("gpt-4.1-mini");
  final isProcessingAll = signal<bool>(false);
  final filenameTemplate = signal<String>("[YEAR]-[MONTH]-[DAY] - [VENDOR].pdf");
  final autoRenameDropped = signal<bool>(false);

  Future<void> loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    apiKey.value =
        dotenv.maybeGet(
          'OPENAI_API_KEY',
          fallback: prefs.getString('openai_api_key'),
        ) ??
        "";
    aiModel.value =
        dotenv.maybeGet(
          'OPENAI_MODEL',
          fallback: prefs.getString('openai_model'),
        ) ??
        "gpt-4.1-mini";

    filenameTemplate.value = prefs.getString('filename_template') ??
        "[YEAR]-[MONTH]-[DAY] - [VENDOR].pdf";
    autoRenameDropped.value = prefs.getBool('auto_rename_dropped') ?? false;

    // Load legacy single folder for backwards compatibility
    selectedFolder.value = prefs.getString('selected_folder');

    // Load project folders
    final foldersJson = prefs.getString('project_folders');
    if (foldersJson != null) {
      final foldersList = jsonDecode(foldersJson) as List;
      projectFolders.clear();
      projectFolders.addAll(
        foldersList.map((json) => ProjectFolder.fromJson(json)).toList(),
      );
    }

    // Load individual files
    final individualFilesJson = prefs.getString('individual_files');
    if (individualFilesJson != null) {
      final filesList = jsonDecode(individualFilesJson) as List;
      individualFiles.clear();
      for (var fileJson in filesList) {
        final filePath = fileJson['path'] as String;
        // Only add if file still exists
        if (File(filePath).existsSync()) {
          individualFiles.add(
            PdfDocument(
              name: fileJson['name'] ?? path.basename(filePath),
              path: filePath,
              source: 'individual',
            ),
          );
        }
      }
    }

    // Migrate legacy folder to new system if exists
    if (selectedFolder.value != null && projectFolders.isEmpty) {
      await addFolder(selectedFolder.value!);
    }

    // Load current view
    currentView.value = prefs.getString('current_view') ?? 'overview';

    // Load currently selected folder
    final currentFolderPath = prefs.getString('currently_selected_folder');
    if (currentFolderPath != null) {
      try {
        currentlySelectedFolder.value = projectFolders.firstWhere(
          (folder) => folder.path == currentFolderPath,
        );
      } catch (e) {
        currentlySelectedFolder.value = null;
      }
    }
  }

  Future<void> saveSettings() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('openai_api_key', apiKey.value);
    await prefs.setString('openai_model', aiModel.value);
    await prefs.setString('filename_template', filenameTemplate.value);
    await prefs.setBool('auto_rename_dropped', autoRenameDropped.value);

    // Save legacy folder for backwards compatibility
    if (selectedFolder.value != null) {
      await prefs.setString('selected_folder', selectedFolder.value!);
    }

    // Save project folders
    final foldersJson = jsonEncode(
      projectFolders.map((folder) => folder.toJson()).toList(),
    );
    await prefs.setString('project_folders', foldersJson);

    // Save individual files
    final individualFilesJson = jsonEncode(
      individualFiles
          .map((file) => {'name': file.name, 'path': file.path})
          .toList(),
    );
    await prefs.setString('individual_files', individualFilesJson);

    // Save current view
    await prefs.setString('current_view', currentView.value);

    // Save currently selected folder
    if (currentlySelectedFolder.value != null) {
      await prefs.setString(
        'currently_selected_folder',
        currentlySelectedFolder.value!.path,
      );
    } else {
      await prefs.remove('currently_selected_folder');
    }
  }

  // Folder management methods
  Future<void> addFolder(String folderPath) async {
    final directory = Directory(folderPath);
    if (!directory.existsSync()) {
      throw Exception('Folder does not exist');
    }

    final folderName = path.basename(folderPath);
    final newFolder = ProjectFolder(
      path: folderPath,
      name: folderName,
      addedAt: DateTime.now(),
    );

    // Check if folder already exists
    final existingIndex = projectFolders.indexWhere(
      (f) => f.path == folderPath,
    );
    if (existingIndex != -1) {
      return; // Folder already added
    }

    // Update file count
    final fileCount = _countPDFFiles(folderPath);
    newFolder.fileCount = fileCount;

    projectFolders.add(newFolder);
    await saveSettings();
  }

  Future<void> removeFolder(ProjectFolder folder) async {
    projectFolders.removeWhere((f) => f.path == folder.path);

    // If this was the currently selected folder, clear it
    if (currentlySelectedFolder.value?.path == folder.path) {
      currentlySelectedFolder.value = null;
      pdfFiles.clear();
    }

    await saveSettings();
  }

  void selectFolder(ProjectFolder folder) {
    currentlySelectedFolder.value = folder;
    selectedFolder.value = folder.path; // Keep legacy compatibility
    loadPDFFiles();
    saveSettings();
  }

  int _countPDFFiles(String folderPath) {
    try {
      final directory = Directory(folderPath);
      return directory
          .listSync()
          .where((file) => file.path.toLowerCase().endsWith('.pdf'))
          .length;
    } catch (e) {
      return 0;
    }
  }

  Future<void> refreshFolderCounts() async {
    for (int i = 0; i < projectFolders.length; i++) {
      final folder = projectFolders[i];
      final newCount = _countPDFFiles(folder.path);
      if (newCount != folder.fileCount) {
        projectFolders[i] = folder.copyWith(fileCount: newCount);
      }
    }
    await saveSettings();
  }

  void loadPDFFiles() {
    final currentFolder = currentlySelectedFolder.value;
    if (currentFolder == null) {
      pdfFiles.clear();
      return;
    }

    try {
      final directory = Directory(currentFolder.path);
      final pdfFilePaths = directory
          .listSync()
          .where((file) => file.path.toLowerCase().endsWith('.pdf'))
          .toList();

      pdfFiles.clear();
      pdfFiles.addAll(
        pdfFilePaths.map(
          (file) => PdfDocument(
            name: path.basename(file.path),
            path: file.path,
            source: 'folder',
            folderPath: currentFolder.path,
          ),
        ),
      );
    } catch (e) {
      print('Error loading PDF files: $e');
      pdfFiles.clear();
    }
  }

  Future<void> pickAndAddFolder() async {
    String? selectedDirectory = await FilePicker.platform.getDirectoryPath();
    if (selectedDirectory != null) {
      try {
        await addFolder(selectedDirectory);
        // If this is the first folder, automatically select it
        if (currentlySelectedFolder.value == null) {
          final addedFolder = projectFolders.firstWhere(
            (f) => f.path == selectedDirectory,
          );
          selectFolder(addedFolder);
        }
      } catch (e) {
        print('Error adding folder: $e');
      }
    }
  }

  Future<void> processFile(PdfDocument file) async {
    // Find the file in the appropriate list
    int folderIndex = pdfFiles.indexOf(file);
    int individualIndex = individualFiles.indexOf(file);

    if ((folderIndex == -1 && individualIndex == -1) || file.isProcessing) {
      return;
    }

    // Update processing state in the correct list
    if (folderIndex != -1) {
      pdfFiles[folderIndex] = file.copyWith(isProcessing: true, error: null);
    } else {
      individualFiles[individualIndex] = file.copyWith(
        isProcessing: true,
        error: null,
      );
    }

    try {
      // Extract text from PDF
      final textContent = await Extractor.extractTextFromPDF(file.path);

      if (textContent.trim().isEmpty) {
        throw Exception('No text found in PDF');
      }

      // Analyze with OpenAI
      final result = await Extractor.extractReceiptData(
        textContent,
        apiKey.value,
        model: aiModel.value,
      );

      final updatedFile = file.copyWith(
        items:
            (result['items'] as List<dynamic>?)
                ?.map((item) => ReceiptItem.fromJson(item))
                .toList() ??
            [],
        vendor: result['vendor'],
        invoiceDate: DateTime.tryParse(result['invoice_date'] ?? ""),
        dueDate: DateTime.tryParse(result['due_date'] ?? ""),
        currency: result['currency'],
        taxAmount: result['tax_amount']?.toDouble(),
        totalAmount: result['total_amount']?.toDouble(),
        discountAmount: result['discount_amount']?.toDouble(),
        vendorWebsite: result['vendor_website'],
        vendorEmail: result['vendor_email'],
        vendorDisplayAddress: result['vendor_display_address'],
        paymentMethod: result['payment_method'],
        lastFourDigits: result['last_four_digits'],
        isProcessing: false,
      );

      // Update the correct list
      if (folderIndex != -1) {
        pdfFiles[folderIndex] = updatedFile;
      } else {
        individualFiles[individualIndex] = updatedFile;
      }

      // Save extracted data to persistent storage
      await saveExtractedData();
    } catch (e) {
      final errorFile = file.copyWith(error: e.toString(), isProcessing: false);

      // Update the correct list
      if (folderIndex != -1) {
        pdfFiles[folderIndex] = errorFile;
      } else {
        individualFiles[individualIndex] = errorFile;
      }
    }
  }

  Future<void> processAllFiles() async {
    if (isProcessingAll.value) return;

    isProcessingAll.value = true;

    try {
      final futures = pdfFiles.map((file) => processFile(file)).toList();
      await Future.wait(futures);
    } finally {
      isProcessingAll.value = false;
    }
  }

  Future<void> renameFile(PdfDocument file, BuildContext context) async {
    if (file.vendor == null) {
      return;
    }

    // Use the filename template
    final newName = FilenameTemplateService.applyTemplate(
      filenameTemplate.value,
      file,
    );
    final newPath = path.join(path.dirname(file.path), newName);

    // Don't rename if the path would be the same
    if (file.path == newPath) {
      return;
    }

    // Check if target file already exists
    if (File(newPath).existsSync()) {
      _showRenameErrorDialog(
        context,
        'Cannot rename: A file named "$newName" already exists in this location.',
      );
      return;
    }

    // Store original state for rollback
    final originalFile = file;
    final index = pdfFiles.indexOf(file);

    if (index == -1) {
      return; // File not found in list
    }

    // Optimistic UI update
    pdfFiles[index] = file.copyWith(name: newName, path: newPath);

    try {
      // Perform the actual filesystem rename
      await File(file.path).rename(newPath);

      // Persist the change
      await saveSettings();

    } on FileSystemException catch (e) {
      // Rollback on filesystem error
      pdfFiles[index] = originalFile;

      print('Rename failed: $e');

      if (context.mounted) {
        _showRenameErrorDialog(
          context,
          'Failed to rename file: ${e.message}\n\n'
              'Possible causes:\n'
              '• File is open in another application\n'
              '• Insufficient permissions\n'
              '• File is on a read-only volume',
        );
      }
    } catch (e) {
      // Rollback on unexpected errors
      pdfFiles[index] = originalFile;

      print('Unexpected error during rename: $e');

      if (context.mounted) {
        _showRenameErrorDialog(
          context,
          'An unexpected error occurred while renaming the file.',
        );
      }
    }
  }

  void _showRenameErrorDialog(BuildContext context, String message) {
    showMacosAlertDialog(
      context: context,
      builder: (context) => MacosAlertDialog(
        appIcon: const MacosIcon(CupertinoIcons.exclamationmark_triangle),
        title: const Text('Rename Failed'),
        message: Text(message),
        primaryButton: PushButton(
          controlSize: ControlSize.large,
          child: const Text('OK'),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
    );
  }

  // Data persistence methods (JSON file-based)
  String _getDataFilePath() {
    final homeDir = Platform.environment['HOME'] ?? Platform.environment['USERPROFILE'];
    if (homeDir == null) {
      throw Exception('Cannot determine user home directory');
    }
    return path.join(homeDir, '.invoicer', 'data.json');
  }

  Future<void> _ensureDataDirectoryExists() async {
    final homeDir = Platform.environment['HOME'] ?? Platform.environment['USERPROFILE'];
    if (homeDir == null) {
      throw Exception('Cannot determine user home directory');
    }
    final dataDir = Directory(path.join(homeDir, '.invoicer'));
    if (!dataDir.existsSync()) {
      await dataDir.create(recursive: true);
      print('Created data directory: ${dataDir.path}');
    }
  }

  Future<void> saveExtractedData() async {
    try {
      await _ensureDataDirectoryExists();

      // Collect all processed files (those with extracted data)
      final processedFiles = [
        ...pdfFiles.where((file) => file.vendor != null),
        ...individualFiles.where((file) => file.vendor != null),
      ];

      final data = {
        'version': 1,
        'lastUpdated': DateTime.now().toIso8601String(),
        'processedFiles': processedFiles.map((file) => file.toJson()).toList(),
      };

      final dataFilePath = _getDataFilePath();
      final tempFilePath = '$dataFilePath.tmp';

      // Write to temporary file first (atomic write pattern)
      final tempFile = File(tempFilePath);
      await tempFile.writeAsString(
        jsonEncode(data),
        flush: true,
      );

      // Move temporary file to actual file (atomic operation)
      await tempFile.rename(dataFilePath);

      print('Saved ${processedFiles.length} processed files to $dataFilePath');
    } catch (e) {
      print('Error saving extracted data: $e');
      // Don't throw - silent failure is better than blocking user
    }
  }

  Future<void> loadExtractedData() async {
    try {
      final dataFilePath = _getDataFilePath();
      final dataFile = File(dataFilePath);

      if (!dataFile.existsSync()) {
        print('No cached data file found at $dataFilePath');
        return;
      }

      final jsonString = await dataFile.readAsString();
      final data = jsonDecode(jsonString) as Map<String, dynamic>;

      final version = data['version'] as int? ?? 1;
      if (version != 1) {
        print('Unknown data version: $version, skipping cache load');
        return;
      }

      final processedFilesList = data['processedFiles'] as List<dynamic>? ?? [];
      final processedFiles = processedFilesList
          .map((json) {
            try {
              return PdfDocument.fromJson(json as Map<String, dynamic>);
            } catch (e) {
              print('Error parsing saved file: $e');
              return null;
            }
          })
          .whereType<PdfDocument>()
          .toList();

      int restoredCount = 0;

      // Restore extracted data for files that still exist
      for (var processed in processedFiles) {
        // Only restore if file still exists on disk
        if (!File(processed.path).existsSync()) {
          print('Skipping ${processed.name} - file no longer exists');
          continue;
        }

        if (processed.source == 'folder') {
          final index = pdfFiles.indexWhere((f) => f.path == processed.path);
          if (index != -1) {
            pdfFiles[index] = processed;
            restoredCount++;
          }
        } else {
          // Individual file
          final index = individualFiles.indexWhere((f) => f.path == processed.path);
          if (index != -1) {
            individualFiles[index] = processed;
            restoredCount++;
          }
        }
      }

      final lastUpdated = data['lastUpdated'] as String?;
      print('Restored $restoredCount processed files from cache (last updated: $lastUpdated)');
    } catch (e) {
      print('Error loading extracted data: $e');
      // Don't throw - app should still work without cache
    }
  }

  Future<void> clearExtractedDataCache() async {
    try {
      final dataFilePath = _getDataFilePath();
      final dataFile = File(dataFilePath);
      if (dataFile.existsSync()) {
        await dataFile.delete();
        print('Cleared extracted data cache');
      }
    } catch (e) {
      print('Error clearing cache: $e');
    }
  }

  // Individual file management methods
  Future<void> addIndividualFiles() async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf'],
        allowMultiple: true,
      );

      if (result != null) {
        for (PlatformFile file in result.files) {
          if (file.path != null) {
            await _addIndividualFile(file.path!);
          }
        }
      }
    } catch (e) {
      print('Error adding individual files: $e');
    }
  }

  Future<void> addIndividualFile(String filePath) async {
    await _addIndividualFile(filePath);
  }

  Future<void> _addIndividualFile(String filePath) async {
    // Check if file already exists
    final fileName = path.basename(filePath);
    final existsInIndividual = individualFiles.any((f) => f.path == filePath);
    final existsInFolder = pdfFiles.any((f) => f.path == filePath);

    if (existsInIndividual || existsInFolder) {
      return; // File already added
    }

    // Verify it's a PDF file
    if (!filePath.toLowerCase().endsWith('.pdf')) {
      return;
    }

    // Verify file exists
    final file = File(filePath);
    if (!file.existsSync()) {
      return;
    }

    final pdfDoc = PdfDocument(
      name: fileName,
      path: filePath,
      source: 'individual',
    );

    individualFiles.add(pdfDoc);
    await saveSettings();
  }

  Future<void> removeIndividualFile(PdfDocument file) async {
    individualFiles.removeWhere((f) => f.path == file.path);
    await saveSettings();
  }

  // Get all files (both folder and individual)
  List<PdfDocument> get allFiles {
    return [...pdfFiles, ...individualFiles];
  }

  /// Process a dropped file with optional auto-rename
  Future<void> processDroppedFile(String filePath, BuildContext context) async {
    // Add the file as an individual file
    await _addIndividualFile(filePath);

    // Find the newly added file
    final file = individualFiles.firstWhere((f) => f.path == filePath);

    // Process the file with AI
    await processFile(file);

    // Check if processing was successful
    final processedFile = individualFiles.firstWhere((f) => f.path == filePath);

    if (processedFile.vendor != null && context.mounted) {
      if (autoRenameDropped.value) {
        // Auto-rename without showing dialog
        await renameFile(processedFile, context);

        // Show success notification
        if (context.mounted) {
          showMacosAlertDialog(
            context: context,
            builder: (context) => MacosAlertDialog(
              appIcon: const MacosIcon(CupertinoIcons.checkmark_circle_fill),
              title: const Text('File Processed'),
              message: Text(
                'Successfully processed and renamed:\n${processedFile.vendor}',
              ),
              primaryButton: PushButton(
                controlSize: ControlSize.large,
                child: const Text('OK'),
                onPressed: () => Navigator.of(context).pop(),
              ),
            ),
          );
        }
      } else {
        // Show file detail dialog for manual review
        await showMacosSheet(
          context: context,
          barrierDismissible: true,
          builder: (context) => FileDetailDialog(initialFile: processedFile),
        );
      }
    } else if (processedFile.error != null && context.mounted) {
      // Show error dialog
      showMacosAlertDialog(
        context: context,
        builder: (context) => MacosAlertDialog(
          appIcon: const MacosIcon(CupertinoIcons.exclamationmark_triangle),
          title: const Text('Processing Failed'),
          message: Text('Error processing file:\n${processedFile.error}'),
          primaryButton: PushButton(
            controlSize: ControlSize.large,
            child: const Text('OK'),
            onPressed: () => Navigator.of(context).pop(),
          ),
        ),
      );
    }
  }

  /// Bulk rename multiple files using the filename template
  Future<BulkRenameResult> bulkRenameFiles(
    List<PdfDocument> files,
    BuildContext context,
  ) async {
    int successCount = 0;
    int failureCount = 0;
    final List<String> errors = [];

    for (var file in files) {
      // Skip files without vendor (not processed)
      if (file.vendor == null) {
        continue;
      }

      try {
        // Use the filename template
        final newName = FilenameTemplateService.applyTemplate(
          filenameTemplate.value,
          file,
        );
        final newPath = path.join(path.dirname(file.path), newName);

        // Skip if already has correct name
        if (file.path == newPath) {
          continue;
        }

        // Check if target file already exists
        if (File(newPath).existsSync()) {
          errors.add('${file.name}: Target file already exists');
          failureCount++;
          continue;
        }

        // Find the file in the appropriate list
        final folderIndex = pdfFiles.indexOf(file);
        final individualIndex = individualFiles.indexOf(file);

        if (folderIndex == -1 && individualIndex == -1) {
          continue;
        }

        // Perform the actual filesystem rename
        await File(file.path).rename(newPath);

        // Update the file in the appropriate list
        if (folderIndex != -1) {
          pdfFiles[folderIndex] = file.copyWith(name: newName, path: newPath);
        } else {
          individualFiles[individualIndex] = file.copyWith(
            name: newName,
            path: newPath,
          );
        }

        successCount++;
      } on FileSystemException catch (e) {
        errors.add('${file.name}: ${e.message}');
        failureCount++;
      } catch (e) {
        errors.add('${file.name}: $e');
        failureCount++;
      }
    }

    // Persist changes if any succeeded
    if (successCount > 0) {
      await saveSettings();
    }

    return BulkRenameResult(
      successCount: successCount,
      failureCount: failureCount,
      errors: errors,
    );
  }
}

class BulkRenameResult {
  final int successCount;
  final int failureCount;
  final List<String> errors;

  BulkRenameResult({
    required this.successCount,
    required this.failureCount,
    required this.errors,
  });

  bool get hasErrors => failureCount > 0;
  int get totalProcessed => successCount + failureCount;
}
