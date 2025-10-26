import 'dart:io';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart' show ThemeMode;
import 'package:flutter/services.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:invoicer/dialogs/settings_dialog.dart';
import 'package:invoicer/state.dart';
import 'package:invoicer/utils.dart';
import 'package:invoicer/views/files_view.dart';
import 'package:invoicer/views/folders_view.dart';
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

  void _quitApp() {
    exit(0);
  }

  @override
  Widget build(BuildContext context) {
    return Watch((context) {
      final currentView = appState.currentView.value;
      final sidebarIndex = currentView == 'folders' ? 0 : 1;

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
                minWidth: 200,
                builder: (context, scrollController) {
                  return SidebarItems(
                    currentIndex: sidebarIndex,
                    scrollController: scrollController,
                    onChanged: (i) {
                      appState.currentView.value = i == 0 ? 'folders' : 'files';
                    },
                    items: const [
                      SidebarItem(section: true, label: Text('Documents')),
                      SidebarItem(
                        leading: MacosIcon(CupertinoIcons.folder),
                        label: Text('Folders'),
                      ),
                      SidebarItem(
                        leading: MacosIcon(CupertinoIcons.doc),
                        label: Text('Files'),
                      ),
                    ],
                  );
                },
              ),
              child: IndexedStack(
                index: sidebarIndex,
                children: [_buildFoldersView(), _buildFilesView()],
              ),
            ),
          ),
        ),
      );
    });
  }

  Widget _buildFoldersView() {
    return MacosScaffold(
      toolBar: ToolBar(
        centerTitle: false,
        title: const Text('Invoicer - Folders'),
        actions: [
          ToolBarIconButton(
            label: 'Settings',
            icon: const MacosIcon(CupertinoIcons.settings),
            onPressed: _openSettings,
            showLabel: true,
            tooltipMessage: 'Open application settings (⌘,)',
          ),
          ToolBarIconButton(
            label: 'Add Folder',
            icon: const MacosIcon(CupertinoIcons.folder_badge_plus),
            onPressed: appState.pickAndAddFolder,
            showLabel: true,
            tooltipMessage: 'Add a folder containing PDF receipts',
          ),
        ],
      ),
      children: [
        ContentArea(
          builder: (context, scrollController) {
            return FoldersView(appState: appState);
          },
        ),
      ],
    );
  }

  Widget _buildFilesView() {
    return Watch((context) {
      final hasFiles = appState.pdfFiles.isNotEmpty;
      final isProcessing = appState.isProcessingAll.value;
      final currentFolder = appState.currentlySelectedFolder.value;

      return MacosScaffold(
        toolBar: ToolBar(
          centerTitle: false,
          title: Text('Invoicer'),
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
              return FilesView(appState: appState);
            },
          ),
        ],
      );
    });
  }
}
