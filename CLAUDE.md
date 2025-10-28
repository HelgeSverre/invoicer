# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

Invoicer is a macOS desktop application built with Flutter for processing invoices and receipts. It uses OpenAI's GPT models with function calling to extract structured data from PDF documents, including line items, vendor details, dates, and financial information.

## Development Commands

This project uses `just` (task runner) and `fvm` (Flutter Version Manager). All commands are available via the justfile.

### Common Commands

```bash
just                    # List all available commands
just run                # Run app on macOS (alias: just dev)
just build              # Build macOS release bundle
just test               # Run all tests
just test-coverage      # Run tests with coverage
just analyze            # Static analysis
just format             # Format all Dart code
just check              # Run format-check + analyze
just pre-commit         # Full check: format + analyze + test
```

### Setup and Maintenance

```bash
just install            # Install Flutter SDK and dependencies
just update             # Update dependencies
just outdated           # Check for outdated dependencies
just clean              # Clean build artifacts
just reset              # Clean + reinstall dependencies
just pod-install        # Install CocoaPods (macOS)
just pod-reset          # Clean and reinstall pods
```

### Running Specific Tests

```bash
fvm flutter test test/unit/extractor_test.dart           # Run specific test file
fvm flutter test --name "extractReceiptData"             # Run specific test by name
fvm flutter test test/unit/ --coverage                   # Run unit tests with coverage
```

## Architecture

### State Management

The app uses the **signals** pattern (via the `signals` package) for reactive state management. The entire application state is managed through a singleton `AppState` class (lib/state.dart) that uses signals for reactive updates.

Key state signals:

- `projectFolders`: List of watched folders containing PDFs
- `currentlySelectedFolder`: Currently active project folder
- `pdfFiles`: PDFs from the current folder
- `individualFiles`: Individually added PDF files
- `currentView`: UI view state ('overview', 'folders', or 'all_files')
- `isProcessingAll`: Batch processing status
- `filenameTemplate`: Current filename template string
- `autoRenameDropped`: Whether to auto-rename dropped files
- `apiKey` / `aiModel`: OpenAI configuration

### Data Flow Architecture

1. **PDF Loading**: Files are loaded from selected folders or added individually (including drag-and-drop)
2. **Text Extraction**: Uses `syncfusion_flutter_pdf` to extract text from PDFs
3. **AI Processing**: Extracted text is sent to OpenAI with function calling schema
4. **Retry Logic**: Automatic retry with exponential backoff for transient failures (rate limits, server errors, network timeouts)
5. **Data Extraction**: OpenAI returns structured data conforming to the schema
6. **State Update**: Signals trigger reactive UI updates when processing completes
7. **Data Persistence**: Extracted data cached to `~/.invoicer/data.json` for restoration on app restart

### Key Components

#### AppState (lib/state.dart)

Singleton managing all application state. Key responsibilities:

- Folder and file management (multi-folder support, individual files)
- PDF processing orchestration with concurrent processing support
- Settings persistence via SharedPreferences
- AI processing coordination with retry logic
- Filename template-based renaming (single and bulk operations)
- Drag-and-drop file handling with optional auto-rename
- Data caching to JSON file with atomic write pattern

#### Extractor (lib/extractor.dart)

Static utility class for PDF processing:

- `extractTextFromPDF()`: Extracts text content from PDFs using Syncfusion
- `extractReceiptData()`: Calls OpenAI API with function calling to extract structured invoice data
- Uses Dio with caching interceptor for API requests
- **Automatic retry with exponential backoff**:
  - Retries on rate limiting (HTTP 429), server errors (5xx), and network timeouts
  - Default: 3 retries with 1s initial delay, doubling each attempt
  - Non-retryable errors (4xx except 429) fail immediately

The AI extraction uses OpenAI's function calling feature with a detailed schema defining all invoice fields (vendor, dates, items, amounts, payment details, etc.).

#### Services Layer (lib/services/)

- **ExportService**: Handles CSV, JSON, and Excel export
  - CSV: Configurable delimiter, line item formatting (JSON/newline/bulleted), optional headers
  - JSON: Structured export with metadata and timestamp
  - Excel: Multi-sheet workbook (Summary sheet + Line Items sheet with styling)
- **FilenameTemplateService**: Template parsing and filename generation
  - Placeholders: `[YEAR]`, `[MONTH]`, `[DAY]`, `[DATE]`, `[VENDOR]`, `[CURRENCY]`, `[TOTAL]`
  - Automatic sanitization of vendor names for filesystem safety
  - Template validation with real-time feedback
- **StatsService**: Statistics and analytics for processed invoices

#### Models (lib/models.dart)

Core data models:

