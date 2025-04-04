import 'dart:io';

import 'package:maxit_cli/helpers/path_helper.dart';
import 'package:yaml/yaml.dart';

class MaxitConfig {
  final String kernelPath;
  final List<String> superAppsPaths;
  final String defaultSuperAppPath;
  final String remoteKernelRef;
  final String defaultEditor;
  final List<String> kernelPkgsPaths;
  final List<String> superAppPkgsPaths;
  final String remoteKernelPath;

  MaxitConfig({
    required this.kernelPath,
    required this.superAppsPaths,
    required this.defaultSuperAppPath,
    required this.remoteKernelRef,
    required this.defaultEditor,
    required this.kernelPkgsPaths,
    required this.superAppPkgsPaths,
    String? remoteKernelPath,
  }) : remoteKernelPath = remoteKernelPath ?? getRemoteKernelPath();

  static String getRemoteKernelPath() {
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

  String get superAppRelativePathToKernel => PathHelper.getRelativePath(
      sourceDirectory: defaultSuperAppPath, targetDirectory: kernelPath);

  @override
  String toString() {
    final buffer = StringBuffer();
    buffer.writeln('Configuration:');
    buffer.writeln('  Kernel Path: $kernelPath');
    buffer.writeln('  Super Apps:');
    for (final path in superAppsPaths) {
      buffer.writeln(
          '    - $path${path == defaultSuperAppPath ? ' (default)' : ''}');
    }
    buffer.writeln('  Remote Kernel Reference: $remoteKernelRef');
    buffer.writeln('  Default Editor: $defaultEditor');
    buffer.writeln(
        '  Default Super App Relative Path to Kernel: $superAppRelativePathToKernel');
    buffer.writeln('  Kernel Packages Paths:');
    for (final path in kernelPkgsPaths) {
      buffer.writeln('    - $path');
    }
    buffer.writeln('  Super App Packages Paths:');
    for (final path in superAppPkgsPaths) {
      buffer.writeln('    - $path');
    }

    // Don't print the actual URL with token for security reasons
    buffer.writeln('  Remote Kernel Path: [Repository URL configured]');

    return buffer.toString();
  }

  /// Converts the config to a Map that can be serialized to YAML
  Map<String, dynamic> toMap() {
    return {
      'kernelPath': kernelPath,
      'superAppsPaths': superAppsPaths,
      'defaultSuperAppPath': defaultSuperAppPath,
      'remoteKernelRef': remoteKernelRef,
      'defaultEditor': defaultEditor,
      'kernelPkgsPaths': kernelPkgsPaths,
      'superAppPkgsPaths': superAppPkgsPaths,
      // Don't include the authenticated URL in the serialized config
      'remoteKernelPath':
          'https://github.com/keyrustunisie/maxit-mobile-kernel.git',
    };
  }

  /// Converts the config to a YAML string
  String toYaml() {
    final map = toMap();
    final yamlString = StringBuffer();

    yamlString.writeln('kernelPath: ${map['kernelPath']}');

    yamlString.writeln('superAppsPaths:');
    for (final path in map['superAppsPaths']) {
      yamlString.writeln('  - $path');
    }

    yamlString.writeln('defaultSuperAppPath: ${map['defaultSuperAppPath']}');
    yamlString.writeln('remoteKernelRef: ${map['remoteKernelRef']}');
    yamlString.writeln('defaultEditor: ${map['defaultEditor']}');

    yamlString.writeln('kernelPkgsPaths:');
    for (final path in map['kernelPkgsPaths']) {
      yamlString.writeln('  - $path');
    }

    yamlString.writeln('superAppPkgsPaths:');
    for (final path in map['superAppPkgsPaths']) {
      yamlString.writeln('  - $path');
    }

    yamlString.writeln('remoteKernelPath: ${map['remoteKernelPath']}');

    return yamlString.toString();
  }

  /// Creates a MainConfig from a YAML map
  factory MaxitConfig.fromMap(Map<String, dynamic> map) {
    final superAppsPaths = (map['superAppsPaths'] as List<dynamic>)
        .map((e) => e.toString())
        .toList();

    final kernelPkgsPaths = map['kernelPkgsPaths'] != null
        ? (map['kernelPkgsPaths'] as List<dynamic>)
            .map((e) => e.toString())
            .toList()
        : <String>[];

    final superAppPkgsPaths = map['superAppPkgsPaths'] != null
        ? (map['superAppPkgsPaths'] as List<dynamic>)
            .map((e) => e.toString())
            .toList()
        : <String>[];

    // When loading from config, use the base URL and let the constructor apply the token
    final baseRemoteKernelPath = map['remoteKernelPath'] as String? ??
        'https://github.com/keyrustunisie/maxit-mobile-kernel.git';

    return MaxitConfig(
      kernelPath: map['kernelPath'] as String,
      superAppsPaths: superAppsPaths,
      defaultSuperAppPath: map['defaultSuperAppPath'] as String,
      remoteKernelRef: map['remoteKernelRef'] as String,
      defaultEditor: map['defaultEditor'] as String? ?? "",
      kernelPkgsPaths: kernelPkgsPaths,
      superAppPkgsPaths: superAppPkgsPaths,
      remoteKernelPath: baseRemoteKernelPath,
    );
  }

  /// Creates a MainConfig from a YAML string
  factory MaxitConfig.fromYaml(String yamlString) {
    final yamlMap = loadYaml(yamlString) as Map;
    final map = Map<String, dynamic>.from(yamlMap);

    return MaxitConfig.fromMap(map);
  }
}
