import 'package:intl/intl.dart';
import 'package:invoicer/models.dart';

class FilenameTemplateService {
  /// Apply the filename template to a PDF document
  /// Supported placeholders:
  /// - [YEAR] - 4-digit year (e.g., 2024)
  /// - [MONTH] - 2-digit month (e.g., 01, 12)
  /// - [DAY] - 2-digit day (e.g., 01, 31)
  /// - [VENDOR] - Vendor name
  /// - [CURRENCY] - Currency code
  /// - [TOTAL] - Total amount
  /// - [DATE] - Full date in YYYY-MM-DD format
  static String applyTemplate(String template, PdfDocument document) {
    String result = template;

    // Date-based replacements (use invoice date if available, otherwise current date)
    final date = document.invoiceDate ?? DateTime.now();

    result = result.replaceAll('[YEAR]', DateFormat('yyyy').format(date));
    result = result.replaceAll('[MONTH]', DateFormat('MM').format(date));
    result = result.replaceAll('[DAY]', DateFormat('dd').format(date));
    result = result.replaceAll('[DATE]', DateFormat('yyyy-MM-dd').format(date));

    // Vendor replacement
    if (document.vendor != null) {
      result = result.replaceAll('[VENDOR]', _sanitizeFilename(document.vendor!));
    } else {
      result = result.replaceAll('[VENDOR]', 'Unknown');
    }

    // Currency replacement
    if (document.currency != null) {
      result = result.replaceAll('[CURRENCY]', document.currency!);
    } else {
      result = result.replaceAll('[CURRENCY]', '');
    }

    // Total amount replacement
    if (document.totalAmount != null) {
      result = result.replaceAll(
        '[TOTAL]',
        document.totalAmount!.toStringAsFixed(2),
      );
    } else {
      result = result.replaceAll('[TOTAL]', '0.00');
    }

    // Clean up any double spaces or dashes that might result from empty placeholders
    result = result.replaceAll(RegExp(r'\s{2,}'), ' ');
    result = result.replaceAll(RegExp(r'-{2,}'), '-');
    result = result.replaceAll(RegExp(r'\s+-\s+'), ' - ');

    // Clean up leading/trailing spaces and dashes
    result = result.trim();
    result = result.replaceAll(RegExp(r'^-+|-+$'), '');
    result = result.trim();

    return result;
  }

  /// Sanitize a string to be safe for use in filenames
  static String _sanitizeFilename(String input) {
    // Remove or replace characters that are invalid in filenames
    // macOS/Linux: only / is truly forbidden, but we'll be more conservative
    // Windows: < > : " / \ | ? *
    return input
        .replaceAll(RegExp(r'[<>:"/\\|?*]'), '_')
        .replaceAll(RegExp(r'\s{2,}'), ' ')
        .trim();
  }

  /// Get a list of available placeholders for display in UI
  static List<TemplatePlaceholder> getAvailablePlaceholders() {
    return [
      TemplatePlaceholder(
        name: '[YEAR]',
        description: '4-digit year (e.g., 2024)',
      ),
      TemplatePlaceholder(
        name: '[MONTH]',
        description: '2-digit month (e.g., 01, 12)',
      ),
      TemplatePlaceholder(
        name: '[DAY]',
        description: '2-digit day (e.g., 01, 31)',
      ),
      TemplatePlaceholder(
        name: '[DATE]',
        description: 'Full date in YYYY-MM-DD format',
      ),
      TemplatePlaceholder(
        name: '[VENDOR]',
        description: 'Vendor/business name',
      ),
      TemplatePlaceholder(
        name: '[CURRENCY]',
        description: 'Currency code (e.g., USD, EUR)',
      ),
      TemplatePlaceholder(
        name: '[TOTAL]',
        description: 'Total amount',
      ),
    ];
  }

  /// Validate that a template string is valid
  static ValidationResult validateTemplate(String template) {
    if (template.isEmpty) {
      return ValidationResult(
        isValid: false,
        error: 'Template cannot be empty',
      );
    }

    if (!template.toLowerCase().endsWith('.pdf')) {
      return ValidationResult(
        isValid: false,
        error: 'Template must end with .pdf',
      );
    }

    // Check for invalid filename characters
    final invalidChars = RegExp(r'[<>:"/\\|?*]');
    // But allow placeholders in brackets
    final withoutPlaceholders = template.replaceAll(RegExp(r'\[[^\]]+\]'), '');
    if (invalidChars.hasMatch(withoutPlaceholders)) {
      return ValidationResult(
        isValid: false,
        error: 'Template contains invalid filename characters',
      );
    }

    return ValidationResult(isValid: true);
  }
}

class TemplatePlaceholder {
  final String name;
  final String description;

  TemplatePlaceholder({
    required this.name,
    required this.description,
  });
}

class ValidationResult {
  final bool isValid;
  final String? error;

  ValidationResult({
    required this.isValid,
    this.error,
  });
}
