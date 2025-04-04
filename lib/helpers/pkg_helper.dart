import 'dart:io';
import 'package:mason_logger/mason_logger.dart';
import 'package:maxit_cli/helpers/path_helper.dart';
import 'package:maxit_cli/helpers/yaml_helper.dart';
import 'package:maxit_cli/maxit_cli.dart';
import 'package:path/path.dart' as path;
import 'package:yaml/yaml.dart';

abstract class PkgHelper {
  static final Logger _logger = Logger();

  static Future<List<String>> findFlutterPkgs(
      String monorepoRoot, String appsPath) async {
    final appDir = Directory(path.join(monorepoRoot, appsPath));
    final projectPaths = <String>[];

    // Directories to exclude from search
    final excludeDirs = [
      '.symlinks',
      '.dart_tool',
      '.idea',
      '.fvm',
      'build',
      '.git',
      'ios/Pods',
      'android/.gradle',
    ];

    if (!await appDir.exists()) {
      _logger.warn('🚫 Apps directory does not exist: ${appDir.path}');
      return projectPaths;
    }

    _logger.info('🔍 Scanning for Flutter projects in ${appDir.path}...');

    await for (final entity in appDir.list(recursive: true)) {
      if (entity is Directory) {
        // Skip excluded directories
        final dirName = path.basename(entity.path);
        final relativePath = path.relative(entity.path, from: appDir.path);

        // Check if this directory or any parent directory should be excluded
        bool shouldSkip = excludeDirs.any((exclude) =>
            relativePath.contains('/$exclude/') ||
            relativePath.endsWith('/$exclude'));

        if (shouldSkip) continue;

        // Check if it's a Flutter project
        final pubspecFile = File(path.join(entity.path, 'pubspec.yaml'));
        if (await pubspecFile.exists()) {
          final content = await pubspecFile.readAsString();
          if (content.contains('flutter:')) {
            _logger.success('✅ Found Flutter package: ${relativePath}');
            projectPaths.add(relativePath);
          }
        }
      }
    }

    if (projectPaths.isEmpty) {
      _logger.warn('⚠️  No Flutter projects found in $appsPath');
    } else {
      _logger.info('🎉 Found ${projectPaths.length} Flutter projects');
    }

    return projectPaths;
  }

  static Future<bool> switchEnv(
      {required String pkgPath, required DevEnv env}) async {
    try {
      _logger.info(
          'Switching ${path.basename(pkgPath)} to ${env.name} environment');

      final directory = Directory(pkgPath);
      if (!await directory.exists()) {
        _logger.err('Directory does not exist: $pkgPath');
        return false;
      }

      // Traverse the directory and process all pubspec.yaml files
      await _traverseDirectories(directory, env);

      _logger.success(
          '✅ Successfully switched ${path.basename(pkgPath)} to ${env.name} environment');
      return true;
    } catch (e) {
      _logger.err('Failed to switch environment: $e');
      return false;
    }
  }

  static Future<void> _processPubspecFile(
    File file,
    DevEnv devEnv,
  ) async {
    try {
      _logger.detail("Processing: ${file.path}");
      final contents = await file.readAsString();
      final originalYaml = loadYaml(contents);
      final yamlMap = YamlHelper.toMutable(originalYaml);

      if (yamlMap is Map && yamlMap.containsKey('dependencies')) {
        final dependencies = yamlMap['dependencies'];
        if (dependencies is Map) {
          // Work on a copy of keys since we may modify the map.
          final keys = dependencies.keys.toList();
          bool modified = false;

          for (final key in keys) {
            final value = dependencies[key];
            if (value is Map) {
              if (devEnv == DevEnv.local) {
                // Convert remote (git) dependency to local (path)
                if (value.containsKey('git')) {
                  final git = value['git'];
                  if (git is Map &&
                      git.containsKey('url') &&
                      git.containsKey('path')) {
                    final gitUrl = git['url'];
                    final gitPath = git['path'];

                    // Check if the git URL matches our configured remote path
                    // or just check if it has a URL and path (less restrictive)
                    if (gitUrl is String && gitPath is String) {
                      // Calculate the relative path from the pubspec.yaml file to the kernel path.
                      final relativePath = PathHelper.getRelativePath(
                        sourceDirectory: path.dirname(file.path),
                        targetDirectory: path.join(
                            ConfigManager().config!.kernelPath, gitPath),
                      );
                      dependencies[key] = {'path': relativePath};
                      _logger.detail(
                          "Updated dependency: $key to local path: $relativePath");
                      modified = true;
                    }
                  }
                }
              } else {
                // Revert local (path) dependency back to remote (git)
                if (value.containsKey('path')) {
                  final localPath = value['path'];
                  if (localPath is String) {
                    // Check if the path is relative and points to the kernel directory.
                    final absolutePath = path.normalize(
                        path.join(path.dirname(file.path), localPath));
                    if (absolutePath
                        .startsWith(ConfigManager().config!.kernelPath)) {
                      final relativePath = path.relative(absolutePath,
                          from: ConfigManager().config!.kernelPath);
                      dependencies[key] = {
                        'git': {
                          'url': getRemoteKernelPath(),
                          'path': relativePath,
                          'ref': ConfigManager().config!.remoteKernelRef,
                        }
                      };
                      _logger.detail("Reverted dependency: $key to remote");
                      modified = true;
                    }
                  }
                }
              }
            }
          }

          // Only write back to the file if we made changes
          if (modified) {
            final updatedContents = YamlHelper.yamlToString(yamlMap);
            await file.writeAsString(updatedContents);
            _logger.detail("Updated: ${file.path}");
          }
        }
      }
    } catch (e) {
      _logger.err("Error processing file ${file.path}: $e");
    }
  }

  static Future<void> _traverseDirectories(
      Directory directory, DevEnv devEnv) async {
    // Directories to exclude from traversal
    final excludeDirs = [
      '.symlinks',
      '.dart_tool',
      '.idea',
      '.fvm',
      'build',
      '.git',
      'ios/Pods',
      'android/.gradle',
      'ios',
      'android',
    ];

    try {
      await for (final entity in directory.list()) {
        if (entity is Directory) {
          final dirName = path.basename(entity.path);

          // Skip excluded directories
          if (excludeDirs.contains(dirName) || dirName.startsWith('.')) {
            continue;
          }

          await _traverseDirectories(entity, devEnv);
        } else if (entity is File && entity.path.endsWith('pubspec.yaml')) {
          await _processPubspecFile(entity, devEnv);
        }
      }
    } catch (e) {
      _logger.err("Error traversing directory ${directory.path}: $e");
    }
  }
}

enum DevEnv { local, remote }

String getRemoteKernelPath() {
  // Check if GITHUB_TOKEN environment variable exists
  final githubToken = Platform.environment['GITHUB_TOKEN'];
  const baseUrl = 'https://github.com/keyrustunisie/maxit-mobile-kernel.git';

  // If token exists, create authenticated URL
  if (githubToken != null && githubToken.isNotEmpty) {
    return 'https://$githubToken@github.com/keyrustunisie/maxit-mobile-kernel.git';
  }

  // Return unauthenticated URL as fallback
  return baseUrl;
}
