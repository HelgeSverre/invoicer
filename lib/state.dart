// State Management
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:intl/intl.dart';
import 'package:invoicer/extractor.dart';
import 'package:invoicer/models.dart';
import 'package:path/path.dart' as path;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:signals/signals.dart';

class AppState {
  static final AppState _instance = AppState._internal();

  factory AppState() => _instance;

  AppState._internal();

  final selectedFolder = signal<String?>(null);
  final pdfFiles = listSignal<PdfDocument>([]);
  final apiKey = signal<String>("");
  final promptTemplate = signal<String>(
    'Additional instructions for AI processing (currently unused - extraction is guided by function definitions)',
  );
  final isProcessingAll = signal<bool>(false);

  Future<void> loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    apiKey.value =
        dotenv.maybeGet(
          'OPENAI_API_KEY',
          fallback: prefs.getString('openai_api_key'),
        ) ??
        "";
    promptTemplate.value =
        prefs.getString('prompt_template') ?? promptTemplate.value;
    selectedFolder.value = prefs.getString('selected_folder');
  }

  Future<void> saveSettings() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('openai_api_key', apiKey.value);
    await prefs.setString('prompt_template', promptTemplate.value);
    if (selectedFolder.value != null) {
      await prefs.setString('selected_folder', selectedFolder.value!);
    }
  }

  void loadPDFFiles() {
    if (selectedFolder.value == null) return;

    try {
      final directory = Directory(selectedFolder.value!);
      final pdfFilePaths = directory
          .listSync()
          .where((file) => file.path.toLowerCase().endsWith('.pdf'))
          .toList();

      pdfFiles.clear();
      pdfFiles.addAll(
        pdfFilePaths.map(
          (file) =>
              PdfDocument(name: path.basename(file.path), path: file.path),
        ),
      );
    } catch (e) {
      print('Error loading PDF files: $e');
      pdfFiles.clear();
      selectedFolder.value = null;
    }
  }

  Future<void> selectFolder() async {
    String? selectedDirectory = await FilePicker.platform.getDirectoryPath();
    if (selectedDirectory != null) {
      selectedFolder.value = selectedDirectory;
      await saveSettings();
      loadPDFFiles();
    }
  }

  Future<void> processFile(PdfDocument file) async {
    final index = pdfFiles.indexOf(file);
    if (index == -1 || file.isProcessing) return;

    // Update processing state
    pdfFiles[index] = file.copyWith(isProcessing: true, error: null);

    try {
      // Extract text from PDF
      final textContent = await Extractor.extractTextFromPDF(file.path);

      if (textContent.trim().isEmpty) {
        throw Exception('No text found in PDF');
      }

      // Analyze with OpenAI
      final result = await Extractor.extractReceiptData(
        textContent,
        apiKey.value,
      );

      final items =
          (result['items'] as List<dynamic>?)
              ?.map((item) => ReceiptItem.fromJson(item))
              .toList() ??
          [];

      // Parse dates
      DateTime? invoiceDate;
      if (result['invoice_date'] != null) {
        try {
          invoiceDate = DateTime.parse(result['invoice_date']);
        } catch (e) {
          // If date parsing fails, leave it null
        }
      }

      DateTime? dueDate;
      if (result['due_date'] != null) {
        try {
          dueDate = DateTime.parse(result['due_date']);
        } catch (e) {
          // If date parsing fails, leave it null
        }
      }

      pdfFiles[index] = file.copyWith(
        items: items,
        vendor: result['vendor'],
        invoiceDate: invoiceDate,
        dueDate: dueDate,
        taxAmount: result['tax_amount']?.toDouble(),
        totalAmount: result['total_amount']?.toDouble(),
        discountAmount: result['discount_amount']?.toDouble(),
        vendorWebsite: result['vendor_website'],
        vendorEmail: result['vendor_email'],
        vendorDisplayAddress: result['vendor_display_address'],
        paymentMethod: result['payment_method'],
        lastFourDigits: result['last_four_digits'],
        isProcessing: false,
      );
    } catch (e) {
      pdfFiles[index] = file.copyWith(error: e.toString(), isProcessing: false);
    }
  }

  Future<void> processAllFiles() async {
    if (isProcessingAll.value) return;

    isProcessingAll.value = true;

    try {
      final futures = pdfFiles.map((file) => processFile(file)).toList();
      await Future.wait(futures);
    } finally {
      isProcessingAll.value = false;
    }
  }

  Future<void> renameFile(PdfDocument file, BuildContext context) async {
    if (file.invoiceDate == null || file.vendor == null) {
      return;
    }

    final dateStr = DateFormat('yyyy-MM-dd').format(file.invoiceDate!);
    final sanitizedVendor = file.vendor!.replaceAll(
      RegExp(r'[<>:"/\\|?*]'),
      '_',
    );
    final newName = '$dateStr - $sanitizedVendor.pdf';
    final newPath = path.join(path.dirname(file.path), newName);

    try {
      // await File(file.path).rename(newPath);

      final index = pdfFiles.indexOf(file);
      if (index != -1) {
        pdfFiles[index] = file.copyWith(name: newName, path: newPath);
      }
    } catch (e) {
      print(e);
    }
  }
}
