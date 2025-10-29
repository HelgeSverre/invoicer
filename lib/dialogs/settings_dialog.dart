import 'package:flutter/cupertino.dart';
import 'package:invoicer/services/filename_template_service.dart';
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
  late TextEditingController _filenameTemplateController;
  late String _selectedModel;
  bool _obscureApiKey = true;
  String? _templateError;
  bool _showPlaceholderHelp = false;

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
    _filenameTemplateController = TextEditingController(
      text: widget.appState.filenameTemplate.value,
    );
    _selectedModel = widget.appState.aiModel.value;

    // Validate template on change
    _filenameTemplateController.addListener(_validateTemplate);
  }

  void _validateTemplate() {
    final validation = FilenameTemplateService.validateTemplate(
      _filenameTemplateController.text,
    );
    setState(() {
      _templateError = validation.isValid ? null : validation.error;
    });
  }

  @override
  Widget build(BuildContext context) {
    return MacosSheet(
      child: SingleChildScrollView(
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

              // Divider
              Container(
                height: 1,
                color: MacosTheme.of(context).dividerColor,
              ),
              const SizedBox(height: 24),

              // Filename Template Section
              Text(
                'Filename Template',
                style: MacosTheme.of(context).typography.headline,
              ),
              const SizedBox(height: 8),
              MacosTextField(
                controller: _filenameTemplateController,
                placeholder: '[YEAR]-[MONTH]-[DAY] - [VENDOR].pdf',
                prefix: const MacosIcon(CupertinoIcons.doc_text),
              ),
              if (_templateError != null) ...[
                const SizedBox(height: 4),
                Text(
                  _templateError!,
                  style: MacosTheme.of(context).typography.caption1.copyWith(
                        color: CupertinoColors.systemRed,
                      ),
                ),
              ],
              const SizedBox(height: 8),
              Text(
                'Available placeholders: ${FilenameTemplateService.getAvailablePlaceholders().map((p) => p.name).join(', ')}',
                style: MacosTheme.of(context).typography.caption1.copyWith(
                      color: CupertinoColors.systemGrey,
                    ),
              ),
              const SizedBox(height: 4),
              _buildPlaceholderHelp(context),

              const SizedBox(height: 24),

              // Divider
              Container(
                height: 1,
                color: MacosTheme.of(context).dividerColor,
              ),
              const SizedBox(height: 24),

              // Danger Zone
              Text(
                'Danger Zone',
                style: MacosTheme.of(context).typography.headline,
              ),
              const SizedBox(height: 8),
              Text(
                'Reset all app data including folders, processed files, and cache. This will NOT reset your API key, model selection, or filename template.',
                style: MacosTheme.of(context).typography.caption1.copyWith(
                      color: CupertinoColors.systemGrey,
                    ),
              ),
              const SizedBox(height: 12),
              PushButton(
                controlSize: ControlSize.large,
                color: CupertinoColors.systemRed,
                onPressed: () => _showResetConfirmation(context),
                child: const Text('Reset App Data'),
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
                    onPressed: _templateError == null
                        ? () {
                            widget.appState.apiKey.value =
                                _apiKeyController.text;
                            widget.appState.aiModel.value = _selectedModel;
                            widget.appState.filenameTemplate.value =
                                _filenameTemplateController.text;
                            widget.appState.saveSettings();
                            Navigator.of(context).pop();
                          }
                        : null,
                    child: const Text('Save'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showResetConfirmation(BuildContext context) {
    showMacosAlertDialog(
      context: context,
      builder: (dialogContext) => MacosAlertDialog(
        appIcon: const MacosIcon(
          CupertinoIcons.exclamationmark_triangle,
          size: 64,
        ),
        title: const Text('Reset App Data?'),
        message: const Text(
          'This will permanently delete:\n'
          '• All added folders\n'
          '• All processed files and their data\n'
          '• Cached extraction data\n\n'
          'Your API key, model selection, and filename template will be preserved.\n\n'
          'This action cannot be undone.',
        ),
        primaryButton: PushButton(
          controlSize: ControlSize.large,
          color: CupertinoColors.systemRed,
          onPressed: () async {
            // Close confirmation dialog
            Navigator.of(dialogContext).pop();

            // Perform reset
            await widget.appState.resetAppData();

            // Close settings dialog
            if (context.mounted) {
              Navigator.of(context).pop();
            }

            // Show success message
            if (context.mounted) {
              showMacosAlertDialog(
                context: context,
                builder: (context) => MacosAlertDialog(
                  appIcon: const MacosIcon(
                    CupertinoIcons.checkmark_circle_fill,
                    size: 64,
                  ),
                  title: const Text('App Data Reset'),
                  message:
                      const Text('All app data has been successfully reset.'),
                  primaryButton: PushButton(
                    controlSize: ControlSize.large,
                    child: const Text('OK'),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ),
              );
            }
          },
          child: const Text('Reset'),
        ),
        secondaryButton: PushButton(
          controlSize: ControlSize.large,
          secondary: true,
          onPressed: () => Navigator.of(dialogContext).pop(),
          child: const Text('Cancel'),
        ),
      ),
    );
  }

  Widget _buildPlaceholderHelp(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Toggle button
        GestureDetector(
          onTap: () {
            setState(() {
              _showPlaceholderHelp = !_showPlaceholderHelp;
            });
          },
          child: Row(
            children: [
              MacosIcon(
                _showPlaceholderHelp
                    ? CupertinoIcons.chevron_down
                    : CupertinoIcons.chevron_right,
                size: 12,
                color: CupertinoColors.systemGrey,
              ),
              const SizedBox(width: 4),
              Text(
                'Show placeholder descriptions',
                style: MacosTheme.of(context).typography.caption1.copyWith(
                      color: CupertinoColors.systemGrey,
                    ),
              ),
            ],
          ),
        ),

        // Placeholder list (conditionally shown)
        if (_showPlaceholderHelp) ...[
          const SizedBox(height: 8),
          _buildPlaceholderList(context),
        ],
      ],
    );
  }

  Widget _buildPlaceholderList(BuildContext context) {
    final placeholders = FilenameTemplateService.getAvailablePlaceholders();
    return Container(
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: MacosTheme.of(context).canvasColor.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: MacosTheme.of(context).dividerColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: placeholders.map((placeholder) {
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  width: 120,
                  child: Text(
                    placeholder.name,
                    style: MacosTheme.of(context).typography.body.copyWith(
                          fontFamily: 'monospace',
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                ),
                Expanded(
                  child: Text(
                    placeholder.description,
                    style: MacosTheme.of(context).typography.caption1,
                  ),
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }

  @override
  void dispose() {
    _apiKeyController.dispose();
    _filenameTemplateController.dispose();
    super.dispose();
  }
}
