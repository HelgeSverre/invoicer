import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:dio_cache_interceptor/dio_cache_interceptor.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart';

class Extractor {
  static Dio client() {
    var dio = Dio();

    dio.interceptors.add(
      DioCacheInterceptor(
        options: CacheOptions(
          store: MemCacheStore(
            maxEntrySize: 100,
            maxSize: 100 * 1024 * 1024, // 100 MB
          ),
          hitCacheOnNetworkFailure: true,
          allowPostMethod: true,
        ),
      ),
    );

    return dio;
  }

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
    String apiKey, {
    String model = "gpt-4.1-mini",
    int maxRetries = 3,
    Duration initialDelay = const Duration(seconds: 1),
  }) async {
    if (apiKey.isEmpty) {
      throw Exception('OpenAI API key not set');
    }

    var prompt = {
      'model': model,
      'messages': [
        {
          'role': 'user',
          'content': "Extract comprehensive invoice data from the following document content. "
              "Please extract all available information including vendor details, "
              "financial amounts, dates, line items, and payment information. "
              "\n\nDocument content:"
              "\n\n$pdfText",
        },
      ],
      'function_call': {'name': 'extract_receipt_data'},
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
              'currency': {
                'type': 'string',
                'description':
                    'Currency used in the invoice (e.g., USD, EUR), null if not specified',
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
                'description': 'Last four digits of payment card if applicable',
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
            'required': ['invoiceDate', 'totalAmount', 'vendor'],
          },
        },
      ],
    };

    // Retry logic with exponential backoff
    int attemptNumber = 0;
    Duration currentDelay = initialDelay;
    Exception? lastException;

    while (attemptNumber < maxRetries) {
      try {
        final response = await client().post(
          "https://api.openai.com/v1/chat/completions",
          options: Options(
            contentType: Headers.jsonContentType,
            headers: {'Authorization': 'Bearer $apiKey'},
            receiveDataWhenStatusError: true,
          ),
          data: prompt,
        );

        if (response.statusCode == 200) {
          var choices = response.data['choices'];
          var functionCall = choices[0]['message']['function_call'];
          return jsonDecode(functionCall['arguments']);
        }

        // Handle rate limiting (429) and server errors (5xx) with retry
        if (response.statusCode == 429 ||
            (response.statusCode! >= 500 && response.statusCode! < 600)) {
          throw _RetryableException(
            'OpenAI API error: ${response.statusCode} - ${response.data}',
            statusCode: response.statusCode,
          );
        }

        // Non-retryable errors (4xx except 429)
        throw Exception(
          'OpenAI API error: ${response.statusCode} - ${response.data}',
        );
      } on _RetryableException catch (e) {
        lastException = e;
        attemptNumber++;

        if (attemptNumber < maxRetries) {
          print(
            'Attempt $attemptNumber failed with ${e.statusCode}. Retrying in ${currentDelay.inSeconds}s...',
          );
          await Future.delayed(currentDelay);
          currentDelay *= 2; // Exponential backoff
        }
      } on DioException catch (e) {
        // Network errors are retryable
        if (_isNetworkError(e)) {
          lastException = Exception('Network error: ${e.message}');
          attemptNumber++;

          if (attemptNumber < maxRetries) {
            print(
              'Network error on attempt $attemptNumber. Retrying in ${currentDelay.inSeconds}s...',
            );
            await Future.delayed(currentDelay);
            currentDelay *= 2; // Exponential backoff
          }
        } else {
          // Non-network Dio errors are not retryable
          throw Exception('Request failed: ${e.message}');
        }
      }
    }

    // All retries exhausted
    throw Exception(
      'Failed after $maxRetries attempts. Last error: ${lastException?.toString()}',
    );
  }

  static bool _isNetworkError(DioException e) {
    return e.type == DioExceptionType.connectionTimeout ||
        e.type == DioExceptionType.sendTimeout ||
        e.type == DioExceptionType.receiveTimeout ||
        e.type == DioExceptionType.connectionError ||
        e.type == DioExceptionType.unknown;
  }
}

class _RetryableException implements Exception {
  final String message;
  final int? statusCode;

  _RetryableException(this.message, {this.statusCode});

  @override
  String toString() => message;
}
