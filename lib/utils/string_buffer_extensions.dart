import 'package:auto_reflect/utils/status_markers.dart';

extension StringBufferExtensions on StringBuffer {
  void writeSuccess(String text) {
    write(_foreground('${StatusMarker.success} ', _AnsiColor.green));
    write(text);
  }

  void writeError(String text) {
    write(_foreground('${StatusMarker.error} ', _AnsiColor.red));
    write(text);
  }

  void writeWarning(String text) {
    write(_foreground('${StatusMarker.warning} ', _AnsiColor.yellow));
    write(text);
  }

  void writeBullet(String text) {
    write(_foreground('${StatusMarker.bullet} ', _AnsiColor.green));
    write(text);
  }

  void writeSuccessBullet(String text) {
    write(_foreground('${StatusMarker.successBullet} ', _AnsiColor.green));
    write(text);
  }

  void writeErrorBullet(String text) {
    write(_foreground('${StatusMarker.errorBullet} ', _AnsiColor.red));
    write(text);
  }

  void writeWarningBullet(String text) {
    write(_foreground('${StatusMarker.warningBullet} ', _AnsiColor.yellow));
    write(text);
  }

  String _foreground(String text, String color) =>
      '$color$text${_AnsiColor.reset}';
}

class _AnsiColor {
  static const reset = '\x1B[0m';
  static const green = '\x1B[32m';
  static const red = '\x1B[31m';
  static const yellow = '\x1B[33m';
}
