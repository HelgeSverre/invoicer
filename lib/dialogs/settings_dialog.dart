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
  late String _selectedModel;
  bool _obscureApiKey = true;

  final List<String> _availableModels = [
    'gpt-4.1',
    'gpt-4.1-mini',
    'gpt-4.1-nano',
  ];

  @override
  void initState() {
    super.initState();
    _apiKeyController = TextEditingController(
      text: widget.appState.apiKey.value,
    );
    _selectedModel = widget.appState.aiModel.value;
  }

  @override
  Widget build(BuildContext context) {
    return MacosSheet(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const MacosIcon(CupertinoIcons.settings, size: 20),
                const SizedBox(width: 8),
                Text('Settings',
                    style: MacosTheme.of(context).typography.title2),
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
            const SizedBox(height: 24),

            // API Key Section
            Text(
              'OpenAI API Key',
              style: MacosTheme.of(context).typography.headline,
            ),
            const SizedBox(height: 8),
            Watch(
              (context) => MacosTextField(
                controller: _apiKeyController,
                placeholder: 'sk-...',
                obscureText: _obscureApiKey,
                prefix: MacosTooltip(
                  message: 'Your OpenAI API key for processing receipts',
                  child: const MacosIcon(CupertinoIcons.lock),
                ),
                suffix: MacosIconButton(
                  icon: MacosIcon(
                    _obscureApiKey
                        ? CupertinoIcons.eye
                        : CupertinoIcons.eye_slash,
                    size: 18,
                  ),
                  onPressed: () {
                    setState(() {
                      _obscureApiKey = !_obscureApiKey;
                    });
                  },
                ),
              ),
            ),

            const SizedBox(height: 24),

            // Divider
            Container(
              height: 1,
              color: MacosTheme.of(context).dividerColor,
            ),
            const SizedBox(height: 24),

            // AI Model Section
            Text(
              'AI Model',
              style: MacosTheme.of(context).typography.headline,
            ),
            const SizedBox(height: 8),
            MacosPopupButton<String>(
              value: _selectedModel,
              onChanged: (String? newValue) {
                if (newValue != null) {
                  setState(() {
                    _selectedModel = newValue;
                  });
                }
              },
              items: _availableModels
                  .map<MacosPopupMenuItem<String>>(
                    (String value) => MacosPopupMenuItem<String>(
                      value: value,
                      child: Text(value),
                    ),
                  )
                  .toList(),
            ),
            const SizedBox(height: 6),
            Text(
              'Recommended: gpt-4.1-mini (fast, lower cost). gpt-4.1 (best quality). nano (smallest; may miss details).',
              style: MacosTheme.of(context).typography.caption1.copyWith(
                    color: CupertinoColors.systemGrey,
                  ),
            ),

            const SizedBox(height: 24),

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
                    widget.appState.aiModel.value = _selectedModel;
                    widget.appState.saveSettings();
                    Navigator.of(context).pop();
                  },
                  child: const Text('Save'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _apiKeyController.dispose();
    super.dispose();
  }
}
