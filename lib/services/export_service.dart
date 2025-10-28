import 'dart:convert';
import 'dart:io';

import 'package:csv/csv.dart';
import 'package:excel/excel.dart';
import 'package:file_picker/file_picker.dart';
import 'package:intl/intl.dart';
import 'package:invoicer/logger.dart';
import 'package:invoicer/models.dart';
import 'package:invoicer/models/export_settings.dart';

final _logger = AppLogger('ExportService');

class ExportService {
  /// Format line items according to the specified format
  static String formatLineItems(
    List<ReceiptItem> items,
    LineItemFormat format,
  ) {
    if (items.isEmpty) return '';

    switch (format) {
      case LineItemFormat.json:
        return jsonEncode(items.map((item) => item.toJson()).toList());

      case LineItemFormat.newlineSeparated:
        return items.map((item) {
          final parts = <String>[
            item.text,
            if (item.sku != null) 'SKU: ${item.sku}',
            'qty: ${item.quantity}',
            '\$${item.unitPrice.toStringAsFixed(2)}',
          ];
          return parts.join(' | ');
        }).join('\n');

      case LineItemFormat.bulletedList:
        return items.map((item) {
          final parts = <String>[
            item.text,
            if (item.sku != null) 'SKU: ${item.sku}',
            'qty: ${item.quantity}',
            '\$${item.unitPrice.toStringAsFixed(2)}',
          ];
          return '- ${parts.join(' | ')}';
        }).join('\n');
    }
  }

  /// Export multiple invoices to CSV format
  static Future<String?> exportToCSV(
    List<PdfDocument> documents, {
    ExportSettings? settings,
  }) async {
    _logger.info('Exporting ${documents.length} invoices to CSV');
    settings ??= ExportSettings.defaultSettings;
    if (documents.isEmpty) {
      _logger.warning('No documents to export');
      throw Exception('No documents to export');
    }

    // Ask user where to save
    String? outputPath = await FilePicker.platform.saveFile(
      dialogTitle: 'Export to CSV',
      fileName:
          'invoices_${DateFormat('yyyy-MM-dd').format(DateTime.now())}.csv',
      type: FileType.custom,
      allowedExtensions: ['csv'],
    );

    if (outputPath == null) {
      return null;
    }

    // Build CSV data
    List<List<dynamic>> rows = [];

    // Header row (if enabled)
    if (settings.includeHeaders) {
      rows.add([
        'File Name',
        'Vendor',
        'Invoice Date',
        'Due Date',
        'Currency',
        'Subtotal',
        'Tax Amount',
        'Discount Amount',
        'Total Amount',
        'Payment Method',
        'Last Four Digits',
        'Vendor Email',
        'Vendor Website',
        'Vendor Address',
        'Item Count',
        'Items',
      ]);
    }

    // Data rows
    for (var doc in documents) {
      // Calculate subtotal
      double subtotal = 0;
      for (var item in doc.items) {
        subtotal += item.total;
      }

      rows.add([
        doc.name,
        doc.vendor ?? '',
        doc.invoiceDate != null
            ? DateFormat('yyyy-MM-dd').format(doc.invoiceDate!)
            : '',
        doc.dueDate != null
            ? DateFormat('yyyy-MM-dd').format(doc.dueDate!)
            : '',
        doc.currency ?? '',
        subtotal.toStringAsFixed(2),
        doc.taxAmount?.toStringAsFixed(2) ?? '',
        doc.discountAmount?.toStringAsFixed(2) ?? '',
        doc.totalAmount?.toStringAsFixed(2) ?? '',
        doc.paymentMethod ?? '',
        doc.lastFourDigits ?? '',
        doc.vendorEmail ?? '',
        doc.vendorWebsite ?? '',
        doc.vendorDisplayAddress ?? '',
        doc.items.length,
        formatLineItems(doc.items, settings.lineItemFormat),
      ]);
    }

    // Convert to CSV string with custom settings
    final converter = settings.alwaysQuote
        ? ListToCsvConverter(
            fieldDelimiter: settings.delimiter,
            textDelimiter: '"',
            eol: '\n',
          )
        : ListToCsvConverter(
            fieldDelimiter: settings.delimiter,
            eol: '\n',
          );
    String csv = converter.convert(rows);

    // Write to file
    await File(outputPath).writeAsString(csv);

    _logger.info('CSV export completed: $outputPath');
    return outputPath;
  }

