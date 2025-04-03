import 'dart:io';
import 'package:args/command_runner.dart';
import 'package:mason_logger/mason_logger.dart';
import 'package:maxit_cli/core/config/config_manager.dart';
import 'package:path/path.dart' as path;

class InitCommand extends Command<int> {
  final Logger _logger;
  final ConfigManager _configManager;

  InitCommand(this._logger, this._configManager) {
    argParser
      ..addOption(
        'monorepo-root',
        abbr: 'r',
        help: 'Path to the monorepo root',
        //  mandatory: true,
      )
      ..addOption(
        'apps-path',
        help: 'Relative path to the apps directory',
        //  mandatory: true,
      )
      ..addOption(
        'shared-modules-path',
        help: 'Relative path to the shared modules',
      );
  }

  @override
  String get description =>
      'Initialize the CLI configuration for your monorepo';

  @override
  String get name => 'init';

  @override
  Future<int> run() async {
    _logger.info('Initializing Flutter monorepo CLI...');

    final monorepoRoot = argResults?['monorepo-root'] as String;
    final appsPath = argResults?['apps-path'] as String;
    final sharedModulesPath = argResults?['shared-modules-path'] as String;

    // Update config with provided values
    // _configManager.updateConfig('monorepoRoot', monorepoRoot);
    // _configManager.updateConfig('appsPath', appsPath);
    // _configManager.updateConfig('sharedModulesPath', sharedModulesPath);

    // // Detect Flutter projects
    // _logger.info('Scanning for Flutter projects...');
    // final projectPaths = await _findFlutterProjects(monorepoRoot, appsPath);
    // _configManager.updateConfig('projectPaths', projectPaths);

    // Save the config
    await _configManager.save();

    _logger.success('Configuration saved!');
    // _logger.info('Found ${projectPaths.length} Flutter projects:');
    // for (final project in projectPaths) {
    //   _logger.info('  - $project');
    // }

    return 0;
  }
}
