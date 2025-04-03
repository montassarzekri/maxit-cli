import 'dart:io';
import 'package:args/command_runner.dart';
import 'package:mason_logger/mason_logger.dart';
import 'package:maxit_cli/commands/config/config_command.dart';
import 'package:maxit_cli/commands/config/add_superapp_command.dart';
import 'package:maxit_cli/commands/pkgs/pkg_command.dart';
import 'package:maxit_cli/maxit_cli.dart';

Future<void> main(List<String> args) async {
  final logger = Logger();

  try {
    // Initialize config
    final configManager = ConfigManager();
    final hasConfig = await configManager.load();

    // Create the command runner
    final runner = CommandRunner<int>(
      'maxit',
      'CLI tool for managing Maxit Monorepo',
    )
      ..addCommand(InitCommand(logger, configManager))
      ..addCommand(ListProjectsCommand(logger, configManager))
      ..addCommand(ConfigCommand(logger, configManager))
      ..addCommand(AddSuperAppCommand(logger, configManager))
      ..addCommand(PkgCommand(logger, configManager));
    // Add more commands as needed

    // If no config and not already running config or help command
    if (hasConfig == null) {
      logger.info('No configuration found. Setting up configuration first...');

      // Instead of directly running the command, modify args to run config command
      final originalArgs = List<String>.from(args);

      // Run config command through the runner
      final configExitCode = await runner.run(
        ['config', '--set'],
      );

      if (configExitCode != 0) {
        logger.err(
            'Configuration setup failed. Please run "maxit config" manually.');
        exit(configExitCode ?? 1);
      }

      logger.success(
          'Configuration setup complete. Continuing with original command...');

      // Continue with the original command
      final exitCode = await runner.run(originalArgs);
      exit(exitCode ?? 0);
    } else {
      // Run the command normally
      final exitCode = await runner.run(args);
      exit(exitCode ?? 0);
    }
  } catch (e, stackTrace) {
    logger.err('$e\n$stackTrace');
    exit(1);
  }
}
