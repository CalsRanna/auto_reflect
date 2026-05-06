import 'dart:io';

import 'package:args/command_runner.dart';

const _version = String.fromEnvironment('JOURNAL_VERSION', defaultValue: 'dev');

class VersionCommand extends Command {
  @override
  String get description => 'Print current version';

  @override
  bool get hidden => true;

  @override
  String get name => 'version';

  @override
  Future<void> run() async {
    stdout.writeln('Journal $_version');
  }
}
