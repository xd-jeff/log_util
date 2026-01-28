import 'dart:developer';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:stack_trace/stack_trace.dart';

enum LogOutputMode { console, file }

enum LogType { log, print, debugPrint }

enum Level {
  verbose(999),
  trace(1000),
  debug(2000),
  info(3000),
  warning(4000),
  error(5000),
  fatal(6000),
  off(10000);

  final int value;

  const Level(this.value);
  bool operator <(Level other) => value < other.value;
  bool operator <=(Level other) => value <= other.value;
  bool operator >(Level other) => value > other.value;
  bool operator >=(Level other) => value >= other.value;
}

class LogUtil {
  final String tag;
  bool enableLog;
  Function(Level level, String message)? logListener;
  final bool enableFileLineNumber;

  static LogType logType = LogType.log;

  LogUtil({
    required this.tag,
    this.enableLog = true,
    this.logListener,
    this.enableFileLineNumber = true,
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
        if (level == Level.error) {
          final time = formatDateMs(now.millisecondsSinceEpoch,
              format: "yyyy-MM-dd HH:mm:ss");
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
    switch (logType) {
      case LogType.print:
        if (kDebugMode) {
          print(message);
        }
        break;
      case LogType.debugPrint:
        assert(() {
          debugPrint(message);
          return true;
        }());
        break;
      case LogType.log:
        log(message, name: tag, level: level.value);
        break;
    }
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
      final dateStr =
          formatDateMs(now.millisecondsSinceEpoch, format: "yyyyMMdd");
      if (_currentDate != dateStr) {
        await _switchLogFile(dateStr);
      }
      _sink?.writeln(message);
    } catch (e) {
      debugPrint("日志写入失败: $e");
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
              debugPrint("日志删除失败: \$e");
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

  String formatDateMs(int milliseconds,
      {String format = "yyyy-MM-dd HH:mm:ss"}) {
    final date = DateTime.fromMillisecondsSinceEpoch(milliseconds);
    return DateFormat(format).format(date);
  }

  void v(Object? object) => _log(Level.verbose, object);
  void d(Object? object) => _log(Level.debug, object);
  void i(Object? object) => _log(Level.info, object);
  void w(Object? object) => _log(Level.warning, object);
  void e(Object? object) => _log(Level.error, object);
}

extension LevelEmojiExt on Level {
  String get emoji {
    switch (this) {
      case Level.verbose:
        return '🗨️'; // 对话气泡
      case Level.trace:
        return '🧭'; // 路径 / 追踪
      case Level.debug:
        return '🐛'; // 毛毛虫（你钦点）
      case Level.info:
        return '💡'; // 信息 / 提示
      case Level.warning:
        return '⚠️'; // 警告
      case Level.error:
        return '🧨'; // 错误 / 爆点
      case Level.fatal:
        return '💥'; // 致命错误
      case Level.off:
        return '⛔️'; // 禁止 / 关闭
    }
  }
}
