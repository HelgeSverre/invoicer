// State Management
import 'dart:convert';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:intl/intl.dart';
import 'package:invoicer/extractor.dart';
import 'package:invoicer/models.dart';
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
  final currentView = signal<String>('files'); // 'folders' or 'files'

  final pdfFiles = listSignal<PdfDocument>([]);
  final individualFiles = listSignal<PdfDocument>(
    [],
  ); // Files added individually
  final apiKey = signal<String>("");
  final aiModel = signal<String>("gpt-4.1-mini");
  final promptTemplate = signal<String>(
    'Additional instructions for AI processing (currently unused - extraction is guided by function definitions)',
  );
  final isProcessingAll = signal<bool>(false);

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
    promptTemplate.value =
        prefs.getString('prompt_template') ?? promptTemplate.value;

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
    currentView.value = prefs.getString('current_view') ?? 'files';

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
    await prefs.setString('prompt_template', promptTemplate.value);

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
    if (file.invoiceDate == null || file.vendor == null) {
      return;
    }

    final dateStr = DateFormat('yyyy-MM-dd').format(file.invoiceDate!);
    final sanitizedVendor = file.vendor!.replaceAll(
      RegExp(r'[<>:"/\\|?*]'),
      '_',
    );
    final newName = '$dateStr - $sanitizedVendor.pdf';
    final newPath = path.join(path.dirname(file.path), newName);

    try {
      // await File(file.path).rename(newPath);

      final index = pdfFiles.indexOf(file);
      if (index != -1) {
        pdfFiles[index] = file.copyWith(name: newName, path: newPath);
      }
    } catch (e) {
      print(e);
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
}
