class ReceiptItem {
  String? sku;
  String text;
  String? currency;
  double unitPrice;
  int quantity;

  double get total => unitPrice * quantity;

  ReceiptItem({
    this.sku,
    required this.text,
    this.currency,
    required this.unitPrice,
    required this.quantity,
  });

  factory ReceiptItem.fromJson(Map<String, dynamic> json) {
    return ReceiptItem(
      sku: json['sku'],
      text: json['text'] ?? '',
      currency: json['currency'],
      unitPrice: (json['unit_price'] ?? 0).toDouble(),
      quantity: json['quantity'] ?? 1,
    );
  }
}

class PdfDocument {
  String name;
  String path;
  List<ReceiptItem> items;
  bool isProcessing;
  String? vendor;

  // Invoice details
  DateTime? invoiceDate;
  DateTime? dueDate;
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
    this.invoiceDate,
    this.dueDate,
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
    DateTime? invoiceDate,
    DateTime? dueDate,
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
      invoiceDate: invoiceDate ?? this.invoiceDate,
      dueDate: dueDate ?? this.dueDate,
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
}
