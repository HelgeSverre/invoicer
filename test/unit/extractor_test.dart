import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:invoicer/extractor.dart';

void main() {
  group('Extractor.extractReceiptData', () {
    test('throws exception when API key is empty', () async {
      // Arrange
      const sampleText = 'Invoice text';
      const emptyApiKey = '';

      // Act & Assert
      expect(
        () => Extractor.extractReceiptData(sampleText, emptyApiKey),
        throwsA(
          isA<Exception>().having(
            (e) => e.toString(),
            'message',
            contains('OpenAI API key not set'),
          ),
        ),
      );
    });

    test('successfully extracts invoice data with valid API key', () async {
      // This test requires refactoring Extractor to allow dependency injection
      // of the Dio client for proper mocking.
      //
      // Expected behavior:
      // - Should accept API key and invoice text
      // - Should return structured data matching the OpenAI response schema
      // - Should extract vendor, total_amount, invoice_date, etc.
    }, skip: 'Requires Extractor refactoring for dependency injection');

    test('retries on 429 rate limit error with exponential backoff', () async {
      // This test requires Extractor refactoring to inject Dio client
    }, skip: 'Requires Extractor refactoring for dependency injection');

    test('retries on 5xx server errors', () async {
      // This test requires Extractor refactoring to inject Dio client
    }, skip: 'Requires Extractor refactoring for dependency injection');

    test('retries on network timeout errors', () async {
      // This test requires Extractor refactoring to inject Dio client
    }, skip: 'Requires Extractor refactoring for dependency injection');

    test('does not retry on 400 bad request', () async {
      // This test requires Extractor refactoring to inject Dio client
    }, skip: 'Requires Extractor refactoring for dependency injection');

    test('throws exception after exhausting max retries', () async {
      // This test requires Extractor refactoring to inject Dio client
    }, skip: 'Requires Extractor refactoring for dependency injection');
  });

  group('Extractor.extractTextFromPDF', () {
    test('throws exception for nonexistent file', () async {
      // Arrange
      const invalidPath = '/nonexistent/path/to/file.pdf';

      // Act & Assert
      expect(
        () => Extractor.extractTextFromPDF(invalidPath),
        throwsA(
          isA<Exception>().having(
            (e) => e.toString(),
            'message',
            contains('Could not extract text from PDF'),
          ),
        ),
      );
    });

    // Note: Testing with real PDF files requires test fixtures
    // The following tests require actual PDF test files
    test('returns trimmed text content from valid PDF', () async {
      // This test requires a sample PDF file in test/fixtures/
    }, skip: 'Requires PDF test fixture');

    test('returns empty string for PDF without text', () async {
      // This test requires an image-only PDF in test/fixtures/
    }, skip: 'Requires PDF test fixture');

    test('throws exception for corrupted PDF', () async {
      // This test requires a corrupted PDF in test/fixtures/
    }, skip: 'Requires PDF test fixture');
  });

  group('Extractor.client', () {
    test('creates Dio instance with cache interceptor', () {
      // Act
      final dio = Extractor.client();

      // Assert
      expect(dio, isA<Dio>());
      expect(dio.interceptors, isNotEmpty);
      expect(
        dio.interceptors
            .any((i) => i.toString().contains('DioCacheInterceptor')),
        isTrue,
        reason: 'Should have DioCacheInterceptor configured',
      );
    });
  });
}
