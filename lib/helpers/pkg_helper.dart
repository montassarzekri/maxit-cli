import 'dart:io';
import 'package:mason_logger/mason_logger.dart';
import 'package:path/path.dart' as path;

abstract class PkgHelper {
  static final Logger _logger = Logger();
  static Future<List<String>> findFlutterProjects(
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
}
