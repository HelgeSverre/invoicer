import 'dart:async';
import 'dart:io';

import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:invoicer/models.dart';
import 'package:invoicer/state.dart';
import 'package:macos_ui/macos_ui.dart';
import 'package:path/path.dart' as path;
import 'package:signals/signals_flutter.dart';
import 'package:syncfusion_flutter_pdfviewer/pdfviewer.dart';
import 'package:url_launcher/url_launcher.dart';

class FileDetailDialog extends StatefulWidget {
  final PdfDocument initialFile;

  const FileDetailDialog({super.key, required this.initialFile});

  @override
  State<FileDetailDialog> createState() => _FileDetailDialogState();
}

class _FileDetailDialogState extends State<FileDetailDialog> {
  late final AppState appState;
  late final PdfViewerController _pdfViewerController;
  final FocusNode _dialogFocusNode = FocusNode();
  String? _recentlyCopiedValue;
  Timer? _copyIndicatorTimer;

  @override
  void initState() {
    super.initState();
    appState = AppState();
    _pdfViewerController = PdfViewerController();

    // Request focus when dialog opens
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _dialogFocusNode.requestFocus();
    });
  }

  @override
  void dispose() {
    _copyIndicatorTimer?.cancel();
    _pdfViewerController.dispose();
    _dialogFocusNode.dispose();
    super.dispose();
  }

  // Get the current file state from the app state
  PdfDocument? get currentFile {
    // Check in folder files first
    try {
      return appState.pdfFiles.firstWhere(
        (file) => file.path == widget.initialFile.path,
      );
    } catch (e) {
      // If not found in folder files, check individual files
      try {
        return appState.individualFiles.firstWhere(
          (file) => file.path == widget.initialFile.path,
        );
      } catch (e) {
        // Fall back to initial file
        return widget.initialFile;
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return MacosSheet(
      insetAnimationDuration: const Duration(milliseconds: 300),
      insetAnimationCurve: Curves.easeInOut,
      child: Focus(
        focusNode: _dialogFocusNode,
        child: SizedBox(
          width: 1200,
          height: 800,
          child: Watch((context) {
            final file = currentFile;
            if (file == null) {
              return const Center(child: Text('File not found'));
            }

            return Column(
              children: [
                // Header
                _buildHeader(context, file),

                // Split content
                Expanded(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.start,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Left side - PDF Preview
                      _buildPdfPreview(context, file),

                      // Right side - Details
                      _buildDetailsPanel(context, file),
                    ],
                  ),
                ),
              ],
            );
          }),
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context, PdfDocument file) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(
            color: MacosTheme.of(context).dividerColor,
            width: 0.5,
          ),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          const MacosIcon(CupertinoIcons.doc_text, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  file.name,
                  style: MacosTheme.of(context).typography.title2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          if (file.vendor == null && !file.isProcessing && file.error == null)
            MacosTooltip(
              message: 'Process this file with AI',
              child: MacosIconButton(
                icon: const MacosIcon(CupertinoIcons.wand_stars),
                onPressed: () => appState.processFile(file),
              ),
            )
          else if (file.error != null)
            MacosTooltip(
              message: 'Retry processing this file',
              child: MacosIconButton(
                icon: const MacosIcon(CupertinoIcons.wand_stars),
                onPressed: () => appState.processFile(file),
              ),
            ),
          const SizedBox(width: 12),
          MacosTooltip(
            message: 'Copy file path to clipboard',
            child: MacosIconButton(
              icon: const MacosIcon(CupertinoIcons.doc_on_clipboard),
              onPressed: () => _copyFilePathToClipboard(file.path),
            ),
          ),
          const SizedBox(width: 8),
          MacosTooltip(
            message: 'Open file location in Finder',
            child: MacosIconButton(
              icon: const MacosIcon(CupertinoIcons.folder_open),
              onPressed: () => _openFileInFinder(file.path),
            ),
          ),
          const SizedBox(width: 8),
          MacosTooltip(
            message: 'Close',
            child: MacosIconButton(
              icon: const MacosIcon(CupertinoIcons.xmark),
              onPressed: () => Navigator.of(context).pop(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPdfPreview(BuildContext context, PdfDocument file) {
    return Expanded(
      flex: 2,
      child: Container(
        decoration: BoxDecoration(
          border: Border(
            right: BorderSide(
              color: MacosTheme.of(context).dividerColor,
              width: 0.5,
            ),
          ),
        ),
        child: Container(
          margin: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            border: Border.all(color: MacosTheme.of(context).dividerColor),
            borderRadius: BorderRadius.circular(8),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: SfPdfViewer.file(
              File(file.path),
              controller: _pdfViewerController,
              enableDoubleTapZooming: true,
              enableTextSelection: true,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDetailsPanel(BuildContext context, PdfDocument file) {
    return SizedBox(
      width: 520,
      child: Container(
        margin: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          border: Border.all(color: MacosTheme.of(context).dividerColor),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          children: [
            // Invoice Information Data Grid (only if file has been processed successfully)
            if (file.hasInvoiceDetails) _buildInvoiceDataGrid(context, file),

            if (file.items.isNotEmpty)
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: MacosTheme.of(context).canvasColor,
                  borderRadius: file.vendor != null || file.invoiceDate != null
                      ? null
                      : const BorderRadius.vertical(top: Radius.circular(8)),
                  border: Border(
                    bottom: BorderSide(
                      color: MacosTheme.of(context).dividerColor,
                      width: 0.5,
                    ),
                  ),
                ),
                child: Row(
                  children: [
                    Text(
                      'Items',
                      style: MacosTheme.of(context).typography.headline,
                    ),
                  ],
                ),
              ),

            // Content Area
            Expanded(child: _buildContentArea(context, file)),
          ],
        ),
      ),
    );
  }

  Widget _buildContentArea(BuildContext context, PdfDocument file) {
    // Processing state
    if (file.isProcessing) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const SizedBox(
              width: 32,
              height: 32,
              child: ProgressCircle(radius: 16),
            ),
            const SizedBox(height: 16),
            Text(
              'Processing...',
              style: MacosTheme.of(context).typography.title3,
            ),
            const SizedBox(height: 8),
            Text(
              'Extracting invoice data with AI',
              style: MacosTheme.of(context).typography.body,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    // Error state
    if (file.error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const MacosIcon(
              CupertinoIcons.exclamationmark_triangle,
              size: 48,
              color: CupertinoColors.systemRed,
            ),
            const SizedBox(height: 16),
            Text(
              'Processing Error',
              style: MacosTheme.of(context).typography.title3,
            ),
            const SizedBox(height: 8),
            Text(
              file.error!,
              style: MacosTheme.of(
                context,
              ).typography.body.copyWith(color: CupertinoColors.systemRed),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    // No items state
    if (file.items.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const MacosIcon(
              CupertinoIcons.doc_text,
              size: 48,
              color: CupertinoColors.systemGrey,
            ),
            const SizedBox(height: 16),
            Text(
              'No items extracted',
              style: MacosTheme.of(context).typography.title3,
            ),
            const SizedBox(height: 8),
            Text(
              'Process this file to extract invoice items',
              style: MacosTheme.of(context).typography.body,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    // Items table
    return Column(
      children: [
        // Table header
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: MacosTheme.of(context).canvasColor.withValues(alpha: 0.5),
            border: Border(
              bottom: BorderSide(
                color: MacosTheme.of(context).dividerColor,
                width: 0.5,
              ),
            ),
          ),
          child: Row(
            children: [
              Expanded(
                flex: 3,
                child: Text(
                  'Description',
                  style: MacosTheme.of(
                    context,
                  ).typography.headline.copyWith(fontWeight: FontWeight.w400),
                ),
              ),
              Expanded(
                child: Text(
                  'Qty',
                  style: MacosTheme.of(
                    context,
                  ).typography.headline.copyWith(fontWeight: FontWeight.w400),
                ),
              ),
              Expanded(
                child: Text(
                  'Price',
                  style: MacosTheme.of(
                    context,
                  ).typography.headline.copyWith(fontWeight: FontWeight.w400),
                ),
              ),
              Expanded(
                child: Text(
                  'Total',
                  style: MacosTheme.of(
                    context,
                  ).typography.headline.copyWith(fontWeight: FontWeight.w400),
                ),
              ),
            ],
          ),
        ),

        // Items list
        Expanded(
          child: ListView.builder(
            itemCount: file.items.length,
            itemBuilder: (context, index) {
              final item = file.items[index];
              final isEven = index % 2 == 0;
              return Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: isEven
                      ? null
                      : MacosTheme.of(
                          context,
                        ).canvasColor.withValues(alpha: 0.3),
                  border: index < file.items.length - 1
                      ? Border(
                          bottom: BorderSide(
                            color: MacosTheme.of(context).dividerColor,
                            width: 0.5,
                          ),
                        )
                      : null,
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      flex: 3,
                      child: Text(
                        item.text,
                        style: MacosTheme.of(context).typography.body,
                      ),
                    ),
                    Expanded(
                      child: Text(
                        item.quantity.toString(),
                        style: MacosTheme.of(context).typography.body,
                      ),
                    ),
                    Expanded(
                      child: Text(
                        item.unitPrice.toStringAsFixed(2),
                        style: MacosTheme.of(context).typography.body,
                      ),
                    ),
                    Expanded(
                      child: Text(
                        item.total.toStringAsFixed(2),
                        style: MacosTheme.of(
                          context,
                        ).typography.body.copyWith(fontWeight: FontWeight.w400),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildInvoiceDataGrid(BuildContext context, PdfDocument file) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: MacosTheme.of(context).canvasColor.withValues(alpha: 0.7),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(8)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Invoice Details',
            style: MacosTheme.of(context).typography.headline,
          ),
          const SizedBox(height: 8),

          // Basic Info
          if (file.vendor?.isNotEmpty ?? false)
            _buildDataRow(context, 'Vendor', file.vendor),
          if (file.vendorEmail?.isNotEmpty ?? false)
            _buildDataRow(context, 'Email', file.vendorEmail),
          if (file.vendorWebsite?.isNotEmpty ?? false)
            _buildDataRow(context, 'Website', file.vendorWebsite),
          if (file.vendorDisplayAddress?.isNotEmpty ?? false)
            _buildDataRow(context, 'Address', file.vendorDisplayAddress),

          // Dates
          if (file.invoiceDate != null)
            _buildDataRow(
              context,
              'Invoice Date',
              file.invoiceDate!.format('MMM d, yyyy'),
              copyValue: file.invoiceDate!.format('yyyy-MM-dd'),
            ),
          if (file.dueDate != null)
            _buildDataRow(
              context,
              'Due Date',
              file.dueDate?.format('MMM d, yyyy'),
              copyValue: file.dueDate!.format('yyyy-MM-dd'),
            ),

          // Financial Details
          if (file.currency?.isNotEmpty ?? false)
            _buildDataRow(
              context,
              'Currency',
              file.currency!.toUpperCase(),
            ),

          if (file.totalAmount != null)
            _buildDataRow(
              context,
              'Total Amount',
              file.totalAmount!.toStringAsFixed(2),
            ),
          if (file.taxAmount != null)
            _buildDataRow(
              context,
              'Tax Amount',
              file.taxAmount!.toStringAsFixed(2),
            ),
          if (file.discountAmount != null)
            _buildDataRow(
              context,
              'Discount',
              file.discountAmount!.toStringAsFixed(2),
            ),

          // Payment Info
          if (file.paymentMethod?.isNotEmpty ?? false)
            _buildDataRow(context, 'Payment Method', file.paymentMethod),
          if (file.lastFourDigits?.isNotEmpty ?? false)
            _buildDataRow(context, 'Last 4 Digits', file.lastFourDigits),
        ],
      ),
    );
  }

  Widget _buildDataRow(
    BuildContext context,
    String label,
    String? value, {
    String? copyValue,
  }) {
    final valueToCopy = copyValue ?? value;

    return MacosTooltip(
      message: valueToCopy != '-'
          ? (_recentlyCopiedValue == valueToCopy
              ? 'Copied!'
              : 'Click to copy: $valueToCopy')
          : '',
      child: GestureDetector(
        onTap: valueToCopy != null && valueToCopy.isNotEmpty
            ? () => _copyToClipboard(valueToCopy)
            : null,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 6),
          decoration: BoxDecoration(borderRadius: BorderRadius.circular(4)),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              SizedBox(
                width: 120,
                child: Text(
                  '$label:',
                  style: MacosTheme.of(context).typography.body.copyWith(
                        fontWeight: FontWeight.w400,
                        color: CupertinoColors.systemGrey,
                      ),
                ),
              ),
              Expanded(
                child: value == null
                    ? Text(
                        "-",
                        style: MacosTheme.of(context).typography.body.copyWith(
                              fontWeight: FontWeight.w400,
                              color: CupertinoColors.systemGrey
                                  .withValues(alpha: .5),
                            ),
                      )
                    : Text(
                        value,
                        style: MacosTheme.of(context).typography.body.copyWith(
                              fontWeight: FontWeight.w500,
                            ),
                      ),
              ),
              SizedBox(width: 24),
              if (valueToCopy != null && valueToCopy.isNotEmpty)
                MacosIcon(
                  CupertinoIcons.doc_on_clipboard,
                  size: 12,
                  color: CupertinoColors.systemGrey,
                ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _copyToClipboard(String text) async {
    try {
      await Clipboard.setData(ClipboardData(text: text));

      // Show visual feedback
      setState(() {
        _recentlyCopiedValue = text;
      });

      // Reset the indicator after 1.5 seconds
      _copyIndicatorTimer?.cancel();
      _copyIndicatorTimer = Timer(const Duration(milliseconds: 1500), () {
        if (mounted) {
          setState(() {
            _recentlyCopiedValue = null;
          });
        }
      });
    } catch (e) {
      debugPrint('Could not copy to clipboard: $e');
    }
  }

  Future<void> _copyFilePathToClipboard(String filePath) async {
    try {
      await Clipboard.setData(ClipboardData(text: filePath));
    } catch (e) {
      debugPrint('Could not copy file path to clipboard: $e');
    }
  }

  Future<void> _openFileInFinder(String filePath) async {
    try {
      final uri = Uri.file(path.dirname(filePath));
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri);
      }
    } catch (e) {
      debugPrint('Could not open file location: $e');
    }
  }
}
