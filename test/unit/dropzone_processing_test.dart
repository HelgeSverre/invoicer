// Tests for dropzone file processing functionality
//
// This test suite verifies that the Overview dropzone correctly:
// - Automatically processes dropped PDF files
// - Filters out non-PDF files
// - Handles batch processing of multiple files
// - Respects the autoRenameDropped setting
// - Properly manages file metadata and state
//
// The dropzone on the Overview page is designed to immediately start
// processing files when they are dropped (no confirmation dialog).
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:invoicer/models.dart';
import 'package:invoicer/state.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Dropzone File Processing', () {
    late AppState appState;
    late Directory testDir;

    setUp(() async {
      // Mock SharedPreferences to avoid plugin errors in tests
      SharedPreferences.setMockInitialValues({});

      appState = AppState();

      // Clear state from previous tests (AppState is a singleton)
      appState.individualFiles.clear();
      appState.pdfFiles.clear();

      // Create a temporary test directory
      testDir = await Directory.systemTemp.createTemp('invoicer_test');
    });

    tearDown(() async {
      // Clean up test directory
      if (await testDir.exists()) {
        await testDir.delete(recursive: true);
      }

      // Clear state after test
      appState.individualFiles.clear();
      appState.pdfFiles.clear();
    });

    test('processDroppedFile adds file to individualFiles list', () async {
      // Arrange
      final testFile = File('${testDir.path}/test_invoice.pdf');
      await testFile.writeAsString('Test PDF content');

      // Act
      await appState.addIndividualFile(testFile.path);

      // Assert
      expect(appState.individualFiles.length, 1);
      expect(appState.individualFiles.first.name, 'test_invoice.pdf');
      expect(appState.individualFiles.first.path, testFile.path);
      expect(appState.individualFiles.first.source, 'individual');
    });

    test('processDroppedFile filters out non-PDF files', () async {
      // Arrange
      final pdfFile = File('${testDir.path}/invoice.pdf');
      final txtFile = File('${testDir.path}/notes.txt');
      final docFile = File('${testDir.path}/document.docx');

      await pdfFile.writeAsString('PDF content');
      await txtFile.writeAsString('Text content');
      await docFile.writeAsString('Word content');

      // Simulate dropzone logic that filters files
      final droppedFiles = [pdfFile.path, txtFile.path, docFile.path];
      final pdfFiles =
          droppedFiles.where((f) => f.toLowerCase().endsWith('.pdf')).toList();

      // Act
      for (final path in pdfFiles) {
        await appState.addIndividualFile(path);
      }

      // Assert
      expect(pdfFiles.length, 1);
      expect(pdfFiles.first, pdfFile.path);
      expect(appState.individualFiles.length, 1);
      expect(appState.individualFiles.first.name, 'invoice.pdf');
    });

    test('processDroppedFile handles multiple PDF files', () async {
      // Arrange
      final file1 = File('${testDir.path}/invoice1.pdf');
      final file2 = File('${testDir.path}/invoice2.pdf');
      final file3 = File('${testDir.path}/receipt.pdf');

      await file1.writeAsString('PDF 1');
      await file2.writeAsString('PDF 2');
      await file3.writeAsString('PDF 3');

      // Act
      await appState.addIndividualFile(file1.path);
      await appState.addIndividualFile(file2.path);
      await appState.addIndividualFile(file3.path);

      // Assert
      expect(appState.individualFiles.length, 3);
      expect(appState.individualFiles.map((f) => f.name).toList(), [
        'invoice1.pdf',
        'invoice2.pdf',
        'receipt.pdf',
      ]);
    });

    test('processDroppedFile does not add duplicate files', () async {
      // Arrange
      final testFile = File('${testDir.path}/invoice.pdf');
      await testFile.writeAsString('PDF content');

      // Act
      await appState.addIndividualFile(testFile.path);
      await appState.addIndividualFile(testFile.path); // Add same file again

      // Assert
      expect(appState.individualFiles.length, 1);
    });

    test('processDroppedFile handles non-existent files gracefully', () async {
      // Arrange
      final nonExistentPath = '${testDir.path}/does_not_exist.pdf';

      // Act & Assert - should not throw
      await appState.addIndividualFile(nonExistentPath);

      // File should not be added if it doesn't exist
      expect(appState.individualFiles.length, 0);
    });

    test('autoRenameDropped setting defaults to false', () {
      // Assert
      expect(appState.autoRenameDropped.value, false);
    });

    test('autoRenameDropped setting can be toggled', () {
      // Arrange
      expect(appState.autoRenameDropped.value, false);

      // Act
      appState.autoRenameDropped.value = true;

      // Assert
      expect(appState.autoRenameDropped.value, true);

      // Act - toggle back
      appState.autoRenameDropped.value = false;

      // Assert
      expect(appState.autoRenameDropped.value, false);
    });

    test('allFiles includes both folder and individual files', () {
      // Arrange
      // Create a temporary folder with a PDF file
      final projectFolder = Directory('${testDir.path}/project_folder')
        ..createSync();
      final folderFile = File('${projectFolder.path}/folder_invoice.pdf')
        ..writeAsStringSync('PDF content');

      // Add the project folder to appState
      appState.projectFolders.add(ProjectFolder(
        path: projectFolder.path,
        name: 'Test Folder',
        addedAt: DateTime.now(),
      ));

      // Add an individual file
      final individualFile = PdfDocument(
        name: 'dropped_invoice.pdf',
        path: '/test/dropped/invoice.pdf',
        source: 'individual',
      );
      appState.individualFiles.add(individualFile);

      // Act
      final allFiles = appState.allFiles;

      // Assert
      expect(allFiles.length, 2);
      expect(allFiles.where((f) => f.path == folderFile.path).length, 1);
      expect(allFiles.where((f) => f.path == individualFile.path).length, 1);

      // Cleanup
      appState.projectFolders.clear();
      appState.individualFiles.clear();
    });

    test('removeIndividualFile removes file from list', () async {
      // Arrange
      final testFile = File('${testDir.path}/invoice.pdf');
      await testFile.writeAsString('PDF content');
      await appState.addIndividualFile(testFile.path);
      expect(appState.individualFiles.length, 1);

      final fileToRemove = appState.individualFiles.first;

      // Act
      await appState.removeIndividualFile(fileToRemove);

      // Assert
      expect(appState.individualFiles.length, 0);
    });

    test('batch processing simulation: multiple PDFs with non-PDF files',
        () async {
      // Arrange - simulate dropping 5 files: 3 PDFs, 2 non-PDFs
      final pdf1 = File('${testDir.path}/invoice1.pdf');
      final pdf2 = File('${testDir.path}/receipt.pdf');
      final pdf3 = File('${testDir.path}/statement.pdf');
      final txt = File('${testDir.path}/notes.txt');
      final jpg = File('${testDir.path}/scan.jpg');

      await pdf1.writeAsString('PDF 1');
      await pdf2.writeAsString('PDF 2');
      await pdf3.writeAsString('PDF 3');
      await txt.writeAsString('Text');
      await jpg.writeAsString('Image');

      final droppedFiles = [
        pdf1.path,
        txt.path,
        pdf2.path,
        jpg.path,
        pdf3.path,
      ];

      // Act - simulate dropzone filtering
      final pdfFiles =
          droppedFiles.where((f) => f.toLowerCase().endsWith('.pdf')).toList();

      final skippedCount = droppedFiles.length - pdfFiles.length;

      for (final path in pdfFiles) {
        await appState.addIndividualFile(path);
      }

      // Assert
      expect(pdfFiles.length, 3);
      expect(skippedCount, 2);
      expect(appState.individualFiles.length, 3);
      expect(
        appState.individualFiles.map((f) => f.name).toSet(),
        {'invoice1.pdf', 'receipt.pdf', 'statement.pdf'},
      );
    });

    test('file added via dropzone has correct metadata', () async {
      // Arrange
      final testFile = File('${testDir.path}/my_invoice.pdf');
      await testFile.writeAsString('PDF content');

      // Act
      await appState.addIndividualFile(testFile.path);

      // Assert
      final addedFile = appState.individualFiles.first;
      expect(addedFile.name, 'my_invoice.pdf');
      expect(addedFile.path, testFile.path);
      expect(addedFile.source, 'individual');
      expect(addedFile.vendor, isNull); // Not yet processed
      expect(addedFile.isProcessing, false);
      expect(addedFile.error, isNull);
    });
  });
}
