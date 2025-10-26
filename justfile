# List available commands
default:
    @just --list

# Run the app in debug mode on macOS
run:
    fvm flutter run -d macos

# Run the app in debug mode (alias for run)
dev:
    fvm flutter run -d macos

# Build the macOS app
build:
    fvm flutter build macos

# Run tests
test:
    fvm flutter test

# Analyze code for issues
analyze:
    fvm flutter analyze

# Install dependencies
install:
    fvm flutter pub get

# Update dependencies
update:
    fvm flutter pub upgrade

# Check for outdated dependencies
outdated:
    fvm flutter pub outdated

# Clean build artifacts
clean:
    fvm flutter clean

# Clean and reinstall dependencies
reset: clean install

# Install CocoaPods dependencies (macOS)
pod-install:
    cd macos && pod install

# Clean and reinstall pods
pod-reset:
    cd macos && rm -rf Pods Podfile.lock
    cd macos && pod install

# Run build_runner code generation (uncomment if needed)
# generate:
#     fvm flutter pub run build_runner build --delete-conflicting-outputs

# Watch and regenerate code (uncomment if needed)
# watch:
#     fvm flutter pub run build_runner watch --delete-conflicting-outputs
