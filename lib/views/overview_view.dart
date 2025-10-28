import 'package:desktop_drop/desktop_drop.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/cupertino.dart';
import 'package:intl/intl.dart';
import 'package:invoicer/dialogs/file_detail_dialog.dart';
import 'package:invoicer/services/stats_service.dart';
import 'package:invoicer/state.dart';
import 'package:macos_ui/macos_ui.dart';
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
                Expanded(child: _buildStatCard(
                  context,
                  'Total Invoices',
                  stats.totalInvoices.toString(),
                  CupertinoIcons.doc_fill,
                  CupertinoColors.systemBlue,
                )),
                const SizedBox(width: 16),
                Expanded(child: _buildStatCard(
                  context,
                  'Processed',
                  stats.processedInvoices.toString(),
                  CupertinoIcons.checkmark_circle_fill,
                  CupertinoColors.systemGreen,
                )),
                const SizedBox(width: 16),
                Expanded(child: _buildStatCard(
                  context,
                  'Pending',
                  stats.pendingInvoices.toString(),
                  CupertinoIcons.clock_fill,
                  CupertinoColors.systemOrange,
                )),
                const SizedBox(width: 16),
                Expanded(child: _buildStatCard(
                  context,
                  'Total Amount',
                  '${stats.currency} ${NumberFormat('#,##0.00').format(stats.totalAmount)}',
                  CupertinoIcons.money_dollar_circle_fill,
                  CupertinoColors.systemPurple,
                )),
              ],
            ),
            const SizedBox(height: 24),

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
                  child: _buildSpendingChart(context, spendingData, stats.currency),
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

  Widget _buildDropzone(BuildContext context) {
    return DropTarget(
      onDragEntered: (_) => setState(() => _isDragging = true),
      onDragExited: (_) => setState(() => _isDragging = false),
      onDragDone: (details) async {
        setState(() => _isDragging = false);

        for (var file in details.files) {
          if (file.path.toLowerCase().endsWith('.pdf')) {
            await widget.appState.processDroppedFile(file.path, context);
          }
        }
      },
      child: GestureDetector(
        onTap: () => widget.appState.addIndividualFiles(),
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
            child: Column(
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
            ),
          ),
        ),
      ),
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
                  horizontalInterval: 1,
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
                      interval: 1,
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
                maxY: data.map((d) => d.amount).reduce((a, b) => a > b ? a : b) * 1.2,
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
                      color: MacosTheme.of(context).primaryColor.withValues(alpha: 0.1),
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
                      style: MacosTheme.of(context).typography.body.copyWith(
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
                          widthFactor: vendor.invoiceCount / vendors.first.invoiceCount,
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
                      style: MacosTheme.of(context).typography.caption1.copyWith(
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

  Widget _buildRecentActivity(BuildContext context, List<RecentActivity> activities) {
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
                    MacosIcon(
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
                            style: MacosTheme.of(context).typography.caption1.copyWith(
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
                          style: MacosTheme.of(context).typography.caption1.copyWith(
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
}
