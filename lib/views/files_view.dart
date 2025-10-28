import 'package:flutter/cupertino.dart';
import 'package:intl/intl.dart';
import 'package:invoicer/dialogs/export_settings_dialog.dart';
import 'package:invoicer/dialogs/file_detail_dialog.dart';
import 'package:invoicer/models.dart';
import 'package:invoicer/models/export_settings.dart';
import 'package:invoicer/services/export_service.dart';
import 'package:invoicer/state.dart';
import 'package:macos_ui/macos_ui.dart';
import 'package:path/path.dart' as path;
import 'package:signals/signals_flutter.dart';

class FilesView extends StatefulWidget {
  final AppState appState;

  const FilesView({super.key, required this.appState});

  @override
  State<FilesView> createState() => _FilesViewState();
}

class _FilesViewState extends State<FilesView> {
  @override
  Widget build(BuildContext context) {
    return Watch((context) {
      final currentFolder = widget.appState.currentlySelectedFolder.value;
      final allFiles = widget.appState.allFiles;

      if (allFiles.isEmpty && currentFolder == null) {
        return _buildEmptyState(context);
      }

      if (allFiles.isEmpty) {
        return _buildNoFilesState(context, currentFolder);
      }

      return SingleChildScrollView(
        physics: const ClampingScrollPhysics(),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Current folder info (if applicable)
            if (currentFolder != null) ...[
              _buildCurrentFolderInfo(context, currentFolder),
              const SizedBox(height: 16),
            ],

            // Export Toolbar
            _buildExportToolbar(context, allFiles),
            const SizedBox(height: 16),

            // Table Header
            _buildTableHeader(context),

            // Table Rows
            ...allFiles.asMap().entries.map((
              MapEntry<int, PdfDocument> entry,
            ) {
              return _buildFileRow(context, entry.key, entry.value);
            }),
          ],
        ),
      );
    });
  }

  Widget _buildFileRow(BuildContext context, int index, PdfDocument file) {
    return GestureDetector(
      onTap: () => _showFileDetails(file),
      behavior: HitTestBehavior.opaque,
      child: Container(
        height: 42,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: index % 2 == 0
              ? MacosTheme.of(context).canvasColor
              : CupertinoColors.quaternarySystemFill,
          border: Border(
            bottom: BorderSide(
              color: MacosTheme.of(context).dividerColor,
              width: 0.5,
            ),
          ),
        ),
        child: Row(
          children: [
            // File Name with icon
            Expanded(
              flex: 3,
              child: Row(
                children: [
                  MacosTooltip(
                    message: _getFileTooltip(file),
                    child: MacosIcon(
                      _getFileIcon(file),
                      size: 16,
                      color: _getFileIconColor(file),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      file.name,
                      style: MacosTheme.of(context).typography.body,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
            // Source
            Expanded(
              flex: 2,
              child: Text(
                file.source == 'folder'
                    ? (file.folderPath != null
                        ? path.basename(file.folderPath!)
                        : 'Folder')
                    : 'Individual',
                style: MacosTheme.of(context).typography.body.copyWith(
                  color: CupertinoColors.systemGrey,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            // Vendor
            Expanded(
              flex: 2,
              child: Text(
                file.vendor ??
                    (file.error != null
                        ? 'Error'
                        : file.isProcessing
                            ? 'Processing...'
                            : '-'),
                style: MacosTheme.of(context).typography.body.copyWith(
                      color:
                          file.error != null ? CupertinoColors.systemRed : null,
                    ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            // Date
            Expanded(
              flex: 2,
              child: Text(
                file.invoiceDate != null
                    ? DateFormat('MMM dd, yyyy').format(file.invoiceDate!)
                    : '-',
                style: MacosTheme.of(context).typography.body,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            // Items Count
            Expanded(
              child: Text(
                file.items.isNotEmpty ? '${file.items.length}' : '-',
                style: MacosTheme.of(context).typography.body,
              ),
            ),
            // Actions
            SizedBox(
              width: 100,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  if (file.vendor == null &&
                      !file.isProcessing &&
                      file.error == null)
                    MacosTooltip(
                      message: 'Process this file with AI',
                      child: MacosIconButton(
                        padding: EdgeInsets.zero,
                        icon: const MacosIcon(
                          CupertinoIcons.wand_stars,
                          size: 16,
                        ),
                        onPressed: () => widget.appState.processFile(file),
                      ),
                    )
                  else if (file.isProcessing)
                    const MacosTooltip(
                      message: 'Processing in progress...',
                      child: SizedBox(
                        width: 16,
                        height: 16,
                        child: ProgressCircle(radius: 8),
                      ),
                    )
                  else if (file.error != null)
                    MacosTooltip(
                      message: 'Retry processing this file',
                      child: MacosIconButton(
                        padding: EdgeInsets.zero,
                        icon: const MacosIcon(
                          CupertinoIcons.wand_stars,
                          size: 16,
                        ),
                        onPressed: () => widget.appState.processFile(file),
                      ),
                    )
                  else if (file.vendor != null)
                    MacosTooltip(
                      message: 'Rename this file',
                      child: MacosIconButton(
                        padding: EdgeInsets.zero,
                        icon: const MacosIcon(CupertinoIcons.pencil,
                            size: 16),
                        onPressed: () => widget.appState.renameFile(
                          file,
                          context,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _getFileTooltip(PdfDocument file) {
    if (file.error != null) {
      return 'Error: ${file.error}';
    } else if (file.vendor != null) {
      return 'Processed successfully';
    } else if (file.isProcessing) {
      return 'Processing in progress...';
    } else {
      return 'Not processed yet';
    }
  }

  IconData _getFileIcon(PdfDocument file) {
    if (file.error != null) {
      return CupertinoIcons.exclamationmark_triangle;
    } else if (file.vendor != null) {
      return CupertinoIcons.doc_checkmark_fill;
    } else if (file.isProcessing) {
      return CupertinoIcons.clock;
    } else {
      return CupertinoIcons.doc_fill;
    }
  }

  Color _getFileIconColor(PdfDocument file) {
    if (file.error != null) {
      return CupertinoColors.systemRed;
    } else if (file.vendor != null) {
      return CupertinoColors.systemGreen;
    } else if (file.isProcessing) {
      return CupertinoColors.systemOrange;
    } else {
      return CupertinoColors.systemGrey;
    }
  }

  Future _showFileDetails(PdfDocument file) {
    return showMacosSheet(
      context: context,
      barrierDismissible: true,
      builder: (context) => FileDetailDialog(initialFile: file),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const MacosIcon(
            CupertinoIcons.plus_rectangle_on_rectangle,
            size: 80,
            color: CupertinoColors.placeholderText,
          ),
          const SizedBox(height: 24),
          Text(
            'No Files Added',
            style: MacosTheme.of(context).typography.title1,
          ),
          const SizedBox(height: 8),
          Text(
            'Add PDF files by selecting a folder or individual files',
            style: MacosTheme.of(context).typography.body,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              PushButton(
                controlSize: ControlSize.large,
                onPressed: () => widget.appState.currentView.value = 'folders',
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    MacosIcon(CupertinoIcons.folder),
                    SizedBox(width: 8),
                    Text('Add Folder'),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              PushButton(
                controlSize: ControlSize.large,
                onPressed: widget.appState.addIndividualFiles,
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    MacosIcon(CupertinoIcons.plus_rectangle),
                    SizedBox(width: 8),
                    Text('Add Files'),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildNoFilesState(
    BuildContext context,
    ProjectFolder? currentFolder,
  ) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const MacosIcon(
            CupertinoIcons.doc,
            size: 64,
            color: CupertinoColors.placeholderText,
          ),
          const SizedBox(height: 16),
          Text(
            'No PDF Files Found',
            style: MacosTheme.of(context).typography.title1,
          ),
          const SizedBox(height: 8),
          if (currentFolder != null)
            Text(
              'The folder "${currentFolder.name}" doesn\'t contain any PDF files',
              style: MacosTheme.of(context).typography.body,
              textAlign: TextAlign.center,
            )
          else
            Text(
              'Use the Add Files button to select PDF files',
              style: MacosTheme.of(context).typography.body,
              textAlign: TextAlign.center,
            ),
          const SizedBox(height: 24),
          PushButton(
            controlSize: ControlSize.large,
            onPressed: widget.appState.addIndividualFiles,
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                MacosIcon(CupertinoIcons.plus_rectangle),
                SizedBox(width: 8),
                Text('Add Files'),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCurrentFolderInfo(
    BuildContext context,
    ProjectFolder currentFolder,
  ) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: MacosTheme.of(context).canvasColor.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: MacosTheme.of(context).dividerColor),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              spacing: 4,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  currentFolder.name,
                  style: MacosTheme.of(context).typography.headline,
                ),
                Text(
                  currentFolder.path,
                  style: MacosTheme.of(context).typography.caption1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTableHeader(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: MacosTheme.of(context).canvasColor,
        border: Border(
          bottom: BorderSide(
            color: MacosTheme.of(context).dividerColor,
            width: 0.5,
          ),
        ),
      ),
      child: Row(
        children: [
          const Expanded(flex: 3, child: Text('File Name')),
          const Expanded(flex: 2, child: Text('Source')),
          const Expanded(flex: 2, child: Text('Vendor')),
          const Expanded(flex: 2, child: Text('Date')),
          const Expanded(child: Text('Items')),
          const SizedBox(width: 100), // Actions column
        ],
      ),
    );
  }

  Widget _buildExportToolbar(BuildContext context, List<PdfDocument> files) {
    // Only show processed files
    final processedFiles = files.where((f) => f.vendor != null).toList();
    final hasProcessedFiles = processedFiles.isNotEmpty;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: MacosTheme.of(context).canvasColor.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: MacosTheme.of(context).dividerColor),
      ),
      child: Row(
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '${processedFiles.length} processed invoice${processedFiles.length != 1 ? 's' : ''}',
                style: MacosTheme.of(context).typography.body,
              ),
              const SizedBox(height: 2),
              Text(
                'Export or bulk rename',
                style: MacosTheme.of(context).typography.caption1.copyWith(
                      color: CupertinoColors.systemGrey,
                    ),
              ),
            ],
          ),
          const Spacer(),
          // Bulk Rename Button
          PushButton(
            controlSize: ControlSize.regular,
            onPressed: hasProcessedFiles
                ? () => _bulkRenameFiles(context, processedFiles)
                : null,
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                MacosIcon(CupertinoIcons.pencil_circle, size: 16),
                SizedBox(width: 6),
                Text('Bulk Rename'),
              ],
            ),
          ),
          const SizedBox(width: 16),
          // Export buttons
          PushButton(
            controlSize: ControlSize.regular,
            secondary: true,
            onPressed: hasProcessedFiles
                ? () => _exportFiles(context, processedFiles, ExportFormat.csv)
                : null,
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                MacosIcon(CupertinoIcons.table, size: 16),
                SizedBox(width: 6),
                Text('CSV'),
              ],
            ),
          ),
          const SizedBox(width: 8),
          PushButton(
            controlSize: ControlSize.regular,
            secondary: true,
            onPressed: hasProcessedFiles
                ? () => _exportFiles(context, processedFiles, ExportFormat.json)
                : null,
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                MacosIcon(CupertinoIcons.doc_text, size: 16),
                SizedBox(width: 6),
                Text('JSON'),
              ],
            ),
          ),
          const SizedBox(width: 8),
          PushButton(
            controlSize: ControlSize.regular,
            secondary: true,
            onPressed: hasProcessedFiles
                ? () =>
                    _exportFiles(context, processedFiles, ExportFormat.excel)
                : null,
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                MacosIcon(CupertinoIcons.table_badge_more, size: 16),
                SizedBox(width: 6),
                Text('Excel'),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _exportFiles(
    BuildContext context,
    List<PdfDocument> files,
    ExportFormat format,
  ) async {
    // Show export settings dialog first
    final settings = await showMacosSheet<ExportSettings>(
      context: context,
      builder: (context) => ExportSettingsDialog(
        initialSettings: ExportSettings.defaultSettings,
      ),
    );

    // User cancelled
    if (settings == null || !context.mounted) return;

    try {
      String? outputPath;

      switch (format) {
        case ExportFormat.csv:
          outputPath = await ExportService.exportToCSV(
            files,
            settings: settings,
          );
          break;
        case ExportFormat.json:
          outputPath = await ExportService.exportToJSON(
            files,
            settings: settings,
          );
          break;
        case ExportFormat.excel:
          outputPath = await ExportService.exportToExcel(
            files,
            settings: settings,
          );
          break;
      }

      if (outputPath != null && context.mounted) {
        showMacosAlertDialog(
          context: context,
          builder: (context) => MacosAlertDialog(
            appIcon: const MacosIcon(CupertinoIcons.check_mark_circled),
            title: const Text('Export Successful'),
            message: Text(
              'Exported ${files.length} invoice${files.length != 1 ? 's' : ''} to:\n$outputPath',
            ),
            primaryButton: PushButton(
              controlSize: ControlSize.large,
              child: const Text('OK'),
              onPressed: () => Navigator.of(context).pop(),
            ),
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        showMacosAlertDialog(
          context: context,
          builder: (context) => MacosAlertDialog(
            appIcon: const MacosIcon(CupertinoIcons.exclamationmark_triangle),
            title: const Text('Export Failed'),
            message: Text('Failed to export files: $e'),
            primaryButton: PushButton(
              controlSize: ControlSize.large,
              child: const Text('OK'),
              onPressed: () => Navigator.of(context).pop(),
            ),
          ),
        );
      }
    }
  }

  Future<void> _bulkRenameFiles(
    BuildContext context,
    List<PdfDocument> files,
  ) async {
    // Show confirmation dialog first
    final confirmed = await showMacosAlertDialog<bool>(
      context: context,
      builder: (context) => MacosAlertDialog(
        appIcon: const MacosIcon(CupertinoIcons.pencil_circle),
        title: const Text('Bulk Rename'),
        message: Text(
          'Rename ${files.length} processed file${files.length != 1 ? 's' : ''} using the filename template?\n\n'
          'Template: ${widget.appState.filenameTemplate.value}',
        ),
        primaryButton: PushButton(
          controlSize: ControlSize.large,
          child: const Text('Rename'),
          onPressed: () => Navigator.of(context).pop(true),
        ),
        secondaryButton: PushButton(
          controlSize: ControlSize.large,
          secondary: true,
          child: const Text('Cancel'),
          onPressed: () => Navigator.of(context).pop(false),
        ),
      ),
    );

    if (confirmed != true || !context.mounted) return;

    // Show progress indicator
    showMacosAlertDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => MacosAlertDialog(
        appIcon: const MacosIcon(CupertinoIcons.clock),
        title: const Text('Renaming Files'),
        message: const Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Please wait...'),
            SizedBox(height: 16),
            ProgressCircle(),
          ],
        ),
        primaryButton: PushButton(
          controlSize: ControlSize.large,
          onPressed: null,
          child: const Text('Please wait...'),
        ),
      ),
    );

    try {
      final result = await widget.appState.bulkRenameFiles(files, context);

      if (context.mounted) {
        // Close progress dialog
        Navigator.of(context).pop();

        // Show result dialog
        showMacosAlertDialog(
          context: context,
          builder: (context) => MacosAlertDialog(
            appIcon: MacosIcon(
              result.hasErrors
                  ? CupertinoIcons.exclamationmark_triangle
                  : CupertinoIcons.check_mark_circled,
            ),
            title: const Text('Bulk Rename Complete'),
            message: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Successfully renamed: ${result.successCount}\n'
                    'Failed: ${result.failureCount}',
                  ),
                  if (result.errors.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    const Text(
                      'Errors:',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 4),
                    ...result.errors.take(5).map(
                          (error) => Padding(
                            padding: const EdgeInsets.only(top: 2),
                            child: Text(
                              '• $error',
                              style: const TextStyle(fontSize: 12),
                            ),
                          ),
                        ),
                    if (result.errors.length > 5)
                      Text(
                        '\n... and ${result.errors.length - 5} more errors',
                        style: const TextStyle(fontSize: 12),
                      ),
                  ],
                ],
              ),
            ),
            primaryButton: PushButton(
              controlSize: ControlSize.large,
              child: const Text('OK'),
              onPressed: () => Navigator.of(context).pop(),
            ),
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        // Close progress dialog
        Navigator.of(context).pop();

        showMacosAlertDialog(
          context: context,
          builder: (context) => MacosAlertDialog(
            appIcon: const MacosIcon(CupertinoIcons.exclamationmark_triangle),
            title: const Text('Bulk Rename Failed'),
            message: Text('An error occurred: $e'),
            primaryButton: PushButton(
              controlSize: ControlSize.large,
              child: const Text('OK'),
              onPressed: () => Navigator.of(context).pop(),
            ),
          ),
        );
      }
    }
  }
}
