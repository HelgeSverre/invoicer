import 'package:flutter/cupertino.dart';
import 'package:invoicer/models.dart';
import 'package:invoicer/state.dart';
import 'package:macos_ui/macos_ui.dart';
import 'package:signals/signals_flutter.dart';

class FoldersView extends StatefulWidget {
  final AppState appState;

  const FoldersView({super.key, required this.appState});

  @override
  State<FoldersView> createState() => _FoldersViewState();
}

class _FoldersViewState extends State<FoldersView> {
  @override
  Widget build(BuildContext context) {
    return Watch((context) {
      if (widget.appState.projectFolders.isEmpty) {
        return Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const MacosIcon(
                CupertinoIcons.folder_badge_plus,
                size: 80,
                color: CupertinoColors.systemGrey,
              ),
              const SizedBox(height: 24),
              Text(
                'No Folders Added',
                style: MacosTheme.of(context).typography.title1,
              ),
              const SizedBox(height: 8),
              Text(
                'Add folders containing PDF receipts to get started',
                style: MacosTheme.of(context).typography.body,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              PushButton(
                controlSize: ControlSize.large,
                onPressed: widget.appState.pickAndAddFolder,
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    MacosIcon(CupertinoIcons.folder_badge_plus),
                    SizedBox(width: 8),
                    Text('Add Folder'),
                  ],
                ),
              ),
            ],
          ),
        );
      }

      return SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              children: [
                Text(
                  'Project Folders',
                  style: MacosTheme.of(context).typography.title1,
                ),
                const Spacer(),
                PushButton(
                  controlSize: ControlSize.regular,
                  onPressed: widget.appState.pickAndAddFolder,
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      MacosIcon(CupertinoIcons.plus, size: 16),
                      SizedBox(width: 6),
                      Text('Add Folder'),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Folders grid
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),

              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                crossAxisSpacing: 16,
                mainAxisSpacing: 16,
                childAspectRatio: 2.25,
              ),
              itemCount: widget.appState.projectFolders.length,
              itemBuilder: (context, index) {
                final folder = widget.appState.projectFolders[index];
                final isSelected =
                    widget.appState.currentlySelectedFolder.value?.path ==
                        folder.path;

                return _buildFolderCard(context, folder, isSelected);
              },
            ),
          ],
        ),
      );
    });
  }

  Widget _buildFolderCard(
    BuildContext context,
    ProjectFolder folder,
    bool isSelected,
  ) {
    return GestureDetector(
      onTap: () {
        widget.appState.selectFolder(folder);
        widget.appState.currentView.value = 'files';
      },
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isSelected
              ? MacosTheme.of(context).primaryColor.withValues(alpha: 0.08)
              : MacosTheme.of(context).canvasColor,
          border: Border.all(
            color: isSelected
                ? MacosTheme.of(context).primaryColor
                : MacosTheme.of(context).dividerColor.withValues(alpha: 0.5),
            width: isSelected ? 1.5 : 0.5,
          ),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                MacosIcon(
                  CupertinoIcons.folder_fill,
                  size: 20,
                  color: isSelected
                      ? MacosTheme.of(context).primaryColor
                      : CupertinoColors.systemGrey,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    folder.name,
                    style: MacosTheme.of(context).typography.headline.copyWith(
                          fontWeight:
                              isSelected ? FontWeight.w600 : FontWeight.w500,
                        ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                MacosTooltip(
                  message: 'Remove folder',
                  child: MacosIconButton(
                    icon: const MacosIcon(CupertinoIcons.xmark, size: 14),
                    onPressed: () => _showRemoveFolderDialog(context, folder),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              folder.path,
              style: MacosTheme.of(context).typography.caption1.copyWith(
                    color: CupertinoColors.inactiveGray,
                  ),
              overflow: TextOverflow.ellipsis,
              maxLines: 2,
            ),
            const Spacer(),
            Row(
              children: [
                Text(
                  '${folder.fileCount} PDF${folder.fileCount == 1 ? '' : 's'}',
                  style: MacosTheme.of(context).typography.caption1,
                ),
                const Spacer(),
                Text(
                  folder.addedAt.format('yyyy-MM-dd'),
                  style: MacosTheme.of(context).typography.caption1.copyWith(
                        color: CupertinoColors.inactiveGray,
                      ),
                ),

                // TODO: human friendly "since" date
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future _showRemoveFolderDialog(BuildContext context, ProjectFolder folder) {
    return showMacosAlertDialog(
      context: context,
      builder: (context) => MacosAlertDialog(
        appIcon: const MacosIcon(CupertinoIcons.folder_fill),
        title: const Text('Remove Folder'),
        message: Text(
          'Are you sure you want to remove "${folder.name}" from the project? This will not delete the actual folder or files.',
        ),
        primaryButton: PushButton(
          controlSize: ControlSize.large,
          child: const Text('Remove'),
          onPressed: () {
            widget.appState.removeFolder(folder);
            Navigator.of(context).pop();
          },
        ),
        secondaryButton: PushButton(
          controlSize: ControlSize.large,
          secondary: true,
          child: const Text('Cancel'),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
    );
  }
}
