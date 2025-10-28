import 'package:flutter_test/flutter_test.dart';
import 'package:invoicer/services/filename_template_service.dart';

import '../helpers/test_data.dart';

void main() {
  group('FilenameTemplateService.applyTemplate', () {
    test('replaces all placeholders correctly', () {
      // Arrange
      const template = '[YEAR]-[MONTH]-[DAY] - [VENDOR] - [CURRENCY] [TOTAL].pdf';
      final document = TestData.createPdfDocument(
        vendor: 'Acme Corp',
        invoiceDate: DateTime(2024, 1, 15),
        currency: 'USD',
        totalAmount: 1234.56,
      );

      // Act
      final result = FilenameTemplateService.applyTemplate(template, document);

      // Assert
      expect(result, '2024-01-15 - Acme Corp - USD 1234.56.pdf');
    });

    test('uses current date when invoiceDate is null', () {
      // Arrange
      const template = '[YEAR]-[MONTH]-[DAY] - [VENDOR].pdf';
      final document = TestData.createPdfDocument(
        vendor: 'Test Vendor',
        invoiceDate: null, // No invoice date
      );

      // Act
      final result = FilenameTemplateService.applyTemplate(template, document);

      // Assert
      final now = DateTime.now();
      final expectedDatePart = '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
      expect(result, contains(expectedDatePart));
      expect(result, contains('Test Vendor'));
    });

    test('sanitizes vendor name with special characters', () {
      // Arrange
      const template = '[VENDOR].pdf';
      final document = TestData.createPdfDocument(
        vendor: 'Test/Vendor:2024<>Corp',
      );

      // Act
      final result = FilenameTemplateService.applyTemplate(template, document);

      // Assert
      expect(result, 'Test_Vendor_2024__Corp.pdf');
      expect(result, isNot(contains('/')));
      expect(result, isNot(contains(':')));
      expect(result, isNot(contains('<')));
      expect(result, isNot(contains('>')));
    });

    test('uses "Unknown" for null vendor', () {
      // Arrange
      const template = '[VENDOR].pdf';
      final document = TestData.createPdfDocument(
        vendor: null,
      );

      // Act
      final result = FilenameTemplateService.applyTemplate(template, document);

      // Assert
      expect(result, 'Unknown.pdf');
    });

    test('handles null currency gracefully', () {
      // Arrange
      const template = '[VENDOR] - [CURRENCY].pdf';
      final document = TestData.createPdfDocument(
        vendor: 'Test',
        currency: null,
      );

      // Act
      final result = FilenameTemplateService.applyTemplate(template, document);

      // Assert
      expect(result, 'Test - .pdf');
    });

    test('formats total amount with 2 decimal places', () {
      // Arrange
      const template = '[TOTAL].pdf';
      final document = TestData.createPdfDocument(
        totalAmount: 1234.5, // One decimal place
      );

      // Act
      final result = FilenameTemplateService.applyTemplate(template, document);

      // Assert
      expect(result, '1234.50.pdf');
    });

    test('uses 0.00 for null total amount', () {
      // Arrange
      const template = '[TOTAL].pdf';
      final document = TestData.createPdfDocument(
        totalAmount: null,
      );

      // Act
      final result = FilenameTemplateService.applyTemplate(template, document);

      // Assert
      expect(result, '0.00.pdf');
    });

    test('cleans up double spaces and dashes', () {
      // Arrange
      const template = '[VENDOR] - [CURRENCY] - [TOTAL].pdf';
      final document = TestData.createPdfDocument(
        vendor: 'Test',
        currency: null, // Will create empty space
        totalAmount: null,
      );

      // Act
      final result = FilenameTemplateService.applyTemplate(template, document);

      // Assert
      expect(result, isNot(contains('  '))); // No double spaces
      expect(result, contains('Test - - 0.00.pdf')); // Dashes preserved
    });

    test('handles [DATE] placeholder with YYYY-MM-DD format', () {
      // Arrange
      const template = '[DATE] - [VENDOR].pdf';
      final document = TestData.createPdfDocument(
        vendor: 'Acme Corp',
        invoiceDate: DateTime(2024, 3, 5),
      );

      // Act
      final result = FilenameTemplateService.applyTemplate(template, document);

      // Assert
      expect(result, '2024-03-05 - Acme Corp.pdf');
    });

    test('sanitizes vendor with multiple spaces', () {
      // Arrange
      const template = '[VENDOR].pdf';
      final document = TestData.createPdfDocument(
        vendor: 'Test    Multiple   Spaces',
      );

      // Act
      final result = FilenameTemplateService.applyTemplate(template, document);

      // Assert
      expect(result, 'Test Multiple Spaces.pdf');
      expect(result, isNot(contains('  '))); // No double spaces
    });

    test('handles complex template with all placeholders', () {
      // Arrange
      const template = '[YEAR][MONTH][DAY]_[VENDOR]_INV_[TOTAL]_[CURRENCY].pdf';
      final document = TestData.createPdfDocument(
        vendor: 'ACME Corp',
        invoiceDate: DateTime(2024, 12, 25),
        currency: 'EUR',
        totalAmount: 999.99,
      );

      // Act
      final result = FilenameTemplateService.applyTemplate(template, document);

      // Assert
      expect(result, '20241225_ACME Corp_INV_999.99_EUR.pdf');
    });
  });

  group('FilenameTemplateService.validateTemplate', () {
    test('returns success for valid template', () {
      // Arrange
      const validTemplate = '[YEAR]-[MONTH]-[DAY] - [VENDOR].pdf';

      // Act
      final result = FilenameTemplateService.validateTemplate(validTemplate);

      // Assert
      expect(result.isValid, isTrue);
      expect(result.error, isNull);
    });

    test('fails for empty template', () {
      // Arrange
      const emptyTemplate = '';

      // Act
      final result = FilenameTemplateService.validateTemplate(emptyTemplate);

      // Assert
      expect(result.isValid, isFalse);
      expect(result.error, 'Template cannot be empty');
    });

    test('fails when template does not end with .pdf', () {
      // Arrange
      const invalidTemplate = '[VENDOR]';

      // Act
      final result = FilenameTemplateService.validateTemplate(invalidTemplate);

      // Assert
      expect(result.isValid, isFalse);
      expect(result.error, 'Template must end with .pdf');
    });

    test('fails with invalid filename characters outside placeholders', () {
      // Arrange
      const invalidTemplate = '[VENDOR]/test:file.pdf';

      // Act
      final result = FilenameTemplateService.validateTemplate(invalidTemplate);

      // Assert
      expect(result.isValid, isFalse);
      expect(result.error, 'Template contains invalid filename characters');
    });

    test('allows special characters inside placeholders', () {
      // Arrange
      const validTemplate = '[VENDOR] - [CURRENCY:USD].pdf';

      // Act
      final result = FilenameTemplateService.validateTemplate(validTemplate);

      // Assert
      // This should be valid because : is inside a placeholder
      expect(result.isValid, isTrue);
    });

    test('allows uppercase .PDF extension', () {
      // Arrange
      const validTemplate = '[VENDOR].PDF';

      // Act
      final result = FilenameTemplateService.validateTemplate(validTemplate);

      // Assert
      expect(result.isValid, isTrue);
    });

    test('fails with asterisk in template', () {
      // Arrange
      const invalidTemplate = '[VENDOR]*.pdf';

      // Act
      final result = FilenameTemplateService.validateTemplate(invalidTemplate);

      // Assert
      expect(result.isValid, isFalse);
      expect(result.error, 'Template contains invalid filename characters');
    });

    test('fails with question mark in template', () {
      // Arrange
      const invalidTemplate = '[VENDOR]?.pdf';

      // Act
      final result = FilenameTemplateService.validateTemplate(invalidTemplate);

      // Assert
      expect(result.isValid, isFalse);
      expect(result.error, 'Template contains invalid filename characters');
    });

    test('fails with pipe character in template', () {
      // Arrange
      const invalidTemplate = '[VENDOR]|test.pdf';

      // Act
      final result = FilenameTemplateService.validateTemplate(invalidTemplate);

      // Assert
      expect(result.isValid, isFalse);
      expect(result.error, 'Template contains invalid filename characters');
    });

    test('allows dashes, underscores, and spaces', () {
      // Arrange
      const validTemplate = '[YEAR]-[MONTH]_[DAY] [VENDOR].pdf';

      // Act
      final result = FilenameTemplateService.validateTemplate(validTemplate);

      // Assert
      expect(result.isValid, isTrue);
      expect(result.error, isNull);
    });
  });

  group('FilenameTemplateService.getAvailablePlaceholders', () {
    test('returns list of available placeholders', () {
      // Act
      final placeholders = FilenameTemplateService.getAvailablePlaceholders();

      // Assert
      expect(placeholders, isNotEmpty);
      expect(placeholders.length, 7); // 7 placeholders defined
      expect(placeholders.any((p) => p.name == '[YEAR]'), isTrue);
      expect(placeholders.any((p) => p.name == '[MONTH]'), isTrue);
      expect(placeholders.any((p) => p.name == '[DAY]'), isTrue);
      expect(placeholders.any((p) => p.name == '[DATE]'), isTrue);
      expect(placeholders.any((p) => p.name == '[VENDOR]'), isTrue);
      expect(placeholders.any((p) => p.name == '[CURRENCY]'), isTrue);
      expect(placeholders.any((p) => p.name == '[TOTAL]'), isTrue);
    });

    test('each placeholder has a description', () {
      // Act
      final placeholders = FilenameTemplateService.getAvailablePlaceholders();

      // Assert
      for (final placeholder in placeholders) {
        expect(placeholder.description, isNotEmpty);
        expect(placeholder.name, isNotEmpty);
      }
    });
  });
}
