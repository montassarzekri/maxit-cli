import 'dart:io';
import 'package:maxit_cli/helpers/path_helper.dart';
import 'package:path/path.dart' as path;
import 'package:args/command_runner.dart';
import 'package:mason_logger/mason_logger.dart';
import 'package:maxit_cli/core/config/config_manager.dart';

class AddSuperAppCommand extends Command<int> {
  final Logger _logger;
  final ConfigManager _configManager;

  @override
  String get description => "Add a super app to the existing configuration";

  @override
  String get name => "add-superapp";

  AddSuperAppCommand(this._logger, this._configManager) {
    argParser.addOption(
      'path',
      abbr: 'p',
      help: 'Path to the super app directory',
      valueHelp: 'path',
    );

    argParser.addFlag(
      'default',
      abbr: 'd',
      help: 'Set as the default super app',
      negatable: false,
    );
  }

  /// Expands the tilde (~) in the path to the home directory

  @override
  Future<int> run() async {
    // Check if configuration exists
    if (!_configManager.hasConfig || _configManager.config == null) {
      _logger.err(
          'No configuration found. Run "maxit config" first to set up the initial configuration.');
      return 1;
    }

    final args = argResults!;

    // Get super app path from arguments or prompt
    String? superAppPath = args['path'] as String?;

    if (superAppPath == null || superAppPath.isEmpty) {
      superAppPath = _logger.prompt('Enter the super app path:');
    }

    // Expand tilde in path
    superAppPath = PathHelper.expandPath(superAppPath);

    // Check if the path already exists in configuration
    if (_configManager.config!.superAppsPaths.contains(superAppPath)) {
      _logger.warn(
          'Super app path already exists in configuration: $superAppPath');

      // If user wants to set as default, do that
      // if (args['default'] == true) {
      //   await _configManager.setDefaultSuperApp(superAppPath);
      //   _logger.success('Set as default super app: $superAppPath');
      // }

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
      // final currentSuperApps = _configManager.config!.superAppsPaths;
      // final updatedSuperApps = [...currentSuperApps, superAppPath];

      // // Determine default super app
      // String defaultSuperApp = _configManager.config!.defaultSuperAppPath;
      // if (args['default'] == true || defaultSuperApp.isEmpty) {
      //   defaultSuperApp = superAppPath;
      // }

      // // Create updated config and save
      // final updatedConfig = MainConfig(
      //   kernelPath: kernelPath,
      //   superAppsPaths: updatedSuperApps,
      //   defaultSuperAppPath: defaultSuperApp,
      //   remoteKernelRef: _configManager.config!.remoteKernelRef,
      // );
      await _configManager.addSuperAppPath(superAppPath,
          setAsDefault: args['default']);
      // Save the updated config
      //   await _configManager.save(config: updatedConfig);

      _logger.success('Super app added successfully!');
      _logger.info('Super app path: $superAppPath');
      if (args['default'] == true) {
        _logger.info('Set as default super app');
      }

      return 0;
    } catch (e) {
      _logger.err('Error adding super app: $e');
      return 1;
    }
  }
}
