import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as path;
import 'package:url_launcher/url_launcher.dart';

/// Reveals a file in Finder and selects it.
///
/// Takes the full path to a file and reveals it in Finder with the file selected.
/// Uses the `open -R` command on macOS to properly highlight the file.
Future<void> revealFileInFinder(String filePath) async {
  try {
    if (Platform.isMacOS) {
      // Use 'open -R' to reveal and select the file in Finder
      final result = await Process.run('open', ['-R', filePath]);
      if (result.exitCode != 0) {
        debugPrint('Failed to reveal file in Finder: ${result.stderr}');
      }
    } else {
      // Fallback for non-macOS platforms: just open the containing folder
      final uri = Uri.file(path.dirname(filePath));
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri);
      }
    }
  } catch (e) {
    debugPrint('Could not reveal file in Finder: $e');
  }
}

/// Reveals a folder in Finder by opening it.
///
/// Takes the full path to a folder and opens it in Finder.
Future<void> revealFolderInFinder(String folderPath) async {
  try {
    final uri = Uri.file(folderPath);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    }
  } catch (e) {
    debugPrint('Could not reveal folder in Finder: $e');
  }
}
