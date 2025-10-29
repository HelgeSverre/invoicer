import 'package:desktop_drop/desktop_drop.dart';
import 'package:file_picker/file_picker.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/cupertino.dart';
import 'package:intl/intl.dart';
import 'package:invoicer/dialogs/file_detail_dialog.dart';
import 'package:invoicer/models.dart';
import 'package:invoicer/services/stats_service.dart';
import 'package:invoicer/state.dart';
import 'package:macos_ui/macos_ui.dart';
import 'package:path/path.dart' as path;
import 'package:signals/signals_flutter.dart';
import 'package:timeago/timeago.dart' as timeago;

class OverviewView extends StatefulWidget {
  final AppState appState;

  const OverviewView({super.key, required this.appState});

  @override
  State<OverviewView> createState() => _OverviewViewState();
}

class _OverviewViewState extends State<OverviewView> {
  bool _isDragging = false;

  @override
  Widget build(BuildContext context) {
    // Wrap entire return in Watch() to react to signal changes
    return Watch((context) {
      final allFiles = widget.appState.allFiles;
      final stats = StatsService.calculateStats(allFiles);
      final spendingData = StatsService.getSpendingOverTime(allFiles);
      final topVendors = StatsService.getTopVendors(allFiles, limit: 5);
      final recentActivity = StatsService.getRecentActivity(allFiles, limit: 8);

      return SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Stats Cards Row
            Row(
              children: [
                Expanded(
                  child: _buildStatCard(
                    context,
                    'Total Invoices',
                    stats.totalInvoices.toString(),
                    CupertinoIcons.doc_fill,
                    CupertinoColors.systemBlue,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _buildStatCard(
                    context,
                    'Processed',
                    stats.processedInvoices.toString(),
                    CupertinoIcons.checkmark_circle_fill,
                    CupertinoColors.systemGreen,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _buildStatCard(
                    context,
                    'Pending',
                    stats.pendingInvoices.toString(),
                    CupertinoIcons.clock_fill,
                    CupertinoColors.systemOrange,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _buildStatCard(
                    context,
                    'Total Amount',
                    '${stats.currency} ${NumberFormat('#,##0.00').format(stats.totalAmount)}',
                    CupertinoIcons.money_dollar_circle_fill,
                    CupertinoColors.systemPurple,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),

            // Auto-rename toggle
            GestureDetector(
              onTap: () {
                widget.appState.autoRenameDropped.value =
                    !widget.appState.autoRenameDropped.value;
              },
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color:
                      MacosTheme.of(context).canvasColor.withValues(alpha: 0.5),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: MacosTheme.of(context).dividerColor,
                  ),
                ),
                child: Row(
                  children: [
                    MacosSwitch(
                      value: widget.appState.autoRenameDropped.value,
                      onChanged: (value) {
                        widget.appState.autoRenameDropped.value = value;
                      },
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Auto-rename dropped files',
                            style: MacosTheme.of(context).typography.body,
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Files will be renamed automatically using the filename template',
                            style: MacosTheme.of(context)
                                .typography
                                .caption1
                                .copyWith(
                                  color: CupertinoColors.systemGrey,
                                ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Dropzone
            _buildDropzone(context),
            const SizedBox(height: 24),

            // Charts Row
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Spending Over Time Chart
                Expanded(
                  flex: 2,
                  child: _buildSpendingChart(
                      context, spendingData, stats.currency),
                ),
                const SizedBox(width: 16),

                // Top Vendors
                Expanded(
                  child: _buildTopVendors(context, topVendors),
                ),
              ],
            ),
            const SizedBox(height: 24),

            // Recent Activity
            _buildRecentActivity(context, recentActivity),
          ],
        ),
      );
    });
  }

  Widget _buildStatCard(
    BuildContext context,
    String label,
    String value,
    IconData icon,
    Color color,
  ) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: MacosTheme.of(context).canvasColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: MacosTheme.of(context).dividerColor,
          width: 0.5,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              MacosIcon(icon, color: color, size: 24),
              const Spacer(),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            value,
            style: MacosTheme.of(context).typography.title1.copyWith(
                  fontWeight: FontWeight.bold,
                ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: MacosTheme.of(context).typography.body.copyWith(
                  color: CupertinoColors.systemGrey,
                ),
          ),
        ],
      ),
    );
  }

