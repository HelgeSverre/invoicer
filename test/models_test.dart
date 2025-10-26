import 'package:flutter_test/flutter_test.dart';
import 'package:invoicer/models.dart';

void main() {
  group('ReceiptItem', () {
    test('creates instance with required fields', () {
      final item = ReceiptItem(
        text: 'Test Item',
        unitPrice: 10.0,
        quantity: 2,
      );

      expect(item.text, 'Test Item');
      expect(item.unitPrice, 10.0);
      expect(item.quantity, 2);
      expect(item.sku, isNull);
    });

    test('calculates total correctly', () {
      final item = ReceiptItem(
        text: 'Test Item',
        unitPrice: 10.0,
        quantity: 3,
      );

      expect(item.total, 30.0);
    });

    test('creates from JSON correctly', () {
      final json = {
        'sku': 'SKU-123',
        'text': 'Test Item',
        'unit_price': 15.5,
        'quantity': 2,
      };

      final item = ReceiptItem.fromJson(json);

      expect(item.sku, 'SKU-123');
      expect(item.text, 'Test Item');
      expect(item.unitPrice, 15.5);
      expect(item.quantity, 2);
    });

    test('handles missing JSON fields with defaults', () {
      final json = {
        'text': 'Minimal Item',
      };

      final item = ReceiptItem.fromJson(json);

      expect(item.text, 'Minimal Item');
      expect(item.unitPrice, 0.0);
      expect(item.quantity, 1);
      expect(item.sku, isNull);
    });
  });

  group('ProjectFolder', () {
    test('creates instance with required fields', () {
      final now = DateTime.now();
      final folder = ProjectFolder(
        path: '/test/path',
        name: 'Test Folder',
        addedAt: now,
      );

      expect(folder.path, '/test/path');
      expect(folder.name, 'Test Folder');
      expect(folder.addedAt, now);
      expect(folder.fileCount, 0);
    });

    test('serializes to JSON correctly', () {
      final now = DateTime(2024, 1, 1, 12, 0);
      final folder = ProjectFolder(
        path: '/test/path',
        name: 'Test Folder',
        addedAt: now,
        fileCount: 5,
      );

      final json = folder.toJson();

      expect(json['path'], '/test/path');
      expect(json['name'], 'Test Folder');
      expect(json['addedAt'], now.toIso8601String());
      expect(json['fileCount'], 5);
    });

    test('deserializes from JSON correctly', () {
      final now = DateTime(2024, 1, 1, 12, 0);
      final json = {
        'path': '/test/path',
        'name': 'Test Folder',
        'addedAt': now.toIso8601String(),
        'fileCount': 5,
      };

      final folder = ProjectFolder.fromJson(json);

      expect(folder.path, '/test/path');
      expect(folder.name, 'Test Folder');
      expect(folder.addedAt, now);
      expect(folder.fileCount, 5);
    });

    test('copyWith creates new instance with updated fields', () {
      final original = ProjectFolder(
        path: '/test/path',
        name: 'Original',
        addedAt: DateTime.now(),
        fileCount: 3,
      );

      final updated = original.copyWith(name: 'Updated', fileCount: 5);

      expect(updated.name, 'Updated');
      expect(updated.fileCount, 5);
      expect(updated.path, original.path);
      expect(updated.addedAt, original.addedAt);
    });
  });

  group('PdfDocument', () {
    test('creates instance with required fields', () {
      final doc = PdfDocument(
        name: 'test.pdf',
        path: '/test/test.pdf',
      );

      expect(doc.name, 'test.pdf');
      expect(doc.path, '/test/test.pdf');
      expect(doc.items, isEmpty);
      expect(doc.isProcessing, false);
      expect(doc.source, 'folder');
      expect(doc.vendor, isNull);
    });

    test('hasInvoiceDetails returns false when no details present', () {
      final doc = PdfDocument(
        name: 'test.pdf',
        path: '/test/test.pdf',
      );

      expect(doc.hasInvoiceDetails, false);
    });

    test('hasInvoiceDetails returns true when vendor is set', () {
      final doc = PdfDocument(
        name: 'test.pdf',
        path: '/test/test.pdf',
        vendor: 'Test Vendor',
      );

      expect(doc.hasInvoiceDetails, true);
    });

    test('hasInvoiceDetails returns true when any detail is set', () {
      final doc = PdfDocument(
        name: 'test.pdf',
        path: '/test/test.pdf',
        currency: 'USD',
      );

      expect(doc.hasInvoiceDetails, true);
    });

    test('copyWith creates new instance with updated fields', () {
      final original = PdfDocument(
        name: 'original.pdf',
        path: '/test/original.pdf',
      );

      final items = [
        ReceiptItem(text: 'Item 1', unitPrice: 10.0, quantity: 1),
      ];

      final updated = original.copyWith(
        vendor: 'Test Vendor',
        items: items,
        isProcessing: true,
      );

      expect(updated.vendor, 'Test Vendor');
      expect(updated.items, items);
      expect(updated.isProcessing, true);
      expect(updated.name, original.name);
      expect(updated.path, original.path);
    });

    test('creates instance with all invoice details', () {
      final invoiceDate = DateTime(2024, 1, 15);
      final dueDate = DateTime(2024, 2, 15);

      final doc = PdfDocument(
        name: 'invoice.pdf',
        path: '/test/invoice.pdf',
        vendor: 'Test Vendor',
        invoiceDate: invoiceDate,
        dueDate: dueDate,
        currency: 'USD',
        taxAmount: 10.0,
        totalAmount: 110.0,
        discountAmount: 5.0,
        vendorWebsite: 'https://example.com',
        vendorEmail: 'test@example.com',
        vendorDisplayAddress: '123 Test St',
        paymentMethod: 'Credit Card',
        lastFourDigits: '1234',
      );

      expect(doc.vendor, 'Test Vendor');
      expect(doc.invoiceDate, invoiceDate);
      expect(doc.dueDate, dueDate);
      expect(doc.currency, 'USD');
      expect(doc.taxAmount, 10.0);
      expect(doc.totalAmount, 110.0);
      expect(doc.discountAmount, 5.0);
      expect(doc.vendorWebsite, 'https://example.com');
      expect(doc.vendorEmail, 'test@example.com');
      expect(doc.vendorDisplayAddress, '123 Test St');
      expect(doc.paymentMethod, 'Credit Card');
      expect(doc.lastFourDigits, '1234');
      expect(doc.hasInvoiceDetails, true);
    });
  });
}
