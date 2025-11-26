import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:logger/logger.dart';

/// Global error handler for QuantumTrader Pro
class ErrorHandler {
  static final ErrorHandler _instance = ErrorHandler._internal();
  factory ErrorHandler() => _instance;
  ErrorHandler._internal();

  final Logger _logger = Logger(
    printer: PrettyPrinter(
      methodCount: 3,
      errorMethodCount: 8,
      lineLength: 120,
      colors: true,
      printEmojis: true,
      printTime: true,
    ),
  );

  // Error listeners
  final List<Function(AppError)> _errorListeners = [];
  
  // Error history
  final List<AppError> _errorHistory = [];
  static const int _maxErrorHistory = 100;

  void initialize() {
    // Set up Flutter error handling
    FlutterError.onError = (FlutterErrorDetails details) {
      handleFlutterError(details);
    };

    // Set up Zone error handling
    runZonedGuarded(() {
      // App runs in this guarded zone
    }, (error, stackTrace) {
      handleError(error, stackTrace: stackTrace);
    });

    _logger.i('Error Handler initialized');
  }

  void handleError(
    dynamic error, {
    StackTrace? stackTrace,
    String? context,
    ErrorSeverity severity = ErrorSeverity.medium,
  }) {
    final appError = AppError(
      error: error,
      stackTrace: stackTrace,
      context: context,
      severity: severity,
      timestamp: DateTime.now(),
    );

    // Log the error
    _logError(appError);

    // Store in history
    _addToHistory(appError);

    // Notify listeners
    _notifyListeners(appError);

    // Handle specific error types
    _handleSpecificError(error);
  }

  void handleFlutterError(FlutterErrorDetails details) {
    final appError = AppError(
      error: details.exception,
      stackTrace: details.stack,
      context: 'Flutter Framework',
      severity: details.silent ? ErrorSeverity.low : ErrorSeverity.high,
      timestamp: DateTime.now(),
      flutterDetails: details,
    );

    _logError(appError);
    _addToHistory(appError);
    _notifyListeners(appError);
  }

  void _logError(AppError error) {
    switch (error.severity) {
      case ErrorSeverity.low:
        _logger.d('${error.context ?? 'Error'}: ${error.error}');
        break;
      case ErrorSeverity.medium:
        _logger.w('${error.context ?? 'Warning'}: ${error.error}');
        break;
      case ErrorSeverity.high:
        _logger.e(
          '${error.context ?? 'Error'}: ${error.error}',
          error.error,
          error.stackTrace,
        );
        break;
      case ErrorSeverity.critical:
        _logger.f(
          '${error.context ?? 'CRITICAL ERROR'}: ${error.error}',
          error.error,
          error.stackTrace,
        );
        break;
    }
  }

  void _handleSpecificError(dynamic error) {
    if (error is SocketException) {
      _handleNetworkError(error);
    } else if (error is FormatException) {
      _handleFormatError(error);
    } else if (error is TimeoutException) {
      _handleTimeoutError(error);
    } else if (error is TradingError) {
      _handleTradingError(error);
    }
  }

  void _handleNetworkError(SocketException error) {
    _logger.w('Network error: ${error.message}');
    // Could trigger reconnection logic here
  }

  void _handleFormatError(FormatException error) {
    _logger.w('Data format error: ${error.message}');
    // Could notify data service to refresh
  }

  void _handleTimeoutError(TimeoutException error) {
    _logger.w('Operation timeout: ${error.message}');
    // Could retry operation
  }

  void _handleTradingError(TradingError error) {
    _logger.e('Trading error: ${error.message} (Code: ${error.code})');
    // Could notify user with specific trading error message
  }

  void _addToHistory(AppError error) {
    _errorHistory.add(error);
    if (_errorHistory.length > _maxErrorHistory) {
      _errorHistory.removeAt(0);
    }
  }

