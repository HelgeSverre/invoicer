import 'package:flutter_test/flutter_test.dart';
import 'package:invoicer/models.dart';
import 'package:invoicer/state.dart';

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
      expect(state.currentView.value, anyOf('files', 'folders'));
      expect(state.pdfFiles, isEmpty);
      expect(state.individualFiles, isEmpty);
      expect(state.isProcessingAll.value, false);
    });

    test('allFiles getter combines pdfFiles and individualFiles', () {
      final state = AppState();

      final folderFile = PdfDocument(
        name: 'folder.pdf',
        path: '/test/folder.pdf',
        source: 'folder',
      );

      final individualFile = PdfDocument(
        name: 'individual.pdf',
        path: '/test/individual.pdf',
        source: 'individual',
      );

      state.pdfFiles.add(folderFile);
      state.individualFiles.add(individualFile);

      final allFiles = state.allFiles;

      expect(allFiles.length, 2);
      expect(allFiles.contains(folderFile), true);
      expect(allFiles.contains(individualFile), true);
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
