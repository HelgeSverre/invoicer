import 'package:flutter/cupertino.dart';
import 'package:invoicer/state.dart';
import 'package:macos_ui/macos_ui.dart';
import 'package:signals/signals_flutter.dart';

class SettingsDialog extends StatefulWidget {
  final AppState appState;

  const SettingsDialog({super.key, required this.appState});

  @override
  State<SettingsDialog> createState() => _SettingsDialogState();
}

class _SettingsDialogState extends State<SettingsDialog> {
  late TextEditingController _apiKeyController;
  late TextEditingController _promptController;

  @override
  void initState() {
    super.initState();
    _apiKeyController = TextEditingController(
      text: widget.appState.apiKey.value,
    );
    _promptController = TextEditingController(
      text: widget.appState.promptTemplate.value,
    );
  }

  @override
  Widget build(BuildContext context) {
    return MacosSheet(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const MacosIcon(CupertinoIcons.settings, size: 20),
              const SizedBox(width: 8),
              Text('Settings', style: MacosTheme.of(context).typography.title2),
              const Spacer(),
              MacosTooltip(
                message: 'Close',
                child: MacosIconButton(
                  icon: const MacosIcon(CupertinoIcons.xmark),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // API Key Section
          Text(
            'OpenAI API Key',
            style: MacosTheme.of(context).typography.headline,
          ),
          const SizedBox(height: 6),
          Watch(
            (context) => MacosTextField(
              controller: _apiKeyController,
              placeholder: 'sk-...',
              obscureText: true,
              prefix: MacosTooltip(
                message: 'Your OpenAI API key for processing receipts',
                child: const MacosIcon(CupertinoIcons.lock),
              ),
            ),
          ),

          const SizedBox(height: 20),

          // Action Buttons
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              PushButton(
                controlSize: ControlSize.large,
                secondary: true,
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Cancel'),
              ),
              const SizedBox(width: 12),
              PushButton(
                controlSize: ControlSize.large,
                onPressed: () {
                  widget.appState.apiKey.value = _apiKeyController.text;
                  widget.appState.promptTemplate.value = _promptController.text;
                  widget.appState.saveSettings();
                  Navigator.of(context).pop();
                },
                child: const Text('Save'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _apiKeyController.dispose();
    _promptController.dispose();
    super.dispose();
  }
}
