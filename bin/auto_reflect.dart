import 'dart:io';

import 'package:args/command_runner.dart';

import '../lib/commands/config_command.dart';
import '../lib/commands/doctor_command.dart';
import '../lib/commands/reflect_command.dart';
import '../lib/commands/version_command.dart';

Future<void> main(List<String> arguments) async {
  final runner = CommandRunner(
      'journal', 'Journal - Automatic Git Work Log Generator')
    ..addCommand(ReflectCommand())
    ..addCommand(ConfigCommand())
    ..addCommand(DoctorCommand())
    ..addCommand(VersionCommand());

  runner.argParser.addFlag(
    'version',
    abbr: 'v',
    negatable: false,
    help: 'Print the current version.',
  );

  final args = _filterVersionArgument(arguments);

  try {
    await runner.run(args);
  } catch (e) {
    stdout.writeln('Error: $e');
    exit(1);
  }
}

List<String> _filterVersionArgument(List<String> arguments) {
  if (arguments.length != 1) return arguments;
  final argument = arguments.first;
  if (argument == '--version' || argument == '-v') return ['version'];
  return arguments;
}
