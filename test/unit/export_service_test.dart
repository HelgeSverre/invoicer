import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:invoicer/models.dart';
import 'package:invoicer/models/export_settings.dart';
import 'package:invoicer/services/export_service.dart';

import '../helpers/test_data.dart';

void main() {
  group('ExportService.formatLineItems', () {
    test('produces valid JSON for json format', () {
      // Arrange
      final items = [
        TestData.createReceiptItem(
          text: 'Widget',
          unitPrice: 10.0,
          quantity: 2,
          sku: 'W-001',
        ),
        TestData.createReceiptItem(
          text: 'Gadget',
          unitPrice: 20.0,
          quantity: 1,
        ),
      ];

      // Act
      final result = ExportService.formatLineItems(items, LineItemFormat.json);

      // Assert
      final parsed = jsonDecode(result);
      expect(parsed, isA<List>());
      expect(parsed.length, 2);
      expect(parsed[0]['text'], 'Widget');
      expect(parsed[0]['unit_price'], 10.0);
      expect(parsed[0]['quantity'], 2);
      expect(parsed[0]['sku'], 'W-001');
      expect(parsed[1]['text'], 'Gadget');
    });

    test('produces newline-separated text for newlineSeparated format', () {
      // Arrange
      final items = [
        TestData.createReceiptItem(
          text: 'Widget',
          unitPrice: 10.0,
          quantity: 2,
        ),
        TestData.createReceiptItem(
          text: 'Gadget',
          unitPrice: 20.0,
          quantity: 1,
          sku: 'G-001',
        ),
      ];

      // Act
      final result = ExportService.formatLineItems(
        items,
        LineItemFormat.newlineSeparated,
      );

      // Assert
      expect(result, contains('Widget'));
      expect(result, contains('Gadget'));
      expect(result, contains('qty: 2'));
      expect(result, contains('qty: 1'));
      expect(result, contains('\$10.00'));
      expect(result, contains('\$20.00'));
      expect(result, contains('SKU: G-001'));
      expect(result, contains('\n')); // Has newline separator

      // Check that items are on separate lines
      final lines = result.split('\n');
      expect(lines.length, 2);
    });

    test('produces bulleted list for bulletedList format', () {
      // Arrange
      final items = [
        TestData.createReceiptItem(
          text: 'Widget',
          unitPrice: 10.0,
          quantity: 2,
        ),
      ];

      // Act
      final result = ExportService.formatLineItems(
        items,
        LineItemFormat.bulletedList,
      );

      // Assert
      expect(result, startsWith('- '));
      expect(result, contains('Widget'));
      expect(result, contains('qty: 2'));
      expect(result, contains('\$10.00'));
    });

    test('returns empty string for empty items list', () {
      // Arrange
      final items = <ReceiptItem>[];

      // Act
      final result = ExportService.formatLineItems(items, LineItemFormat.json);

      // Assert
      expect(result, isEmpty);
    });

    test('includes SKU when present in item', () {
      // Arrange
      final items = [
        TestData.createReceiptItem(
          text: 'Widget Pro',
          sku: 'WP-2024',
          unitPrice: 50.0,
          quantity: 1,
        ),
      ];

      // Act
      final newlineResult = ExportService.formatLineItems(
        items,
        LineItemFormat.newlineSeparated,
      );
      final bulletedResult = ExportService.formatLineItems(
        items,
        LineItemFormat.bulletedList,
      );

      // Assert
      expect(newlineResult, contains('SKU: WP-2024'));
      expect(bulletedResult, contains('SKU: WP-2024'));
    });

    test('formats price with 2 decimal places', () {
      // Arrange
      final items = [
        TestData.createReceiptItem(
          text: 'Widget',
          unitPrice: 10.5, // One decimal
          quantity: 1,
        ),
      ];

      // Act
      final result = ExportService.formatLineItems(
        items,
        LineItemFormat.newlineSeparated,
      );

      // Assert
      expect(result, contains('\$10.50'));
    });
  });

  group('ExportService.exportToCSV', () {
    test('throws exception for empty documents list', () async {
      // Arrange
      final emptyDocuments = <PdfDocument>[];

      // Act & Assert
      expect(
        () => ExportService.exportToCSV(emptyDocuments),
        throwsA(
          isA<Exception>().having(
            (e) => e.toString(),
            'message',
            contains('No documents to export'),
          ),
        ),
      );
    });

    // Note: Full CSV export tests require mocking FilePicker.platform
    // which is challenging without dependency injection
    test('note: full export tests require FilePicker mocking', () {
      // These tests would need:
      // 1. Mock FilePicker.platform.saveFile
      // 2. Verify CSV structure
      // 3. Check delimiter settings
      // 4. Validate header inclusion
    }, skip: 'Requires FilePicker mocking infrastructure');
  });

  group('ExportService.exportToJSON', () {
    test('throws exception for empty documents list', () async {
      // Arrange
      final emptyDocuments = <PdfDocument>[];

      // Act & Assert
      expect(
        () => ExportService.exportToJSON(emptyDocuments),
        throwsA(
          isA<Exception>().having(
            (e) => e.toString(),
            'message',
            contains('No documents to export'),
          ),
        ),
      );
    });

    test('note: full JSON export tests require FilePicker mocking', () {
    }, skip: 'Requires FilePicker mocking infrastructure');
  });

  group('ExportService.exportToExcel', () {
    test('throws exception for empty documents list', () async {
      // Arrange
      final emptyDocuments = <PdfDocument>[];

      // Act & Assert
      expect(
        () => ExportService.exportToExcel(emptyDocuments),
        throwsA(
          isA<Exception>().having(
            (e) => e.toString(),
            'message',
            contains('No documents to export'),
          ),
        ),
      );
    });

    test('note: full Excel export tests require FilePicker mocking', () {
    }, skip: 'Requires FilePicker mocking infrastructure');
  });

  group('ExportSettings', () {
    test('copyWith updates only specified fields', () {
      // Arrange
      final original = ExportSettings(
        delimiter: ',',
        alwaysQuote: false,
        lineItemFormat: LineItemFormat.json,
      );

      // Act
      final updated = original.copyWith(
        delimiter: ';',
        alwaysQuote: true,
      );

      // Assert
      expect(updated.delimiter, ';');
      expect(updated.alwaysQuote, isTrue);
      expect(updated.lineItemFormat, LineItemFormat.json); // Unchanged
    });

    test('delimiterDisplay returns readable names', () {
      // Assert
      expect(
        ExportSettings(delimiter: ',').delimiterDisplay,
        'Comma (,)',
      );
      expect(
        ExportSettings(delimiter: ';').delimiterDisplay,
        'Semicolon (;)',
      );
      expect(
        ExportSettings(delimiter: '\t').delimiterDisplay,
        'Tab',
      );
      expect(
        ExportSettings(delimiter: '|').delimiterDisplay,
        'Pipe (|)',
      );
    });

    test('defaultSettings provides reasonable defaults', () {
      // Act
      final defaults = ExportSettings.defaultSettings;

      // Assert
      expect(defaults.delimiter, ',');
      expect(defaults.alwaysQuote, isFalse);
      expect(defaults.lineItemFormat, LineItemFormat.json);
      expect(defaults.includeHeaders, isTrue);
    });
  });

  group('LineItemFormat extension', () {
    test('displayName returns human-readable names', () {
      expect(
        LineItemFormat.json.displayName,
        'JSON (compact)',
      );
      expect(
        LineItemFormat.newlineSeparated.displayName,
        'Newline separated',
      );
      expect(
        LineItemFormat.bulletedList.displayName,
        'Bulleted list (- item)',
      );
    });

    test('description provides format explanation', () {
      // All formats should have descriptions
      expect(LineItemFormat.json.description, isNotEmpty);
      expect(LineItemFormat.newlineSeparated.description, isNotEmpty);
      expect(LineItemFormat.bulletedList.description, isNotEmpty);
    });

    test('example provides format sample', () {
      // All formats should have examples
      expect(LineItemFormat.json.example, isNotEmpty);
      expect(LineItemFormat.newlineSeparated.example, isNotEmpty);
      expect(LineItemFormat.bulletedList.example, isNotEmpty);
    });
  });
}
