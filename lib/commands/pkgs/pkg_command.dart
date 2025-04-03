import 'dart:io';
import 'package:args/command_runner.dart';
import 'package:mason_logger/mason_logger.dart';
import 'package:maxit_cli/core/config/config_manager.dart';
import 'package:maxit_cli/helpers/pkg_helper.dart';
import 'package:path/path.dart' as path;

class PkgCommand extends Command<int> {
  final Logger _logger;
  final ConfigManager _configManager;

  PkgCommand(this._logger, this._configManager) {
    argParser.addFlag(
      'scan-kernel',
      abbr: 'k',
      help: 'Scan kernel directory for packages',
      negatable: false,
    );
    argParser.addFlag(
      'scan-superapp',
      abbr: 's',
      help: 'Scan super app directory for packages',
      negatable: false,
    );
  }

  @override
  String get description => "Project packages utilities";

  @override
  String get name => "pkg";

  @override
  Future<int> run() async {
    if (!_configManager.hasConfig || _configManager.config == null) {
      _logger.err(
          'No configuration found. Run "maxit config" first to set up the initial configuration.');
      return 1;
    }

    final args = argResults!;
    if (args.wasParsed('scan-kernel')) {
      return await scanForPkgs(FolderBase.kernel);
    } else if (args.wasParsed('scan-superapp')) {
      return await scanForPkgs(FolderBase.superApp);
    } else {
      _logger.info(
          'Please specify a scan option (--scan-kernel or --scan-superapp)');
      return 1;
    }
  }

  Future<int> scanForPkgs(FolderBase folderBase) async {
    _logger.info(
        'Scanning for packages in ${folderBase == FolderBase.kernel ? 'kernel' : 'super app'}...');

    final progress = _logger.progress('Scanning directories');

    try {
      if (folderBase == FolderBase.kernel) {
        final kernelPath = _configManager.config!.kernelPath;
        if (kernelPath.isEmpty) {
          progress.fail('Kernel path not configured');
          _logger
              .err('Kernel path is not configured. Run "maxit config" first.');
          return 1;
        }

        final packagesFound =
            await PkgHelper.findFlutterProjects(kernelPath, kernelPath);
        if (packagesFound.isEmpty) {
          progress.fail('No packages found');
          _logger.warn('No packages found in kernel directory.');
          return 1;
        }

        await _configManager.updateKernelPkgsPaths(packagesFound);
        progress.complete('Found ${packagesFound.length} packages');

        _logger.success('Found ${packagesFound.length} packages in kernel:');
        for (final pkg in packagesFound) {
          _logger.info('  • ${path.basename(pkg)}');
        }
      } else {
        final superAppPath = _configManager.config!.defaultSuperAppPath;
        if (superAppPath.isEmpty) {
          progress.fail('Super app path not configured');
          _logger.err(
              'Default super app path is not configured. Run "maxit config" first.');
          return 1;
        }

        final packagesFound =
            await PkgHelper.findFlutterProjects(superAppPath, superAppPath);
        if (packagesFound.isEmpty) {
          progress.fail('No packages found');
          _logger.warn('No packages found in super app directory.');
          return 1;
        }

        await _configManager.updateSuperAppPkgsPaths(packagesFound);
        progress.complete('Found ${packagesFound.length} packages');

        _logger.success('Found ${packagesFound.length} packages in super app:');
        for (final pkg in packagesFound) {
          _logger.info('  • ${path.basename(pkg)}');
        }
      }

      return 0;
    } catch (e) {
      progress.fail('Error scanning directories');
      _logger.err('Error during scan: $e');
      return 1;
    }
  }
}

enum FolderBase { kernel, superApp }
