# Invoicer - Flutter macOS Development Commands
# https://just.systems/man/en/

# Show available commands by default
help:
    @just --list

# === Setup ===

[group('setup')]
[doc('Install Flutter SDK and dependencies')]
install:
    @echo "Installing Flutter SDK and dependencies..."
    fvm install
    fvm flutter pub get

[group('setup')]
[doc('Update dependencies')]
update:
    @echo "Updating dependencies..."
    fvm flutter pub upgrade

[group('setup')]
[doc('Check for outdated dependencies')]
outdated:
    @echo "Checking for outdated dependencies..."
    fvm flutter pub outdated

# === Development ===

[group('dev')]
[doc('Run the app in debug mode on macOS')]
run:
    @echo "Running app on macOS..."
    fvm flutter run -d macos

[group('dev')]
[doc('Alias for run')]
dev: run

[group('dev')]
[doc('Build the macOS app')]
build:
    @echo "Building macOS app..."
    fvm flutter build macos

# === Testing ===

[group('test')]
[doc('Run all tests')]
test:
    @echo "Running tests..."
    fvm flutter test

[group('test')]
[doc('Run tests with coverage')]
test-coverage:
    @echo "Running tests with coverage..."
    fvm flutter test --coverage

# === Code Quality ===

[group('quality')]
[doc('Analyze code for issues')]
analyze:
    @echo "Analyzing code..."
    fvm flutter analyze

[group('quality')]
[doc('Format code')]
format:
    @echo "Formatting code..."
    fvm dart format .

[group('quality')]
[doc('Check code formatting')]
format-check:
    @echo "Checking code formatting..."
    fvm dart format --set-exit-if-changed .

[group('quality')]
[doc('Run all quality checks (format-check + analyze)')]
check: format-check analyze
    @echo "All checks passed!"

# === Cleanup ===

[group('workflow')]
[doc('Clean build artifacts')]
clean:
    @echo "Cleaning build artifacts..."
    fvm flutter clean

[group('workflow')]
[doc('Clean and reinstall dependencies')]
reset: clean install
    @echo "Reset complete!"

# === macOS Specific ===

[group('macos')]
[doc('Install CocoaPods dependencies')]
pod-install:
    @echo "Installing CocoaPods dependencies..."
    cd macos && pod install

[group('macos')]
[doc('Clean and reinstall pods')]
pod-reset:
    @echo "Resetting CocoaPods..."
    cd macos && rm -rf Pods Podfile.lock
    cd macos && pod install
    @echo "Pods reset complete!"

# === Workflows ===

[group('workflow')]
[doc('Quick dev cycle: format and run')]
quick: format run

[group('workflow')]
[doc('Prepare for commit: format + analyze + test')]
pre-commit: format analyze test
    @echo "Ready to commit!"

# === Code Generation (uncomment if using build_runner) ===

# [group('codegen')]
# [doc('Run build_runner code generation')]
# generate:
#     @echo "Generating code..."
#     fvm flutter pub run build_runner build --delete-conflicting-outputs

# [group('codegen')]
# [doc('Watch and regenerate code on change')]
# watch:
#     @echo "Watching for changes..."
#     fvm flutter pub run build_runner watch --delete-conflicting-outputs
