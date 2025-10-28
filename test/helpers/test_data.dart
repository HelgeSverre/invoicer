import 'package:invoicer/models.dart';

/// Factory methods for creating test data
class TestData {
  /// Create a sample PdfDocument for testing
  static PdfDocument createPdfDocument({
    String? name,
    String? path,
    String? vendor,
    DateTime? invoiceDate,
    double? totalAmount,
    String? currency,
    double? taxAmount,
    double? discountAmount,
    List<ReceiptItem>? items,
    bool isProcessing = false,
    String? error,
    String source = 'folder',
  }) {
    return PdfDocument(
      name: name ?? 'test.pdf',
      path: path ?? '/tmp/test.pdf',
      vendor: vendor,
      invoiceDate: invoiceDate,
      totalAmount: totalAmount,
      currency: currency,
      taxAmount: taxAmount,
      discountAmount: discountAmount,
      items: items ?? [],
      isProcessing: isProcessing,
      error: error,
      source: source,
    );
  }

  /// Create a sample ReceiptItem for testing
  static ReceiptItem createReceiptItem({
    String? sku,
    String? text,
    double? unitPrice,
    int? quantity,
  }) {
    return ReceiptItem(
      sku: sku,
      text: text ?? 'Test Item',
      unitPrice: unitPrice ?? 10.0,
      quantity: quantity ?? 1,
    );
  }

  /// Create a sample ProjectFolder for testing
  static ProjectFolder createProjectFolder({
    String? path,
    String? name,
    DateTime? addedAt,
    int fileCount = 0,
  }) {
    return ProjectFolder(
      path: path ?? '/test/folder',
      name: name ?? 'Test Folder',
      addedAt: addedAt ?? DateTime.now(),
      fileCount: fileCount,
    );
  }

  /// Sample invoice text for PDF extraction testing
  static const String sampleInvoiceText = '''
Invoice

ACME Corporation
123 Main Street
Anytown, CA 12345
contact@acmecorp.com
www.acmecorp.com

Invoice Date: January 15, 2024
Due Date: February 15, 2024
Invoice #: INV-2024-001

Bill To:
John Doe
456 Oak Avenue
Somewhere, CA 54321

Items:
-------------------------------------------
Description         Qty    Unit Price    Total
Widget Pro          2      \$50.00       \$100.00
Gadget Basic        1      \$30.00       \$30.00
-------------------------------------------

Subtotal:                               \$130.00
Tax (10%):                              \$13.00
Discount:                               \$5.00
-------------------------------------------
Total:                                  \$138.00

Payment Method: Credit Card ending in 1234

Thank you for your business!
''';

  /// Sample OpenAI API response for testing
  static Map<String, dynamic> createOpenAIResponse({
    String? vendor,
    String? invoiceDate,
    double? totalAmount,
    List<Map<String, dynamic>>? items,
  }) {
    return {
      'choices': [
        {
          'message': {
            'function_call': {
              'name': 'extract_receipt_data',
              'arguments': '''
{
  "vendor": "${vendor ?? "ACME Corporation"}",
  "invoice_date": "${invoiceDate ?? "2024-01-15"}",
  "due_date": "2024-02-15",
  "currency": "USD",
  "tax_amount": 13.0,
  "total_amount": ${totalAmount ?? 138.0},
  "discount_amount": 5.0,
  "vendor_email": "contact@acmecorp.com",
  "vendor_website": "www.acmecorp.com",
  "vendor_display_address": "123 Main Street, Anytown, CA 12345",
  "payment_method": "Credit Card",
  "last_four_digits": "1234",
  "items": ${items != null ? _itemsToJson(items) : '''[
    {
      "text": "Widget Pro",
      "unit_price": 50.0,
      "quantity": 2
    },
    {
      "text": "Gadget Basic",
      "unit_price": 30.0,
      "quantity": 1
    }
  ]'''}
}
'''
            }
          }
        }
      ]
    };
  }

  static String _itemsToJson(List<Map<String, dynamic>> items) {
    final buffer = StringBuffer('[');
    for (int i = 0; i < items.length; i++) {
      if (i > 0) buffer.write(',');
      buffer.write('''{
        "text": "${items[i]['text']}",
        "unit_price": ${items[i]['unit_price']},
        "quantity": ${items[i]['quantity']}
      }''');
    }
    buffer.write(']');
    return buffer.toString();
  }
}
