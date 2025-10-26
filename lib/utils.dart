import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as path;
import 'package:url_launcher/url_launcher.dart';

/// Reveals a file in Finder by opening its containing folder.
///
/// Takes the full path to a file and opens its parent directory in Finder.
Future<void> revealFileInFinder(String filePath) async {
  try {
    final uri = Uri.file(path.dirname(filePath));
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
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
