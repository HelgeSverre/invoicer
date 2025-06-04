import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:http/http.dart' as http;
import 'package:syncfusion_flutter_pdf/pdf.dart';

class Extractor {
  static Future<String> extractTextFromPDF(String filePath) async {
    try {
      final Uint8List inputBytes = File(filePath).readAsBytesSync();
      final PdfDocument document = PdfDocument(inputBytes: inputBytes);
      String text = PdfTextExtractor(document).extractText();
      document.dispose();
      return text.trim();
    } catch (e) {
      throw Exception('Could not extract text from PDF: $e');
    }
  }

  static Future<Map<String, dynamic>> extractReceiptData(
    String pdfText,
    String apiKey,
  ) async {
    if (apiKey.isEmpty) {
      throw Exception('OpenAI API key not set');
    }

    final response = await http.post(
      Uri.parse('https://api.openai.com/v1/chat/completions'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $apiKey',
      },
      body: jsonEncode({
        'model': 'gpt-4o-mini',
        'messages': [
          {
            'role': 'user',
            'content':
                'Extract comprehensive invoice data from the following document content. Please extract all available information including vendor details, financial amounts, dates, line items, and payment information.\n\nDocument content:\n\n$pdfText',
          },
        ],
        'functions': [
          {
            'name': 'extract_receipt_data',
            'description':
                'Extract comprehensive invoice data including line items, vendor details, dates, and financial information',
            'parameters': {
              'type': 'object',
              'properties': {
                'vendor': {
                  'type': 'string',
                  'description': 'The vendor/business name from the invoice',
                },
                'invoice_date': {
                  'type': 'string',
                  'description': 'The invoice date (YYYY-MM-DD format)',
                },
                'due_date': {
                  'type': 'string',
                  'description': 'The payment due date (YYYY-MM-DD format)',
                },
                'tax_amount': {
                  'type': 'number',
                  'description': 'Total tax amount on the invoice',
                },
                'total_amount': {
                  'type': 'number',
                  'description': 'Total amount of the invoice including tax',
                },
                'discount_amount': {
                  'type': 'number',
                  'description': 'Total discount amount applied',
                },
                'vendor_website': {
                  'type': 'string',
                  'description': 'Vendor website URL if available',
                },
                'vendor_email': {
                  'type': 'string',
                  'description': 'Vendor email address if available',
                },
                'vendor_display_address': {
                  'type': 'string',
                  'description': 'Vendor full address as displayed on invoice',
                },
                'payment_method': {
                  'type': 'string',
                  'description':
                      'Payment method used (e.g., Credit Card, Cash, Bank Transfer)',
                },
                'last_four_digits': {
                  'type': 'string',
                  'description':
                      'Last four digits of payment card if applicable',
                },
                'items': {
                  'type': 'array',
                  'description': 'List of line items from the invoice',
                  'items': {
                    'type': 'object',
                    'properties': {
                      'sku': {
                        'type': 'string',
                        'description': 'SKU or identifier for the item',
                      },
                      'text': {
                        'type': 'string',
                        'description': 'Product name or description',
                      },
                      'currency': {
                        'type': 'string',
                        'description': 'Currency of the item price',
                      },
                      'unit_price': {
                        'type': 'number',
                        'description': 'Unit price of the item',
                      },
                      'quantity': {
                        'type': 'integer',
                        'description': 'Quantity of the item',
                      },
                    },
                    'required': ['text', 'quantity', 'unit_price'],
                  },
                },
              },
              'required': ['items'],
            },
          },
        ],
        'function_call': {'name': 'extract_receipt_data'},
      }),
    );

    if (response.statusCode != 200) {
      throw Exception(
        'OpenAI API error: ${response.statusCode} - ${response.body}',
      );
    }

    final responseData = jsonDecode(response.body);
    final functionCall = responseData['choices'][0]['message']['function_call'];
    return jsonDecode(functionCall['arguments']);
  }
}