  /// Export multiple invoices to JSON format
  static Future<String?> exportToJSON(
    List<PdfDocument> documents, {
    ExportSettings? settings,
  }) async {
    _logger.info('Exporting ${documents.length} invoices to JSON');
    settings ??= ExportSettings.defaultSettings;
    if (documents.isEmpty) {
      _logger.warning('No documents to export');
      throw Exception('No documents to export');
    }

    // Ask user where to save
    String? outputPath = await FilePicker.platform.saveFile(
      dialogTitle: 'Export to JSON',
      fileName:
          'invoices_${DateFormat('yyyy-MM-dd').format(DateTime.now())}.json',
      type: FileType.custom,
      allowedExtensions: ['json'],
    );

    if (outputPath == null) {
      return null;
    }

    // Build JSON data
    final exportData = {
      'exportDate': DateTime.now().toIso8601String(),
      'version': '1.0',
      'invoiceCount': documents.length,
      'invoices': documents.map((doc) => doc.toJson()).toList(),
    };

    // Write to file with pretty printing
    const encoder = JsonEncoder.withIndent('  ');
    String prettyJson = encoder.convert(exportData);
    await File(outputPath).writeAsString(prettyJson);

    _logger.info('JSON export completed: $outputPath');
    return outputPath;
  }

  /// Export multiple invoices to Excel format
  static Future<String?> exportToExcel(
    List<PdfDocument> documents, {
    ExportSettings? settings,
  }) async {
    _logger.info('Exporting ${documents.length} invoices to Excel');
    settings ??= ExportSettings.defaultSettings;
    if (documents.isEmpty) {
      _logger.warning('No documents to export');
      throw Exception('No documents to export');
    }

    // Ask user where to save
    String? outputPath = await FilePicker.platform.saveFile(
      dialogTitle: 'Export to Excel',
      fileName:
          'invoices_${DateFormat('yyyy-MM-dd').format(DateTime.now())}.xlsx',
      type: FileType.custom,
      allowedExtensions: ['xlsx'],
    );

    if (outputPath == null) {
      return null;
    }

    // Create Excel workbook
    var excel = Excel.createExcel();
    excel.delete('Sheet1');
    _createSummarySheet(excel, documents);
    _createItemsSheet(excel, documents);

    // Save file
    var bytes = excel.encode();
    if (bytes != null) {
      await File(outputPath).writeAsBytes(bytes);
      _logger.info('Excel export completed: $outputPath');
    } else {
      _logger.error('Failed to encode Excel file');
    }

    return outputPath;
  }

