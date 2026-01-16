import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';
import 'package:logging/logging.dart';
import 'package:path_provider/path_provider.dart';
import 'package:stack_trace/stack_trace.dart';

enum LogOutputMode { console, file }

class LogUtil {
  final String tag;
  bool enableLog;
  Function(Level level, String message)? logListener;
  final bool enableFileLineNumber;
  final bool useLog;

  LogUtil({
    required this.tag,
    this.enableLog = true,
    this.logListener,
    this.enableFileLineNumber = true,
    this.useLog = false,
  }) {
    if (outputMode == LogOutputMode.file) {
      _initLogWriter();
    }
  }

  LogOutputMode get outputMode =>
      kDebugMode ? LogOutputMode.console : LogOutputMode.file;

  void setEnable(bool enable) {
    enableLog = enable;
  }

  void setLogListener(Function(Level level, String message) listener) {
    logListener = listener;
  }

  void _log(Level level, Object? object) {
    if (!enableLog) return;

    String message;
    final now = DateTime.now();

    switch (outputMode) {
      case LogOutputMode.console:
        final time = now.toIso8601String().split('T')[1].split('.')[0];
        if (enableFileLineNumber) {
          final callerInfo = Trace.current(2).frames.firstWhere(
                (frame) => frame.library.contains('/'),
                orElse: () => Trace.current(2).frames.first,
              );
          final fileName = callerInfo.library.split('/').last;
          final lineNumber = callerInfo.line;
          message =
              "${level.emoji} [$fileName:$lineNumber] [$time] ${object?.toString()}";
        } else {
          message = "${level.emoji} [$time] ${object?.toString()}";
        }
        _printLog(level, message);
        logListener?.call(level, message);
        break;

      case LogOutputMode.file:
        if (level == Level.SEVERE) {
          final time = DateFormat('yyyy-MM-dd HH:mm:ss').format(now);
          final callerInfo = Trace.current(2).frames.firstWhere(
                (frame) => frame.library.contains('/'),
                orElse: () => Trace.current(2).frames.first,
              );
          final fileName = callerInfo.library.split('/').last;
          final lineNumber = callerInfo.line;
          message =
              "[$tag] $level [$fileName:$lineNumber] [$time] \${object?.toString()}";
          _writeLog(message);
          logListener?.call(level, message);
        }
        break;
    }
  }

  void _printLog(Level level, String message) {
    // ignore: avoid_print
    print('[$tag] $message');
  }

  IOSink? _sink;
  String? _currentDate;
  late String _logDirPath;
  bool _initialized = false;

  Future<void> _initLogWriter() async {
    final tempDir = await getTemporaryDirectory();
    final logDir = Directory("${tempDir.path}/logs");
    if (!await logDir.exists()) {
      await logDir.create(recursive: true);
    }
    _logDirPath = logDir.path;
    _initialized = true;
    await _cleanOldLogs(logDir);
  }

  Future<void> _writeLog(String message) async {
    try {
      if (!_initialized) return;
      final now = DateTime.now();
      final dateStr = DateFormat('yyyyMMdd').format(now);
      if (_currentDate != dateStr) {
        await _switchLogFile(dateStr);
      }
      _sink?.writeln(message);
    } catch (e) {
      print("日志写入失败: $e");
    }
  }

  Future<void> _switchLogFile(String dateStr) async {
    await _sink?.flush();
    await _sink?.close();
    _currentDate = dateStr;
    final logFile = File("$_logDirPath/$_currentDate.log");
    _sink = logFile.openWrite(mode: FileMode.append);
  }

  Future<void> _cleanOldLogs(Directory dir) async {
    final now = DateTime.now();
    final files = dir.listSync();
    for (final file in files) {
      if (file is File) {
        final name = file.uri.pathSegments.last;
        final match = RegExp(r'^(\d{8})\.log\$').firstMatch(name);
        if (match != null) {
          final dateStr = match.group(1)!;
          final fileDate = DateTime.tryParse(dateStr);
          if (fileDate != null && now.difference(fileDate).inDays > 7) {
            try {
              await file.delete();
            } catch (e) {
              print("日志删除失败: \$e");
            }
          }
        }
      }
    }
  }

  Future<void> dispose() async {
    await _sink?.flush();
    await _sink?.close();
  }

  void v(Object? object) => _log(Level.FINEST, object);
  void d(Object? object) => _log(Level.FINE, object);
  void i(Object? object) => _log(Level.INFO, object);
  void w(Object? object) => _log(Level.WARNING, object);
  void e(Object? object) => _log(Level.SEVERE, object);
}

extension LevelEmojiExt on Level {
  String get emoji {
    switch (name) {
      case 'ALL':
        return '⚪️';
      case 'FINEST':
        return '🔍';
      case 'FINER':
        return '🔵';
      case 'FINE':
        return '🟢';
      case 'CONFIG':
        return '⚙️';
      case 'INFO':
        return 'ℹ️';
      case 'WARNING':
        return '🟡';
      case 'SEVERE':
        return '🔴';
      case 'SHOUT':
        return '📢';
      case 'OFF':
        return '🚫';
      default:
        return '❔';
    }
  }
}
