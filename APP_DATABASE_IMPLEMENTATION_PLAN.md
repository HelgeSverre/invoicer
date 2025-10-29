# SQLite Database Migration: Complete Implementation Plan

**Project:** Invoicer - Flutter macOS Invoice Processing Application
**Migration:** JSON/SharedPreferences/Log Files → SQLite (drift)
**Approach:** Clean replacement (no backwards compatibility)
**Estimated Time:** 22-32 hours over 2-3 weeks
**Status:** Complete, self-contained, ready for AI agent execution

---

## Important Notes

⚠️ **This document is fully self-contained** - no external references needed
⚠️ **All code is complete** - no TODOs or placeholders
⚠️ **Execute sequentially** - each phase builds on previous
⚠️ **Test after each phase** - verify before proceeding

---

## Table of Contents

1. [Pre-Flight Checklist](#pre-flight-checklist)
2. [Phase 1: Drift Setup](#phase-1-drift-setup-6-8-hours)
3. [Phase 2: Create DAOs](#phase-2-create-daos-4-6-hours)
4. [Phase 3: Integrate AppState](#phase-3-integrate-appstate-8-12-hours)
5. [Phase 4: Update Logger](#phase-4-update-logger-2-4-hours)
6. [Phase 5: Testing & Cleanup](#phase-5-testing--cleanup-4-6-hours)
7. [Rollback Plan](#rollback-plan)
8. [Error Recovery](#error-recovery)
9. [Post-Migration Verification](#post-migration-verification)

---

## Pre-Flight Checklist

**Before starting:**

```bash
# 1. Verify environment
fvm flutter doctor
just build
just test

# 2. Check git status
git status  # Should be clean

# 3. Create feature branch
git checkout -b feature/sqlite-migration

# 4. Backup current data (CRITICAL - no backwards compatibility)
cp ~/.invoicer/data.json ~/.invoicer/data.json.backup.$(date +%s) 2>/dev/null || true
cp -r ~/.invoicer/logs ~/.invoicer/logs.backup.$(date +%s) 2>/dev/null || true
```

**Current architecture:**
- `lib/state.dart` - 855 lines, signals-based state management
- `lib/models.dart` - PdfDocument, ReceiptItem, ProjectFolder
- `lib/extractor.dart` - PDF OCR + OpenAI extraction
- `lib/logger.dart` - File-based rotating logs
- Current persistence: JSON file + SharedPreferences

**Critical data flows to replace:**
1. PDF → `Extractor.extractTextFromPDF()` → OCR text (MUST BE SAVED)
2. OCR text → `Extractor.extractReceiptData()` → structured JSON
3. Structured data → signals → `saveExtractedData()` → JSON file (REPLACE)
4. Settings → `SharedPreferences` → persistence (REPLACE)
5. Logs → daily text files in `~/.invoicer/logs/` (REPLACE)

---

## Phase 1: Drift Setup (6-8 hours)

### Step 1.1: Add Dependencies

**File:** `pubspec.yaml`

**Find this section (around line 35):**
```yaml
dependencies:
  flutter:
    sdk: flutter
  cupertino_icons: ^1.0.6
  signals: ^5.5.3
```

**Add after `signals:`:**
```yaml
  signals: ^5.5.3
  drift: ^2.14.0
  sqlite3_flutter_libs: ^0.5.0
  path_provider: ^2.1.0
```

**Find dev_dependencies (around line 50):**
```yaml
dev_dependencies:
  flutter_test:
    sdk: flutter
  flutter_lints: ^3.0.0
```

**Add after `flutter_lints:`:**
```yaml
  flutter_lints: ^3.0.0
  drift_dev: ^2.14.0
  build_runner: ^2.4.0
```

**Verify:**
```bash
fvm flutter pub get
echo $?  # Should output 0
```

---

### Step 1.2: Create Database Tables (COMPLETE)

**File:** `lib/database/tables.dart` (NEW FILE)

**Create with complete content:**

```dart
import 'package:drift/drift.dart';

// ============================================================================
// CORE TABLES (Essential for migration)
// ============================================================================

// ----------------------------------------------------------------------------
// VENDORS - Normalized vendor information
// ----------------------------------------------------------------------------
class Vendors extends Table {
  IntColumn get id => integer().autoIncrement()();

  // Core (required)
  TextColumn get name => text().unique()();

  // Contact
  TextColumn get email => text().nullable()();
  TextColumn get website => text().nullable()();
  TextColumn get phone => text().nullable()();

  // Address
  TextColumn get addressLine1 => text().nullable()();
  TextColumn get addressLine2 => text().nullable()();
  TextColumn get city => text().nullable()();
  TextColumn get stateProvince => text().nullable()();
  TextColumn get postalCode => text().nullable()();
  TextColumn get country => text().nullable()();

  // Statistics (cached, updated via trigger/DAO)
  IntColumn get totalInvoices => integer().withDefault(const Constant(0))();
  RealColumn get totalSpent => real().withDefault(const Constant(0.0))();
  RealColumn get averageInvoiceAmount => real().nullable()();

  // Date range (stored as ISO 8601 strings for simplicity)
  TextColumn get firstInvoiceDate => text().nullable()();
  TextColumn get lastInvoiceDate => text().nullable()();

  // Metadata
  TextColumn get notes => text().nullable()();

  // Audit
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get deletedAt => dateTime().nullable()();
}

// ----------------------------------------------------------------------------
// RECEIPTS - Main invoice/receipt data (replaces PdfDocument)
// Maps to: lib/models.dart PdfDocument class
// ----------------------------------------------------------------------------
class Receipts extends Table {
  IntColumn get id => integer().autoIncrement()();

  // File information (from PdfDocument.name, .path)
  TextColumn get fileName => text()();
  TextColumn get filePath => text().unique()();
  IntColumn get fileSize => integer().nullable()();
  TextColumn get fileHash => text().nullable()();

  // Source tracking (from PdfDocument.source, .folderPath)
  TextColumn get sourceType => text()();  // 'folder' or 'individual'
  IntColumn get sourceFolderId => integer().nullable()
    .references(Folders, #id, onDelete: KeyAction.setNull)();

  // Vendor relationship (NORMALIZED - from PdfDocument.vendor string → FK)
  IntColumn get vendorId => integer().nullable()
    .references(Vendors, #id, onDelete: KeyAction.setNull)();

  // Receipt info
  TextColumn get receiptType => text().nullable()();
  TextColumn get invoiceNumber => text().nullable()();

  // Dates (stored as DateTime for proper querying)
  DateTimeColumn get invoiceDate => dateTime().nullable()();
  DateTimeColumn get dueDate => dateTime().nullable()();
  DateTimeColumn get paidDate => dateTime().nullable()();

  // Financial (from PdfDocument fields)
  TextColumn get currency => text().withDefault(const Constant('USD'))();
  RealColumn get subtotal => real().nullable()();
  RealColumn get taxAmount => real().nullable()();
  RealColumn get discountAmount => real().nullable()();
  RealColumn get shippingAmount => real().nullable()();
  RealColumn get totalAmount => real()();  // NOT NULL - required field

  // Payment (from PdfDocument.paymentMethod, .lastFourDigits)
  TextColumn get paymentMethod => text().nullable()();
  TextColumn get paymentCardLast4 => text().nullable()();
  TextColumn get paymentStatus => text().nullable()();

  // OCR/AI - CRITICAL FIELDS FOR REPROCESSING
  TextColumn get ocrText => text()();  // NOT NULL - from Extractor.extractTextFromPDF()
  TextColumn get ocrMethod => text().withDefault(const Constant('syncfusion'))();
  TextColumn get aiModelUsed => text().nullable()();
  IntColumn get aiExtractionVersion => integer().withDefault(const Constant(1))();

  // Processing metadata
  DateTimeColumn get processedAt => dateTime().nullable()();
  IntColumn get reprocessedCount => integer().withDefault(const Constant(0))();
  IntColumn get processingDurationMs => integer().nullable()();

  // Error tracking (from PdfDocument.error)
  TextColumn get lastError => text().nullable()();
  IntColumn get errorCount => integer().withDefault(const Constant(0))();

  // Flags
  BoolColumn get userVerified => boolean().withDefault(const Constant(false))();
  BoolColumn get archived => boolean().withDefault(const Constant(false))();

  // Audit
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get deletedAt => dateTime().nullable()();

  @override
  List<Set<Column>> get customIndexes => [
    {vendorId},
    {invoiceDate},
    {totalAmount},
    {sourceFolderId},
    {filePath},
  ];
}

// ----------------------------------------------------------------------------
// LINE_ITEMS - Individual items from receipts (replaces ReceiptItem)
// Maps to: lib/models.dart ReceiptItem class
// ----------------------------------------------------------------------------
class LineItems extends Table {
  IntColumn get id => integer().autoIncrement()();

  // Foreign key to receipt (CASCADE DELETE - if receipt deleted, items deleted)
  IntColumn get receiptId => integer()
    .references(Receipts, #id, onDelete: KeyAction.cascade)();

  // Line order
  IntColumn get lineNumber => integer().nullable()();

  // Item info (from ReceiptItem.sku, .text)
  TextColumn get sku => text().nullable()();
  TextColumn get description => text()();  // maps to ReceiptItem.text

  // Pricing (from ReceiptItem.unitPrice, .quantity)
  RealColumn get quantity => real().withDefault(const Constant(1.0))();
  TextColumn get unitOfMeasure => text().nullable()();
  RealColumn get unitPrice => real()();
  RealColumn get lineTotal => real()();  // quantity * unitPrice

  // Tax
  BoolColumn get isTaxable => boolean().withDefault(const Constant(true))();
  RealColumn get taxAmount => real().nullable()();

  // Audit
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();

  @override
  List<Set<Column>> get customIndexes => [
    {receiptId},
    {sku},
  ];
}

// ----------------------------------------------------------------------------
// FOLDERS - Project/watched folders (replaces ProjectFolder)
// Maps to: lib/models.dart ProjectFolder class
// ----------------------------------------------------------------------------
class Folders extends Table {
  IntColumn get id => integer().autoIncrement()();

  // Folder info (from ProjectFolder.path, .name)
  TextColumn get path => text().unique()();
  TextColumn get name => text()();

  // Hierarchy (for nested folders)
  IntColumn get parentFolderId => integer().nullable()
    .references(Folders, #id)();

  // Statistics (cached, updated via DAO)
  IntColumn get fileCount => integer().withDefault(const Constant(0))();
  IntColumn get processedCount => integer().withDefault(const Constant(0))();
  RealColumn get totalValue => real().withDefault(const Constant(0.0))();

  // Settings
  BoolColumn get autoProcess => boolean().withDefault(const Constant(true))();

  // Metadata
  TextColumn get description => text().nullable()();

  // Audit (from ProjectFolder.addedAt)
  DateTimeColumn get addedAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get lastScannedAt => dateTime().nullable()();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get deletedAt => dateTime().nullable()();

  @override
  List<Set<Column>> get customIndexes => [
    {path},
    {parentFolderId},
  ];
}

// ----------------------------------------------------------------------------
// SETTINGS - Application settings (replaces SharedPreferences)
// Stores: AppState signal values (apiKey, aiModel, filenameTemplate, etc.)
// ----------------------------------------------------------------------------
class Settings extends Table {
  TextColumn get key => text()();
  TextColumn get value => text()();
  TextColumn get valueType => text()();  // 'string', 'int', 'bool', 'json'

  // Metadata
  TextColumn get category => text().nullable()();  // 'api', 'ui', 'processing'
  TextColumn get description => text().nullable()();
  BoolColumn get isSecret => boolean().withDefault(const Constant(false))();

  // Audit
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column> get primaryKey => {key};

  @override
  List<Set<Column>> get customIndexes => [
    {category},
  ];
}

// Settings keys from lib/state.dart AppState class:
// - 'openai_api_key' (appState.apiKey.value)
// - 'openai_model' (appState.aiModel.value)
// - 'filename_template' (appState.filenameTemplate.value)
// - 'auto_rename_dropped' (appState.autoRenameDropped.value)
// - 'current_view' (appState.currentView.value)
// - 'currently_selected_folder' (appState.currentlySelectedFolder.value?.path)

// ----------------------------------------------------------------------------
// LOG_ENTRIES - Structured application logs (replaces text log files)
// Replaces: lib/logger.dart file-based logging
// ----------------------------------------------------------------------------
class LogEntries extends Table {
  IntColumn get id => integer().autoIncrement()();

  // Timestamp
  DateTimeColumn get timestamp => dateTime().withDefault(currentDateAndTime)();

  // Log level (from AppLogger: debug, info, warning, error)
  TextColumn get level => text()();  // 'DEBUG', 'INFO', 'WARN', 'ERROR'

  // Source (from AppLogger component parameter)
  TextColumn get component => text()();  // 'AppState', 'Extractor', 'ExportService'
  TextColumn get functionName => text().nullable()();

  // Message (from AppLogger message parameter)
  TextColumn get message => text()();

  // Context
  TextColumn get context => text().nullable()();  // JSON for additional data

  // Error details (from AppLogger error/stackTrace parameters)
  TextColumn get errorType => text().nullable()();
  TextColumn get errorMessage => text().nullable()();
  TextColumn get stackTrace => text().nullable()();

  // Associated entities (for tracing)
  IntColumn get receiptId => integer().nullable()();
  IntColumn get vendorId => integer().nullable()();

  // Performance tracking
  IntColumn get durationMs => integer().nullable()();

  // Session tracking
  TextColumn get sessionId => text().nullable()();

  // Flags
  BoolColumn get isRead => boolean().withDefault(const Constant(false))();
  BoolColumn get isArchived => boolean().withDefault(const Constant(false))();

  @override
  List<Set<Column>> get customIndexes => [
    {timestamp},
    {level},
    {component},
    {receiptId},
  ];
}
```

**Verify:**
```bash
test -f lib/database/tables.dart && echo "✓ Tables file created" || echo "✗ FAILED"
wc -l lib/database/tables.dart  # Should show ~250+ lines
```

---

### Step 1.3: Create Main Database Class (COMPLETE)

**File:** `lib/database/database.dart` (NEW FILE)

**Create with complete content:**

```dart
import 'dart:io';
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path/path.dart' as path;
import 'package:invoicer/database/tables.dart';

// DAO imports will be added in Phase 2
// import 'package:invoicer/database/daos/documents_dao.dart';
// import 'package:invoicer/database/daos/vendors_dao.dart';
// import 'package:invoicer/database/daos/folders_dao.dart';
// import 'package:invoicer/database/daos/settings_dao.dart';
// import 'package:invoicer/database/daos/logs_dao.dart';

part 'database.g.dart';

@DriftDatabase(
  tables: [
    Vendors,
    Receipts,
    LineItems,
    Folders,
    Settings,
    LogEntries,
  ],
  // DAOs will be added in Phase 2:
  // daos: [DocumentsDao, VendorsDao, FoldersDao, SettingsDao, LogsDao],
)
class AppDatabase extends _$AppDatabase {
  // Singleton pattern
  static AppDatabase? _instance;

  AppDatabase._() : super(_openConnection());

  // Test constructor for unit tests (in-memory database)
  AppDatabase.test() : super(NativeDatabase.memory());

  // Singleton accessor
  static AppDatabase get instance {
    _instance ??= AppDatabase._();
    return _instance!;
  }

  @override
  int get schemaVersion => 1;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (Migrator m) async {
      // Create all tables
      await m.createAll();

      // Create additional indexes for performance
      await customStatement('CREATE INDEX idx_receipts_vendor ON receipts(vendor_id)');
      await customStatement('CREATE INDEX idx_receipts_date ON receipts(invoice_date)');
      await customStatement('CREATE INDEX idx_receipts_total ON receipts(total_amount)');
      await customStatement('CREATE INDEX idx_line_items_receipt ON line_items(receipt_id)');
      await customStatement('CREATE INDEX idx_logs_timestamp ON log_entries(timestamp DESC)');
      await customStatement('CREATE INDEX idx_logs_level ON log_entries(level)');
      await customStatement('CREATE INDEX idx_logs_component ON log_entries(component)');

      // Optional: FTS5 virtual table for full-text search
      // Uncomment when needed for search functionality:
      // await customStatement(
      //   '''
      //   CREATE VIRTUAL TABLE receipts_fts USING fts5(
      //     file_name,
      //     vendor_name,
      //     invoice_number,
      //     content='receipts'
      //   )
      //   ''',
      // );
    },

    onUpgrade: (Migrator m, int from, int to) async {
      // Future schema migrations go here
      // Example:
      // if (from < 2) {
      //   await m.addColumn(receipts, receipts.paymentStatus);
      // }
    },

    beforeOpen: (details) async {
      // Enable foreign keys (CRITICAL for referential integrity)
      await customStatement('PRAGMA foreign_keys = ON');

      // Enable WAL mode for better concurrency
      // (multiple readers, single writer)
      await customStatement('PRAGMA journal_mode = WAL');

      // Verify foreign keys are actually enabled
      final result = await customSelect('PRAGMA foreign_keys').getSingle();
      final fkEnabled = result.data['foreign_keys'] == 1;
      if (!fkEnabled) {
        throw Exception('Failed to enable foreign keys');
      }
    },
  );

  /// Open database connection
  /// Location: ~/.invoicer/invoicer.db
  static QueryExecutor _openConnection() {
    return LazyDatabase(() async {
      final home = Platform.environment['HOME'] ??
                   Platform.environment['USERPROFILE'];

      if (home == null) {
        throw Exception('Cannot determine user home directory');
      }

      final dbFolder = Directory(path.join(home, '.invoicer'));

      if (!await dbFolder.exists()) {
        await dbFolder.create(recursive: true);
      }

      final file = File(path.join(dbFolder.path, 'invoicer.db'));

      return NativeDatabase.createInBackground(file);
    });
  }

  /// Delete database file (for testing or full reset)
  Future<void> deleteDatabase() async {
    final home = Platform.environment['HOME'] ??
                 Platform.environment['USERPROFILE'];

    if (home == null) return;

    final dbFile = File(path.join(home, '.invoicer', 'invoicer.db'));
    final walFile = File(path.join(home, '.invoicer', 'invoicer.db-wal'));
    final shmFile = File(path.join(home, '.invoicer', 'invoicer.db-shm'));

    if (await dbFile.exists()) await dbFile.delete();
    if (await walFile.exists()) await walFile.delete();
    if (await shmFile.exists()) await shmFile.delete();
  }

  /// Delete all data (for reset, keeps schema)
  Future<void> deleteAllData() async {
    await transaction(() async {
      // Order matters - delete children before parents to avoid FK violations
      await customStatement('DELETE FROM log_entries');
      await customStatement('DELETE FROM line_items');
      await customStatement('DELETE FROM receipts');
      await customStatement('DELETE FROM vendors');
      await customStatement('DELETE FROM folders');
      // Don't delete settings - preserve API key etc.
    });
  }
}
```

**Verify:**
```bash
test -f lib/database/database.dart && echo "✓ Database file created" || echo "✗ FAILED"
```

---

### Step 1.4: Run Code Generator

**Command:**
```bash
dart run build_runner build --delete-conflicting-outputs
```

**Expected output:**
```
[INFO] Generating build script...
[INFO] Running build...
[INFO] Succeeded after X.Xs with 2 outputs
```

**Verify:**
```bash
test -f lib/database/database.g.dart && echo "✓ Generated file exists" || echo "✗ FAILED"
grep -c "class _\$AppDatabase" lib/database/database.g.dart  # Should output 1
```

**If build fails:**
```bash
# Clean and retry
dart run build_runner clean
fvm flutter pub get
dart run build_runner build --delete-conflicting-outputs
```

**Success Criteria:**
- ✅ No build errors
- ✅ `database.g.dart` created
- ✅ File contains `_$AppDatabase` class

---

## Phase 2: Create DAOs (4-6 hours)

### Step 2.1: Create DAO Directory

```bash
mkdir -p lib/database/daos
```

---

### Step 2.2: DocumentsDao (COMPLETE)

**File:** `lib/database/daos/documents_dao.dart` (NEW FILE)

```dart
import 'package:drift/drift.dart';
import 'package:invoicer/database/database.dart';
import 'package:invoicer/database/tables.dart';

part 'documents_dao.g.dart';

@DriftAccessor(tables: [Receipts, LineItems, Vendors])
class DocumentsDao extends DatabaseAccessor<AppDatabase>
    with _$DocumentsDaoMixin {
  DocumentsDao(AppDatabase db) : super(db);

  // ==========================================================================
  // INSERT OPERATIONS
  // ==========================================================================

  /// Insert receipt with line items in a transaction
  /// Returns the receipt ID
  Future<int> insertReceiptWithItems(
    ReceiptsCompanion receipt,
    List<LineItemsCompanion> items,
  ) {
    return transaction(() async {
      final receiptId = await into(receipts).insert(receipt);

      for (var i = 0; i < items.length; i++) {
        await into(lineItems).insert(
          items[i].copyWith(
            receiptId: Value(receiptId),
            lineNumber: Value(i + 1),
          ),
        );
      }

      return receiptId;
    });
  }

  /// Upsert: Insert or update receipt by file path
  /// If receipt exists (by file_path), update it and replace line items
  /// Otherwise, insert new receipt
  Future<int> upsertReceiptWithItems(
    ReceiptsCompanion receipt,
    List<LineItemsCompanion> items,
  ) {
    return transaction(() async {
      // Check if receipt exists by file path
      final existing = await (select(receipts)
        ..where((r) => r.filePath.equals(receipt.filePath.value)))
        .getSingleOrNull();

      int receiptId;

      if (existing != null) {
        // Update existing receipt
        receiptId = existing.id;

        await (update(receipts)..where((r) => r.id.equals(receiptId)))
          .write(receipt.copyWith(
            id: Value(receiptId),
            updatedAt: Value(DateTime.now()),
          ));

        // Delete old line items (will be replaced)
        await (delete(lineItems)
          ..where((l) => l.receiptId.equals(receiptId)))
          .go();
      } else {
        // Insert new receipt
        receiptId = await into(receipts).insert(receipt);
      }

      // Insert line items
      for (var i = 0; i < items.length; i++) {
        await into(lineItems).insert(
          items[i].copyWith(
            receiptId: Value(receiptId),
            lineNumber: Value(i + 1),
          ),
        );
      }

      return receiptId;
    });
  }

  // ==========================================================================
  // QUERY OPERATIONS
  // ==========================================================================

  /// Get receipt by file path
  Future<Receipt?> getReceiptByFilePath(String filePath) {
    return (select(receipts)
      ..where((r) => r.filePath.equals(filePath)))
      .getSingleOrNull();
  }

  /// Get receipt by ID
  Future<Receipt?> getReceiptById(int id) {
    return (select(receipts)..where((r) => r.id.equals(id)))
      .getSingleOrNull();
  }

  /// Get line items for a receipt
  Future<List<LineItem>> getLineItemsForReceipt(int receiptId) {
    return (select(lineItems)
      ..where((l) => l.receiptId.equals(receiptId))
      ..orderBy([(l) => OrderingTerm.asc(l.lineNumber)]))
      .get();
  }

  /// Get receipts by folder ID (for currently selected folder)
  Future<List<Receipt>> getReceiptsByFolderId(int folderId) {
    return (select(receipts)
      ..where((r) =>
        r.sourceFolderId.equals(folderId) &
        r.deletedAt.isNull()))
      .get();
  }

  /// Get receipts by folder path (convenience method)
  /// First looks up folder ID, then queries receipts
  Future<List<Receipt>> getReceiptsByFolderPath(String folderPath) async {
    // Get folder by path
    final folder = await (select(db.folders)
      ..where((f) => f.path.equals(folderPath)))
      .getSingleOrNull();

    if (folder == null) return [];

    return getReceiptsByFolderId(folder.id);
  }

  /// Get all individual files (not from folders)
  Future<List<Receipt>> getIndividualReceipts() {
    return (select(receipts)
      ..where((r) =>
        r.sourceType.equals('individual') &
        r.deletedAt.isNull()))
      .get();
  }

  /// Get all receipts (for export or stats)
  Future<List<Receipt>> getAllReceipts() {
    return (select(receipts)
      ..where((r) => r.deletedAt.isNull())
      ..orderBy([(r) => OrderingTerm.desc(r.invoiceDate)]))
      .get();
  }

  /// Get receipts by vendor ID
  Future<List<Receipt>> getReceiptsByVendor(int vendorId) {
    return (select(receipts)
      ..where((r) =>
        r.vendorId.equals(vendorId) &
        r.deletedAt.isNull())
      ..orderBy([(r) => OrderingTerm.desc(r.invoiceDate)]))
      .get();
  }

  /// Get receipts by date range
  Future<List<Receipt>> getReceiptsByDateRange(
    DateTime start,
    DateTime end,
  ) {
    return (select(receipts)
      ..where((r) =>
        r.invoiceDate.isBiggerOrEqualValue(start) &
        r.invoiceDate.isSmallerOrEqualValue(end) &
        r.deletedAt.isNull())
      ..orderBy([(r) => OrderingTerm.desc(r.invoiceDate)]))
      .get();
  }

  // ==========================================================================
  // UPDATE OPERATIONS
  // ==========================================================================

  /// Update receipt
  Future<bool> updateReceipt(Receipt receipt) {
    return update(receipts).replace(
      receipt.copyWith(updatedAt: DateTime.now()),
    );
  }

  // ==========================================================================
  // DELETE OPERATIONS
  // ==========================================================================

  /// Soft delete (set deleted_at timestamp)
  Future<int> softDeleteReceipt(int receiptId) {
    return (update(receipts)..where((r) => r.id.equals(receiptId)))
      .write(ReceiptsCompanion(deletedAt: Value(DateTime.now())));
  }

  /// Hard delete (permanently remove from database)
  /// Line items are cascade deleted automatically
  Future<int> deleteReceipt(int receiptId) {
    return (delete(receipts)..where((r) => r.id.equals(receiptId))).go();
  }

  /// Delete all receipts (for reset)
  Future<int> deleteAllReceipts() {
    return delete(receipts).go();
  }

  // ==========================================================================
  // STATISTICS
  // ==========================================================================

  /// Get total count of receipts
  Future<int> getTotalReceiptCount() async {
    final query = selectOnly(receipts)
      ..addColumns([receipts.id.count()])
      ..where(receipts.deletedAt.isNull());

    final result = await query.getSingle();
    return result.read(receipts.id.count()) ?? 0;
  }

  /// Get total amount spent across all receipts
  Future<double> getTotalSpent() async {
    final query = selectOnly(receipts)
      ..addColumns([receipts.totalAmount.sum()])
      ..where(receipts.deletedAt.isNull());

    final result = await query.getSingle();
    return result.read(receipts.totalAmount.sum()) ?? 0.0;
  }

  /// Get average receipt amount
  Future<double> getAverageAmount() async {
    final query = selectOnly(receipts)
      ..addColumns([receipts.totalAmount.avg()])
      ..where(receipts.deletedAt.isNull());

    final result = await query.getSingle();
    return result.read(receipts.totalAmount.avg()) ?? 0.0;
  }
}
```

---

### Step 2.3: VendorsDao (COMPLETE)

**File:** `lib/database/daos/vendors_dao.dart` (NEW FILE)

```dart
import 'package:drift/drift.dart';
import 'package:invoicer/database/database.dart';
import 'package:invoicer/database/tables.dart';

part 'vendors_dao.g.dart';

@DriftAccessor(tables: [Vendors, Receipts])
class VendorsDao extends DatabaseAccessor<AppDatabase>
    with _$VendorsDaoMixin {
  VendorsDao(AppDatabase db) : super(db);

  // ==========================================================================
  // VENDOR MANAGEMENT
  // ==========================================================================

  /// Find or create vendor by name
  /// Returns vendor ID, or null if vendorName is null/empty
  /// Normalizes vendor name (trims whitespace)
  /// Creates new vendor if not found
  Future<int?> findOrCreateVendor(String? vendorName) async {
    if (vendorName == null || vendorName.trim().isEmpty) {
      return null;
    }

    final normalized = vendorName.trim();

    // Try to find existing vendor
    final existing = await (select(vendors)
      ..where((v) =>
        v.name.equals(normalized) &
        v.deletedAt.isNull()))
      .getSingleOrNull();

    if (existing != null) {
      return existing.id;
    }

    // Create new vendor
    return into(vendors).insert(
      VendorsCompanion.insert(name: normalized),
    );
  }

  /// Get vendor by ID
  Future<Vendor?> getVendorById(int vendorId) {
    return (select(vendors)..where((v) => v.id.equals(vendorId)))
      .getSingleOrNull();
  }

  /// Get vendor by name
  Future<Vendor?> getVendorByName(String name) {
    return (select(vendors)..where((v) => v.name.equals(name)))
      .getSingleOrNull();
  }

  /// Get all vendors
  Future<List<Vendor>> getAllVendors() {
    return (select(vendors)
      ..where((v) => v.deletedAt.isNull())
      ..orderBy([(v) => OrderingTerm.asc(v.name)]))
      .get();
  }

  // ==========================================================================
  // STATISTICS
  // ==========================================================================

  /// Update vendor statistics based on receipts
  /// Should be called after inserting/updating/deleting receipts
  Future<void> updateVendorStats(int vendorId) async {
    // Get all receipts for this vendor
    final vendorReceipts = await (select(receipts)
      ..where((r) =>
        r.vendorId.equals(vendorId) &
        r.deletedAt.isNull()))
      .get();

    if (vendorReceipts.isEmpty) {
      // Reset stats to zero
      await (update(vendors)..where((v) => v.id.equals(vendorId)))
        .write(VendorsCompanion(
          totalInvoices: const Value(0),
          totalSpent: const Value(0.0),
          averageInvoiceAmount: const Value(null),
          firstInvoiceDate: const Value(null),
          lastInvoiceDate: const Value(null),
          updatedAt: Value(DateTime.now()),
        ));
      return;
    }

    // Calculate statistics
    final totalSpent = vendorReceipts
      .fold<double>(0.0, (sum, r) => sum + r.totalAmount);
    final count = vendorReceipts.length;
    final avgAmount = totalSpent / count;

    // Find date range
    final dates = vendorReceipts
      .map((r) => r.invoiceDate)
      .whereType<DateTime>()
      .toList();

    dates.sort((a, b) => a.compareTo(b));

    final firstDate = dates.isNotEmpty ? dates.first.toIso8601String() : null;
    final lastDate = dates.isNotEmpty ? dates.last.toIso8601String() : null;

    // Update vendor record
    await (update(vendors)..where((v) => v.id.equals(vendorId)))
      .write(VendorsCompanion(
        totalInvoices: Value(count),
        totalSpent: Value(totalSpent),
        averageInvoiceAmount: Value(avgAmount),
        firstInvoiceDate: Value(firstDate),
        lastInvoiceDate: Value(lastDate),
        updatedAt: Value(DateTime.now()),
      ));
  }

  /// Get top vendors by spend
  Future<List<Vendor>> getTopVendorsBySpend({int limit = 10}) {
    return (select(vendors)
      ..where((v) => v.deletedAt.isNull())
      ..orderBy([(v) => OrderingTerm.desc(v.totalSpent)])
      ..limit(limit))
      .get();
  }

  // ==========================================================================
  // DELETE OPERATIONS
  // ==========================================================================

  /// Soft delete vendor
  Future<int> softDeleteVendor(int vendorId) {
    return (update(vendors)..where((v) => v.id.equals(vendorId)))
      .write(VendorsCompanion(deletedAt: Value(DateTime.now())));
  }

  /// Delete all vendors (for reset)
  Future<int> deleteAllVendors() {
    return delete(vendors).go();
  }
}
```

---

### Step 2.4: FoldersDao (COMPLETE)

**File:** `lib/database/daos/folders_dao.dart` (NEW FILE)

```dart
import 'package:drift/drift.dart';
import 'package:invoicer/database/database.dart';
import 'package:invoicer/database/tables.dart';

part 'folders_dao.g.dart';

@DriftAccessor(tables: [Folders, Receipts])
class FoldersDao extends DatabaseAccessor<AppDatabase>
    with _$FoldersDaoMixin {
  FoldersDao(AppDatabase db) : super(db);

  // ==========================================================================
  // FOLDER MANAGEMENT
  // ==========================================================================

  /// Insert folder
  Future<int> insertFolder(FoldersCompanion folder) {
    return into(folders).insert(folder);
  }

  /// Get all folders
  Future<List<Folder>> getAllFolders() {
    return (select(folders)
      ..where((f) => f.deletedAt.isNull())
      ..orderBy([(f) => OrderingTerm.desc(f.addedAt)]))
      .get();
  }

  /// Watch all folders (reactive stream for signals)
  Stream<List<Folder>> watchAllFolders() {
    return (select(folders)
      ..where((f) => f.deletedAt.isNull())
      ..orderBy([(f) => OrderingTerm.desc(f.addedAt)]))
      .watch();
  }

  /// Get folder by path
  Future<Folder?> getFolderByPath(String path) {
    return (select(folders)..where((f) => f.path.equals(path)))
      .getSingleOrNull();
  }

  /// Get folder by ID
  Future<Folder?> getFolderById(int id) {
    return (select(folders)..where((f) => f.id.equals(id)))
      .getSingleOrNull();
  }

  // ==========================================================================
  // STATISTICS
  // ==========================================================================

  /// Update folder statistics based on receipts
  /// Should be called after processing files
  Future<void> updateFolderStats(int folderId) async {
    // Count total receipts in this folder
    final totalReceipts = await (selectOnly(receipts)
      ..addColumns([receipts.id.count()])
      ..where(receipts.sourceFolderId.equals(folderId) &
              receipts.deletedAt.isNull()))
      .getSingle()
      .then((row) => row.read(receipts.id.count()) ?? 0);

    // Count processed receipts (have vendor data)
    final processedCount = await (selectOnly(receipts)
      ..addColumns([receipts.id.count()])
      ..where(receipts.sourceFolderId.equals(folderId) &
              receipts.processedAt.isNotNull() &
              receipts.deletedAt.isNull()))
      .getSingle()
      .then((row) => row.read(receipts.id.count()) ?? 0);

    // Sum total value
    final totalValue = await (selectOnly(receipts)
      ..addColumns([receipts.totalAmount.sum()])
      ..where(receipts.sourceFolderId.equals(folderId) &
              receipts.deletedAt.isNull()))
      .getSingle()
      .then((row) => row.read(receipts.totalAmount.sum()) ?? 0.0);

    // Update folder
    await (update(folders)..where((f) => f.id.equals(folderId)))
      .write(FoldersCompanion(
        processedCount: Value(processedCount),
        totalValue: Value(totalValue),
        lastScannedAt: Value(DateTime.now()),
        updatedAt: Value(DateTime.now()),
      ));
  }

  /// Update folder file count
  Future<void> updateFolderFileCount(int folderId, int count) {
    return (update(folders)..where((f) => f.id.equals(folderId)))
      .write(FoldersCompanion(
        fileCount: Value(count),
        updatedAt: Value(DateTime.now()),
      ));
  }

  // ==========================================================================
  // UPDATE OPERATIONS
  // ==========================================================================

  /// Update folder
  Future<bool> updateFolder(Folder folder) {
    return update(folders).replace(
      folder.copyWith(updatedAt: DateTime.now()),
    );
  }

  // ==========================================================================
  // DELETE OPERATIONS
  // ==========================================================================

  /// Soft delete folder (set deleted_at)
  Future<int> softDeleteFolder(int folderId) {
    return (update(folders)..where((f) => f.id.equals(folderId)))
      .write(FoldersCompanion(deletedAt: Value(DateTime.now())));
  }

  /// Soft delete folder by path
  Future<int> softDeleteFolderByPath(String path) {
    return (update(folders)..where((f) => f.path.equals(path)))
      .write(FoldersCompanion(deletedAt: Value(DateTime.now())));
  }

  /// Hard delete folder
  Future<int> deleteFolder(int folderId) {
    return (delete(folders)..where((f) => f.id.equals(folderId))).go();
  }

  /// Delete all folders (for reset)
  Future<int> deleteAllFolders() {
    return delete(folders).go();
  }
}
```

---

### Step 2.5: SettingsDao (COMPLETE)

**File:** `lib/database/daos/settings_dao.dart` (NEW FILE)

```dart
import 'dart:convert';
import 'package:drift/drift.dart';
import 'package:invoicer/database/database.dart';
import 'package:invoicer/database/tables.dart';

part 'settings_dao.g.dart';

@DriftAccessor(tables: [Settings])
class SettingsDao extends DatabaseAccessor<AppDatabase>
    with _$SettingsDaoMixin {
  SettingsDao(AppDatabase db) : super(db);

  // ==========================================================================
  // STRING OPERATIONS
  // ==========================================================================

  Future<String?> getString(String key) async {
    final result = await (select(settings)
      ..where((s) => s.key.equals(key)))
      .getSingleOrNull();
    return result?.value;
  }

  Future<void> setString(String key, String value, {String? category}) {
    return into(settings).insertOnConflictUpdate(
      SettingsCompanion.insert(
        key: key,
        value: value,
        valueType: 'string',
        category: Value(category),
        updatedAt: Value(DateTime.now()),
      ),
    );
  }

  Stream<String?> watchString(String key) {
    return (select(settings)..where((s) => s.key.equals(key)))
      .watchSingleOrNull()
      .map((setting) => setting?.value);
  }

  // ==========================================================================
  // INTEGER OPERATIONS
  // ==========================================================================

  Future<int?> getInt(String key) async {
    final value = await getString(key);
    return value != null ? int.tryParse(value) : null;
  }

  Future<void> setInt(String key, int value, {String? category}) {
    return into(settings).insertOnConflictUpdate(
      SettingsCompanion.insert(
        key: key,
        value: value.toString(),
        valueType: 'int',
        category: Value(category),
        updatedAt: Value(DateTime.now()),
      ),
    );
  }

  Stream<int?> watchInt(String key) {
    return watchString(key).map((v) => v != null ? int.tryParse(v) : null);
  }

  // ==========================================================================
  // BOOLEAN OPERATIONS
  // ==========================================================================

  Future<bool> getBool(String key, {bool defaultValue = false}) async {
    final value = await getString(key);
    if (value == null) return defaultValue;
    return value.toLowerCase() == 'true';
  }

  Future<void> setBool(String key, bool value, {String? category}) {
    return into(settings).insertOnConflictUpdate(
      SettingsCompanion.insert(
        key: key,
        value: value.toString(),
        valueType: 'bool',
        category: Value(category),
        updatedAt: Value(DateTime.now()),
      ),
    );
  }

  Stream<bool> watchBool(String key, {bool defaultValue = false}) {
    return watchString(key).map((v) {
      if (v == null) return defaultValue;
      return v.toLowerCase() == 'true';
    });
  }

  // ==========================================================================
  // DOUBLE OPERATIONS
  // ==========================================================================

  Future<double?> getDouble(String key) async {
    final value = await getString(key);
    return value != null ? double.tryParse(value) : null;
  }

  Future<void> setDouble(String key, double value, {String? category}) {
    return into(settings).insertOnConflictUpdate(
      SettingsCompanion.insert(
        key: key,
        value: value.toString(),
        valueType: 'double',
        category: Value(category),
        updatedAt: Value(DateTime.now()),
      ),
    );
  }

  // ==========================================================================
  // JSON OPERATIONS
  // ==========================================================================

  Future<Map<String, dynamic>?> getJson(String key) async {
    final value = await getString(key);
    if (value == null) return null;

    try {
      return jsonDecode(value) as Map<String, dynamic>;
    } catch (e) {
      return null;
    }
  }

  Future<void> setJson(
    String key,
    Map<String, dynamic> value, {
    String? category,
  }) {
    return into(settings).insertOnConflictUpdate(
      SettingsCompanion.insert(
        key: key,
        value: jsonEncode(value),
        valueType: 'json',
        category: Value(category),
        updatedAt: Value(DateTime.now()),
      ),
    );
  }

  // ==========================================================================
  // GENERIC OPERATIONS
  // ==========================================================================

  Future<Setting?> getSetting(String key) {
    return (select(settings)..where((s) => s.key.equals(key)))
      .getSingleOrNull();
  }

  Future<List<Setting>> getSettingsByCategory(String category) {
    return (select(settings)..where((s) => s.category.equals(category)))
      .get();
  }

  Future<List<Setting>> getAllSettings() {
    return select(settings).get();
  }

  Future<int> deleteSetting(String key) {
    return (delete(settings)..where((s) => s.key.equals(key))).go();
  }

  Future<int> deleteSettingsByCategory(String category) {
    return (delete(settings)..where((s) => s.category.equals(category)))
      .go();
  }

  /// Delete all settings except specified keys
  /// Useful for reset while preserving API key, etc.
  Future<int> deleteAllExcept(List<String> keysToKeep) {
    return (delete(settings)..where((s) => s.key.isNotIn(keysToKeep))).go();
  }

  /// Delete all settings (for complete reset)
  Future<int> deleteAllSettings() {
    return delete(settings).go();
  }
}
```

---

### Step 2.6: LogsDao (COMPLETE)

**File:** `lib/database/daos/logs_dao.dart` (NEW FILE)

```dart
import 'package:drift/drift.dart';
import 'package:invoicer/database/database.dart';
import 'package:invoicer/database/tables.dart';

part 'logs_dao.g.dart';

@DriftAccessor(tables: [LogEntries])
class LogsDao extends DatabaseAccessor<AppDatabase>
    with _$LogsDaoMixin {
  LogsDao(AppDatabase db) : super(db);

  // ==========================================================================
  // INSERT OPERATIONS
  // ==========================================================================

  /// Insert log entry
  Future<int> insertLog(LogEntriesCompanion log) {
    return into(logEntries).insert(log);
  }

  /// Quick log helper
  Future<int> log(
    String level,
    String component,
    String message, {
    String? functionName,
    String? errorType,
    String? errorMessage,
    String? stackTrace,
    int? receiptId,
    int? vendorId,
    int? durationMs,
    String? sessionId,
  }) {
    return insertLog(
      LogEntriesCompanion.insert(
        level: level,
        component: component,
        message: message,
        functionName: Value(functionName),
        errorType: Value(errorType),
        errorMessage: Value(errorMessage),
        stackTrace: Value(stackTrace),
        receiptId: Value(receiptId),
        vendorId: Value(vendorId),
        durationMs: Value(durationMs),
        sessionId: Value(sessionId),
      ),
    );
  }

  // ==========================================================================
  // QUERY OPERATIONS
  // ==========================================================================

  /// Get recent logs
  Future<List<LogEntry>> getRecentLogs({int limit = 100}) {
    return (select(logEntries)
      ..orderBy([(log) => OrderingTerm.desc(log.timestamp)])
      ..limit(limit))
      .get();
  }

  /// Watch recent logs (reactive stream)
  Stream<List<LogEntry>> watchRecentLogs({int limit = 100}) {
    return (select(logEntries)
      ..orderBy([(log) => OrderingTerm.desc(log.timestamp)])
      ..limit(limit))
      .watch();
  }

  /// Get logs by level
  Future<List<LogEntry>> getLogsByLevel(String level, {int limit = 100}) {
    return (select(logEntries)
      ..where((log) => log.level.equals(level))
      ..orderBy([(log) => OrderingTerm.desc(log.timestamp)])
      ..limit(limit))
      .get();
  }

  /// Watch logs by level
  Stream<List<LogEntry>> watchLogsByLevel(String level) {
    return (select(logEntries)
      ..where((log) => log.level.equals(level))
      ..orderBy([(log) => OrderingTerm.desc(log.timestamp)]))
      .watch();
  }

  /// Get logs by component
  Future<List<LogEntry>> getLogsByComponent(
    String component, {
    int limit = 100,
  }) {
    return (select(logEntries)
      ..where((log) => log.component.equals(component))
      ..orderBy([(log) => OrderingTerm.desc(log.timestamp)])
      ..limit(limit))
      .get();
  }

  /// Get error logs
  Future<List<LogEntry>> getErrorLogs({int limit = 100}) {
    return (select(logEntries)
      ..where((log) => log.level.equals('ERROR'))
      ..orderBy([(log) => OrderingTerm.desc(log.timestamp)])
      ..limit(limit))
      .get();
  }

  /// Search logs by message
  Future<List<LogEntry>> searchLogs(String query, {int limit = 100}) {
    return (select(logEntries)
      ..where((log) => log.message.like('%$query%'))
      ..orderBy([(log) => OrderingTerm.desc(log.timestamp)])
      ..limit(limit))
      .get();
  }

  /// Get logs for a specific receipt
  Future<List<LogEntry>> getLogsForReceipt(int receiptId) {
    return (select(logEntries)
      ..where((log) => log.receiptId.equals(receiptId))
      ..orderBy([(log) => OrderingTerm.desc(log.timestamp)]))
      .get();
  }

  // ==========================================================================
  // DELETE OPERATIONS
  // ==========================================================================

  /// Delete logs older than cutoff date
  Future<int> deleteLogsOlderThan(DateTime cutoff) {
    return (delete(logEntries)
      ..where((log) => log.timestamp.isSmallerThanValue(cutoff)))
      .go();
  }

  /// Cleanup old logs (default: keep last 30 days)
  Future<int> cleanupOldLogs({int daysToKeep = 30}) {
    final cutoffDate = DateTime.now().subtract(Duration(days: daysToKeep));
    return deleteLogsOlderThan(cutoffDate);
  }

  /// Delete all logs (for reset)
  Future<int> deleteAllLogs() {
    return delete(logEntries).go();
  }

  // ==========================================================================
  // STATISTICS
  // ==========================================================================

  /// Get log counts by level
  Future<Map<String, int>> getLogCountsByLevel() async {
    final levels = ['DEBUG', 'INFO', 'WARN', 'ERROR'];
    final counts = <String, int>{};

    for (var level in levels) {
      final count = await (selectOnly(logEntries)
        ..addColumns([logEntries.id.count()])
        ..where(logEntries.level.equals(level)))
        .getSingle()
        .then((row) => row.read(logEntries.id.count()) ?? 0);

      counts[level] = count;
    }

    return counts;
  }

  /// Get total log count
  Future<int> getTotalLogCount() async {
    final query = selectOnly(logEntries)
      ..addColumns([logEntries.id.count()]);

    final result = await query.getSingle();
    return result.read(logEntries.id.count()) ?? 0;
  }
}
```

---

### Step 2.7: Update Database Class with DAOs

**File:** `lib/database/database.dart`

**Find lines 7-12 (commented DAO imports):**
```dart
// DAO imports will be added in Phase 2
// import 'package:invoicer/database/daos/documents_dao.dart';
// import 'package:invoicer/database/daos/vendors_dao.dart';
// import 'package:invoicer/database/daos/folders_dao.dart';
// import 'package:invoicer/database/daos/settings_dao.dart';
// import 'package:invoicer/database/daos/logs_dao.dart';
```

**Replace with:**
```dart
// DAO imports
import 'package:invoicer/database/daos/documents_dao.dart';
import 'package:invoicer/database/daos/vendors_dao.dart';
import 'package:invoicer/database/daos/folders_dao.dart';
import 'package:invoicer/database/daos/settings_dao.dart';
import 'package:invoicer/database/daos/logs_dao.dart';
```

**Find line 14 (part statement):**
```dart
part 'database.g.dart';
```

**Add after it:**
```dart
part 'database.g.dart';
part 'daos/documents_dao.g.dart';
part 'daos/vendors_dao.g.dart';
part 'daos/folders_dao.g.dart';
part 'daos/settings_dao.g.dart';
part 'daos/logs_dao.g.dart';
```

**Find lines 16-22 (@DriftDatabase):**
```dart
@DriftDatabase(
  tables: [
    Vendors,
    Receipts,
    LineItems,
    Folders,
    Settings,
    LogEntries,
  ],
  // DAOs will be added in Phase 2:
  // daos: [DocumentsDao, VendorsDao, FoldersDao, SettingsDao, LogsDao],
)
```

**Replace with:**
```dart
@DriftDatabase(
  tables: [
    Vendors,
    Receipts,
    LineItems,
    Folders,
    Settings,
    LogEntries,
  ],
  daos: [
    DocumentsDao,
    VendorsDao,
    FoldersDao,
    SettingsDao,
    LogsDao,
  ],
)
```

---

### Step 2.8: Regenerate Code

**Command:**
```bash
dart run build_runner build --delete-conflicting-outputs
```

**Verify all DAO files generated:**
```bash
for dao in documents vendors folders settings logs; do
  test -f lib/database/daos/${dao}_dao.g.dart && echo "✓ ${dao}_dao.g.dart" || echo "✗ FAILED: ${dao}_dao"
done
```

**Expected output:**
```
✓ documents_dao.g.dart
✓ vendors_dao.g.dart
✓ folders_dao.g.dart
✓ settings_dao.g.dart
✓ logs_dao.g.dart
```

**If build fails:**
```bash
dart run build_runner clean
rm -f lib/database/**/*.g.dart
dart run build_runner build --delete-conflicting-outputs
```

**Success Criteria:**
- ✅ All 5 DAO .g.dart files created
- ✅ No build errors
- ✅ database.g.dart updated with DAO accessors

**Checkpoint:** Database and DAOs are complete and ready for integration

---

## Phase 3: Integrate AppState (8-12 hours)

This is the most complex phase. We'll replace JSON file operations with database calls.

### Step 3.1: Add Database to AppState

**File:** `lib/state.dart`

**Find line 1-16 (imports section):**
```dart
// State Management
import 'dart:convert';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:invoicer/dialogs/file_detail_dialog.dart';
import 'package:invoicer/extractor.dart';
import 'package:invoicer/logger.dart';
import 'package:invoicer/models.dart';
import 'package:invoicer/services/filename_template_service.dart';
import 'package:macos_ui/macos_ui.dart';
import 'package:path/path.dart' as path;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:signals/signals.dart';
```

**Add after `import 'package:invoicer/models.dart';`:**
```dart
import 'package:invoicer/models.dart';
import 'package:invoicer/database/database.dart';
import 'package:invoicer/database/tables.dart' as db_tables;
```

**Find line 20-25 (AppState class definition):**
```dart
class AppState {
  static final AppState _instance = AppState._internal();

  factory AppState() => _instance;

  AppState._internal();
```

**Replace with:**
```dart
class AppState {
  static final AppState _instance = AppState._internal();

  factory AppState() => _instance;

  AppState._internal() {
    _db = AppDatabase.instance;
  }

  // Database instance
  late final AppDatabase _db;
```

---

### Step 3.2: Replace loadSettings() Method

**File:** `lib/state.dart`

**Find lines 49-118 (entire loadSettings method):**
```dart
Future<void> loadSettings() async {
  final prefs = await SharedPreferences.getInstance();
  // ... rest of current implementation ...
}
```

**Replace entire method with:**
```dart
Future<void> loadSettings() async {
  try {
    // Load from database first
    apiKey.value = await _db.settingsDao.getString('openai_api_key') ?? '';
    aiModel.value = await _db.settingsDao.getString('openai_model') ?? 'gpt-4.1-mini';
    filenameTemplate.value = await _db.settingsDao.getString('filename_template') ??
        '[YEAR]-[MONTH]-[DAY] - [VENDOR].pdf';
    autoRenameDropped.value = await _db.settingsDao.getBool('auto_rename_dropped');
    currentView.value = await _db.settingsDao.getString('current_view') ?? 'overview';

    // Fall back to .env if API key not in database
    if (apiKey.value.isEmpty) {
      apiKey.value = dotenv.maybeGet('OPENAI_API_KEY') ?? '';
      if (apiKey.value.isNotEmpty) {
        // Save to database for next time
        await _db.settingsDao.setString('openai_api_key', apiKey.value, category: 'api');
      }
    }

    // Fall back to .env for model if default
    if (aiModel.value == 'gpt-4.1-mini') {
      final envModel = dotenv.maybeGet('OPENAI_MODEL');
      if (envModel != null && envModel.isNotEmpty) {
        aiModel.value = envModel;
        await _db.settingsDao.setString('openai_model', envModel, category: 'api');
      }
    }

    // Load folders from database
    final dbFolders = await _db.foldersDao.getAllFolders();
    projectFolders.clear();
    for (var folder in dbFolders) {
      projectFolders.add(ProjectFolder(
        path: folder.path,
        name: folder.name,
        addedAt: folder.addedAt,
        fileCount: folder.fileCount,
      ));
    }

    // Load currently selected folder
    final currentFolderPath = await _db.settingsDao.getString('currently_selected_folder');
    if (currentFolderPath != null) {
      try {
        currentlySelectedFolder.value = projectFolders.firstWhere(
          (folder) => folder.path == currentFolderPath,
        );

        // Load receipts for selected folder
        await _loadReceiptsForCurrentFolder();
      } catch (e) {
        currentlySelectedFolder.value = null;
      }
    }

    // Load individual files
    await _loadIndividualReceipts();

    _logger.info('Settings and data loaded from database');
  } catch (e, stack) {
    _logger.error('Error loading settings', error: e, stackTrace: stack);
  }
}
```

---

### Step 3.3: Add Database Loading Helper Methods

**File:** `lib/state.dart`

**Add after loadSettings() method (around line 103):**
```dart
/// Load receipts for the currently selected folder
Future<void> _loadReceiptsForCurrentFolder() async {
  if (currentlySelectedFolder.value == null) {
    pdfFiles.clear();
    return;
  }

  try {
    final dbReceipts = await _db.documentsDao.getReceiptsByFolderPath(
      currentlySelectedFolder.value!.path,
    );

    pdfFiles.clear();
    for (var receipt in dbReceipts) {
      final lineItems = await _db.documentsDao.getLineItemsForReceipt(receipt.id);
      final vendor = receipt.vendorId != null
          ? await _db.vendorsDao.getVendorById(receipt.vendorId!)
          : null;

      pdfFiles.add(_convertReceiptToPdfDocument(receipt, lineItems, vendor));
    }
  } catch (e, stack) {
    _logger.error('Failed to load receipts for folder', error: e, stackTrace: stack);
  }
}

/// Load individual receipts (not from folders)
Future<void> _loadIndividualReceipts() async {
  try {
    final dbReceipts = await _db.documentsDao.getIndividualReceipts();

    individualFiles.clear();
    for (var receipt in dbReceipts) {
      final lineItems = await _db.documentsDao.getLineItemsForReceipt(receipt.id);
      final vendor = receipt.vendorId != null
          ? await _db.vendorsDao.getVendorById(receipt.vendorId!)
          : null;

      individualFiles.add(_convertReceiptToPdfDocument(receipt, lineItems, vendor));
    }
  } catch (e, stack) {
    _logger.error('Failed to load individual receipts', error: e, stackTrace: stack);
  }
}

/// Convert database Receipt to PdfDocument model
PdfDocument _convertReceiptToPdfDocument(
  db_tables.Receipt receipt,
  List<db_tables.LineItem> lineItems,
  db_tables.Vendor? vendor,
) {
  return PdfDocument(
    name: receipt.fileName,
    path: receipt.filePath,
    source: receipt.sourceType,
    folderPath: receipt.sourceFolderId != null
        ? currentlySelectedFolder.value?.path
        : null,
    vendor: vendor?.name,
    vendorEmail: vendor?.email,
    vendorWebsite: vendor?.website,
    vendorDisplayAddress: vendor?.addressLine1,
    invoiceDate: receipt.invoiceDate,
    dueDate: receipt.dueDate,
    currency: receipt.currency,
    taxAmount: receipt.taxAmount,
    totalAmount: receipt.totalAmount,
    discountAmount: receipt.discountAmount,
    paymentMethod: receipt.paymentMethod,
    lastFourDigits: receipt.paymentCardLast4,
    items: lineItems.map((item) => ReceiptItem(
      sku: item.sku,
      text: item.description,
      unitPrice: item.unitPrice,
      quantity: item.quantity.toInt(),
    )).toList(),
    error: receipt.lastError,
    isProcessing: false,
  );
}
```

---

### Step 3.4: Replace saveSettings() Method

**File:** `lib/state.dart`

**Find lines 120-158 (entire saveSettings method):**
```dart
Future<void> saveSettings() async {
  final prefs = await SharedPreferences.getInstance();
  // ... rest of current implementation ...
}
```

**Replace entire method with:**
```dart
Future<void> saveSettings() async {
  try {
    await _db.settingsDao.setString('openai_api_key', apiKey.value, category: 'api');
    await _db.settingsDao.setString('openai_model', aiModel.value, category: 'api');
    await _db.settingsDao.setString('filename_template', filenameTemplate.value, category: 'ui');
    await _db.settingsDao.setBool('auto_rename_dropped', autoRenameDropped.value, category: 'ui');
    await _db.settingsDao.setString('current_view', currentView.value, category: 'ui');

    if (currentlySelectedFolder.value != null) {
      await _db.settingsDao.setString(
        'currently_selected_folder',
        currentlySelectedFolder.value!.path,
        category: 'ui',
      );
    } else {
      await _db.settingsDao.deleteSetting('currently_selected_folder');
    }

    _logger.info('Settings saved to database');
  } catch (e, stack) {
    _logger.error('Error saving settings', error: e, stackTrace: stack);
  }
}
```

---

### Step 3.5: Update processFile() Method

**File:** `lib/state.dart`

**Find lines 281-361 (processFile method):**
```dart
Future<void> processFile(PdfDocument file) async {
  _logger.info('Processing ${file.name}');

  // Find the file in the appropriate list
  int folderIndex = pdfFiles.indexOf(file);
  int individualIndex = individualFiles.indexOf(file);

  if ((folderIndex == -1 && individualIndex == -1) || file.isProcessing) {
    debugPrint('Warning: File not found or already processing: ${file.name}');
    return;
  }

  // Update processing state in the correct list
  if (folderIndex != -1) {
    pdfFiles[folderIndex] = file.copyWith(isProcessing: true, error: null);
  } else {
    individualFiles[individualIndex] = file.copyWith(
      isProcessing: true,
      error: null,
    );
  }

  try {
    // Extract text from PDF
    final textContent = await Extractor.extractTextFromPDF(file.path);

    if (textContent.trim().isEmpty) {
      debugPrint('Error: No text found in PDF: ${file.name}');
      throw Exception('No text found in PDF');
    }

    // Analyze with OpenAI
    final result = await Extractor.extractReceiptData(
      textContent,
      apiKey.value,
      model: aiModel.value,
    );

    final updatedFile = file.copyWith(
      items: (result['items'] as List<dynamic>?)
              ?.map((item) => ReceiptItem.fromJson(item))
              .toList() ??
          [],
      vendor: result['vendor'],
      invoiceDate: DateTime.tryParse(result['invoice_date'] ?? ""),
      dueDate: DateTime.tryParse(result['due_date'] ?? ""),
      currency: result['currency'],
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

    // Update the correct list
    if (folderIndex != -1) {
      pdfFiles[folderIndex] = updatedFile;
    } else {
      individualFiles[individualIndex] = updatedFile;
    }

    _logger.info('Completed: ${file.name} (${updatedFile.vendor}, \$${updatedFile.totalAmount}, ${updatedFile.items.length} items)');

    // Save extracted data to persistent storage
    await saveExtractedData();
  } catch (e, stackTrace) {
    _logger.error('Processing failed: ${file.name}', error: e, stackTrace: stackTrace);
    final errorFile = file.copyWith(error: e.toString(), isProcessing: false);

    // Update the correct list
    if (folderIndex != -1) {
      pdfFiles[folderIndex] = errorFile;
    } else {
      individualFiles[individualIndex] = errorFile;
    }
  }
}
```

**Replace with:**
```dart
Future<void> processFile(PdfDocument file) async {
  _logger.info('Processing ${file.name}');

  // Find the file in the appropriate list
  int folderIndex = pdfFiles.indexOf(file);
  int individualIndex = individualFiles.indexOf(file);

  if ((folderIndex == -1 && individualIndex == -1) || file.isProcessing) {
    debugPrint('Warning: File not found or already processing: ${file.name}');
    return;
  }

  // Update processing state in the correct list
  if (folderIndex != -1) {
    pdfFiles[folderIndex] = file.copyWith(isProcessing: true, error: null);
  } else {
    individualFiles[individualIndex] = file.copyWith(
      isProcessing: true,
      error: null,
    );
  }

  final startTime = DateTime.now();

  try {
    // Extract text from PDF (CRITICAL: Save this for reprocessing!)
    final textContent = await Extractor.extractTextFromPDF(file.path);

    if (textContent.trim().isEmpty) {
      debugPrint('Error: No text found in PDF: ${file.name}');
      throw Exception('No text found in PDF');
    }

    // Analyze with OpenAI
    final result = await Extractor.extractReceiptData(
      textContent,
      apiKey.value,
      model: aiModel.value,
    );

    final processingDuration = DateTime.now().difference(startTime);

    final updatedFile = file.copyWith(
      items: (result['items'] as List<dynamic>?)
              ?.map((item) => ReceiptItem.fromJson(item))
              .toList() ??
          [],
      vendor: result['vendor'],
      invoiceDate: DateTime.tryParse(result['invoice_date'] ?? ""),
      dueDate: DateTime.tryParse(result['due_date'] ?? ""),
      currency: result['currency'],
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

    // CRITICAL: Save to database with OCR text!
    await _saveReceiptToDatabase(
      updatedFile,
      textContent,  // OCR text
      processingDuration,
    );

    // Update signal (after successful DB save)
    if (folderIndex != -1) {
      pdfFiles[folderIndex] = updatedFile;
    } else {
      individualFiles[individualIndex] = updatedFile;
    }

    _logger.info('Completed: ${file.name} (${updatedFile.vendor}, \$${updatedFile.totalAmount}, ${updatedFile.items.length} items)');
  } catch (e, stackTrace) {
    _logger.error('Processing failed: ${file.name}', error: e, stackTrace: stackTrace);
    final errorFile = file.copyWith(error: e.toString(), isProcessing: false);

    // Update the correct list
    if (folderIndex != -1) {
      pdfFiles[folderIndex] = errorFile;
    } else {
      individualFiles[individualIndex] = errorFile;
    }
  }
}
```

---

### Step 3.6: Add _saveReceiptToDatabase() Method

**File:** `lib/state.dart`

**Add after processFile() method (around line 365):**
```dart
/// Save receipt to database
/// CRITICAL: Stores OCR text for future reprocessing
Future<void> _saveReceiptToDatabase(
  PdfDocument doc,
  String ocrText,
  Duration processingDuration,
) async {
  try {
    await _db.transaction(() async {
      // 1. Find or create vendor
      final vendorId = await _db.vendorsDao.findOrCreateVendor(doc.vendor);

      // 2. Get folder ID if applicable
      int? folderId;
      if (doc.source == 'folder' && doc.folderPath != null) {
        final folder = await _db.foldersDao.getFolderByPath(doc.folderPath!);
        folderId = folder?.id;
      }

      // 3. Prepare receipt companion
      final receiptCompanion = db_tables.ReceiptsCompanion.insert(
        fileName: doc.name,
        filePath: doc.path,
        sourceType: doc.source,
        sourceFolderId: Value(folderId),
        vendorId: Value(vendorId),
        invoiceDate: Value(doc.invoiceDate),
        dueDate: Value(doc.dueDate),
        currency: Value(doc.currency ?? 'USD'),
        taxAmount: Value(doc.taxAmount),
        discountAmount: Value(doc.discountAmount),
        totalAmount: doc.totalAmount ?? 0.0,
        paymentMethod: Value(doc.paymentMethod),
        paymentCardLast4: Value(doc.lastFourDigits),
        ocrText: ocrText,  // CRITICAL: Save OCR text!
        ocrMethod: const Value('syncfusion'),
        aiModelUsed: Value(aiModel.value),
        aiExtractionVersion: const Value(1),
        processedAt: Value(DateTime.now()),
        processingDurationMs: Value(processingDuration.inMilliseconds),
      );

      // 4. Prepare line items
      final lineItemsCompanions = doc.items.map((item) {
        final lineTotal = item.unitPrice * item.quantity;
        return db_tables.LineItemsCompanion.insert(
          sku: Value(item.sku),
          description: item.text,
          quantity: Value(item.quantity.toDouble()),
          unitPrice: item.unitPrice,
          lineTotal: lineTotal,
        );
      }).toList();

      // 5. Insert or update receipt with line items
      await _db.documentsDao.upsertReceiptWithItems(
        receiptCompanion,
        lineItemsCompanions,
      );

      // 6. Update vendor statistics
      if (vendorId != null) {
        await _db.vendorsDao.updateVendorStats(vendorId);
      }

      // 7. Update folder statistics if applicable
      if (folderId != null) {
        await _db.foldersDao.updateFolderStats(folderId);
      }
    });

    _logger.info('Saved ${doc.name} to database');
  } catch (e, stack) {
    _logger.error('Failed to save receipt to database', error: e, stackTrace: stack);
    rethrow;
  }
}
```

---

### Step 3.7: Update Folder Methods

**File:** `lib/state.dart`

**Find addFolder method (around line 161-188):**
```dart
Future<void> addFolder(String folderPath) async {
  final directory = Directory(folderPath);
  if (!directory.existsSync()) {
    throw Exception('Folder does not exist');
  }

  final folderName = path.basename(folderPath);
  final newFolder = ProjectFolder(
    path: folderPath,
    name: folderName,
    addedAt: DateTime.now(),
  );

  // Check if folder already exists
  final existingIndex = projectFolders.indexWhere(
    (f) => f.path == folderPath,
  );
  if (existingIndex != -1) {
    return; // Folder already added
  }

  // Update file count
  final fileCount = _countPDFFiles(folderPath);
  newFolder.fileCount = fileCount;

  projectFolders.add(newFolder);
  await saveSettings();
}
```

**Replace with:**
```dart
Future<void> addFolder(String folderPath) async {
  final directory = Directory(folderPath);
  if (!directory.existsSync()) {
    throw Exception('Folder does not exist');
  }

  // Check if folder already exists in database
  final existing = await _db.foldersDao.getFolderByPath(folderPath);
  if (existing != null) {
    return; // Folder already added
  }

  final folderName = path.basename(folderPath);
  final fileCount = _countPDFFiles(folderPath);

  // Insert into database
  await _db.foldersDao.insertFolder(
    db_tables.FoldersCompanion.insert(
      path: folderPath,
      name: folderName,
      addedAt: DateTime.now(),
      fileCount: Value(fileCount),
    ),
  );

  // Add to in-memory list
  projectFolders.add(ProjectFolder(
    path: folderPath,
    name: folderName,
    addedAt: DateTime.now(),
    fileCount: fileCount,
  ));

  _logger.info('Added folder: $folderPath');
}
```

**Find removeFolder method (around line 190-200):**
```dart
Future<void> removeFolder(ProjectFolder folder) async {
  projectFolders.removeWhere((f) => f.path == folder.path);

  // If this was the currently selected folder, clear it
  if (currentlySelectedFolder.value?.path == folder.path) {
    currentlySelectedFolder.value = null;
    pdfFiles.clear();
  }

  await saveSettings();
}
```

**Replace with:**
```dart
Future<void> removeFolder(ProjectFolder folder) async {
  // Soft delete in database
  await _db.foldersDao.softDeleteFolderByPath(folder.path);

  // Remove from in-memory list
  projectFolders.removeWhere((f) => f.path == folder.path);

  // If this was the currently selected folder, clear it
  if (currentlySelectedFolder.value?.path == folder.path) {
    currentlySelectedFolder.value = null;
    pdfFiles.clear();
  }

  _logger.info('Removed folder: ${folder.path}');
}
```

---

### Step 3.8: Delete Old JSON Methods

**File:** `lib/state.dart`

**Find and DELETE these methods entirely (lines 474-612):**

1. `_getDataFilePath()` (lines ~475-482)
2. `_ensureDataDirectoryExists()` (lines ~484-495)
3. `saveExtractedData()` (lines ~497-531)
4. `loadExtractedData()` (lines ~533-599)
5. `clearExtractedDataCache()` (lines ~601-612)

**These are replaced by database operations - no longer needed!**

---

### Step 3.9: Update resetAppData() Method

**File:** `lib/state.dart`

**Find resetAppData method (lines 840-874):**
```dart
Future<void> resetAppData() async {
  _logger.info('Resetting app data');

  // Clear in-memory state
  selectedFolder.value = null;
  projectFolders.clear();
  currentlySelectedFolder.value = null;
  pdfFiles.clear();
  individualFiles.clear();
  currentView.value = 'overview';
  autoRenameDropped.value = false;

  // Clear cached data file
  await clearExtractedDataCache();

  // Clear SharedPreferences (except settings)
  final prefs = await SharedPreferences.getInstance();

  // Remove folder and file data
  await prefs.remove('selected_folder');
  await prefs.remove('project_folders');
  await prefs.remove('individual_files');
  await prefs.remove('current_view');
  await prefs.remove('currently_selected_folder');
  await prefs.remove('auto_rename_dropped');

  // Keep these settings:
  // - openai_api_key
  // - openai_model
  // - filename_template

  _logger.info('App data reset complete');
}
```

**Replace with:**
```dart
Future<void> resetAppData() async {
  _logger.info('Resetting app data');

  try {
    // Clear in-memory state
    selectedFolder.value = null;
    projectFolders.clear();
    currentlySelectedFolder.value = null;
    pdfFiles.clear();
    individualFiles.clear();
    currentView.value = 'overview';
    autoRenameDropped.value = false;

    // Delete all data from database (keeps schema)
    await _db.deleteAllData();

    // Delete UI settings (but keep API key, model, filename template)
    await _db.settingsDao.deleteSetting('current_view');
    await _db.settingsDao.deleteSetting('currently_selected_folder');
    await _db.settingsDao.deleteSetting('auto_rename_dropped');

    // Preserve these settings:
    // - openai_api_key
    // - openai_model
    // - filename_template

    _logger.info('App data reset complete');
  } catch (e, stack) {
    _logger.error('Error resetting app data', error: e, stackTrace: stack);
    rethrow;
  }
}
```

---

**Checkpoint:** AppState now uses database instead of JSON files

**Verify:**
```bash
fvm flutter analyze lib/state.dart
```

**Expected:** No errors related to undefined methods

---

## Phase 4: Update Logger (2-4 hours)

### Step 4.1: Replace Logger Implementation

**File:** `lib/logger.dart`

**Replace ENTIRE FILE contents with:**

```dart
import 'package:flutter/foundation.dart';
import 'package:invoicer/database/database.dart';
import 'package:invoicer/database/tables.dart';

/// Minimal logger that writes to database and console
/// Replaces file-based logging with database logging
class AppLogger {
  final String component;
  late final AppDatabase _db;

  // ANSI color codes for console output
  static const Map<String, String> _levelColors = {
    'DEBUG': '\x1B[90m',  // Gray
    'INFO': '\x1B[32m',   // Green
    'WARN': '\x1B[33m',   // Yellow
    'ERROR': '\x1B[31m',  // Red
  };

  static const String _reset = '\x1B[0m';

  AppLogger(this.component) {
    _db = AppDatabase.instance;
  }

  /// Debug level log (gray in console)
  void debug(String message) {
    _log('DEBUG', message);
  }

  /// Info level log (green in console)
  void info(String message) {
    _log('INFO', message);
  }

  /// Warning level log (yellow in console)
  void warning(String message) {
    _log('WARN', message);
  }

  /// Error level log (red in console)
  void error(
    String message, {
    Object? error,
    StackTrace? stackTrace,
  }) {
    _log(
      'ERROR',
      message,
      error: error,
      stackTrace: stackTrace,
    );
  }

  /// Internal logging method
  void _log(
    String level,
    String message, {
    Object? error,
    StackTrace? stackTrace,
  }) {
    final timestamp = DateTime.now();

    // Format for console output
    final timeStr = _formatTime(timestamp);
    final color = _levelColors[level] ?? '';
    final paddedLevel = level.padRight(5);
    final consoleMessage = '$color[$timeStr] $paddedLevel [$component]$_reset $message';

    // Print to console
    debugPrint(consoleMessage);

    if (error != null) {
      debugPrint('$color  Error: $error$_reset');
    }

    if (stackTrace != null && level == 'ERROR') {
      debugPrint('$color  Stack trace:\n$stackTrace$_reset');
    }

    // Write to database (async, non-blocking)
    _writeToDatabase(
      timestamp: timestamp,
      level: level,
      message: message,
      error: error,
      stackTrace: stackTrace,
    ).catchError((e) {
      // Fallback: if DB write fails, already printed to console
      debugPrint('[Logger] Failed to write to database: $e');
    });
  }

  /// Write log entry to database (async, fire-and-forget)
  Future<void> _writeToDatabase({
    required DateTime timestamp,
    required String level,
    required String message,
    Object? error,
    StackTrace? stackTrace,
  }) async {
    try {
      await _db.logsDao.insertLog(
        LogEntriesCompanion.insert(
          timestamp: Value(timestamp),
          level: level,
          component: component,
          message: message,
          errorType: Value(error?.runtimeType.toString()),
          errorMessage: Value(error?.toString()),
          stackTrace: Value(stackTrace?.toString()),
        ),
      );
    } catch (e) {
      // Silently fail - don't disrupt app if logging fails
    }
  }

  /// Format timestamp for console output
  String _formatTime(DateTime time) {
    final hour = time.hour.toString().padLeft(2, '0');
    final minute = time.minute.toString().padLeft(2, '0');
    final second = time.second.toString().padLeft(2, '0');
    final millisecond = time.millisecond.toString().padLeft(3, '0');
    return '$hour:$minute:$second.$millisecond';
  }

  /// Cleanup old logs (call periodically or on app start)
  /// Default: keep last 30 days
  static Future<void> cleanupOldLogs({int daysToKeep = 30}) async {
    try {
      final db = AppDatabase.instance;
      final deleted = await db.logsDao.cleanupOldLogs(daysToKeep: daysToKeep);
      debugPrint('[Logger] Cleaned up $deleted old log entries (keeping last $daysToKeep days)');
    } catch (e) {
      debugPrint('[Logger] Failed to cleanup old logs: $e');
    }
  }
}
```

---

### Step 4.2: Add Log Cleanup to App Startup

**File:** `lib/main.dart`

**Find the main() function (around line 6-12):**
```dart
void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await dotenv.load(fileName: ".env");

  runApp(const InvoicerApp());
}
```

**Replace with:**
```dart
void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await dotenv.load(fileName: ".env");

  // Cleanup old logs (keep last 30 days)
  // Runs async, doesn't block app startup
  AppLogger.cleanupOldLogs(daysToKeep: 30);

  runApp(const InvoicerApp());
}
```

**Add import at top of file:**
```dart
import 'package:invoicer/logger.dart';
```

---

**Checkpoint:** Logger now writes to database instead of files

**Verify:**
```bash
fvm flutter analyze lib/logger.dart lib/main.dart
```

---

## Phase 5: Testing & Cleanup (4-6 hours)

### Step 5.1: Build and Analyze

**Command:**
```bash
fvm flutter pub get
dart run build_runner build --delete-conflicting-outputs
fvm flutter analyze
```

**Expected:** No errors

**If errors occur:**
```bash
# Clean and rebuild
fvm flutter clean
fvm flutter pub get
dart run build_runner clean
dart run build_runner build --delete-conflicting-outputs
```

---

### Step 5.2: Create Database Tests

**File:** `test/unit/database_test.dart` (NEW FILE)

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:invoicer/database/database.dart';
import 'package:invoicer/database/tables.dart';
import 'package:drift/drift.dart';

void main() {
  late AppDatabase db;

  setUp(() {
    // Use in-memory database for tests
    db = AppDatabase.test();
  });

  tearDown(() async {
    await db.close();
  });

  group('DocumentsDao Tests', () {
    test('inserts and retrieves receipt with line items', () async {
      // Insert receipt
      final receiptId = await db.documentsDao.insertReceiptWithItems(
        ReceiptsCompanion.insert(
          fileName: 'test.pdf',
          filePath: '/test/test.pdf',
          sourceType: 'individual',
          ocrText: 'Sample OCR text for testing',
          totalAmount: 100.0,
        ),
        [
          const LineItemsCompanion.insert(
            description: 'Test Item',
            quantity: Value(1.0),
            unitPrice: 50.0,
            lineTotal: 50.0,
          ),
          const LineItemsCompanion.insert(
            description: 'Test Item 2',
            quantity: Value(2.0),
            unitPrice: 25.0,
            lineTotal: 50.0,
          ),
        ],
      );

      expect(receiptId, greaterThan(0));

      // Retrieve receipt
      final receipt = await db.documentsDao.getReceiptById(receiptId);
      expect(receipt, isNotNull);
      expect(receipt!.fileName, equals('test.pdf'));
      expect(receipt.ocrText, equals('Sample OCR text for testing'));
      expect(receipt.totalAmount, equals(100.0));

      // Retrieve line items
      final lineItems = await db.documentsDao.getLineItemsForReceipt(receiptId);
      expect(lineItems.length, equals(2));
      expect(lineItems[0].description, equals('Test Item'));
      expect(lineItems[1].description, equals('Test Item 2'));
    });

    test('upsert updates existing receipt', () async {
      // Insert initial receipt
      await db.documentsDao.upsertReceiptWithItems(
        ReceiptsCompanion.insert(
          fileName: 'test.pdf',
          filePath: '/test/test.pdf',
          sourceType: 'individual',
          ocrText: 'Original text',
          totalAmount: 100.0,
        ),
        [],
      );

      // Update with same file path
      await db.documentsDao.upsertReceiptWithItems(
        ReceiptsCompanion.insert(
          fileName: 'test.pdf',
          filePath: '/test/test.pdf',
          sourceType: 'individual',
          ocrText: 'Updated text',
          totalAmount: 200.0,
        ),
        [
          const LineItemsCompanion.insert(
            description: 'New item',
            quantity: Value(1.0),
            unitPrice: 200.0,
            lineTotal: 200.0,
          ),
        ],
      );

      final receipt = await db.documentsDao.getReceiptByFilePath('/test/test.pdf');
      expect(receipt, isNotNull);
      expect(receipt!.totalAmount, equals(200.0));
      expect(receipt.ocrText, equals('Updated text'));

      final lineItems = await db.documentsDao.getLineItemsForReceipt(receipt.id);
      expect(lineItems.length, equals(1));
      expect(lineItems[0].description, equals('New item'));
    });

    test('cascade deletes line items when receipt deleted', () async {
      final receiptId = await db.documentsDao.insertReceiptWithItems(
        ReceiptsCompanion.insert(
          fileName: 'test.pdf',
          filePath: '/test/test.pdf',
          sourceType: 'individual',
          ocrText: 'Test',
          totalAmount: 100.0,
        ),
        [
          const LineItemsCompanion.insert(
            description: 'Item 1',
            quantity: Value(1.0),
            unitPrice: 50.0,
            lineTotal: 50.0,
          ),
        ],
      );

      // Delete receipt
      await db.documentsDao.deleteReceipt(receiptId);

      // Verify line items are also deleted
      final items = await db.documentsDao.getLineItemsForReceipt(receiptId);
      expect(items, isEmpty);
    });

    test('gets receipts by folder path', () async {
      // Create folder
      final folderId = await db.foldersDao.insertFolder(
        FoldersCompanion.insert(
          path: '/test/folder',
          name: 'Test Folder',
        ),
      );

      // Insert receipts
      await db.documentsDao.insertReceiptWithItems(
        ReceiptsCompanion.insert(
          fileName: 'r1.pdf',
          filePath: '/test/folder/r1.pdf',
          sourceType: 'folder',
          sourceFolderId: Value(folderId),
          ocrText: 'Test',
          totalAmount: 100.0,
        ),
        [],
      );

      await db.documentsDao.insertReceiptWithItems(
        ReceiptsCompanion.insert(
          fileName: 'r2.pdf',
          filePath: '/test/folder/r2.pdf',
          sourceType: 'folder',
          sourceFolderId: Value(folderId),
          ocrText: 'Test',
          totalAmount: 200.0,
        ),
        [],
      );

      // Query by folder path
      final receipts = await db.documentsDao.getReceiptsByFolderPath('/test/folder');
      expect(receipts.length, equals(2));
    });
  });

  group('VendorsDao Tests', () {
    test('finds or creates vendor (deduplication)', () async {
      final id1 = await db.vendorsDao.findOrCreateVendor('Acme Corp');
      expect(id1, isNotNull);

      final id2 = await db.vendorsDao.findOrCreateVendor('Acme Corp');
      expect(id2, equals(id1)); // Should return same ID

      final id3 = await db.vendorsDao.findOrCreateVendor('Other Corp');
      expect(id3, isNot(equals(id1))); // Different vendor

      final vendors = await db.vendorsDao.getAllVendors();
      expect(vendors.length, equals(2));
    });

    test('updates vendor statistics', () async {
      final vendorId = await db.vendorsDao.findOrCreateVendor('Test Vendor');

      // Insert receipts
      await db.documentsDao.insertReceiptWithItems(
        ReceiptsCompanion.insert(
          fileName: 'r1.pdf',
          filePath: '/r1.pdf',
          sourceType: 'individual',
          ocrText: 'Test',
          totalAmount: 100.0,
          vendorId: Value(vendorId),
          invoiceDate: Value(DateTime(2024, 1, 1)),
        ),
        [],
      );

      await db.documentsDao.insertReceiptWithItems(
        ReceiptsCompanion.insert(
          fileName: 'r2.pdf',
          filePath: '/r2.pdf',
          sourceType: 'individual',
          ocrText: 'Test',
          totalAmount: 200.0,
          vendorId: Value(vendorId),
          invoiceDate: Value(DateTime(2024, 2, 1)),
        ),
        [],
      );

      // Update stats
      await db.vendorsDao.updateVendorStats(vendorId!);

      final vendor = await db.vendorsDao.getVendorById(vendorId);
      expect(vendor!.totalInvoices, equals(2));
      expect(vendor.totalSpent, equals(300.0));
      expect(vendor.averageInvoiceAmount, equals(150.0));
      expect(vendor.firstInvoiceDate, isNotNull);
      expect(vendor.lastInvoiceDate, isNotNull);
    });
  });

  group('SettingsDao Tests', () {
    test('stores and retrieves string', () async {
      await db.settingsDao.setString('test_key', 'test_value');
      final value = await db.settingsDao.getString('test_key');
      expect(value, equals('test_value'));
    });

    test('stores and retrieves boolean', () async {
      await db.settingsDao.setBool('test_bool', true);
      final value = await db.settingsDao.getBool('test_bool');
      expect(value, isTrue);

      await db.settingsDao.setBool('test_bool', false);
      final value2 = await db.settingsDao.getBool('test_bool');
      expect(value2, isFalse);
    });

    test('stores and retrieves integer', () async {
      await db.settingsDao.setInt('test_int', 42);
      final value = await db.settingsDao.getInt('test_int');
      expect(value, equals(42));
    });

    test('deletes all except specified keys', () async {
      await db.settingsDao.setString('keep1', 'value1');
      await db.settingsDao.setString('keep2', 'value2');
      await db.settingsDao.setString('delete1', 'value3');
      await db.settingsDao.setString('delete2', 'value4');

      await db.settingsDao.deleteAllExcept(['keep1', 'keep2']);

      final keep1 = await db.settingsDao.getString('keep1');
      final keep2 = await db.settingsDao.getString('keep2');
      final delete1 = await db.settingsDao.getString('delete1');
      final delete2 = await db.settingsDao.getString('delete2');

      expect(keep1, equals('value1'));
      expect(keep2, equals('value2'));
      expect(delete1, isNull);
      expect(delete2, isNull);
    });
  });

  group('LogsDao Tests', () {
    test('inserts and retrieves logs', () async {
      await db.logsDao.log('INFO', 'TestComponent', 'Test message');

      final logs = await db.logsDao.getRecentLogs(limit: 10);
      expect(logs.length, equals(1));
      expect(logs.first.level, equals('INFO'));
      expect(logs.first.component, equals('TestComponent'));
      expect(logs.first.message, equals('Test message'));
    });

    test('filters logs by level', () async {
      await db.logsDao.log('INFO', 'Test', 'Info message');
      await db.logsDao.log('ERROR', 'Test', 'Error message');
      await db.logsDao.log('WARN', 'Test', 'Warning message');

      final errorLogs = await db.logsDao.getLogsByLevel('ERROR');
      expect(errorLogs.length, equals(1));
      expect(errorLogs.first.message, equals('Error message'));
    });

    test('deletes old logs', () async {
      // Insert old log
      await db.logsDao.insertLog(
        LogEntriesCompanion.insert(
          level: 'INFO',
          component: 'Test',
          message: 'Old log',
          timestamp: Value(DateTime.now().subtract(const Duration(days: 60))),
        ),
      );

      // Insert recent log
      await db.logsDao.log('INFO', 'Test', 'Recent log');

      // Cleanup logs older than 30 days
      await db.logsDao.cleanupOldLogs(daysToKeep: 30);

      final logs = await db.logsDao.getRecentLogs(limit: 100);
      expect(logs.length, equals(1));
      expect(logs.first.message, equals('Recent log'));
    });
  });

  group('FoldersDao Tests', () {
    test('inserts and retrieves folder', () async {
      final folderId = await db.foldersDao.insertFolder(
        FoldersCompanion.insert(
          path: '/test/folder',
          name: 'Test Folder',
        ),
      );

      final folder = await db.foldersDao.getFolderById(folderId);
      expect(folder, isNotNull);
      expect(folder!.path, equals('/test/folder'));
      expect(folder.name, equals('Test Folder'));
    });

    test('updates folder statistics', () async {
      final folderId = await db.foldersDao.insertFolder(
        FoldersCompanion.insert(
          path: '/test/folder',
          name: 'Test Folder',
        ),
      );

      // Add receipts to folder
      await db.documentsDao.insertReceiptWithItems(
        ReceiptsCompanion.insert(
          fileName: 'r1.pdf',
          filePath: '/test/folder/r1.pdf',
          sourceType: 'folder',
          sourceFolderId: Value(folderId),
          ocrText: 'Test',
          totalAmount: 100.0,
          processedAt: Value(DateTime.now()),
        ),
        [],
      );

      await db.foldersDao.updateFolderStats(folderId);

      final folder = await db.foldersDao.getFolderById(folderId);
      expect(folder!.processedCount, equals(1));
      expect(folder.totalValue, equals(100.0));
    });
  });

  group('Transaction Tests', () {
    test('transaction rolls back on error', () async {
      try {
        await db.transaction(() async {
          await db.settingsDao.setString('test', 'value');
          throw Exception('Test error');
        });
      } catch (e) {
        // Expected
      }

      final value = await db.settingsDao.getString('test');
      expect(value, isNull); // Should be rolled back
    });
  });
}
```

---

### Step 5.3: Run Tests

**Command:**
```bash
fvm flutter test test/unit/database_test.dart
```

**Expected output:**
```
00:01 +23: All tests passed!
```

**If tests fail:**
- Check error messages
- Verify database schema matches DAO expectations
- Ensure foreign keys are enabled

---

### Step 5.4: Manual App Testing

**Command:**
```bash
just run
```

**Test checklist:**

1. **App starts without errors**
   - ✅ No crashes on launch
   - ✅ Console shows "Settings and data loaded from database"

2. **Settings persist**
   - Add API key in Settings
   - Restart app
   - ✅ API key still there

3. **Folder management**
   - Add a folder
   - Restart app
   - ✅ Folder persists

4. **File processing**
   - Process a PDF file
   - ✅ Data extracted and displayed
   - Restart app
   - ✅ Processed data still there

5. **Database created**
   - Check file exists: `ls -lh ~/.invoicer/invoicer.db`
   - ✅ File exists and has size > 0

6. **Logs working**
   - Check console for colored log messages
   - Query database: `sqlite3 ~/.invoicer/invoicer.db "SELECT COUNT(*) FROM log_entries;"`
   - ✅ Logs are being written

7. **Reset works**
   - Use "Reset App Data" in Settings
   - ✅ All data cleared
   - ✅ API key preserved

---

### Step 5.5: Database Inspection

**Check database schema:**
```bash
sqlite3 ~/.invoicer/invoicer.db

.tables
# Should show: folders  line_items  log_entries  receipts  settings  vendors

.schema receipts
# Should show CREATE TABLE statement with all columns

SELECT COUNT(*) FROM receipts;
SELECT COUNT(*) FROM vendors;
SELECT COUNT(*) FROM log_entries;

.quit
```

---

## Rollback Plan

If migration fails or causes issues:

### Step 1: Stop App
```bash
pkill -f invoicer
```

### Step 2: Revert Code Changes
```bash
git checkout lib/state.dart lib/logger.dart lib/main.dart
git clean -fd lib/database/
```

### Step 3: Remove Database
```bash
rm -f ~/.invoicer/invoicer.db
rm -f ~/.invoicer/invoicer.db-wal
rm -f ~/.invoicer/invoicer.db-shm
```

### Step 4: Restore Old Data (if backed up)
```bash
# Restore JSON file
cp ~/.invoicer/data.json.backup.* ~/.invoicer/data.json 2>/dev/null || true

# Restore logs
cp -r ~/.invoicer/logs.backup.* ~/.invoicer/logs/ 2>/dev/null || true
```

### Step 5: Rebuild
```bash
fvm flutter clean
fvm flutter pub get
just build
```

---

## Error Recovery

### Error: "Database is locked"

**Cause:** Multiple app instances or zombie process

**Solution:**
```bash
# Kill all instances
pkill -9 -f invoicer

# Remove lock files
rm -f ~/.invoicer/invoicer.db-shm
rm -f ~/.invoicer/invoicer.db-wal

# Restart app
just run
```

---

### Error: "Foreign key constraint failed"

**Cause:** Foreign keys not enabled or data inconsistency

**Solution:**
```bash
# Check foreign keys
sqlite3 ~/.invoicer/invoicer.db "PRAGMA foreign_keys;"
# Should output: 1

# If 0, database.dart beforeOpen() isn't working
# Rebuild database:
rm ~/.invoicer/invoicer.db*
just run
```

---

### Error: Build fails with drift errors

**Cause:** Stale generated files

**Solution:**
```bash
dart run build_runner clean
rm -rf lib/**/*.g.dart
fvm flutter pub get
dart run build_runner build --delete-conflicting-outputs
```

---

### Error: "No such table: receipts"

**Cause:** Database not initialized

**Solution:**
```bash
# Delete and recreate
rm ~/.invoicer/invoicer.db*
just run
```

---

### Error: Data not persisting

**Cause:** Database writes failing silently

**Solution:**
```bash
# Check logs in console for errors
# Check database permissions
ls -la ~/.invoicer/
# Should be writable by current user

# Check database integrity
sqlite3 ~/.invoicer/invoicer.db "PRAGMA integrity_check;"
# Should output: ok
```

---

## Post-Migration Verification

### Final Checklist

Run all these commands to verify success:

```bash
# 1. Build succeeds
just build
echo "✅ Build: $?"

# 2. Tests pass
just test
echo "✅ Tests: $?"

# 3. No analysis errors
fvm flutter analyze
echo "✅ Analysis: $?"

# 4. Database file created
test -f ~/.invoicer/invoicer.db && echo "✅ Database file exists"

# 5. Database has tables
sqlite3 ~/.invoicer/invoicer.db "SELECT COUNT(*) FROM sqlite_master WHERE type='table';" | grep -q "6" && echo "✅ All 6 tables exist"

# 6. Foreign keys enabled
sqlite3 ~/.invoicer/invoicer.db "PRAGMA foreign_keys;" | grep -q "1" && echo "✅ Foreign keys enabled"

# 7. Indexes created
sqlite3 ~/.invoicer/invoicer.db "SELECT COUNT(*) FROM sqlite_master WHERE type='index';" | awk '{if($1>10) print "✅ Indexes created"}'

# 8. No old JSON writes in code
! grep -r "saveExtractedData" lib/state.dart && echo "✅ JSON methods removed"

# 9. No old log file writes
! grep -r "File.*write" lib/logger.dart && echo "✅ Log file writes removed"

# 10. SharedPreferences only for fallback
grep -c "SharedPreferences" lib/state.dart | awk '{if($1==0) print "✅ SharedPreferences removed"}'
```

---

## Success Criteria (FINAL)

Migration is 100% complete when:

1. ✅ App builds without errors (`just build`)
2. ✅ All tests pass (`just test`)
3. ✅ No analyzer warnings (`fvm flutter analyze`)
4. ✅ Database file created at `~/.invoicer/invoicer.db`
5. ✅ Settings persist across app restarts
6. ✅ Processed receipts persist across restarts
7. ✅ OCR text stored in database (verify with SQL query)
8. ✅ Vendors deduplicated (same name → same ID)
9. ✅ Logs written to database (check log_entries table)
10. ✅ Reset app data works (clears data, keeps settings)
11. ✅ JSON file operations removed from code
12. ✅ Log file operations removed from code
13. ✅ Export functionality works with database data
14. ✅ No regression in existing features

---

## Manual Cleanup (Optional)

After verifying everything works:

```bash
# Remove old JSON file
rm ~/.invoicer/data.json

# Remove old log files
rm -rf ~/.invoicer/logs/

# Remove backup files
rm ~/.invoicer/data.json.backup.*
rm -rf ~/.invoicer/logs.backup.*
```

---

## Next Steps (Future Enhancements)

After migration is complete and stable:

1. **Add search functionality** using full-text search (uncomment FTS5 in database.dart)
2. **Add vendor analytics** dashboard using vendor statistics
3. **Add log viewer UI** for debugging
4. **Implement recurring invoice detection**
5. **Add database backup/export** feature
6. **Add database vacuum** to reclaim space periodically

---

**END OF IMPLEMENTATION PLAN**

This plan is complete, self-contained, and ready for execution by an AI coding agent.

**Estimated total time:** 22-32 hours
**Phases:** 5
**Files created:** 11
**Files modified:** 4
**Tables:** 6
**DAOs:** 5
**Tests:** 23