  void _notifyListeners(AppError error) {
    for (final listener in _errorListeners) {
      try {
        listener(error);
      } catch (e) {
        _logger.w('Error in error listener: $e');
      }
    }
  }

  // Public methods
  void addErrorListener(Function(AppError) listener) {
    _errorListeners.add(listener);
  }

  void removeErrorListener(Function(AppError) listener) {
    _errorListeners.remove(listener);
  }

  List<AppError> getErrorHistory({ErrorSeverity? minSeverity}) {
    if (minSeverity == null) {
      return List.unmodifiable(_errorHistory);
    }
    return _errorHistory
        .where((e) => e.severity.index >= minSeverity.index)
        .toList();
  }

  void clearErrorHistory() {
    _errorHistory.clear();
  }

  // Utility method for try-catch with logging
  Future<T?> tryAsync<T>(
    Future<T> Function() operation, {
    String? context,
    T? fallback,
    bool showUser = false,
  }) async {
    try {
      return await operation();
    } catch (error, stackTrace) {
      handleError(
        error,
        stackTrace: stackTrace,
        context: context,
        severity: showUser ? ErrorSeverity.high : ErrorSeverity.medium,
      );
      return fallback;
    }
  }

  T? trySync<T>(
    T Function() operation, {
    String? context,
    T? fallback,
    bool showUser = false,
  }) {
    try {
      return operation();
    } catch (error, stackTrace) {
      handleError(
        error,
        stackTrace: stackTrace,
        context: context,
        severity: showUser ? ErrorSeverity.high : ErrorSeverity.medium,
      );
      return fallback;
    }
  }

  // User-friendly error messages
  String getUserMessage(dynamic error) {
    if (error is TradingError) {
      return _getTradingErrorMessage(error);
    } else if (error is SocketException) {
      return 'Network connection error. Please check your internet connection.';
    } else if (error is TimeoutException) {
      return 'Operation timed out. Please try again.';
    } else if (error is FormatException) {
      return 'Invalid data received. Please try again.';
    } else if (error.toString().contains('401')) {
      return 'Authentication failed. Please log in again.';
    } else if (error.toString().contains('403')) {
      return 'Access denied. Please check your permissions.';
    } else if (error.toString().contains('404')) {
      return 'Resource not found. Please try again later.';
    } else if (error.toString().contains('500')) {
      return 'Server error. Please try again later.';
    } else {
      return 'An unexpected error occurred. Please try again.';
    }
  }

  String _getTradingErrorMessage(TradingError error) {
    switch (error.code) {
      case 'INSUFFICIENT_FUNDS':
        return 'Insufficient funds for this trade.';
      case 'MARKET_CLOSED':
        return 'Market is closed. Trading not available.';
      case 'INVALID_VOLUME':
        return 'Invalid trade volume. Please check your lot size.';
      case 'INVALID_STOPS':
        return 'Invalid stop loss or take profit levels.';
      case 'TRADE_DISABLED':
        return 'Trading is disabled for this symbol.';
      case 'POSITION_NOT_FOUND':
        return 'Position not found or already closed.';
      case 'CONNECTION_LOST':
        return 'Connection to broker lost. Please reconnect.';
      default:
        return error.message;
    }
  }
}

// Error models
enum ErrorSeverity {
  low,      // Debug info
  medium,   // Warnings
  high,     // Errors that affect functionality
  critical  // Errors that crash the app
}

class AppError {
  final dynamic error;
  final StackTrace? stackTrace;
  final String? context;
  final ErrorSeverity severity;
  final DateTime timestamp;
  final FlutterErrorDetails? flutterDetails;

  AppError({
    required this.error,
    this.stackTrace,
    this.context,
    required this.severity,
    required this.timestamp,
    this.flutterDetails,
  });

  String get message => error.toString();
  
  String get shortMessage {
    final msg = message;
    return msg.length > 100 ? '${msg.substring(0, 97)}...' : msg;
  }
}

