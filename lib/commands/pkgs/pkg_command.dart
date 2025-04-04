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
    argParser.addFlag(
      'use-local',
      abbr: 'l',
      help: 'Switch to use local dependencies',
      negatable: false,
    );
    argParser.addFlag(
      'use-remote',
      abbr: 'r',
      help: 'Switch to use remote dependencies',
      negatable: false,
    );
    argParser.addFlag(
      'all',
      abbr: 'a',
      help: 'Apply operation to all packages in kernel and super app',
      negatable: false,
    );
    argParser.addOption(
      'package',
      abbr: 'p',
      help: 'Specify package to operate on',
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
    } else if (args.wasParsed('use-local') || args.wasParsed('use-remote')) {
      final env = args.wasParsed('use-local') ? DevEnv.local : DevEnv.remote;

      if (args.wasParsed('all')) {
        return await switchAllPkgsEnv(env);
      } else {
        return await switchPkgEnv(env, args['package'] as String?);
      }
    } else {
      _logger.info(
          'Please specify an option (--scan-kernel, --scan-superapp, --use-local, or --use-remote)');
      return 1;
    }
  }

  Future<int> switchAllPkgsEnv(DevEnv env) async {
    _logger.info('Switching all packages to ${env.name} environment...');
    final progress = _logger.progress('Processing packages');

    try {
      final config = _configManager.config!;
      int successCount = 0;
      int failureCount = 0;

      // Process kernel packages
      if (config.kernelPkgsPaths.isNotEmpty) {
        for (final relativePath in config.kernelPkgsPaths) {
          final pkgPath = relativePath.startsWith('/')
              ? relativePath
              : '${config.kernelPath}/$relativePath';

          final packageName = path.basename(pkgPath);
          _logger.detail('Processing kernel package: $packageName');

          final success = await PkgHelper.switchEnv(pkgPath: pkgPath, env: env);
          if (success) {
            successCount++;
          } else {
            failureCount++;
            _logger.warn('Failed to switch $packageName');
          }
        }
      }

      // Process super app packages
      if (config.superAppPkgsPaths.isNotEmpty) {
        for (final relativePath in config.superAppPkgsPaths) {
          final pkgPath = relativePath.startsWith('/')
              ? relativePath
              : '${config.defaultSuperAppPath}/$relativePath';

          final packageName = path.basename(pkgPath);
          _logger.detail('Processing super app package: $packageName');

          final success = await PkgHelper.switchEnv(pkgPath: pkgPath, env: env);
          if (success) {
            successCount++;
          } else {
            failureCount++;
            _logger.warn('Failed to switch $packageName');
          }
        }
      }

      if (failureCount == 0) {
        progress.complete('All packages processed successfully');
        _logger.success(
            'Successfully switched $successCount packages to ${env.name} mode');
        return 0;
      } else {
        progress.complete('Processed with some failures');
        _logger.warn(
            'Switched $successCount packages successfully, $failureCount packages failed');
        return 1;
      }
    } catch (e) {
      progress.fail('Error switching environments');
      _logger.err('Error: $e');
      return 1;
    }
  }

  Future<int> switchPkgEnv(DevEnv env, String? packageName) async {
    if (packageName == null || packageName.isEmpty) {
      _logger.err('Please specify a package using --package or -p');
      return 1;
    }

    _logger.info('Switching $packageName to ${env.name} environment...');
    final progress = _logger.progress('Processing package dependencies');

    try {
      // First, determine if this is a kernel or superapp package
      final config = _configManager.config!;
      String? pkgPath;

      // Look in kernel packages
      for (final path in config.kernelPkgsPaths) {
        if (path.endsWith(packageName) || path.contains('/$packageName/')) {
          pkgPath = path.startsWith('/') ? path : '${config.kernelPath}/$path';
          break;
        }
      }

      // If not found, look in superapp packages
      if (pkgPath == null) {
        for (final path in config.superAppPkgsPaths) {
          if (path.endsWith(packageName) || path.contains('/$packageName/')) {
            pkgPath = path.startsWith('/')
                ? path
                : '${config.defaultSuperAppPath}/$path';
            break;
          }
        }
      }

      if (pkgPath == null) {
        progress.fail('Package not found');
        _logger.err('Package "$packageName" not found in configured packages');
        return 1;
      }

      final success = await PkgHelper.switchEnv(pkgPath: pkgPath, env: env);
      if (success) {
        progress.complete('Switched environment successfully');
        _logger
            .success('Package "$packageName" is now set to ${env.name} mode');
        return 0;
      } else {
        progress.fail('Failed to switch environment');
        _logger.err('Failed to switch environment for "$packageName"');
        return 1;
      }
    } catch (e) {
      progress.fail('Error switching environment');
      _logger.err('Error: $e');
      return 1;
    }
  }

  Future<int> scanForPkgs(FolderBase folderBase) async {
    // Existing implementation...
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
            await PkgHelper.findFlutterPkgs(kernelPath, kernelPath);
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
            await PkgHelper.findFlutterPkgs(superAppPath, superAppPath);
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
