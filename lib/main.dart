import 'dart:io';

import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart' show ThemeMode;
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:intl/intl.dart';
import 'package:invoicer/dialogs/file_detail_dialog.dart';
import 'package:invoicer/models.dart';
import 'package:invoicer/state.dart';
import 'package:macos_ui/macos_ui.dart';
import 'package:signals/signals_flutter.dart' hide signal;

Future<void> _configureMacosWindowUtils() async {
  const config = MacosWindowUtilsConfig();
  await config.apply();
}

Future<void> main() async {
  await dotenv.load(fileName: ".env");

  if (!kIsWeb) {
    if (Platform.isMacOS) {
      await _configureMacosWindowUtils();
    }
  }

  runApp(const InvoicerApp());
}

class InvoicerApp extends StatelessWidget {
  const InvoicerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MacosApp(
      title: 'Invoicer',
      theme: MacosThemeData.dark(),
      darkTheme: MacosThemeData.dark(),
      themeMode: ThemeMode.dark,
      debugShowCheckedModeBanner: false,
      home: const InvoicerMainScreen(),
    );
  }
}

class InvoicerMainScreen extends StatefulWidget {
  const InvoicerMainScreen({super.key});

  @override
  State<InvoicerMainScreen> createState() => _InvoicerMainScreenState();
}

class _InvoicerMainScreenState extends State<InvoicerMainScreen> {
  late final AppState appState;
  int sidebarIndex = 0;

  @override
  void initState() {
    super.initState();
    appState = AppState();
    _initializeApp();
  }

  Future<void> _initializeApp() async {
    await appState.loadSettings();
    if (appState.selectedFolder.value != null &&
        appState.selectedFolder.value!.isNotEmpty) {
      appState.loadPDFFiles();
    }
  }

  @override
  Widget build(BuildContext context) {
    return MacosWindow(
      disableWallpaperTinting: true,
      titleBar: TitleBar(title: const Text('Invoicer')),
      sidebar: Sidebar(
        minWidth: 200,
        builder: (context, scrollController) {
          return SidebarItems(
            currentIndex: sidebarIndex,
            scrollController: scrollController,
            onChanged: (i) => setState(() => sidebarIndex = i),
            items: const [
              SidebarItem(
                leading: MacosIcon(CupertinoIcons.folder),
                label: Text('Files'),
              ),
            ],
          );
        },
      ),
      child: IndexedStack(index: sidebarIndex, children: [_buildFilesView()]),
    );
  }

  Widget _buildFilesView() {
    return Watch((context) {
      final hasFiles = appState.pdfFiles.isNotEmpty;
      final isProcessing = appState.isProcessingAll.value;
      final selectedFolder = appState.selectedFolder.value;

      return MacosScaffold(
        toolBar: ToolBar(
          centerTitle: false,
          title: const Text('Invoicer'),
          actions: [
            if (selectedFolder == null)
              ToolBarIconButton(
                label: 'Select Folder',
                icon: const MacosIcon(CupertinoIcons.folder_badge_plus),
                onPressed: appState.selectFolder,
                showLabel: true,
                tooltipMessage: 'Select a folder containing PDF receipts',
              )
            else ...[
              ToolBarIconButton(
                label: 'Change Folder',
                icon: const MacosIcon(CupertinoIcons.folder_badge_plus),
                onPressed: appState.selectFolder,
                showLabel: false,
                tooltipMessage: 'Select a different folder',
              ),
              if (hasFiles) ...[
                ToolBarIconButton(
                  label: 'Process All',
                  icon: isProcessing
                      ? const MacosIcon(CupertinoIcons.clock)
                      : const MacosIcon(CupertinoIcons.play_fill),
                  onPressed: isProcessing ? null : appState.processAllFiles,
                  showLabel: false,
                  tooltipMessage: isProcessing
                      ? 'Processing all files...'
                      : 'Process all PDF files',
                ),
              ],
            ],
            // const ToolBarSpacer(),
            // ToolBarIconButton(
            //   label: 'Settings',
            //   icon: const MacosIcon(CupertinoIcons.gear),
            //   onPressed: _showSettings,
            //   showLabel: false,
            //   tooltipMessage: 'Open application settings',
            // ),
          ],
        ),
        children: [
          ContentArea(
            builder: (context, scrollController) {
              return Watch((context) {
                if (appState.selectedFolder.value == null) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const MacosIcon(
                          CupertinoIcons.folder_badge_plus,
                          size: 80,
                          color: CupertinoColors.placeholderText,
                        ),
                        const SizedBox(height: 24),
                        Text(
                          'Select a Folder',
                          style: MacosTheme.of(context).typography.title1,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Choose a folder containing PDF receipts to get started',
                          style: MacosTheme.of(context).typography.body,
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 24),
                        PushButton(
                          controlSize: ControlSize.large,
                          onPressed: appState.selectFolder,
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              MacosIcon(CupertinoIcons.folder_badge_plus),
                              SizedBox(width: 8),
                              Text('Select Folder'),
                            ],
                          ),
                        ),
                      ],
                    ),
                  );
                }

                if (appState.pdfFiles.isEmpty) {
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
                        Text(
                          'The selected folder doesn\'t contain any PDF files',
                          style: MacosTheme.of(context).typography.body,
                        ),
                      ],
                    ),
                  );
                }

