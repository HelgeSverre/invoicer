import 'package:invoicer/models.dart';

/// Statistics data for the dashboard
class DashboardStats {
  final int totalInvoices;
  final int processedInvoices;
  final int pendingInvoices;
  final int errorInvoices;
  final double totalAmount;
  final String currency;

  DashboardStats({
    required this.totalInvoices,
    required this.processedInvoices,
    required this.pendingInvoices,
    required this.errorInvoices,
    required this.totalAmount,
    required this.currency,
  });
}

/// Data point for spending over time chart
class SpendingDataPoint {
  final DateTime date;
  final double amount;
  final int count;

  SpendingDataPoint({
    required this.date,
    required this.amount,
    required this.count,
  });
}

/// Vendor statistics for top vendors display
class VendorStats {
  final String vendorName;
  final int invoiceCount;
  final double totalAmount;
  final String currency;

  VendorStats({
    required this.vendorName,
    required this.invoiceCount,
    required this.totalAmount,
    required this.currency,
  });
}

/// Recent activity item
class RecentActivity {
  final PdfDocument file;
  final DateTime processedAt;

  RecentActivity({
    required this.file,
    required this.processedAt,
  });
}

/// Service for calculating dashboard statistics
class StatsService {
  /// Calculate overall dashboard statistics
  static DashboardStats calculateStats(List<PdfDocument> files) {
    final totalInvoices = files.length;
    final processedInvoices = files.where((f) => f.vendor != null).length;
    final pendingInvoices = files.where((f) => f.vendor == null && f.error == null && !f.isProcessing).length;
    final errorInvoices = files.where((f) => f.error != null).length;

    double totalAmount = 0.0;
    String currency = 'USD';

    for (var file in files) {
      if (file.totalAmount != null) {
        totalAmount += file.totalAmount!;
        if (file.currency != null) {
          currency = file.currency!;
        }
      }
    }

    return DashboardStats(
      totalInvoices: totalInvoices,
      processedInvoices: processedInvoices,
      pendingInvoices: pendingInvoices,
      errorInvoices: errorInvoices,
      totalAmount: totalAmount,
      currency: currency,
    );
  }

  /// Get spending over time data grouped by period
  static List<SpendingDataPoint> getSpendingOverTime(
    List<PdfDocument> files, {
    Duration groupBy = const Duration(days: 7),
  }) {
    // Filter to only processed files with dates and amounts
    final processedFiles = files.where((f) =>
      f.vendor != null &&
      f.invoiceDate != null &&
      f.totalAmount != null
    ).toList();

    if (processedFiles.isEmpty) {
      return [];
    }

    // Sort by date
    processedFiles.sort((a, b) => a.invoiceDate!.compareTo(b.invoiceDate!));

    // Group by time period
    final Map<DateTime, List<PdfDocument>> grouped = {};

    for (var file in processedFiles) {
      // Normalize date to start of period
      final date = file.invoiceDate!;
      final normalized = DateTime(date.year, date.month, date.day);
      final periodStart = normalized.subtract(
        Duration(days: normalized.weekday % 7),
      );

      grouped.putIfAbsent(periodStart, () => []).add(file);
    }

    // Convert to data points
    return grouped.entries.map((entry) {
      final amount = entry.value.fold<double>(
        0.0,
        (sum, file) => sum + (file.totalAmount ?? 0.0),
      );
      return SpendingDataPoint(
        date: entry.key,
        amount: amount,
        count: entry.value.length,
      );
    }).toList()..sort((a, b) => a.date.compareTo(b.date));
  }

  /// Get top vendors by invoice count
  static List<VendorStats> getTopVendors(
    List<PdfDocument> files, {
    int limit = 10,
  }) {
    // Filter to only processed files
    final processedFiles = files.where((f) => f.vendor != null).toList();

    if (processedFiles.isEmpty) {
      return [];
    }

    // Group by vendor
    final Map<String, List<PdfDocument>> grouped = {};

    for (var file in processedFiles) {
      final vendor = file.vendor!;
      grouped.putIfAbsent(vendor, () => []).add(file);
    }

    // Convert to vendor stats and sort by count
    final stats = grouped.entries.map((entry) {
      final totalAmount = entry.value.fold<double>(
        0.0,
        (sum, file) => sum + (file.totalAmount ?? 0.0),
      );
      final currency = entry.value.firstWhere(
        (f) => f.currency != null,
        orElse: () => entry.value.first,
      ).currency ?? 'USD';

      return VendorStats(
        vendorName: entry.key,
        invoiceCount: entry.value.length,
        totalAmount: totalAmount,
        currency: currency,
      );
    }).toList();

    stats.sort((a, b) => b.invoiceCount.compareTo(a.invoiceCount));

    return stats.take(limit).toList();
  }

  /// Get recent activity (recently processed files)
  static List<RecentActivity> getRecentActivity(
    List<PdfDocument> files, {
    int limit = 10,
  }) {
    // For now, we'll use files with vendors as "processed"
    // In the future, you might want to add a processedAt timestamp to PdfDocument
    final processedFiles = files.where((f) => f.vendor != null).toList();

    // Sort by invoice date (as proxy for processed date)
    processedFiles.sort((a, b) {
      if (a.invoiceDate == null && b.invoiceDate == null) return 0;
      if (a.invoiceDate == null) return 1;
      if (b.invoiceDate == null) return -1;
      return b.invoiceDate!.compareTo(a.invoiceDate!);
    });

    return processedFiles.take(limit).map((file) {
      return RecentActivity(
        file: file,
        processedAt: file.invoiceDate ?? DateTime.now(),
      );
    }).toList();
  }
}
