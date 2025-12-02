import 'dart:developer' as developer;

class LoggerService {
  static void logError(String message, dynamic error, [StackTrace? stackTrace]) {
    developer.log(
      message,
      error: error,
      stackTrace: stackTrace,
      name: 'HHFSocial',
      level: 1000, // Severe
    );
  }

  static void logInfo(String message) {
    developer.log(
      message,
      name: 'HHFSocial',
      level: 800, // Info
    );
  }
}
