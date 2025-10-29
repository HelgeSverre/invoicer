import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:invoicer/models.dart';
import 'package:invoicer/state.dart';
import 'package:path/path.dart' as path;

void main() {
  group('AppState', () {
    test('is a singleton', () {
      final instance1 = AppState();
      final instance2 = AppState();

      expect(identical(instance1, instance2), true);
    });

    test('initializes with default values', () {
      final state = AppState();

      expect(state.selectedFolder.value, isNull);
      expect(state.projectFolders, isEmpty);
      expect(state.currentlySelectedFolder.value, isNull);
      expect(state.currentView.value, 'overview'); // Updated default view
      expect(state.pdfFiles, isEmpty);
      expect(state.individualFiles, isEmpty);
      expect(state.isProcessingAll.value, false);
    });

    test(
        'allFiles getter includes files from ALL project folders and individual files',
        () async {
      final state = AppState();

      // Create temporary directories for multiple project folders
      final tempDir = Directory.systemTemp.createTempSync('invoicer_test_');
      final folderA = Directory(path.join(tempDir.path, 'folderA'))
        ..createSync();
      final folderB = Directory(path.join(tempDir.path, 'folderB'))
        ..createSync();

      // Create PDF files in each folder
      final pdfA1 = File(path.join(folderA.path, 'invoiceA1.pdf'))
        ..writeAsStringSync('PDF A1');
      final pdfA2 = File(path.join(folderA.path, 'invoiceA2.pdf'))
        ..writeAsStringSync('PDF A2');
      final pdfB1 = File(path.join(folderB.path, 'invoiceB1.pdf'))
        ..writeAsStringSync('PDF B1');

      // Add folders to project folders
      state.projectFolders.add(ProjectFolder(
        path: folderA.path,
        name: 'Folder A',
        addedAt: DateTime.now(),
      ));
      state.projectFolders.add(ProjectFolder(
        path: folderB.path,
        name: 'Folder B',
        addedAt: DateTime.now(),
      ));

      // Add an individual file
      final individualFile = PdfDocument(
        name: 'individual.pdf',
        path: '/test/individual.pdf',
        source: 'individual',
      );
      state.individualFiles.add(individualFile);

      // Get all files
      final allFiles = state.allFiles;

      // Verify all files from all folders are included
      expect(allFiles.length,
          4); // 2 from folder A + 1 from folder B + 1 individual
      expect(allFiles.where((f) => f.path == pdfA1.path).length, 1);
      expect(allFiles.where((f) => f.path == pdfA2.path).length, 1);
      expect(allFiles.where((f) => f.path == pdfB1.path).length, 1);
      expect(allFiles.where((f) => f.path == individualFile.path).length, 1);

      // Verify files from different folders have correct folder paths
      final fileFromA = allFiles.firstWhere((f) => f.path == pdfA1.path);
      expect(fileFromA.folderPath, folderA.path);

      final fileFromB = allFiles.firstWhere((f) => f.path == pdfB1.path);
      expect(fileFromB.folderPath, folderB.path);

      // Cleanup
      tempDir.deleteSync(recursive: true);
      state.projectFolders.clear();
      state.individualFiles.clear();
    });

    test('currentView signal can be updated', () {
      final state = AppState();
      final initialView = state.currentView.value;

      state.currentView.value = 'folders';
      expect(state.currentView.value, 'folders');

      state.currentView.value = 'files';
      expect(state.currentView.value, 'files');

      // Restore initial value
      state.currentView.value = initialView;
    });

    test('isProcessingAll signal can be toggled', () {
      final state = AppState();

      expect(state.isProcessingAll.value, false);

      state.isProcessingAll.value = true;
      expect(state.isProcessingAll.value, true);

      state.isProcessingAll.value = false;
      expect(state.isProcessingAll.value, false);
    });

    test('apiKey signal can be set', () {
      final state = AppState();

      state.apiKey.value = 'test-api-key';
      expect(state.apiKey.value, 'test-api-key');

      // Clear after test
      state.apiKey.value = '';
    });

    test('aiModel signal has default value', () {
      final state = AppState();

      expect(state.aiModel.value, isNotEmpty);
      expect(state.aiModel.value, contains('gpt'));
    });
  });
}
