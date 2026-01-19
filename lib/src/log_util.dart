import 'package:flutter/foundation.dart';
import 'package:logger/logger.dart';
import 'package:stack_trace/stack_trace.dart';

class LogUtil {
  final String tag;
  bool enableLog;
  Function(Level level, String message)? logListener;
  final bool enableFileLineNumber;

  late final Logger _logger;

  LogUtil({
    required this.tag,
    this.enableLog = true,
    this.logListener,
    this.enableFileLineNumber = true,
  }) {
    _logger = Logger(
      level: Level.trace,
      printer:
          _PrefixPrinter(tag: tag, enableFileLineNumber: enableFileLineNumber),
      output: ConsoleOutput(),
    );
  }

  void setEnable(bool enable) => enableLog = enable;

  void setLogListener(Function(Level level, String message) listener) {
    logListener = listener;
  }

  void _log(Level level, Object? object) {
    if (!enableLog) return;

    final message = object?.toString() ?? '';
    _logger.log(level, message);

    logListener?.call(level, message);
  }

  void v(Object? object) => _log(Level.trace, object);
  void d(Object? object) => _log(Level.debug, object);
  void i(Object? object) => _log(Level.info, object);
  void w(Object? object) => _log(Level.warning, object);
  void e(Object? object) => _log(Level.error, object);
}

class _PrefixPrinter extends LogPrinter {
  final String tag;
  final bool enableFileLineNumber;
  final PrettyPrinter _innerPrinter;

  _PrefixPrinter({required this.tag, required this.enableFileLineNumber})
      : _innerPrinter = PrettyPrinter(
          methodCount: enableFileLineNumber ? 2 : 0,
          lineLength: 120,
          colors: true,
          printEmojis: true,
        );

  @override
  List<String> log(LogEvent event) {
    final lines = _innerPrinter.log(event);

    // 每行加模块前缀
    return lines.map((line) => '[$tag] $line').toList();
  }
}
