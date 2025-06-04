import 'package:flutter/cupertino.dart';
import 'package:intl/intl.dart';
import 'package:invoicer/dialogs/file_detail_dialog.dart';
import 'package:invoicer/models.dart';
import 'package:invoicer/state.dart';
import 'package:macos_ui/macos_ui.dart';
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

      return DragTarget<List<String>>(
        onAcceptWithDetails: (files) => _handleDroppedFiles(files.data),
        builder: (context, candidateData, rejectedData) {
          return Container(
            decoration: candidateData.isNotEmpty
                ? BoxDecoration(
                    border: Border.all(
                      color: MacosTheme.of(context).primaryColor,
                      width: 2,
                    ),
                    borderRadius: BorderRadius.circular(8),
                  )
                : null,
            child: SingleChildScrollView(
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

                  // Add files section
                  _buildAddFilesSection(context),
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
            ),
          );
        },
      );
    });
  }

  Widget _buildFileRow(BuildContext context, int index, PdfDocument file) {
    return GestureDetector(
      onTap: () => _showFileDetails(file),
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: index % 2 == 0
              ? MacosTheme.of(context).canvasColor
              : MacosTheme.of(context).canvasColor.withOpacity(0.5),
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
                        icon: const MacosIcon(
                          CupertinoIcons.wand_stars,
                          size: 16,
                        ),
                        onPressed: () => widget.appState.processFile(file),
                      ),
                    )
                  else if (file.vendor != null)
                    MacosTooltip(
                      message: 'Rename file based on extracted data',
                      child: MacosIconButton(
                        icon: const MacosIcon(
                          CupertinoIcons.square_arrow_up,
                          size: 16,
                        ),
                        onPressed: () =>
                            widget.appState.renameFile(file, context),
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
      return CupertinoIcons.doc_checkmark;
    } else if (file.isProcessing) {
      return CupertinoIcons.clock;
    } else {
      return CupertinoIcons.doc;
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
      return CupertinoColors.secondaryLabel;
    }
  }

  void _showFileDetails(PdfDocument file) {
    showMacosSheet(
      context: context,
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
            'Add PDF files by selecting a folder or dropping files here',
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
              'Drop PDF files here or use the Add Files button',
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
        color: MacosTheme.of(context).canvasColor.withOpacity(0.5),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: MacosTheme.of(context).dividerColor),
      ),
      child: Row(
        children: [
          const MacosIcon(CupertinoIcons.folder_fill, size: 16),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  currentFolder.name,
                  style: MacosTheme.of(context).typography.headline,
                ),
                Text(
                  currentFolder.path,
                  style: MacosTheme.of(context).typography.caption1.copyWith(
                        color: CupertinoColors.secondaryLabel,
                      ),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          PushButton(
            controlSize: ControlSize.mini,
            onPressed: () => widget.appState.currentView.value = 'folders',
            child: const Text('Change Folder'),
          ),
        ],
      ),
    );
  }

  Widget _buildAddFilesSection(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: MacosTheme.of(context).primaryColor.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: MacosTheme.of(context).primaryColor.withOpacity(0.3),
          style: BorderStyle.solid,
        ),
      ),
      child: Row(
        children: [
          const MacosIcon(CupertinoIcons.cloud_download, size: 16),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'Drop PDF files here or click Add Files',
              style: MacosTheme.of(context).typography.body,
            ),
          ),
          PushButton(
            controlSize: ControlSize.mini,
            onPressed: widget.appState.addIndividualFiles,
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                MacosIcon(CupertinoIcons.plus, size: 12),
                SizedBox(width: 4),
                Text('Add Files'),
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

  void _handleDroppedFiles(List<String> files) {
    for (String filePath in files) {
      if (filePath.toLowerCase().endsWith('.pdf')) {
        widget.appState.addIndividualFile(filePath);
      }
    }
  }
}
