import 'dart:io';

class Logger {
  final bool verbose;

  Logger({this.verbose = false});

  void log(String message) {
    if (verbose) {
      stdout.writeln(message);
    }
  }

  void error(String message) {
    stdout.writeln(message);
  }

  void success(String message) {
    stdout.writeln(message);
  }
}
