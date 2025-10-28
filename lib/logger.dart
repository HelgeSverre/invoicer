import 'dart:io';

import 'package:ansicolor/ansicolor.dart';
import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';
import 'package:path/path.dart' as path;

/// Simple logger that writes to both stdout and a log file.
///
/// Logs are written to ~/.invoicer/logs/ directory with daily rotation.
/// Console output is colorized: red (error), yellow (warning), green (info), gray (debug).
class AppLogger {
  final String _name;
  static final _dateFormat = DateFormat('HH:mm:ss.SSS');
  static File? _logFile;
  static IOSink? _logSink;
  static DateTime? _currentLogDate;

  // ANSI color pens for different log levels
  static final _errorPen = AnsiPen()..red();
  static final _warningPen = AnsiPen()..yellow();
  static final _infoPen = AnsiPen()..green();
  static final _debugPen = AnsiPen()..gray();

  AppLogger(this._name);

  /// Get the log directory path (private)
  static String get _logDir {
    final home = Platform.environment['HOME'] ??
        Platform.environment['USERPROFILE'] ??
        '';
    return path.join(home, '.invoicer', 'logs');
  }

  /// Get the log directory path (public)
  static String get logDirectory => _logDir;

  /// Initialize or rotate log file if needed
  static Future<void> _ensureLogFile() async {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    // Check if we need to create or rotate the log file
    if (_logFile == null || _currentLogDate != today) {
      // Close existing sink if any
      await _logSink?.close();

      // Create log directory if it doesn't exist
      final logDir = Directory(_logDir);
      if (!await logDir.exists()) {
        await logDir.create(recursive: true);
      }

      // Create new log file for today
      final dateStr = DateFormat('yyyy-MM-dd').format(now);
      final logPath = path.join(_logDir, 'invoicer_$dateStr.log');
      _logFile = File(logPath);
      _logSink = _logFile!.openWrite(mode: FileMode.append);
      _currentLogDate = today;

      // Clean up old log files (keep last 7 days)
      _cleanupOldLogs();
    }
  }

  /// Remove log files older than 7 days
  static Future<void> _cleanupOldLogs() async {
    try {
      final logDir = Directory(_logDir);
      if (!await logDir.exists()) return;

      final now = DateTime.now();
      final cutoffDate = now.subtract(const Duration(days: 7));

      await for (final entity in logDir.list()) {
        if (entity is File && entity.path.endsWith('.log')) {
          final stat = await entity.stat();
          if (stat.modified.isBefore(cutoffDate)) {
            await entity.delete();
          }
        }
      }
    } catch (e) {
      debugPrint('Failed to cleanup old logs: $e');
    }
  }

  /// Write a log message to both stdout and file
  Future<void> _log(String level, String message,
      {Object? error, StackTrace? stackTrace, AnsiPen? colorPen}) async {
    final timestamp = _dateFormat.format(DateTime.now());
    final plainLogMessage = '[$timestamp] $level [$_name] $message';

    // Write to stdout with color
    if (colorPen != null) {
      debugPrint(colorPen(plainLogMessage));
    } else {
      debugPrint(plainLogMessage);
    }

    // Write to file (without color codes)
    try {
      await _ensureLogFile();
      _logSink?.writeln(plainLogMessage);

      if (error != null) {
        _logSink?.writeln('  Error: $error');
      }

      if (stackTrace != null) {
        _logSink?.writeln('  Stack trace:');
        _logSink?.writeln('  $stackTrace');
      }

      await _logSink?.flush();
    } catch (e) {
      debugPrint('Failed to write to log file: $e');
    }
  }

  /// Log debug message (verbose details) - gray
  void debug(String message) {
    _log('DEBUG', message, colorPen: _debugPen);
  }

  /// Log info message (general workflow) - green
  void info(String message) {
    _log('INFO', message, colorPen: _infoPen);
  }

  /// Log warning message (recoverable issues) - yellow
  void warning(String message) {
    _log('WARN', message, colorPen: _warningPen);
  }

  /// Log error message (failures) - red
  void error(String message, {Object? error, StackTrace? stackTrace}) {
    _log('ERROR', message,
        error: error, stackTrace: stackTrace, colorPen: _errorPen);
  }

  /// Close all log resources (call on app shutdown)
  static Future<void> close() async {
    await _logSink?.flush();
    await _logSink?.close();
    _logSink = null;
    _logFile = null;
  }
}
