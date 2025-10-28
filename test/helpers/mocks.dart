import 'package:dio/dio.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:mocktail/mocktail.dart';

// Mock classes for testing
class MockDio extends Mock implements Dio {}

class MockFilePicker extends Mock implements FilePicker {}

class MockBuildContext extends Mock implements BuildContext {}

class MockRequestOptions extends Fake implements RequestOptions {}

// Fallback values for mocktail
void registerMockFallbacks() {
  registerFallbackValue(MockRequestOptions());
  registerFallbackValue(Options());
}
