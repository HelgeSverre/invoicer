import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:invoicer/extractor.dart';
import 'package:mocktail/mocktail.dart';

import '../helpers/mocks.dart';
import '../helpers/test_data.dart';

void main() {
  setUpAll(() {
    registerMockFallbacks();
  });

  group('Extractor.extractReceiptData', () {
    late MockDio mockDio;

    setUp(() {
      mockDio = MockDio();
    });

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
      // Arrange
      final sampleText = TestData.sampleInvoiceText;
      const apiKey = 'test-api-key';

      final mockResponse = Response(
        statusCode: 200,
        data: TestData.createOpenAIResponse(),
        requestOptions: RequestOptions(path: ''),
      );

      // Mock the Dio client - Note: This test requires refactoring Extractor
      // to allow dependency injection of the Dio client.
      // For now, this test demonstrates the expected behavior.

      // Act
      // final result = await Extractor.extractReceiptData(sampleText, apiKey);

      // Assert
      // expect(result['vendor'], 'ACME Corporation');
      // expect(result['total_amount'], 138.0);
      // expect(result['invoice_date'], '2024-01-15');

      // Skip this test until Extractor is refactored to accept Dio injection
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
        dio.interceptors.any((i) => i.toString().contains('DioCacheInterceptor')),
        isTrue,
        reason: 'Should have DioCacheInterceptor configured',
      );
    });
  });
}
