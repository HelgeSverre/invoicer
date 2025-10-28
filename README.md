# Invoicer

[![Flutter](https://img.shields.io/badge/Flutter-Desktop-02569B?logo=flutter&logoColor=white)](https://flutter.dev/desktop)
[![Platform](https://img.shields.io/badge/platform-macOS-lightgrey?logo=apple&logoColor=white)](https://developer.apple.com/macos/)
[![License](https://img.shields.io/github/license/HelgeSverre/invoicer)](LICENSE)

<p align="center">
  <img src="art/screenshot-detail.png" alt="Screenshot">
</p>

A macOS desktop app built with Flutter that extracts structured data from invoice PDFs. The app uses
Syncfusion PDF for text extraction and sends the extracted text to OpenAI via function calling to
produce normalized invoice fields (vendor, dates, items, totals, tax, etc.).

## What it does

- Loads PDF invoices from watched folders or via single-file selection.
- Extracts text from PDFs using Syncfusion PDF.
- Calls the OpenAI API with a function-calling schema to return structured invoice data.
- Displays parsed results and processing status in a native-looking macOS UI (macos_ui).
- Exports processed invoices to CSV, JSON, or Excel formats.
- Automatically renames files using customizable templates with placeholders.
- Bulk rename multiple files at once based on extracted data.
- Automatic retry with exponential backoff for API failures.
- Persists settings locally (including API key if set in the settings dialog).

## Features

### Data Extraction

Extracts comprehensive invoice data using OpenAI's GPT models:

**Invoice Header Fields:**

- Vendor/business name
- Invoice date and due date
- Currency (USD, EUR, etc.)
- Tax amount, total amount, discount amount

**Vendor Contact Details:**

- Website URL
- Email address
- Full mailing address

**Payment Information:**

- Payment method (Credit Card, Cash, Bank Transfer, etc.)
- Last four digits of payment card

**Line Items:**

- SKU or product identifier
- Item description
- Unit price and quantity
- Per-item currency
- Calculated totals

### Export Capabilities

Export processed invoices in multiple formats:

- **CSV Export**: All invoice fields with line items as embedded JSON
- **JSON Export**: Structured JSON with metadata and timestamp
- **Excel Export**: Multi-sheet workbook with:
  - Summary sheet: One row per invoice with all header fields
  - Line Items sheet: Detailed breakdown of all products/services

### File Management

**Filename Templates:**
Customize how files are renamed using placeholders:

- `[YEAR]` - 4-digit year (e.g., 2024)
- `[MONTH]` - 2-digit month (01-12)
- `[DAY]` - 2-digit day (01-31)
- `[DATE]` - Full date in YYYY-MM-DD format
- `[VENDOR]` - Vendor/business name
- `[CURRENCY]` - Currency code (USD, EUR, etc.)
- `[TOTAL]` - Total invoice amount

Example template: `[YEAR]-[MONTH]-[DAY] - [VENDOR].pdf`
Result: `2024-01-15 - Acme Corp.pdf`

**Bulk Operations:**

- Rename multiple files at once using the filename template
- Process all files in a folder simultaneously
- Detailed success/failure reporting for batch operations

### Reliability Features

**Automatic Retry Logic:**

- Exponential backoff for transient failures
- Automatic retry on rate limiting (HTTP 429)
- Retry on server errors (5xx) and network timeouts
- Default: 3 retries with 1s initial delay, doubling each attempt
- Clear error messages for permanent failures

**Error Handling:**

- Visual indicators for processing status
- Detailed error tooltips for failed extractions
- One-click retry for failed documents
- Error tracking per document

## Requirements

- macOS (desktop target; development requires Xcode toolchain)
- OpenAI API key
- Flutter (managed via fvm; see below)
- CocoaPods for macOS builds (for first-time setup)

## Setup

**1) Install prerequisites**

```bash
# just (task runner)
brew install just

# fvm (Flutter version manager)
brew tap leoafarias/fvm
brew install fvm
```

**2) Clone and prepare**

```bash
git clone https://github.com/HelgeSverre/invoicer.git
cd invoicer
just install
```

**3) Configure OpenAI**

Option A (file-based): copy the example env file and add your API key:

```bash
cp .env.example .env
# Edit .env and replace the placeholder with your actual OpenAI API key
```

The `.env` file should contain:

```dotnev
OPENAI_API_KEY=sk-proj-your-actual-key-here
OPENAI_MODEL=gpt-4.1-mini
```

Option B (in-app): run the app and set the key in the Settings dialog. The key is stored locally (
SharedPreferences).

**4) Run**

```bash
just run
# or: fvm flutter run -d macos
```

## Usage

### Basic Workflow

1. **Add Files**: Add a folder to watch invoices or add PDFs individually
2. **Process**: Click the process button to extract text and analyze with AI
3. **Review**: Check the parsed output in the Files view
4. **Export or Rename**: Use the toolbar to export data or bulk rename files

### Configuring Filename Templates

1. Open **Settings** (Cmd+, or menu)
2. Scroll to **Filename Template** section
3. Enter your desired template using placeholders:
   ```
   [YEAR]-[MONTH]-[DAY] - [VENDOR].pdf
   [VENDOR] - [DATE] - [CURRENCY] [TOTAL].pdf
   [YEAR]/[MONTH]/[VENDOR].pdf
   ```
4. Template is validated in real-time
5. Click **Save**

### Exporting Data

1. Process your invoices
2. In the Files view, find the export toolbar
3. Choose your format:
   - **CSV**: Best for spreadsheet applications
   - **JSON**: Best for programmatic access or data integration
   - **Excel**: Best for detailed analysis with multiple sheets
4. Select save location
5. Files are exported with all processed invoice data

### Bulk Renaming

1. Process multiple invoices
2. Click **Bulk Rename** in the export toolbar
3. Preview the template that will be used
4. Confirm the operation
5. Review the success/failure summary

**Notes:**

- Processing is local except for the OpenAI API call (PDF text is sent to OpenAI).
- Model defaults can be adjusted in Settings (gpt-4.1, gpt-4.1-mini, gpt-4.1-nano).
- Failed extractions can be retried with a single click.
- The app automatically retries transient failures (rate limits, network errors).

## Development

This repo uses fvm to pin and consistently use a Flutter SDK version. All justfile commands call
Flutter via fvm.

- Verify your setup: `fvm flutter doctor`
- If you prefer not to install fvm, replace justfile invocations with the equivalent flutter
  commands (but version drift is on you).

### justfile commands

```bash
just            # List available commands
just run        # Run the app in debug mode on macOS
just dev        # Alias for run
just build      # Build a macOS release bundle
just test       # Run unit/widget tests
just analyze    # Static analysis (flutter analyze)
just install    # flutter pub get via fvm
just update     # flutter pub upgrade via fvm
just outdated   # Check for outdated dependencies
just clean      # Clean build artifacts
just reset      # Clean + reinstall dependencies
just pod-install  # Install CocoaPods dependencies for macOS
just pod-reset    # Clean pod artifacts and reinstall
```

### Project structure (high level)

- `lib/main.dart`: app entry point and macOS window setup
- `lib/state.dart`: AppState singleton with signals-based state management (project folders, files,
  status, filename template)
- `lib/extractor.dart`: PDF text extraction (Syncfusion), OpenAI function-calling with retry logic
- `lib/models.dart`: data models (PdfDocument, ProjectFolder, ReceiptItem)
- `lib/services/`:
  - `export_service.dart`: CSV, JSON, and Excel export functionality
  - `filename_template_service.dart`: Template parsing and filename generation
- `lib/views/`: folders and files views with export/rename UI
- `lib/dialogs/`: settings dialog (API key, model, filename template), file detail dialog

### Architecture overview

- **State management:** signals (reactive, simple, centrally managed in AppState)
- **Data flow:**
  1. PDF(s) loaded from watched folder(s) or by individual file selection
  2. Text extracted with syncfusion_flutter_pdf
  3. Extracted text sent to OpenAI with a function-calling schema
  4. Automatic retry with exponential backoff on transient failures
  5. Structured invoice data returned (vendor, dates, line items, amounts)
  6. AppState updates emit reactive UI changes via signals
  7. Export service transforms data to CSV/JSON/Excel formats
  8. Filename template service generates standardized filenames
- **UI:** macos_ui for native macOS look-and-feel
- **Settings:** SharedPreferences; API key, model selection, filename template
- **Networking:** Dio with caching interceptor and retry logic for API requests
- **Export formats:**
  - CSV: ListToCsvConverter with all fields
  - JSON: Pretty-printed with metadata
  - Excel: Multi-sheet using excel package (Summary + Line Items)
- **Model defaults:** extractor defaults to gpt-4.1-mini; configurable in Settings

## Building

```bash
just build
# Output: build/macos/Build/Products/Release/
```

If you hit CocoaPods issues:

```bash
just pod-reset
just pod-install
```

## Configuration

**.env file** (loaded via flutter_dotenv):

A `.env.example` file is provided as a template. To configure:

```bash
cp .env.example .env
# Edit .env and replace placeholder values with your actual OpenAI API key
```

Example `.env` contents:

```env
OPENAI_API_KEY=sk-proj-your-actual-key-here
OPENAI_MODEL=gpt-4.1-mini
```

**Note:** The `.env` file is gitignored to keep your API key private.

**Settings dialog** (persisted locally) can also store the key at runtime.

No external backend required; network calls are to the OpenAI API.

## Extracted Data Fields

The app extracts the following fields from invoices via OpenAI function calling:

| Field                    | Type    | Description                            | Required |
| ------------------------ | ------- | -------------------------------------- | -------- |
| **Invoice Header**       |
| `vendor`                 | string  | Vendor/business name                   | Yes      |
| `invoice_date`           | date    | Invoice date (YYYY-MM-DD)              | Yes      |
| `due_date`               | date    | Payment due date                       | No       |
| `currency`               | string  | Currency code (USD, EUR, etc.)         | No       |
| `tax_amount`             | number  | Total tax amount                       | No       |
| `total_amount`           | number  | Total including tax                    | Yes      |
| `discount_amount`        | number  | Discount applied                       | No       |
| **Vendor Details**       |
| `vendor_website`         | string  | Vendor website URL                     | No       |
| `vendor_email`           | string  | Vendor email address                   | No       |
| `vendor_display_address` | string  | Full vendor mailing address            | No       |
| **Payment Info**         |
| `payment_method`         | string  | Payment type (Credit Card, Cash, etc.) | No       |
| `last_four_digits`       | string  | Last 4 digits of payment card          | No       |
| **Line Items**           | (array) |
| `sku`                    | string  | Product SKU/identifier                 | No       |
| `text`                   | string  | Item description                       | Yes      |
| `unit_price`             | number  | Price per unit                         | Yes      |
| `quantity`               | integer | Number of items                        | Yes      |
| `currency`               | string  | Item currency                          | No       |

**Note:** The AI model does its best to extract available fields. Not all invoices contain all fields.

## Future Enhancements

Potential additional fields that could be extracted in future versions:

### High Priority

- `invoice_number` - Invoice/receipt ID for tracking and reference
- `purchase_order_number` - PO number for business purchases
- `subtotal` - Amount before tax (for verification)
- `shipping_cost` - Delivery or shipping fees
- `tax_rate` - Tax percentage (not just amount)
- `payment_terms` - Terms like "Net 30" or "Due on receipt"

### Medium Priority

- `customer_name` - Bill-to name
- `customer_address` - Billing address
- `reference_number` - Additional tracking/reference number
- `notes` - Invoice memo or notes field
- `payment_date` - Actual payment date (for paid invoices)
- `bank_details` - IBAN/account number for wire transfers

### Specialized Use Cases

- `shipping_address` - Separate from billing address
- `customer_tax_id` - VAT number or tax registration
- `tips` - Tips or gratuity (service invoices)
- `item_categories` - Product categorization
- `tax_breakdown` - Multiple tax types itemized
- `payment_status` - Paid/unpaid/partial
- `line_item_discounts` - Per-item discount amounts

**Contributions welcome!** If you need any of these fields, feel free to open an issue or submit a PR.

## Privacy and data handling

- PDF text is sent to OpenAI during extraction; do not process sensitive documents unless that's
  acceptable for your use-case and OpenAI account/data policies.
- No analytics or telemetry are implemented in this app.
- Syncfusion's Flutter PDF library is used for text extraction (review their license terms for your
  usage).

## Limitations

- PDF extraction fidelity varies with source quality; some invoices may not parse perfectly.
- The OpenAI output depends on the model and prompt/schema; occasional corrections or re-runs may be
  needed.
- Currently targets macOS only.

## Contributing

Issues and PRs are welcome. Keep changes focused and incremental. Prefer existing patterns (signals,
macos_ui, extractor flow) and avoid introducing new dependencies unless necessary.

- Code quality: `just analyze`
- Tests: `just test`
- Style/lints: see `analysis_options.yaml`

## License

This project is open-source. See LICENSE for details.
