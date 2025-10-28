import 'dart:io';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart' show ThemeMode;
import 'package:flutter/services.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:invoicer/dialogs/settings_dialog.dart';
import 'package:invoicer/logger.dart';
import 'package:invoicer/state.dart';
import 'package:invoicer/utils.dart';
import 'package:invoicer/views/files_view.dart';
import 'package:invoicer/views/overview_view.dart';
import 'package:macos_ui/macos_ui.dart';
import 'package:signals/signals_flutter.dart' hide signal;

Future<void> _bootstrap() async {
  WidgetsFlutterBinding.ensureInitialized();

  await dotenv.load(fileName: ".env", isOptional: true);

  if (Platform.isMacOS) {
    const config = MacosWindowUtilsConfig();
    await config.apply();
  }
}

Future<void> main() async {
  await _bootstrap();

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

  @override
  void initState() {
    super.initState();
    appState = AppState();
    _initializeApp();
  }

  Future<void> _initializeApp() async {
    await appState.loadSettings();

    // Load cached extracted data
    await appState.loadExtractedData();

    // Auto-select first folder if available and no current selection
    if (appState.currentlySelectedFolder.value == null &&
        appState.projectFolders.isNotEmpty) {
      appState.selectFolder(appState.projectFolders.first);
    }

    // Load PDF files if folder is selected
    if (appState.currentlySelectedFolder.value != null) {
      appState.loadPDFFiles();
    }
  }

  void _openSettings() {
    showMacosSheet(
      context: context,
      barrierDismissible: true,
      builder: (context) => SettingsDialog(
        appState: appState,
      ),
    );
  }

  void _showAboutDialog() {
    showMacosAlertDialog(
      context: context,
      builder: (context) => MacosAlertDialog(
        appIcon: const FlutterLogo(size: 64),
        title: const Text('About Invoicer'),
        message: const Text(
          'Version 1.0.0\n\n'
          'A Flutter desktop app for processing invoices and receipts with OpenAI.\n\n'
          'Copyright © 2025 Liseth Solutions. All rights reserved.',
        ),
        primaryButton: PushButton(
          controlSize: ControlSize.large,
          child: const Text('OK'),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
    );
  }

  void _openLogDirectory() {
    revealFolderInFinder(AppLogger.logDirectory);
  }

  void _quitApp() {
    exit(0);
  }

  int _getSidebarIndex(String currentView) {
    // Map currentView to sidebar index
    // 0: Overview
    // 1+: Folders (dynamic)
    // Last: All Files
    if (currentView == 'overview') return 0;
    if (currentView == 'all_files') return 1 + appState.projectFolders.length;

    // Check if it's a folder view
    final folderIndex = appState.projectFolders.indexWhere(
      (f) => currentView == 'folder_${f.path}',
    );
    if (folderIndex != -1) {
      return 1 + folderIndex;
    }

    return 0; // Default to overview
  }

  @override
  Widget build(BuildContext context) {
    return Watch((context) {
      final currentView = appState.currentView.value;
      final sidebarIndex = _getSidebarIndex(currentView);

      return PlatformMenuBar(
        menus: [
          PlatformMenu(
            label: 'Invoicer',
            menus: [
              // About menu item
              PlatformMenuItemGroup(
                members: [
                  PlatformMenuItem(
                    label: 'About Invoicer',
                    onSelected: _showAboutDialog,
                  ),
                ],
              ),
              // Log directory menu item
              PlatformMenuItemGroup(
                members: [
                  PlatformMenuItem(
                    label: 'Open Log Directory…',
                    onSelected: _openLogDirectory,
                  ),
                ],
              ),
              // Preferences menu item (separated by macOS automatically)
              PlatformMenuItemGroup(
                members: [
                  PlatformMenuItem(
                    label: 'Preferences…',
                    shortcut: const SingleActivator(
                      LogicalKeyboardKey.comma,
                      meta: true,
                    ),
                    onSelected: _openSettings,
                  ),
                ],
              ),
              // Quit menu item
              PlatformMenuItemGroup(
                members: [
                  PlatformMenuItem(
                    label: 'Quit Invoicer',
                    shortcut: const SingleActivator(
                      LogicalKeyboardKey.keyQ,
                      meta: true,
                    ),
                    onSelected: _quitApp,
                  ),
                ],
              ),
            ],
          ),
        ],
        child: Focus(
          autofocus: true,
          child: CallbackShortcuts(
            bindings: {
              const SingleActivator(
                LogicalKeyboardKey.comma,
                meta: true,
              ): _openSettings,
              const SingleActivator(
                LogicalKeyboardKey.keyQ,
                meta: true,
              ): _quitApp,
            },
            child: MacosWindow(
              disableWallpaperTinting: true,
              sidebar: Sidebar(
                minWidth: 220,
                builder: (context, scrollController) {
                  return Watch((context) {
                    final folders = appState.projectFolders;

                    // Build sidebar items
                    final items = <SidebarItem>[
                      // Overview section
                      const SidebarItem(section: true, label: Text('Overview')),
                      const SidebarItem(
                        leading: MacosIcon(CupertinoIcons.chart_bar_square),
                        label: Text('Dashboard'),
                      ),

                      // Projects section (folders)
                      const SidebarItem(section: true, label: Text('Projects')),
                      ...folders.map((folder) => SidebarItem(
                            leading:
                                const MacosIcon(CupertinoIcons.folder_fill),
                            label: Text(folder.name),
                            trailing: Text(
                              '${folder.fileCount}',
                              style: const TextStyle(
                                color: CupertinoColors.systemGrey,
                                fontSize: 12,
                              ),
                            ),
                          )),

                      // All Files section
                      const SidebarItem(
                          section: true, label: Text('All Files')),
                      SidebarItem(
                        leading: const MacosIcon(CupertinoIcons.doc_on_doc),
                        label: const Text('All Files'),
                        trailing: Text(
                          '${appState.allFiles.length}',
                          style: const TextStyle(
                            color: CupertinoColors.systemGrey,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ];

                    return SidebarItems(
                      currentIndex: sidebarIndex,
                      scrollController: scrollController,
                      onChanged: (i) {
                        // Calculate which view to show based on index
                        if (i == 0) {
                          // Overview
                          appState.currentView.value = 'overview';
                        } else if (i <= folders.length) {
                          // Folder (index 1 to folders.length)
                          final folderIndex = i - 1;
                          if (folderIndex < folders.length) {
                            final folder = folders[folderIndex];
                            appState.selectFolder(folder);
                            appState.currentView.value =
                                'folder_${folder.path}';
                          }
                        } else {
                          // All Files
                          appState.currentView.value = 'all_files';
                        }
                      },
                      items: items,
                    );
                  });
                },
              ),
              child: _buildMainContent(),
            ),
          ),
        ),
      );
    });
  }

  Widget _buildMainContent() {
    return Watch((context) {
      final currentView = appState.currentView.value;

      if (currentView == 'overview') {
        return _buildOverviewView();
      } else if (currentView == 'all_files') {
        return _buildAllFilesView();
      } else if (currentView.startsWith('folder_')) {
        return _buildFilesView();
      }

      // Default to overview
      return _buildOverviewView();
    });
  }

  Widget _buildOverviewView() {
    return MacosScaffold(
      toolBar: ToolBar(
        centerTitle: false,
        title: const Text('Invoicer - Overview'),
        actions: [
          ToolBarIconButton(
            label: 'Settings',
            icon: const MacosIcon(CupertinoIcons.settings),
            onPressed: _openSettings,
            showLabel: false,
            tooltipMessage: 'Open application settings (⌘,)',
          ),
          ToolBarIconButton(
            label: 'Add Folder',
            icon: const MacosIcon(CupertinoIcons.folder_badge_plus),
            onPressed: appState.pickAndAddFolder,
            showLabel: false,
            tooltipMessage: 'Add a folder containing PDF receipts',
          ),
        ],
      ),
      children: [
        ContentArea(
          builder: (context, scrollController) {
            return OverviewView(appState: appState);
          },
        ),
      ],
    );
  }

  Widget _buildAllFilesView() {
    return Watch((context) {
      final hasFiles = appState.allFiles.isNotEmpty;
      final isProcessing = appState.isProcessingAll.value;

      return MacosScaffold(
        toolBar: ToolBar(
          centerTitle: false,
          title: const Text('Invoicer - All Files'),
          actions: [
            ToolBarIconButton(
              label: 'Settings',
              icon: const MacosIcon(CupertinoIcons.settings),
              onPressed: _openSettings,
              showLabel: false,
              tooltipMessage: 'Open application settings (⌘,)',
            ),
            ToolBarIconButton(
              label: 'Add Files',
              icon: const MacosIcon(CupertinoIcons.plus),
              onPressed: appState.addIndividualFiles,
              showLabel: false,
              tooltipMessage: 'Add individual PDF files',
            ),
            if (hasFiles) ...[
              ToolBarIconButton(
                label: 'Process All',
                icon: isProcessing
                    ? const MacosIcon(CupertinoIcons.clock)
                    : const MacosIcon(CupertinoIcons.play_fill),
                onPressed: isProcessing
                    ? null
                    : () {
                        // Process all files from all sources
                        for (var file in appState.allFiles) {
                          appState.processFile(file);
                        }
                      },
                showLabel: false,
                tooltipMessage: isProcessing
                    ? 'Processing all files...'
                    : 'Process all PDF files',
              ),
            ],
          ],
        ),
        children: [
          ContentArea(
            builder: (context, scrollController) {
              return FilesView(
                appState: appState,
                showAllFiles: true,
              );
            },
          ),
        ],
      );
    });
  }

  Widget _buildFilesView() {
    return Watch((context) {
      final hasFiles = appState.pdfFiles.isNotEmpty;
      final isProcessing = appState.isProcessingAll.value;
      final currentFolder = appState.currentlySelectedFolder.value;

      return MacosScaffold(
        toolBar: ToolBar(
          centerTitle: false,
          title: const Text('Invoicer'),
          actions: [
            ToolBarIconButton(
              label: 'Settings',
              icon: const MacosIcon(CupertinoIcons.settings),
              onPressed: _openSettings,
              showLabel: false,
              tooltipMessage: 'Open application settings (⌘,)',
            ),
            ToolBarIconButton(
              label: 'Open Folder',
              icon: const MacosIcon(CupertinoIcons.folder_open),
              onPressed: currentFolder != null
                  ? () => revealFolderInFinder(currentFolder.path)
                  : null,
              showLabel: false,
              tooltipMessage: 'Open current folder in Finder',
            ),
            ToolBarIconButton(
              label: 'Add Files',
              icon: const MacosIcon(CupertinoIcons.plus),
              onPressed: appState.addIndividualFiles,
              showLabel: false,
              tooltipMessage: 'Add individual PDF files',
            ),
            if (currentFolder != null && hasFiles) ...[
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
        ),
        children: [
          ContentArea(
            builder: (context, scrollController) {
              return FilesView(
                appState: appState,
                showAllFiles: false,
              );
            },
          ),
        ],
      );
    });
  }
}