  static void _createSummarySheet(Excel excel, List<PdfDocument> documents) {
    var sheet = excel['Summary'];

    // Headers with styling
    final headerStyle = CellStyle(
      bold: true,
      backgroundColorHex: ExcelColor.blue,
      fontColorHex: ExcelColor.white,
    );

    final headers = [
      'File Name',
      'Vendor',
      'Invoice Date',
      'Due Date',
      'Currency',
      'Subtotal',
      'Tax Amount',
      'Discount Amount',
      'Total Amount',
      'Payment Method',
      'Last Four Digits',
      'Vendor Email',
      'Vendor Website',
      'Item Count',
    ];

    // Write headers
    for (int i = 0; i < headers.length; i++) {
      var cell =
          sheet.cell(CellIndex.indexByColumnRow(columnIndex: i, rowIndex: 0));
      cell.value = TextCellValue(headers[i]);
      cell.cellStyle = headerStyle;
    }

    // Write data rows
    for (int rowIndex = 0; rowIndex < documents.length; rowIndex++) {
      var doc = documents[rowIndex];

      // Calculate subtotal
      double subtotal = 0;
      for (var item in doc.items) {
        subtotal += item.total;
      }

      final rowData = [
        doc.name,
        doc.vendor ?? '',
        doc.invoiceDate != null
            ? DateFormat('yyyy-MM-dd').format(doc.invoiceDate!)
            : '',
        doc.dueDate != null
            ? DateFormat('yyyy-MM-dd').format(doc.dueDate!)
            : '',
        doc.currency ?? '',
        subtotal,
        doc.taxAmount ?? 0,
        doc.discountAmount ?? 0,
        doc.totalAmount ?? 0,
        doc.paymentMethod ?? '',
        doc.lastFourDigits ?? '',
        doc.vendorEmail ?? '',
        doc.vendorWebsite ?? '',
        doc.items.length,
      ];

      for (int colIndex = 0; colIndex < rowData.length; colIndex++) {
        var cell = sheet.cell(
          CellIndex.indexByColumnRow(
            columnIndex: colIndex,
            rowIndex: rowIndex + 1,
          ),
        );

        final value = rowData[colIndex];
        if (value is String) {
          cell.value = TextCellValue(value);
        } else if (value is int) {
          cell.value = IntCellValue(value);
        } else if (value is double) {
          cell.value = DoubleCellValue(value);
        }
      }
    }

    // Auto-size columns (approximate)
    for (int i = 0; i < headers.length; i++) {
      sheet.setColumnWidth(i, 20.0);
    }
  }

  static void _createItemsSheet(Excel excel, List<PdfDocument> documents) {
    var sheet = excel['Line Items'];

    // Headers
    final headerStyle = CellStyle(
      bold: true,
      backgroundColorHex: ExcelColor.blue,
      fontColorHex: ExcelColor.white,
    );

    final headers = [
      'Invoice File',
      'Vendor',
      'Item SKU',
      'Item Description',
      'Quantity',
      'Unit Price',
      'Total',
    ];

    // Write headers
    for (int i = 0; i < headers.length; i++) {
      var cell =
          sheet.cell(CellIndex.indexByColumnRow(columnIndex: i, rowIndex: 0));
      cell.value = TextCellValue(headers[i]);
      cell.cellStyle = headerStyle;
    }

    // Write data rows
    int currentRow = 1;
    for (var doc in documents) {
      for (var item in doc.items) {
        final rowData = [
          doc.name,
          doc.vendor ?? '',
          item.sku ?? '',
          item.text,
          item.quantity,
          item.unitPrice,
          item.total,
        ];

        for (int colIndex = 0; colIndex < rowData.length; colIndex++) {
          var cell = sheet.cell(
            CellIndex.indexByColumnRow(
              columnIndex: colIndex,
              rowIndex: currentRow,
            ),
          );

          final value = rowData[colIndex];
          if (value is String) {
            cell.value = TextCellValue(value);
          } else if (value is int) {
            cell.value = IntCellValue(value);
          } else if (value is double) {
            cell.value = DoubleCellValue(value);
          }
        }

        currentRow++;
      }
    }

    // Auto-size columns
    for (int i = 0; i < headers.length; i++) {
      sheet.setColumnWidth(i, 20.0);
    }
  }

  /// Export a single invoice with detailed information
  static Future<String?> exportSingleInvoice(
    PdfDocument document,
    ExportFormat format, {
    ExportSettings? settings,
  }) async {
    return switch (format) {
      ExportFormat.csv => exportToCSV([document], settings: settings),
      ExportFormat.json => exportToJSON([document], settings: settings),
      ExportFormat.excel => exportToExcel([document], settings: settings),
    };
  }
}

enum ExportFormat {
  csv,
  json,
  excel,
}
