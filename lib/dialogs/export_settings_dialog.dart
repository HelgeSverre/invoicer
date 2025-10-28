import 'package:flutter/cupertino.dart';
import 'package:invoicer/models/export_settings.dart';
import 'package:macos_ui/macos_ui.dart';

class ExportSettingsDialog extends StatefulWidget {
  final ExportSettings initialSettings;

  const ExportSettingsDialog({
    super.key,
    required this.initialSettings,
  });

  @override
  State<ExportSettingsDialog> createState() => _ExportSettingsDialogState();
}

class _ExportSettingsDialogState extends State<ExportSettingsDialog> {
  late ExportSettings _settings;
  bool _showPreview = false;

  @override
  void initState() {
    super.initState();
    _settings = widget.initialSettings;
  }

  @override
  Widget build(BuildContext context) {
    return MacosSheet(
      child: Container(
        width: 600,
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              children: [
                const MacosIcon(CupertinoIcons.slider_horizontal_3, size: 20),
                const SizedBox(width: 8),
                Text(
                  'Export Settings',
                  style: MacosTheme.of(context).typography.title2,
                ),
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

            // CSV Delimiter Section
            Text(
              'CSV Delimiter',
              style: MacosTheme.of(context).typography.headline,
            ),
            const SizedBox(height: 8),
            MacosPopupButton<String>(
              value: _settings.delimiter,
              onChanged: (String? newValue) {
                if (newValue != null) {
                  setState(() {
                    _settings = _settings.copyWith(delimiter: newValue);
                  });
                }
              },
              items: [
                const MacosPopupMenuItem(
                  value: ',',
                  child: Text('Comma (,)'),
                ),
                const MacosPopupMenuItem(
                  value: ';',
                  child: Text('Semicolon (;)'),
                ),
                const MacosPopupMenuItem(
                  value: '\t',
                  child: Text('Tab'),
                ),
                const MacosPopupMenuItem(
                  value: '|',
                  child: Text('Pipe (|)'),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'Choose the character that separates values in CSV files',
              style: MacosTheme.of(context).typography.caption1.copyWith(
                    color: CupertinoColors.systemGrey,
                  ),
            ),

            const SizedBox(height: 20),

            // Quote Settings
            Text(
              'Quote Settings',
              style: MacosTheme.of(context).typography.headline,
            ),
            const SizedBox(height: 8),
            MacosCheckbox(
              value: _settings.alwaysQuote,
              onChanged: (bool value) {
                setState(() {
                  _settings = _settings.copyWith(alwaysQuote: value);
                });
              },
              semanticLabel: 'Always quote fields',
            ),
            const SizedBox(width: 8),
            GestureDetector(
              onTap: () {
                setState(() {
                  _settings = _settings.copyWith(
                    alwaysQuote: !_settings.alwaysQuote,
                  );
                });
              },
              child: Text(
                'Always quote fields (recommended for Excel compatibility)',
                style: MacosTheme.of(context).typography.body,
              ),
            ),

            const SizedBox(height: 20),

            // Divider
            Container(
              height: 1,
              color: MacosTheme.of(context).dividerColor,
            ),
            const SizedBox(height: 20),

            // Line Item Format Section
            Text(
              'Line Items Format',
              style: MacosTheme.of(context).typography.headline,
            ),
            const SizedBox(height: 8),
            MacosPopupButton<LineItemFormat>(
              value: _settings.lineItemFormat,
              onChanged: (LineItemFormat? newValue) {
                if (newValue != null) {
                  setState(() {
                    _settings = _settings.copyWith(lineItemFormat: newValue);
                  });
                }
              },
              items: LineItemFormat.values
                  .map((format) => MacosPopupMenuItem(
                        value: format,
                        child: Text(format.displayName),
                      ))
                  .toList(),
            ),
            const SizedBox(height: 8),
            Text(
              _settings.lineItemFormat.description,
              style: MacosTheme.of(context).typography.caption1.copyWith(
                    color: CupertinoColors.systemGrey,
                  ),
            ),

            const SizedBox(height: 12),

            // Format Preview
            _buildFormatPreview(context),

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
                  onPressed: () => Navigator.of(context).pop(_settings),
                  child: const Text('Export'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFormatPreview(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Toggle button
        GestureDetector(
          onTap: () {
            setState(() {
              _showPreview = !_showPreview;
            });
          },
          child: Row(
            children: [
              MacosIcon(
                _showPreview
                    ? CupertinoIcons.chevron_down
                    : CupertinoIcons.chevron_right,
                size: 12,
                color: CupertinoColors.systemGrey,
              ),
              const SizedBox(width: 4),
              Text(
                'Show example',
                style: MacosTheme.of(context).typography.caption1.copyWith(
                      color: CupertinoColors.systemGrey,
                    ),
              ),
            ],
          ),
        ),

        // Preview content (conditionally shown)
        if (_showPreview) ...[
          const SizedBox(height: 8),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: MacosTheme.of(context).canvasColor.withValues(alpha: 0.3),
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: MacosTheme.of(context).dividerColor),
            ),
            child: Text(
              _settings.lineItemFormat.example,
              style: MacosTheme.of(context).typography.body.copyWith(
                    fontFamily: 'monospace',
                    fontSize: 12,
                  ),
            ),
          ),
        ],
      ],
    );
  }
}
