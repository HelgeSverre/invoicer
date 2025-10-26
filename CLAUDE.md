# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

Invoicer is a macOS desktop application built with Flutter for processing invoices and receipts. It uses OpenAI's GPT models with function calling to extract structured data from PDF documents, including line items, vendor details, dates, and financial information.

## Development Commands

### Running the Application
```bash
flutter run -d macos
```

### Building
```bash
flutter build macos
```

### Testing
```bash
flutter test
```

### Linting
```bash
flutter analyze
```

## Architecture

### State Management
The app uses the **signals** pattern (via the `signals` package) for reactive state management. The entire application state is managed through a singleton `AppState` class (lib/state.dart) that uses signals for reactive updates.

Key state signals:
- `projectFolders`: List of watched folders containing PDFs
- `currentlySelectedFolder`: Currently active project folder
- `pdfFiles`: PDFs from the current folder
- `individualFiles`: Individually added PDF files
- `currentView`: UI view state ('folders' or 'files')
- `isProcessingAll`: Batch processing status

### Data Flow Architecture

1. **PDF Loading**: Files are loaded from selected folders or added individually
2. **Text Extraction**: Uses `syncfusion_flutter_pdf` to extract text from PDFs
3. **AI Processing**: Extracted text is sent to OpenAI with function calling schema
4. **Data Extraction**: OpenAI returns structured data conforming to the schema
5. **State Update**: Signals trigger reactive UI updates when processing completes

### Key Components

#### AppState (lib/state.dart)
Singleton managing all application state. Handles:
- Folder and file management
- PDF processing orchestration
- Settings persistence (via SharedPreferences)
- AI processing coordination

#### Extractor (lib/extractor.dart)
Static utility class for PDF processing:
- `extractTextFromPDF()`: Extracts text content from PDFs using Syncfusion
- `extractReceiptData()`: Calls OpenAI API with function calling to extract structured invoice data
- Uses Dio with caching interceptor for API requests

The AI extraction uses OpenAI's function calling feature with a detailed schema defining all invoice fields (vendor, dates, items, amounts, etc.).

#### Models (lib/models.dart)
Core data models:
- `PdfDocument`: Represents a PDF file with extracted invoice data
- `ProjectFolder`: Represents a watched folder containing PDFs
- `ReceiptItem`: Individual line item from an invoice

#### Views
- `FoldersView`: Displays grid of project folders with file counts
- `FilesView`: Table view of all PDF files with processing status
- Two-pane UI with sidebar navigation between folders and files views

### UI Framework
Built with **macos_ui** package for native macOS look and feel. Uses MacosWindow, MacosScaffold, and macOS-specific widgets throughout.

### Configuration

The app requires an OpenAI API key, configured either via:
1. `.env` file with `OPENAI_API_KEY` variable
2. Settings dialog (stored in SharedPreferences)

The AI model can be overridden by passing a `model` parameter to `extractReceiptData()` (defaults to "gpt-4.1-mini").

### Linting Rules

Custom rules in analysis_options.yaml:
- `avoid_print: false` - Print statements are allowed for debugging
- `always_use_package_imports: true` - Enforces package imports over relative imports
- Trailing commas are preserved for better git diffs

## Project Structure

```
lib/
├── main.dart              # App entry point, MacosWindow setup
├── state.dart             # Singleton AppState with signals
├── extractor.dart         # PDF text extraction and AI processing
├── models.dart            # Data models
├── views/
│   ├── folders_view.dart  # Folder management UI
│   └── files_view.dart    # File list and processing UI
└── dialogs/
    ├── settings_dialog.dart      # API key configuration
    └── file_detail_dialog.dart   # Detailed invoice view
```
