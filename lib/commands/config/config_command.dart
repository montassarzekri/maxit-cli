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

    // Reset config - check this first as it's destructive
    if (args['reset'] as bool) {
      return await _resetConfig();
    }

    // Set new config if requested
    if (args['set'] as bool) {
      return await _setConfig(args);
    }

    // Show config if explicitly requested or no other commands specified
    if (args['show'] as bool || _noCommandsSpecified(args)) {
      return await _showConfig();
    }

    // If we got here, show help
    _logger
        .info('No valid command specified. Use --help for available options.');
    return 1;
  }

  // Helper to check if no specific commands were given
  bool _noCommandsSpecified(dynamic args) {
    // Check if any action flags are set
    bool hasFlags =
        args['show'] as bool || args['set'] as bool || args['reset'] as bool;

    // Check if any options are provided
    bool hasOptions =
        (args['kernel-path'] != null && args['kernel-path'] != '') ||
            (args['superapp-path'] != null && args['superapp-path'] != '');

    // Return true if no flags or options were specified
    return !hasFlags && !hasOptions;
  }

  Future<int> _showConfig() async {
    try {
      final MaxitConfig? config = await _configManager.load();

      if (config == null) {
        _logger.info(
            'No configuration found. Use "maxit config --set" to set up configuration.');
        return 0;
      }

      // Display configuration details in a formatted way
      _logger.info('📋 Current Configuration:');
      _logger.info('-------------------------');
      _logger.info('🔷 Kernel Path: ${config.kernelPath}');
      _logger.info('🔷 Super App Path: ${config.defaultSuperAppPath}');

      if (config.remoteKernelPath.isNotEmpty) {
        _logger.info('🔷 Remote Kernel Path: ${config.remoteKernelPath}');
        _logger.info('🔷 Remote Kernel Ref: ${config.remoteKernelRef}');
      }

      if (config.kernelPkgsPaths.isNotEmpty) {
        _logger.info('📦 Kernel Packages (${config.kernelPkgsPaths.length})');
      }

      if (config.superAppPkgsPaths.isNotEmpty) {
        _logger
            .info('📦 Super App Packages (${config.superAppPkgsPaths.length})');
      }

      return 0;
    } catch (e) {
      _logger.err('Error loading configuration: $e');
      return 1;
    }
  }

  Future<int> _resetConfig() async {
    try {
      final confirm = _logger.confirm(
        '⚠️  Are you sure you want to reset all configuration?',
        defaultValue: false,
      );

      if (!confirm) {
        _logger.info('Reset cancelled.');
        return 0;
      }

      await _configManager.deleteConfig();
      _logger.success('✅ Configuration has been reset.');
      return 0;
    } catch (e) {
      _logger.err('Error resetting configuration: $e');
      return 1;
    }
  }

  Future<int> _setConfig(dynamic args) async {
    _logger.info('Setting up Maxit CLI configuration...');

    // Collect all required configuration in one go

    // 1. Get kernel path - from arguments or prompt
    String? kernelPath = args['kernel-path'] as String?;
    if (kernelPath == null || kernelPath.isEmpty) {
      kernelPath = _logger.prompt('Enter the kernel path:');
    }
    kernelPath = PathHelper.expandPath(kernelPath);

    // Validate kernel path
    if (!Directory(kernelPath).existsSync() && !File(kernelPath).existsSync()) {
      _logger.err('Error: Kernel path does not exist: $kernelPath');
      return 1;
    }

    // 2. Get super app path - from arguments or prompt
    String? superAppPath = args['superapp-path'] as String?;
    if (superAppPath == null || superAppPath.isEmpty) {
      superAppPath = _logger.prompt('Enter the super app path:');
    }
    superAppPath = PathHelper.expandPath(superAppPath);

    // Validate super app path
    if (!Directory(superAppPath).existsSync() &&
        !File(superAppPath).existsSync()) {
      _logger.err('Error: Super app path does not exist: $superAppPath');
      return 1;
    }

    // 3. Get remote kernel repository URL
    final remoteKernelPath = _logger.prompt(
      'Enter remote kernel repository URL:',
      defaultValue:
          'https://${Platform.environment['GITHUB_TOKEN']}@github.com/keyrustunisie/maxit-mobile-kernel.git',
    );

    // 4. Get remote kernel branch/reference
    final remoteKernelRef = _logger.prompt(
      'Enter remote kernel reference (branch/tag):',
      defaultValue: 'maxit-mobile-kernel_v4.1',
    );

    // Now save all collected configuration at once
    try {
      final progress = _logger.progress('Saving configuration');

      await _configManager.saveConfig(
        kernelPath: kernelPath,
        superAppPath: superAppPath,
        remoteKernelPath: remoteKernelPath,
        remoteKernelRef: remoteKernelRef,
      );

      progress.complete('Configuration saved successfully');

      _logger.success('✅ Configuration set successfully!');
      _logger.info('📂 Kernel path: $kernelPath');
      _logger.info('📂 Super app path: $superAppPath');
      _logger.info('🔗 Remote kernel: $remoteKernelPath ($remoteKernelRef)');

      // Ask if user wants to scan for packages now
      final scanNow = _logger.confirm(
        'Would you like to scan for packages now?',
        defaultValue: true,
      );

      if (scanNow) {
        // Scan kernel packages
        final kernelProgress = _logger.progress('Scanning kernel packages');
        try {
          final kernelPkgs =
              await PkgHelper.findFlutterPkgs(kernelPath, kernelPath);
          await _configManager.updateKernelPkgsPaths(kernelPkgs);
          kernelProgress.complete('Found ${kernelPkgs.length} kernel packages');
        } catch (e) {
          kernelProgress.fail('Failed to scan kernel packages');
          _logger.err('Error: $e');
        }

        // Scan super app packages
        final superAppProgress =
            _logger.progress('Scanning super app packages');
        try {
          final superAppPkgs =
              await PkgHelper.findFlutterPkgs(superAppPath, superAppPath);
          await _configManager.updateSuperAppPkgsPaths(superAppPkgs);
          superAppProgress
              .complete('Found ${superAppPkgs.length} super app packages');
        } catch (e) {
          superAppProgress.fail('Failed to scan super app packages');
          _logger.err('Error: $e');
        }
      }

      return 0;
    } catch (e) {
      _logger.err('Error saving configuration: $e');
      return 1;
    }
  }
}
