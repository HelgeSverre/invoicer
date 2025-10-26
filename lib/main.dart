import 'dart:io';

import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart' show ThemeMode;
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:invoicer/dialogs/settings_dialog.dart';
import 'package:invoicer/state.dart';
import 'package:invoicer/views/files_view.dart';
import 'package:invoicer/views/folders_view.dart';
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

  @override
  void initState() {
    super.initState();
    appState = AppState();
    _initializeApp();
  }

  Future<void> _initializeApp() async {
    await appState.loadSettings();

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

  @override
  Widget build(BuildContext context) {
    return Watch((context) {
      final currentView = appState.currentView.value;
      final sidebarIndex = currentView == 'folders' ? 0 : 1;

      return MacosWindow(
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
            onPressed: () {
              showMacosSheet(
                context: context,
                barrierDismissible: true,
                builder: (context) => SettingsDialog(
                  appState: appState,
                ),
              );
            },
            showLabel: true,
            tooltipMessage: 'Open application settings',

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