                return SingleChildScrollView(
                  controller: scrollController,
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      // Table Header
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
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
                            const SizedBox(width: 32), // Icon column
                            Expanded(
                              flex: 4,
                              child: Text(
                                'File Name',
                                style: MacosTheme.of(context)
                                    .typography
                                    .headline
                                    .copyWith(fontWeight: FontWeight.w600),
                              ),
                            ),
                            Expanded(
                              flex: 2,
                              child: Text(
                                'Vendor',
                                style: MacosTheme.of(context)
                                    .typography
                                    .headline
                                    .copyWith(fontWeight: FontWeight.w600),
                              ),
                            ),
                            Expanded(
                              flex: 2,
                              child: Text(
                                'Date',
                                style: MacosTheme.of(context)
                                    .typography
                                    .headline
                                    .copyWith(fontWeight: FontWeight.w600),
                              ),
                            ),
                            Expanded(
                              child: Text(
                                'Items',
                                style: MacosTheme.of(context)
                                    .typography
                                    .headline
                                    .copyWith(fontWeight: FontWeight.w600),
                              ),
                            ),
                            const SizedBox(width: 100), // Actions column
                          ],
                        ),
                      ),
                      // Table Rows
                      ...appState.pdfFiles.asMap().entries.map((
                        MapEntry<int, PdfDocument> entry,
                      ) {
                        return GestureDetector(
                          onTap: () => _showFileDetails(entry.value),
                          behavior: HitTestBehavior.opaque,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 10,
                            ),
                            decoration: BoxDecoration(
                              color: entry.key % 2 == 0
                                  ? MacosTheme.of(context).canvasColor
                                  : MacosTheme.of(
                                      context,
                                    ).canvasColor.withValues(alpha: 0.5),
                              border: Border(
                                bottom: BorderSide(
                                  color: MacosTheme.of(context).dividerColor,
                                  width: 0.5,
                                ),
                              ),
                            ),
                            child: Row(
                              children: [
                                // Status Icon
                                SizedBox(
                                  width: 32,
                                  child: MacosTooltip(
                                    message: _getFileTooltip(entry.value),
                                    child: MacosIcon(
                                      _getFileIcon(entry.value),
                                      color: _getFileIconColor(
                                        context,
                                        entry.value,
                                      ),
                                      size: 18,
                                    ),
                                  ),
                                ),
                                // File Name
                                Expanded(
                                  flex: 4,
                                  child: Text(
                                    entry.value.name,
                                    style: MacosTheme.of(context)
                                        .typography
                                        .body
                                        .copyWith(
                                          color: entry.value.items.isNotEmpty
                                              ? MacosTheme.of(
                                                  context,
                                                ).primaryColor
                                              : null,
                                          decoration:
                                              entry.value.items.isNotEmpty
                                              ? TextDecoration.underline
                                              : null,
                                        ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                // Vendor
                                Expanded(
                                  flex: 2,
                                  child: Text(
                                    entry.value.vendor ??
                                        (entry.value.error != null
                                            ? 'Error'
                                            : entry.value.isProcessing
                                            ? 'Processing...'
                                            : '-'),
                                    style: MacosTheme.of(context)
                                        .typography
                                        .body
                                        .copyWith(
                                          color: entry.value.error != null
                                              ? CupertinoColors.systemRed
                                              : null,
                                        ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                // Date
                                Expanded(
                                  flex: 2,
                                  child: Text(
                                    entry.value.invoiceDate != null
                                        ? DateFormat(
                                            'MMM dd, yyyy',
                                          ).format(entry.value.invoiceDate!)
                                        : '-',
                                    style: MacosTheme.of(
                                      context,
                                    ).typography.body,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                // Items Count
                                Expanded(
                                  child: Text(
                                    entry.value.items.isNotEmpty
                                        ? '${entry.value.items.length}'
                                        : '-',
                                    style: MacosTheme.of(
                                      context,
                                    ).typography.body,
                                  ),
                                ),
                                // Actions
                                SizedBox(
                                  width: 100,
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.end,
                                    children: [
                                      if (entry.value.vendor == null &&
                                          !entry.value.isProcessing &&
                                          entry.value.error == null)
                                        MacosTooltip(
                                          message: 'Process this file with AI',
                                          child: MacosIconButton(
                                            icon: const MacosIcon(
                                              CupertinoIcons.wand_stars,
                                              size: 16,
                                            ),
                                            onPressed: () => appState
                                                .processFile(entry.value),
                                          ),
                                        )
                                      else if (entry.value.isProcessing)
                                        MacosTooltip(
                                          message: 'Processing in progress...',
                                          child: const SizedBox(
                                            width: 16,
                                            height: 16,
                                            child: ProgressCircle(radius: 8),
                                          ),
                                        )
                                      else if (entry.value.error != null)
                                        MacosTooltip(
                                          message: 'Retry processing this file',
                                          child: MacosIconButton(
                                            icon: const MacosIcon(
                                              CupertinoIcons.wand_stars,
                                              size: 16,
                                            ),
                                            onPressed: () => appState
                                                .processFile(entry.value),
                                          ),
                                        )
                                      else if (entry.value.vendor != null)
                                        MacosTooltip(
                                          message:
                                              'Rename file based on extracted data',
                                          child: MacosIconButton(
                                            icon: const MacosIcon(
                                              CupertinoIcons.square_arrow_up,
                                              size: 16,
                                            ),
                                            onPressed: () =>
                                                appState.renameFile(
                                                  entry.value,
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
                      }),
                    ],
                  ),
                );
              });
            },
          ),
        ],
      );
    });
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

  Color _getFileIconColor(BuildContext context, file) {
    return CupertinoColors.systemGrey;
  }

  void _showFileDetails(PdfDocument file) {
    showMacosSheet(
      context: context,
      barrierDismissible: true,
      builder: (context) => FileDetailDialog(initialFile: file),
    );
  }
}
