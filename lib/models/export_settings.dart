class ExportSettings {
  // CSV options
  final String delimiter;
  final bool alwaysQuote;
  final LineItemFormat lineItemFormat;

  // Future: Excel-specific options could go here
  final bool includeHeaders;

  ExportSettings({
    this.delimiter = ',',
    this.alwaysQuote = false,
    this.lineItemFormat = LineItemFormat.json,
    this.includeHeaders = true,
  });

  ExportSettings copyWith({
    String? delimiter,
    bool? alwaysQuote,
    LineItemFormat? lineItemFormat,
    bool? includeHeaders,
  }) {
    return ExportSettings(
      delimiter: delimiter ?? this.delimiter,
      alwaysQuote: alwaysQuote ?? this.alwaysQuote,
      lineItemFormat: lineItemFormat ?? this.lineItemFormat,
      includeHeaders: includeHeaders ?? this.includeHeaders,
    );
  }

  /// Get the delimiter character for display
  String get delimiterDisplay {
    switch (delimiter) {
      case ',':
        return 'Comma (,)';
      case ';':
        return 'Semicolon (;)';
      case '\t':
        return 'Tab';
      case '|':
        return 'Pipe (|)';
      default:
        return delimiter;
    }
  }

  static ExportSettings get defaultSettings => ExportSettings();
}

enum LineItemFormat {
  json,
  newlineSeparated,
  bulletedList,
}

extension LineItemFormatExtension on LineItemFormat {
  String get displayName {
    switch (this) {
      case LineItemFormat.json:
        return 'JSON (compact)';
      case LineItemFormat.newlineSeparated:
        return 'Newline separated';
      case LineItemFormat.bulletedList:
        return 'Bulleted list (- item)';
    }
  }

  String get description {
    switch (this) {
      case LineItemFormat.json:
        return 'Items as JSON array (current default)';
      case LineItemFormat.newlineSeparated:
        return 'Each item on a new line:\nitem 1\nitem 2';
      case LineItemFormat.bulletedList:
        return 'Bulleted list:\n- item 1\n- item 2';
    }
  }

  String get example {
    switch (this) {
      case LineItemFormat.json:
        return '[{"text":"Widget","qty":2,"price":10.00}]';
      case LineItemFormat.newlineSeparated:
        return 'Widget (qty: 2, \$10.00)\nGadget (qty: 1, \$20.00)';
      case LineItemFormat.bulletedList:
        return '- Widget (qty: 2, \$10.00)\n- Gadget (qty: 1, \$20.00)';
    }
  }
}
