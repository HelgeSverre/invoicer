import 'dart:async';
import 'dart:io';

import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
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

  // Search methods
  void _toggleSearch() {
    setState(() {
      _isSearchVisible = !_isSearchVisible;
      if (!_isSearchVisible) {
        _searchController.clear();
        _searchResult?.clear();
        _searchResult = null;
        _currentSearchIndex = 0;
        _dialogFocusNode.requestFocus();
      } else {
        // Clear any previous search results and focus the search field when opening
        _searchController.clear();
        _searchResult?.clear();
        _searchResult = null;
        _currentSearchIndex = 0;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _searchFocusNode.requestFocus();
        });
      }
    });
  }

  Future<void> _performSearch(String searchText) async {
    if (searchText.trim().isEmpty) {
      setState(() {
        _searchResult?.clear();
        _searchResult = null;
        _currentSearchIndex = 0;
      });
      return;
    }

    setState(() {
      _isSearching = true;
    });

    try {
      _searchResult = _pdfViewerController.searchText(searchText);
      if (_searchResult != null && _searchResult!.totalInstanceCount > 0) {
        setState(() {
          _currentSearchIndex = 1;
        });
      } else {
        setState(() {
          _currentSearchIndex = 0;
        });
      }
    } catch (e) {
      debugPrint('Search error: $e');
      setState(() {
        _searchResult = null;
        _currentSearchIndex = 0;
      });
    } finally {
      setState(() {
        _isSearching = false;
      });
    }
  }

  void _nextSearchResult() {
    if (_searchResult != null && _searchResult!.totalInstanceCount > 0) {
      _searchResult!.nextInstance();
      setState(() {
        _currentSearchIndex =
            (_currentSearchIndex % _searchResult!.totalInstanceCount) + 1;
      });
    }
  }

  void _previousSearchResult() {
    if (_searchResult != null && _searchResult!.totalInstanceCount > 0) {
      _searchResult!.previousInstance();
      setState(() {
        _currentSearchIndex = _currentSearchIndex > 1
            ? _currentSearchIndex - 1
            : _searchResult!.totalInstanceCount;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return MacosSheet(
      insetAnimationDuration: const Duration(milliseconds: 300),
      insetAnimationCurve: Curves.easeInOut,
      child: Focus(
        focusNode: _dialogFocusNode,
        onKeyEvent: (node, event) {
          // Only handle shortcuts when search field is not focused
          if (_searchFocusNode.hasFocus) {
            return KeyEventResult.ignored;
          }

          if (event is KeyDownEvent) {
            // CMD+F to toggle search
            if (event.logicalKey == LogicalKeyboardKey.keyF &&
                HardwareKeyboard.instance.logicalKeysPressed
                    .contains(LogicalKeyboardKey.meta)) {
              _toggleSearch();
              return KeyEventResult.handled;
            }

            // ESC to close search
            if (event.logicalKey == LogicalKeyboardKey.escape &&
                _isSearchVisible) {
              _toggleSearch();
              return KeyEventResult.handled;
            }

            // CMD+G to go to next result
            if (event.logicalKey == LogicalKeyboardKey.keyG &&
                HardwareKeyboard.instance.logicalKeysPressed
                    .contains(LogicalKeyboardKey.meta) &&
                !HardwareKeyboard.instance.logicalKeysPressed
                    .contains(LogicalKeyboardKey.shift) &&
                _isSearchVisible) {
              _nextSearchResult();
              return KeyEventResult.handled;
            }

            // CMD+Shift+G to go to previous result
            if (event.logicalKey == LogicalKeyboardKey.keyG &&
                HardwareKeyboard.instance.logicalKeysPressed
                    .contains(LogicalKeyboardKey.meta) &&
                HardwareKeyboard.instance.logicalKeysPressed
                    .contains(LogicalKeyboardKey.shift) &&
                _isSearchVisible) {
              _previousSearchResult();
              return KeyEventResult.handled;
            }
          }

          return KeyEventResult.ignored;
        },
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
            child: Stack(
              children: [
                SfPdfViewer.file(
                  File(file.path),
                  controller: _pdfViewerController,
                  enableDoubleTapZooming: true,
                  enableTextSelection: true,
                ),

                // Search overlay
                if (_isSearchVisible)
                  Positioned(
                    top: 12,
                    right: 12,
                    child: _buildSearchOverlay(context),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDetailsPanel(BuildContext context, PdfDocument file) {
    return SizedBox(
      width: 400,
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

            // Items Section Header
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
              color: CupertinoColors.placeholderText,
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
                        '${item.quantity}',
                        style: MacosTheme.of(context).typography.body,
                      ),
                    ),
                    Expanded(
                      child: Text(
                        '\$${item.unitPrice.toStringAsFixed(2)}',
                        style: MacosTheme.of(context).typography.body,
                      ),
                    ),
                    Expanded(
                      child: Text(
                        '\$${item.total.toStringAsFixed(2)}',
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
          if (file.vendor != null)
            _buildDataRow(context, 'Vendor', file.vendor),
          if (file.vendorEmail != null)
            _buildDataRow(context, 'Email', file.vendorEmail),
          if (file.vendorWebsite != null)
            _buildDataRow(context, 'Website', file.vendorWebsite),
          if (file.vendorDisplayAddress != null)
            _buildDataRow(context, 'Address', file.vendorDisplayAddress),

          // Dates
          if (file.invoiceDate != null)
            _buildDataRow(
              context,
              'Invoice Date',
              DateFormat('MMM d, yyyy').format(file.invoiceDate!),
              copyValue: DateFormat('yyyy-MM-dd').format(file.invoiceDate!),
            ),
          if (file.dueDate != null)
            _buildDataRow(
              context,
              'Due Date',
              DateFormat('MMM d, yyyy').format(file.dueDate!),
              copyValue: DateFormat('yyyy-MM-dd').format(file.dueDate!),
            ),

          // Financial Details
          if (file.currency != null)
            _buildDataRow(
              context,
              'Currency',
              file.currency,
            ),

          if (file.totalAmount != null)
            _buildDataRow(
              context,
              'Total Amount',
              '\$${file.totalAmount!.toStringAsFixed(2)}',
              copyValue: file.totalAmount!.toStringAsFixed(2),
            ),
          if (file.taxAmount != null)
            _buildDataRow(
              context,
              'Tax Amount',
              '\$${file.taxAmount!.toStringAsFixed(2)}',
              copyValue: file.taxAmount!.toStringAsFixed(2),
            ),
          if (file.discountAmount != null)
            _buildDataRow(
              context,
              'Discount',
              '\$${file.discountAmount!.toStringAsFixed(2)}',
              copyValue: file.discountAmount!.toStringAsFixed(2),
            ),

          // Payment Info
          if (file.paymentMethod != null)
            _buildDataRow(context, 'Payment Method', file.paymentMethod),
          if (file.lastFourDigits != null)
            _buildDataRow(
              context,
              'Last 4 Digits',
              '${file.lastFourDigits}',
              copyValue: file.lastFourDigits,
            ),
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
            crossAxisAlignment: CrossAxisAlignment.center,
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
                child: Row(
                  children: [
                    Expanded(
                      child: value == null
                          ? Text(
                              "-",
                              style: MacosTheme.of(context)
                                  .typography
                                  .body
                                  .copyWith(
                                    fontWeight: FontWeight.w400,
                                    color: CupertinoColors.systemGrey
                                        .withValues(alpha: .5),
                                  ),
                            )
                          : Text(
                              value,
                              style: MacosTheme.of(context)
                                  .typography
                                  .body
                                  .copyWith(fontWeight: FontWeight.w500),
                            ),
                    ),
                    if (valueToCopy != null && valueToCopy.isNotEmpty)
                      MacosIcon(
                        _recentlyCopiedValue == valueToCopy
                            ? CupertinoIcons.checkmark_circle_fill
                            : CupertinoIcons.doc_on_clipboard,
                        size: 16,
                        color: _recentlyCopiedValue == valueToCopy
                            ? CupertinoColors.systemGreen
                            : CupertinoColors.inactiveGray,
                      ),
                  ],
                ),
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

  Widget _buildSearchOverlay(BuildContext context) {
    return Container(
      width: 320,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: MacosTheme.of(context).canvasColor.withValues(alpha: 0.98),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: MacosTheme.of(context).dividerColor),
        boxShadow: [
          BoxShadow(
            color: CupertinoColors.black.withValues(alpha: 0.15),
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              const MacosIcon(CupertinoIcons.search, size: 16),
              const SizedBox(width: 8),
              Expanded(
                child: Focus(
                  onKeyEvent: (node, event) {
                    // Handle Enter key in search field
                    if (event is KeyDownEvent &&
                        event.logicalKey == LogicalKeyboardKey.enter &&
                        _searchController.text.isNotEmpty) {
                      _nextSearchResult();
                      return KeyEventResult.handled;
                    }
                    return KeyEventResult.ignored;
                  },
                  child: MacosTextField(
                    controller: _searchController,
                    focusNode: _searchFocusNode,
                    placeholder: 'Search in PDF... (⌘F)',
                    onChanged: (value) {
                      _performSearch(value);
                    },
                    onSubmitted: (value) {
                      if (value.isNotEmpty) {
                        _nextSearchResult();
                      }
                    },
                  ),
                ),
              ),
              const SizedBox(width: 8),
              MacosTooltip(
                message: 'Close search (ESC)',
                child: MacosIconButton(
                  icon: const MacosIcon(CupertinoIcons.xmark, size: 16),
                  onPressed: _toggleSearch,
                ),
              ),
            ],
          ),

          if (_searchController.text.isNotEmpty) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                // Search results info
                Expanded(
                  child: _isSearching
                      ? Row(
                          children: [
                            const SizedBox(
                              width: 12,
                              height: 12,
                              child: ProgressCircle(radius: 6),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              'Searching...',
                              style: MacosTheme.of(context).typography.caption1,
                            ),
                          ],
                        )
                      : _searchResult != null &&
                              _searchResult!.totalInstanceCount > 0
                          ? Text(
                              '$_currentSearchIndex of ${_searchResult!.totalInstanceCount}',
                              style: MacosTheme.of(context).typography.caption1,
                            )
                          : Text(
                              'No results found',
                              style: MacosTheme.of(context)
                                  .typography
                                  .caption1
                                  .copyWith(color: CupertinoColors.systemRed),
                            ),
                ),

                // Navigation buttons
                const SizedBox(width: 8),
                MacosTooltip(
                  message: 'Previous result (⌘⇧G)',
                  child: MacosIconButton(
                    icon: const MacosIcon(CupertinoIcons.chevron_up, size: 14),
                    onPressed: (_searchResult != null &&
                            _searchResult!.totalInstanceCount > 0)
                        ? _previousSearchResult
                        : null,
                  ),
                ),
                MacosTooltip(
                  message: 'Next result (⌘G)',
                  child: MacosIconButton(
                    icon:
                        const MacosIcon(CupertinoIcons.chevron_down, size: 14),
                    onPressed: (_searchResult != null &&
                            _searchResult!.totalInstanceCount > 0)
                        ? _nextSearchResult
                        : null,
                  ),
                ),
              ],
            ),
          ],

          // Keyboard shortcuts hint
          if (_isSearchVisible && _searchController.text.isEmpty) ...[
            const SizedBox(height: 8),
            Text(
              'Tip: ⌘G for next, ⌘⇧G for previous, ESC to close',
              style: MacosTheme.of(context).typography.caption1.copyWith(
                    color: CupertinoColors.secondaryLabel,
                    fontSize: 10,
                  ),
              textAlign: TextAlign.center,
            ),
          ],
        ],
      ),
    );
  }
}
