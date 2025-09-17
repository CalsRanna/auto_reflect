import 'dart:io';
import 'package:path/path.dart' as path;

class FileUtils {
  static Future<bool> ensureDirectoryExists(String directoryPath) async {
    final directory = Directory(directoryPath);
    if (!await directory.exists()) {
      await directory.create(recursive: true);
      return true;
    }
    return false;
  }

  static String getHomeDirectory() {
    return Platform.environment['HOME']!;
  }

  static String joinPath(String part1, String part2) {
    return path.join(part1, part2);
  }

  static String getDirectoryName(String pathString) {
    return path.basename(pathString);
  }
}