- `PdfDocument`: Represents a PDF file with extracted invoice data (vendor, dates, items, amounts, payment info)
- `ProjectFolder`: Represents a watched folder containing PDFs
- `ReceiptItem`: Individual line item from an invoice
- `ExportSettings`: Configuration for export operations (in lib/models/export_settings.dart)

#### Views (lib/views/)

- **OverviewView**: Dashboard with drag-and-drop support, statistics cards, and quick actions
- **FoldersView**: Grid of project folders with file counts and last modified timestamps
- **FilesView**: Table view with processing status, export toolbar, and bulk rename functionality

#### Dialogs (lib/dialogs/)

- **SettingsDialog**: API key configuration, model selection, filename template editor
- **FileDetailDialog**: Detailed invoice view with line items
- **ExportSettingsDialog**: Export format configuration

### Data Persistence

**Settings Storage** (via SharedPreferences):
- API key and model selection
- Filename template
- Auto-rename preference for dropped files
- Project folders list
- Individual files list
- Currently selected folder and view

**Extracted Data Cache** (JSON file at `~/.invoicer/data.json`):
- Atomic write pattern (write to `.tmp` then rename) for reliability
- Stores all processed invoice data with version metadata
- Automatically loaded on app startup to restore previously processed invoices
- Only restores data for files that still exist on disk

### Logging

Custom minimal logging via `AppLogger` class (lib/logger.dart):

- Logs to both stdout (via `debugPrint`) and rotating log files in `~/.invoicer/logs/`
- Daily log rotation with automatic cleanup (keeps last 7 days)
- Log levels: debug (gray), info (green), warning (yellow), error (red)
- Colorized console output using ANSI colors (via `ansicolor` package)
- Minimal output format: `[HH:mm:ss.SSS] LEVEL [ComponentName] message`
- Log files contain plain text (no color codes)
- Used in AppState, Extractor, and ExportService for debugging

### UI Framework

Built with **macos_ui** package for native macOS look and feel. Uses MacosWindow, MacosScaffold, MacosSheet, MacosAlertDialog, and macOS-specific widgets throughout.

Drag-and-drop support via **desktop_drop** package enables direct file processing from Finder.

### Configuration

The app requires an OpenAI API key, configured via:

1. `.env` file with `OPENAI_API_KEY` and `OPENAI_MODEL` variables (see `.env.example`)
2. Settings dialog (stored in SharedPreferences, takes precedence over .env)

Default model: `gpt-4.1-mini` (configurable in Settings)

### Linting Rules

Custom rules in analysis_options.yaml:

- `avoid_print: false` - Print statements allowed for debugging
- `always_use_package_imports: true` - Enforces package imports over relative imports
- `trailing_commas: preserve` - Preserves trailing commas for better git diffs

## Project Structure

```
lib/
├── main.dart                    # App entry point, MacosWindow setup
├── state.dart                   # Singleton AppState with signals
├── extractor.dart               # PDF text extraction and AI processing with retry logic
├── logger.dart                  # Custom minimal logger with file rotation
├── models.dart                  # Core data models
├── utils.dart                   # Utility functions
├── services/
│   ├── export_service.dart      # CSV/JSON/Excel export functionality
│   ├── filename_template_service.dart  # Template parsing and filename generation
│   └── stats_service.dart       # Statistics and analytics
├── models/
│   └── export_settings.dart     # Export configuration model
├── views/
│   ├── overview_view.dart       # Dashboard with drag-and-drop
│   ├── folders_view.dart        # Folder management UI
│   └── files_view.dart          # File list with export/rename toolbar
└── dialogs/
    ├── settings_dialog.dart     # API key, model, template configuration
    ├── file_detail_dialog.dart  # Detailed invoice view
    └── export_settings_dialog.dart  # Export format configuration

test/
├── unit/                        # Unit tests for services and utilities
├── helpers/                     # Test helpers and mocks
└── widget_test.dart             # Widget tests
```

## Key Features to Understand

### Filename Templates

The app supports customizable filename templates with placeholders:
- Template applied during manual rename, bulk rename, and auto-rename on drop
- Validation ensures .pdf extension and no invalid filename characters
- Sanitization removes/replaces problematic characters in vendor names

### Bulk Operations

- Process all files in a folder concurrently using `Future.wait()`
- Bulk rename with detailed success/failure reporting (`BulkRenameResult`)
- Export filtered subsets of invoices to CSV/JSON/Excel

### Drag-and-Drop Workflow

- Drop files onto OverviewView to trigger processing
- Optional auto-rename based on `autoRenameDropped` setting
- Shows detail dialog (if not auto-renaming) or success notification (if auto-renaming)
- Multiple files processed sequentially with progress indicators
