# AGENTS.md

Guidance for AI coding agents working in this repository.

## Development Commands

**Run:** `fvm flutter run -d macos` or `just run`  
**Build:** `fvm flutter build macos` or `just build`  
**Test all:** `fvm flutter test` or `just test`  
**Test single file:** `fvm flutter test test/widget_test.dart`  
**Lint/analyze:** `fvm flutter analyze` or `just analyze`  
**Clean:** `fvm flutter clean` or `just clean`

## Architecture

- **State management:** Signals pattern via `signals` package. All state in singleton `AppState` (lib/state.dart)
- **PDF processing:** `extractor.dart` uses Syncfusion PDF + OpenAI function calling to extract invoice data
- **UI framework:** `macos_ui` for native macOS look/feel
- **Data models:** `PdfDocument`, `ProjectFolder`, `ReceiptItem` in lib/models.dart
- **Views:** Two-pane UI with FoldersView (grid) and FilesView (table)
- **Config:** OpenAI API key via `.env` file (`OPENAI_API_KEY`) or Settings dialog

## Code Style

- **Imports:** ALWAYS use package imports (`package:invoicer/...`), NEVER relative imports
- **Print statements:** Allowed for debugging (`avoid_print: false`)
- **Trailing commas:** Preserve them for better git diffs
- **Naming:** Follow Dart conventions (camelCase for variables/functions, PascalCase for classes)
- **Signals:** Use `signal()` for reactive state, access with `.value`, update triggers UI refresh
- **Error handling:** Follow existing patterns in extractor.dart and state.dart