// Custom error types
class TradingError extends Error {
  final String message;
  final String code;
  final dynamic details;

  TradingError({
    required this.message,
    required this.code,
    this.details,
  });

  @override
  String toString() => 'TradingError: $message (Code: $code)';
}

class DataError extends Error {
  final String message;
  final String? field;
  final dynamic invalidValue;

  DataError({
    required this.message,
    this.field,
    this.invalidValue,
  });

  @override
  String toString() => 'DataError: $message${field != null ? ' (Field: $field)' : ''}';
}

class ConfigurationError extends Error {
  final String message;
  final String? setting;

  ConfigurationError({
    required this.message,
    this.setting,
  });

  @override
  String toString() => 'ConfigurationError: $message${setting != null ? ' (Setting: $setting)' : ''}';
}

// Error dialog widget
class ErrorDialog extends StatelessWidget {
  final AppError error;
  final VoidCallback? onRetry;

  const ErrorDialog({
    Key? key,
    required this.error,
    this.onRetry,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final errorHandler = ErrorHandler();
    final userMessage = errorHandler.getUserMessage(error.error);

    return AlertDialog(
      title: Row(
        children: [
          Icon(
            _getIconForSeverity(error.severity),
            color: _getColorForSeverity(error.severity),
          ),
          const SizedBox(width: 8),
          Text(_getTitleForSeverity(error.severity)),
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(userMessage),
          if (kDebugMode) ...[
            const SizedBox(height: 16),
            Text(
              'Debug Info:',
              style: Theme.of(context).textTheme.labelSmall,
            ),
            const SizedBox(height: 4),
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.grey[900],
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                error.shortMessage,
                style: const TextStyle(
                  fontFamily: 'monospace',
                  fontSize: 12,
                  color: Colors.white70,
                ),
              ),
            ),
          ],
        ],
      ),
      actions: [
        if (onRetry != null)
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              onRetry!();
            },
            child: const Text('Retry'),
          ),
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('OK'),
        ),
      ],
    );
  }

  IconData _getIconForSeverity(ErrorSeverity severity) {
    switch (severity) {
      case ErrorSeverity.low:
        return Icons.info_outline;
      case ErrorSeverity.medium:
        return Icons.warning_amber_outlined;
      case ErrorSeverity.high:
        return Icons.error_outline;
      case ErrorSeverity.critical:
        return Icons.dangerous_outlined;
    }
  }

  Color _getColorForSeverity(ErrorSeverity severity) {
    switch (severity) {
      case ErrorSeverity.low:
        return Colors.blue;
      case ErrorSeverity.medium:
        return Colors.orange;
      case ErrorSeverity.high:
        return Colors.red;
      case ErrorSeverity.critical:
        return Colors.red[900]!;
    }
  }

  String _getTitleForSeverity(ErrorSeverity severity) {
    switch (severity) {
      case ErrorSeverity.low:
        return 'Information';
      case ErrorSeverity.medium:
        return 'Warning';
      case ErrorSeverity.high:
        return 'Error';
      case ErrorSeverity.critical:
        return 'Critical Error';
    }
  }
}

// Extension for easy error handling in widgets
extension ErrorHandlingExtension on State {
  Future<void> handleErrorAsync(
    Future<void> Function() operation, {
    String? context,
    bool showDialog = true,
    VoidCallback? onRetry,
  }) async {
    final errorHandler = ErrorHandler();
    try {
      await operation();
    } catch (error, stackTrace) {
      errorHandler.handleError(
        error,
        stackTrace: stackTrace,
        context: context ?? widget.runtimeType.toString(),
        severity: showDialog ? ErrorSeverity.high : ErrorSeverity.medium,
      );

      if (showDialog && mounted) {
        showDialog(
          context: this.context,
          builder: (context) => ErrorDialog(
            error: errorHandler.getErrorHistory().last,
            onRetry: onRetry,
          ),
        );
      }
    }
  }
}