import 'dart:io';
import 'package:maxit_cli/helpers/path_helper.dart';
import 'package:maxit_cli/helpers/pkg_helper.dart';
import 'package:path/path.dart' as path;
import 'package:args/command_runner.dart';
import 'package:mason_logger/mason_logger.dart';
import 'package:maxit_cli/core/config/config_manager.dart';

class SuperappCommand extends Command<int> {
  final Logger _logger;
  final ConfigManager _configManager;

  @override
  String get description => "Manage super apps";

  @override
  String get name => "sp";

  SuperappCommand(this._logger, this._configManager) {
    argParser.addOption(
      'add',
      abbr: 'a',
      help: 'Add a super app at the specified path',
      valueHelp: 'path',
    );

    argParser.addFlag(
      'default',
      abbr: 'd',
      help:
          'Set as the default super app when adding or switch to select default super app',
      negatable: false,
    );

    argParser.addFlag(
      'list',
      abbr: 'l',
      help: 'List all configured super apps',
      negatable: false,
    );
  }

  @override
  Future<int> run() async {
    // Check if configuration exists
    if (!_configManager.hasConfig || _configManager.config == null) {
      _logger.err(
          'No configuration found. Run "maxit config" first to set up the initial configuration.');
      return 1;
    }

    final args = argResults!;
    final addPath = args['add'] as String?;
    final setDefault = args['default'] as bool;
    final listApps = args['list'] as bool;

    // List super apps
    if (listApps) {
      return _listSuperApps();
    }

    // Add a new super app
    if (addPath != null && addPath.isNotEmpty) {
      return _addSuperApp(addPath, setDefault);
    }

    // Set default super app (if no add path is provided but default flag is set)
    if (setDefault) {
      return _setDefaultSuperApp();
    }

    // If no specific action is specified, show the current configuration
    return _listSuperApps();
  }

  Future<int> _addSuperApp(String superAppPath, bool setAsDefault) async {
    // Expand tilde in path
    superAppPath = PathHelper.expandPath(superAppPath);

    // Check if the path already exists in configuration
    if (_configManager.config!.superAppsPaths.contains(superAppPath)) {
      _logger.warn(
          'Super app path already exists in configuration: $superAppPath');

      // If user wants to set as default, do that
      if (setAsDefault) {
        await _configManager.setDefaultSuperApp(superAppPath);
        _logger.success('Set as default super app: $superAppPath');
      }

      return 0;
    }

    // Validate super app path
    if (!Directory(superAppPath).existsSync() &&
        !File(superAppPath).existsSync()) {
      _logger.err('Error: Super app path does not exist: $superAppPath');
      return 1;
    }

    try {
      // Get the existing kernel path
      final kernelPath = _configManager.config!.kernelPath;

      // Calculate relative path for information
      String relativePath = PathHelper.getRelativePath(
          sourceDirectory: superAppPath, targetDirectory: kernelPath);
      _logger.info("SuperApp relative path to kernel: $relativePath");

      // Add the super app to configuration
      await _configManager.addSuperAppPath(superAppPath,
          setAsDefault: setAsDefault);

      _logger.success('Super app added successfully!');
      _logger.info('Super app path: $superAppPath');
      if (setAsDefault) {
        _logger.info('Set as default super app');
      }

      return 0;
    } catch (e) {
      _logger.err('Error adding super app: $e');
      return 1;
    }
  }

  Future<int> _setDefaultSuperApp() async {
    final superAppPaths = _configManager.config!.superAppsPaths;

    if (superAppPaths.isEmpty) {
      _logger.err(
          'No super apps configured. Add a super app first with "maxit sp --add=<path>".');
      return 1;
    }

    // Show the current default
    final currentDefault = _configManager.config!.defaultSuperAppPath;
    if (currentDefault.isNotEmpty) {
      _logger.info('Current default super app: $currentDefault');
    } else {
      _logger.info('No default super app set.');
    }

    // Display list of super apps for selection
    _logger.info('Available super apps:');
    for (var i = 0; i < superAppPaths.length; i++) {
      final isDefault = superAppPaths[i] == currentDefault;
      final indicator = isDefault ? '(default)' : '';
      _logger.info('${i + 1}. ${superAppPaths[i]} $indicator');
    }

    // Prompt for selection
    final selection = _logger.prompt(
      'Select default super app (1-${superAppPaths.length}):',
      defaultValue: '1',
    );

    try {
      final index = int.parse(selection) - 1;
      if (index < 0 || index >= superAppPaths.length) {
        _logger.err(
            'Invalid selection. Please choose a number between 1 and ${superAppPaths.length}.');
        return 1;
      }

      final selectedPath = superAppPaths[index];
      await _configManager.setDefaultSuperApp(selectedPath);
      _logger.success('Set default super app to: $selectedPath');
      await PkgHelper.scanSuperAppPackages(
          _configManager.config!.defaultSuperAppPath);
      return 0;
    } catch (e) {
      _logger.err('Invalid selection. Please enter a valid number.');
      return 1;
    }
  }

  int _listSuperApps() {
    final superAppPaths = _configManager.config!.superAppsPaths;
    final currentDefault = _configManager.config!.defaultSuperAppPath;

    if (superAppPaths.isEmpty) {
      _logger.info('No super apps configured.');
      return 0;
    }

    _logger.info('Configured super apps:');
    for (var i = 0; i < superAppPaths.length; i++) {
      final isDefault = superAppPaths[i] == currentDefault;
      final indicator = isDefault ? '(default)' : '';
      _logger.info('• ${superAppPaths[i]} $indicator');
    }

    return 0;
  }
}
