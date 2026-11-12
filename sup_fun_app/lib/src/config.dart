import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';

/// Server origin (no trailing slash), e.g. https://api.supfun.app
/// Override at build time: --dart-define=API_BASE=http://192.168.1.10:3000
class AppConfig {
  static const String _override = String.fromEnvironment('API_BASE');

  static String get serverOrigin {
    if (_override.isNotEmpty) return _override;
    if (kIsWeb) return 'http://localhost:3000';
    if (Platform.isAndroid) return 'http://10.0.2.2:3000';
    return 'http://localhost:3000';
  }

  static String get apiBase => '$serverOrigin/api';

  /// Convert a server-relative path (e.g. /uploads/x.jpg or a full url)
  /// into an absolute URL.
  static String absUrl(String? path) {
    if (path == null || path.isEmpty) return '';
    if (path.startsWith('http://') || path.startsWith('https://')) return path;
    return '$serverOrigin$path';
  }
}