  /// Pick files via file picker and process them
  Future<void> _pickAndProcessFiles(BuildContext context) async {
    debugPrint('[OverviewView] File picker clicked');

    try {
      // Get files from file picker
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf'],
        allowMultiple: true,
      );

      if (result == null || result.files.isEmpty) {
        debugPrint('[OverviewView] File picker cancelled or no files selected');
        return;
      }

      debugPrint('[OverviewView] File picker: ${result.files.length} files selected');

      // Convert to list of file paths
      final filePaths = result.files
          .where((f) => f.path != null)
          .map((f) => f.path!)
          .toList();

      if (filePaths.isEmpty) {
        debugPrint('[OverviewView] No valid file paths from picker');
        return;
      }

      // Process the files (same as drag-and-drop)
      if (context.mounted) {
        await _processMultipleFiles(context, filePaths);
      }
    } catch (e, stackTrace) {
      debugPrint('[OverviewView] Error in file picker: $e');
      debugPrint('[OverviewView] Stack trace: $stackTrace');
    }
  }

  /// Process multiple files (used by both drag-and-drop and file picker)
  Future<void> _processMultipleFiles(
    BuildContext context,
    List<String> filePaths,
  ) async {
    debugPrint('[OverviewView] _processMultipleFiles: ${filePaths.length} files');

    // Set processing state via signals
    debugPrint('[OverviewView] Setting isProcessingDropped = true');
    widget.appState.isProcessingDropped.value = true;
    widget.appState.droppedFileProgress.value = DroppedFileProgress(
      current: 0,
      total: filePaths.length,
    );

    // Separate PDF files from non-PDF files
    final pdfFiles = filePaths
        .where((f) => f.toLowerCase().endsWith('.pdf'))
        .toList();

    final skippedCount = filePaths.length - pdfFiles.length;
    debugPrint(
        '[OverviewView] Processing ${pdfFiles.length} PDFs, skipping $skippedCount non-PDFs');

    // Process each file with progress updates
    int processed = 0;
    int failed = 0;

    for (int i = 0; i < pdfFiles.length; i++) {
      debugPrint(
          '[OverviewView] Processing file ${i + 1}/${pdfFiles.length}: ${path.basename(pdfFiles[i])}');

      // Update progress via signals
      widget.appState.droppedFileProgress.value = DroppedFileProgress(
        current: i + 1,
        total: pdfFiles.length,
        currentFileName: path.basename(pdfFiles[i]),
      );

      try {
        await widget.appState.processDroppedFile(
          pdfFiles[i],
          context,
          showDialog: false, // Never show dialog in batch
        );
        processed++;
        debugPrint(
            '[OverviewView] Successfully processed: ${path.basename(pdfFiles[i])}');
      } catch (e) {
        failed++;
        debugPrint(
            '[OverviewView] Failed to process: ${path.basename(pdfFiles[i])} - $e');
      }
    }

    debugPrint(
        '[OverviewView] Batch complete: $processed succeeded, $failed failed');

    // Clear processing state via signals
    debugPrint('[OverviewView] Setting isProcessingDropped = false');
    widget.appState.isProcessingDropped.value = false;
    widget.appState.droppedFileProgress.value = null;

    // Show summary notification if mounted
    if (mounted && context.mounted) {
      _showProcessingSummary(context, processed, failed, skippedCount);
    }
  }

  Widget _buildDropzone(BuildContext context) {
    return DropTarget(
      onDragEntered: (details) {
        debugPrint('[OverviewView] onDragEntered');
        setState(() => _isDragging = true);
      },
      onDragExited: (details) {
        debugPrint('[OverviewView] onDragExited');
        setState(() => _isDragging = false);
      },
      onDragDone: (details) async {
        final fileCount = details.files.length;
        debugPrint('[OverviewView] onDragDone: $fileCount files dropped');
        setState(() => _isDragging = false);

        // Store context before async gap
        final contextBeforeAsync = context;
        if (!mounted) return;

        // Convert dropped files to paths
        final filePaths = details.files.map((f) => f.path).toList();

        // Process using unified method
        await _processMultipleFiles(contextBeforeAsync, filePaths);
      },
      child: GestureDetector(
        onTap: () => _pickAndProcessFiles(context),
        child: Container(
          height: 160,
          decoration: BoxDecoration(
            color: _isDragging
                ? MacosTheme.of(context).primaryColor.withValues(alpha: 0.1)
                : MacosTheme.of(context).canvasColor.withValues(alpha: 0.5),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: _isDragging
                  ? MacosTheme.of(context).primaryColor
                  : MacosTheme.of(context).dividerColor,
              width: _isDragging ? 2 : 1,
              style: BorderStyle.solid,
            ),
          ),
          child: Center(
            child: widget.appState.isProcessingDropped.value
                ? _buildProcessingState()
                : _buildIdleState(),
          ),
        ),
      ),
    );
  }

  Widget _buildProcessingState() {
    final progress = widget.appState.droppedFileProgress.value;

    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const ProgressCircle(radius: 24),
        const SizedBox(height: 16),
        Text(
          'Processing ${progress?.current ?? 0} of ${progress?.total ?? 0} files...',
          style: MacosTheme.of(context).typography.headline,
        ),
        if (progress?.currentFileName != null) ...[
          const SizedBox(height: 8),
          Text(
            progress!.currentFileName!,
            style: MacosTheme.of(context).typography.caption1.copyWith(
                  color: CupertinoColors.systemGrey,
                ),
            overflow: TextOverflow.ellipsis,
            maxLines: 1,
          ),
        ],
      ],
    );
  }

  Widget _buildIdleState() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        MacosIcon(
          CupertinoIcons.cloud_upload,
          size: 48,
          color: _isDragging
              ? MacosTheme.of(context).primaryColor
              : CupertinoColors.systemGrey,
        ),
        const SizedBox(height: 12),
        Text(
          _isDragging
              ? 'Drop PDF files here'
              : 'Drop PDF files here or click to browse',
          style: MacosTheme.of(context).typography.headline.copyWith(
                color: _isDragging
                    ? MacosTheme.of(context).primaryColor
                    : CupertinoColors.systemGrey,
              ),
        ),
        const SizedBox(height: 4),
        Text(
          'Files will be processed automatically',
          style: MacosTheme.of(context).typography.caption1.copyWith(
                color: CupertinoColors.inactiveGray,
              ),
        ),
      ],
    );
  }

  Widget _buildSpendingChart(
    BuildContext context,
    List<SpendingDataPoint> data,
    String currency,
  ) {
    if (data.isEmpty) {
      return _buildEmptyChartCard(
        context,
        'Spending Over Time',
        'No invoice data available yet',
      );
    }

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: MacosTheme.of(context).canvasColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: MacosTheme.of(context).dividerColor,
          width: 0.5,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Spending Over Time',
            style: MacosTheme.of(context).typography.title2,
          ),
          const SizedBox(height: 20),
          SizedBox(
            height: 200,
            child: LineChart(
              LineChartData(
                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: false,
                  getDrawingHorizontalLine: (value) {
                    return FlLine(
                      color: MacosTheme.of(context).dividerColor,
                      strokeWidth: 0.5,
                    );
                  },
                ),
                titlesData: FlTitlesData(
                  show: true,
                  rightTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  topTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 30,
                      interval: 1,
                      getTitlesWidget: (value, meta) {
                        if (value.toInt() >= 0 && value.toInt() < data.length) {
                          final date = data[value.toInt()].date;
                          return Padding(
                            padding: const EdgeInsets.only(top: 8.0),
                            child: Text(
                              DateFormat('MMM d').format(date),
                              style: const TextStyle(
                                color: CupertinoColors.systemGrey,
                                fontSize: 10,
                              ),
                            ),
                          );
                        }
                        return const Text('');
                      },
                    ),
                  ),
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 45,
                      getTitlesWidget: (value, meta) {
                        return Text(
                          NumberFormat.compact().format(value),
                          style: const TextStyle(
                            color: CupertinoColors.systemGrey,
                            fontSize: 10,
                          ),
                        );
                      },
                    ),
                  ),
                ),
                borderData: FlBorderData(show: false),
                minX: 0,
                maxX: (data.length - 1).toDouble(),
                minY: 0,
                maxY:
                    data.map((d) => d.amount).reduce((a, b) => a > b ? a : b) *
                        1.2,
                lineBarsData: [
                  LineChartBarData(
                    spots: data.asMap().entries.map((e) {
                      return FlSpot(e.key.toDouble(), e.value.amount);
                    }).toList(),
                    isCurved: true,
                    color: MacosTheme.of(context).primaryColor,
                    barWidth: 3,
                    isStrokeCapRound: true,
                    dotData: const FlDotData(show: true),
                    belowBarData: BarAreaData(
                      show: true,
                      color: MacosTheme.of(context)
                          .primaryColor
                          .withValues(alpha: 0.1),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTopVendors(BuildContext context, List<VendorStats> vendors) {
    if (vendors.isEmpty) {
      return _buildEmptyChartCard(
        context,
        'Top Vendors',
        'No vendor data available yet',
      );
    }

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: MacosTheme.of(context).canvasColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: MacosTheme.of(context).dividerColor,
          width: 0.5,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Top Vendors',
            style: MacosTheme.of(context).typography.title2,
          ),
          const SizedBox(height: 16),
          ...vendors.map((vendor) => Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            vendor.vendorName,
                            style: MacosTheme.of(context).typography.body,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        Text(
                          '${vendor.invoiceCount}',
                          style:
                              MacosTheme.of(context).typography.body.copyWith(
                                    color: CupertinoColors.systemGrey,
                                  ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Expanded(
                          child: Container(
                            height: 6,
                            decoration: BoxDecoration(
                              color: MacosTheme.of(context).dividerColor,
                              borderRadius: BorderRadius.circular(3),
                            ),
                            child: FractionallySizedBox(
                              alignment: Alignment.centerLeft,
                              widthFactor: vendor.invoiceCount /
                                  vendors.first.invoiceCount,
                              child: Container(
                                decoration: BoxDecoration(
                                  color: MacosTheme.of(context).primaryColor,
                                  borderRadius: BorderRadius.circular(3),
                                ),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          '${vendor.currency} ${NumberFormat('#,##0.00').format(vendor.totalAmount)}',
                          style: MacosTheme.of(context)
                              .typography
                              .caption1
                              .copyWith(
                                color: CupertinoColors.systemGrey,
                              ),
                        ),
                      ],
                    ),
                  ],
                ),
              )),
        ],
      ),
    );
  }

  Widget _buildRecentActivity(
      BuildContext context, List<RecentActivity> activities) {
    if (activities.isEmpty) {
      return _buildEmptyChartCard(
        context,
        'Recent Activity',
        'No processed invoices yet',
      );
    }

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: MacosTheme.of(context).canvasColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: MacosTheme.of(context).dividerColor,
          width: 0.5,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Recent Activity',
            style: MacosTheme.of(context).typography.title2,
          ),
          const SizedBox(height: 16),
          ...activities.map((activity) {
            final file = activity.file;
            return GestureDetector(
              onTap: () => _showFileDetails(file),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 8),
                decoration: BoxDecoration(
                  border: Border(
                    bottom: BorderSide(
                      color: MacosTheme.of(context).dividerColor,
                      width: 0.5,
                    ),
                  ),
                ),
                child: Row(
                  children: [
                    const MacosIcon(
                      CupertinoIcons.doc_checkmark_fill,
                      size: 16,
                      color: CupertinoColors.systemGreen,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            file.vendor ?? 'Unknown Vendor',
                            style: MacosTheme.of(context).typography.body,
                            overflow: TextOverflow.ellipsis,
                          ),
                          Text(
                            file.name,
                            style: MacosTheme.of(context)
                                .typography
                                .caption1
                                .copyWith(
                                  color: CupertinoColors.systemGrey,
                                ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        if (file.totalAmount != null)
                          Text(
                            '${file.currency ?? 'USD'} ${NumberFormat('#,##0.00').format(file.totalAmount)}',
                            style: MacosTheme.of(context).typography.body,
                          ),
                        Text(
                          timeago.format(activity.processedAt),
                          style: MacosTheme.of(context)
                              .typography
                              .caption1
                              .copyWith(
                                color: CupertinoColors.inactiveGray,
                              ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildEmptyChartCard(
    BuildContext context,
    String title,
    String message,
  ) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: MacosTheme.of(context).canvasColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: MacosTheme.of(context).dividerColor,
          width: 0.5,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: MacosTheme.of(context).typography.title2,
          ),
          const SizedBox(height: 40),
          Center(
            child: Column(
              children: [
                const MacosIcon(
                  CupertinoIcons.chart_bar,
                  size: 48,
                  color: CupertinoColors.systemGrey,
                ),
                const SizedBox(height: 12),
                Text(
                  message,
                  style: MacosTheme.of(context).typography.body.copyWith(
                        color: CupertinoColors.systemGrey,
                      ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 40),
        ],
      ),
    );
  }

  Future _showFileDetails(PdfDocument file) {
    return showMacosSheet(
      context: context,
      barrierDismissible: true,
      builder: (context) => FileDetailDialog(initialFile: file),
    );
  }

  void _showProcessingSummary(
    BuildContext context,
    int processed,
    int failed,
    int skipped,
  ) {
    final messages = <String>[];

    if (processed > 0) {
      messages.add(
        '$processed file${processed != 1 ? 's' : ''} processed successfully',
      );
    }
    if (failed > 0) {
      messages.add('$failed file${failed != 1 ? 's' : ''} failed');
    }
    if (skipped > 0) {
      messages
          .add('$skipped file${skipped != 1 ? 's' : ''} skipped (not PDFs)');
    }

    if (messages.isEmpty) {
      return; // Nothing to show
    }

    showMacosAlertDialog(
      context: context,
      builder: (context) => MacosAlertDialog(
        appIcon: MacosIcon(
          failed > 0
              ? CupertinoIcons.exclamationmark_triangle
              : CupertinoIcons.checkmark_circle_fill,
        ),
        title: const Text('Processing Complete'),
        message: Text(messages.join('\n')),
        primaryButton: PushButton(
          controlSize: ControlSize.large,
          child: const Text('OK'),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
    );
  }
}
