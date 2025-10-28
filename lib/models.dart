import 'package:intl/intl.dart';

extension DateUtils on DateTime {
  String format(String format) => DateFormat(format).format(this);
}

class ReceiptItem {
  String? sku;
  String text;
  double unitPrice;
  int quantity;

  double get total => unitPrice * quantity;

  ReceiptItem({
    this.sku,
    required this.text,
    required this.unitPrice,
    required this.quantity,
  });

  factory ReceiptItem.fromJson(Map<String, dynamic> json) {
    return ReceiptItem(
      sku: json['sku'],
      text: json['text'] ?? '',
      unitPrice: (json['unit_price'] ?? 0).toDouble(),
      quantity: json['quantity'] ?? 1,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'sku': sku,
      'text': text,
      'unit_price': unitPrice,
      'quantity': quantity,
    };
  }
}

class ProjectFolder {
  String path;
  String name;
  DateTime addedAt;
  int fileCount;

  ProjectFolder({
    required this.path,
    required this.name,
    required this.addedAt,
    this.fileCount = 0,
  });

  Map<String, dynamic> toJson() {
    return {
      'path': path,
      'name': name,
      'addedAt': addedAt.toIso8601String(),
      'fileCount': fileCount,
    };
  }

  factory ProjectFolder.fromJson(Map<String, dynamic> json) {
    return ProjectFolder(
      path: json['path'],
      name: json['name'],
      addedAt: DateTime.parse(json['addedAt']),
      fileCount: json['fileCount'] ?? 0,
    );
  }

  ProjectFolder copyWith({
    String? path,
    String? name,
    DateTime? addedAt,
    int? fileCount,
  }) {
    return ProjectFolder(
      path: path ?? this.path,
      name: name ?? this.name,
      addedAt: addedAt ?? this.addedAt,
      fileCount: fileCount ?? this.fileCount,
    );
  }
}

class PdfDocument {
  String name;
  String path;
  List<ReceiptItem> items;
  bool isProcessing;
  String? vendor;

  // Source information
  String source; // 'folder' or 'individual'
  String? folderPath; // null for individual files

  DateTime? invoiceDate;
  DateTime? dueDate;
  String? currency;
  double? taxAmount;
  double? totalAmount;
  double? discountAmount;
  String? vendorWebsite;
  String? vendorEmail;
  String? vendorDisplayAddress;
  String? paymentMethod;
  String? lastFourDigits;

  String? error;

  PdfDocument({
    required this.name,
    required this.path,
    this.items = const [],
    this.isProcessing = false,
    this.vendor,
    this.source = 'folder',
    this.folderPath,
    this.invoiceDate,
    this.dueDate,
    this.currency,
    this.taxAmount,
    this.totalAmount,
    this.discountAmount,
    this.vendorWebsite,
    this.vendorEmail,
    this.vendorDisplayAddress,
    this.paymentMethod,
    this.lastFourDigits,
    this.error,
  });

  bool get hasInvoiceDetails =>
      vendor != null ||
      invoiceDate != null ||
      dueDate != null ||
      currency != null ||
      taxAmount != null ||
      totalAmount != null ||
      discountAmount != null ||
      vendorWebsite != null ||
      vendorEmail != null ||
      vendorDisplayAddress != null ||
      paymentMethod != null ||
      lastFourDigits != null;

  PdfDocument copyWith({
    String? name,
    String? path,
    List<ReceiptItem>? items,
    bool? isProcessing,
    String? vendor,
    String? source,
    String? folderPath,
    DateTime? invoiceDate,
    DateTime? dueDate,
    String? currency,
    double? taxAmount,
    double? totalAmount,
    double? discountAmount,
    String? vendorWebsite,
    String? vendorEmail,
    String? vendorDisplayAddress,
    String? paymentMethod,
    String? lastFourDigits,
    String? error,
  }) {
    return PdfDocument(
      name: name ?? this.name,
      path: path ?? this.path,
      items: items ?? this.items,
      isProcessing: isProcessing ?? this.isProcessing,
      vendor: vendor ?? this.vendor,
      source: source ?? this.source,
      folderPath: folderPath ?? this.folderPath,
      invoiceDate: invoiceDate ?? this.invoiceDate,
      dueDate: dueDate ?? this.dueDate,
      currency: currency ?? this.currency,
      taxAmount: taxAmount ?? this.taxAmount,
      totalAmount: totalAmount ?? this.totalAmount,
      discountAmount: discountAmount ?? this.discountAmount,
      vendorWebsite: vendorWebsite ?? this.vendorWebsite,
      vendorEmail: vendorEmail ?? this.vendorEmail,
      vendorDisplayAddress: vendorDisplayAddress ?? this.vendorDisplayAddress,
      paymentMethod: paymentMethod ?? this.paymentMethod,
      lastFourDigits: lastFourDigits ?? this.lastFourDigits,
      error: error ?? this.error,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'path': path,
      'items': items.map((item) => item.toJson()).toList(),
      'vendor': vendor,
      'source': source,
      'folderPath': folderPath,
      'invoiceDate': invoiceDate?.toIso8601String(),
      'dueDate': dueDate?.toIso8601String(),
      'currency': currency,
      'taxAmount': taxAmount,
      'totalAmount': totalAmount,
      'discountAmount': discountAmount,
      'vendorWebsite': vendorWebsite,
      'vendorEmail': vendorEmail,
      'vendorDisplayAddress': vendorDisplayAddress,
      'paymentMethod': paymentMethod,
      'lastFourDigits': lastFourDigits,
      // Note: Don't serialize isProcessing, error - these are runtime state
    };
  }

  factory PdfDocument.fromJson(Map<String, dynamic> json) {
    return PdfDocument(
      name: json['name'] ?? '',
      path: json['path'] ?? '',
      items: (json['items'] as List<dynamic>?)
              ?.map(
                  (item) => ReceiptItem.fromJson(item as Map<String, dynamic>))
              .toList() ??
          [],
      vendor: json['vendor'],
      source: json['source'] ?? 'folder',
      folderPath: json['folderPath'],
      invoiceDate: json['invoiceDate'] != null
          ? DateTime.tryParse(json['invoiceDate'])
          : null,
      dueDate:
          json['dueDate'] != null ? DateTime.tryParse(json['dueDate']) : null,
      currency: json['currency'],
      taxAmount: json['taxAmount']?.toDouble(),
      totalAmount: json['totalAmount']?.toDouble(),
      discountAmount: json['discountAmount']?.toDouble(),
      vendorWebsite: json['vendorWebsite'],
      vendorEmail: json['vendorEmail'],
      vendorDisplayAddress: json['vendorDisplayAddress'],
      paymentMethod: json['paymentMethod'],
      lastFourDigits: json['lastFourDigits'],
    );
  }
}
