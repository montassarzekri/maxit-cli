import 'package:args/command_runner.dart';
import 'package:mason_logger/mason_logger.dart';
import 'package:maxit_cli/core/config/config_manager.dart';
import 'package:maxit_cli/entities/main_config.dart';
import 'package:maxit_cli/helpers/path_helper.dart';
import 'package:maxit_cli/helpers/pkg_helper.dart';
import 'dart:io';
import 'package:path/path.dart' as path;
import 'dart:async';

class ConfigCommand extends Command<int> {
  final Logger _logger;
  final ConfigManager _configManager;

  @override
  String get description => "Manage CLI configuration";

  @override
  String get name => "config";

  ConfigCommand(this._logger, this._configManager) {
    // Options for setting paths
    argParser.addOption(
      'kernel-path',
      abbr: 'k',
      help: 'Path to the kernel directory or file',
      valueHelp: 'path',
    );

    argParser.addOption(
      'superapp-path',
      abbr: 's',
      help: 'Path to the super app directory or file',
      valueHelp: 'path',
    );

    // Flag for showing current config
    argParser.addFlag(
      'show',
      negatable: false,
      help: 'Show current configuration',
    );
    argParser.addFlag(
      'set',
      negatable: false,
      help: 'set configuration',
    );

    // Optional flag to reset config
    argParser.addFlag(
      'reset',
      negatable: false,
      help: 'Reset configuration',
    );
  }

  @override
  Future<int> run() async {
    final args = argResults!;

    // Show current config
    if (args['show'] as bool) {
      return await _showConfig();
    }

    // Reset config
    if (args['reset'] as bool) {
      return await _resetConfig();
    }
    if (args['set'] as bool) {
      return await _setConfig(args);
    }
    return 1;
    // Set new config if paths are provided or prompt for them
  }

  Future<int> _showConfig() async {
    try {
      final MaxitConfig? config = await _configManager.load();

      if (config == null) {
        _logger.info(
            'No configuration found. Use "maxit config --set" to set up configuration.');
        return 0;
      }
      await PkgHelper.findFlutterProjects(
        config.kernelPath,
        config.kernelPath,
      );

      return 0;
    } catch (e) {
      _logger.err('Error loading configuration: $e');
      return 1;
    }
  }

  Future<int> _resetConfig() async {
    try {
      await _configManager.deleteConfig();
      _logger.success('Configuration has been reset.');
      return 0;
    } catch (e) {
      _logger.err('Error resetting configuration: $e');
      return 1;
    }
  }

  Future<int> _setConfig(dynamic args) async {
    // Get kernel path - from arguments or prompt
    String? kernelPath = args['kernel-path'] as String?;

    if (kernelPath == null || kernelPath.isEmpty) {
      kernelPath = _logger.prompt('Enter the kernel path:');
    }

    // Expand tilde in path
    kernelPath = PathHelper.expandPath(kernelPath);

    // Validate kernel path
    if (!Directory(kernelPath).existsSync() && !File(kernelPath).existsSync()) {
      _logger.err('Error: Kernel path does not exist: $kernelPath');
      return 1;
    }

    // Get super app path - from arguments or prompt
    String? superAppPath = args['superapp-path'] as String?;

    if (superAppPath == null || superAppPath.isEmpty) {
      superAppPath = _logger.prompt('Enter the super app path:');
    }

    // Expand tilde in path
    superAppPath = PathHelper.expandPath(superAppPath);

    // Validate super app path
    if (!Directory(superAppPath).existsSync() &&
        !File(superAppPath).existsSync()) {
      _logger.err('Error: Super app path does not exist: $superAppPath');
      return 1;
    }

    // Store the configuration
    try {
      // Save using config manager
      await _configManager.saveConfig(kernelPath, superAppPath);

      _logger.success('Configuration added successfully!');
      _logger.info('Kernel path: $kernelPath');
      _logger.info('Super app path: $superAppPath');
      return 0;
    } catch (e) {
      _logger.err('Error saving configuration: $e');
      return 1;
    }
  }
}
