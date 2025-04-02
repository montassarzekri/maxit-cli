import 'package:maxit_cli/helpers/path_helper.dart';
import 'package:yaml/yaml.dart';

class MainConfig {
  final String kernelPath;
  final List<String> superAppsPaths;
  final String defaultSuperAppPath;
  final String remoteKernelRef;

  MainConfig({
    required this.kernelPath,
    required this.superAppsPaths,
    required this.defaultSuperAppPath,
    required this.remoteKernelRef,
  });

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
    buffer.writeln(
        '  Default Super App Relative Path to Kernel: $superAppRelativePathToKernel');
    return buffer.toString();
  }

  /// Converts the config to a Map that can be serialized to YAML
  Map<String, dynamic> toMap() {
    return {
      'kernelPath': kernelPath,
      'superAppsPaths': superAppsPaths,
      'defaultSuperAppPath': defaultSuperAppPath,
      'remoteKernelRef': remoteKernelRef,
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

    return yamlString.toString();
  }

  /// Creates a MainConfig from a YAML map
  factory MainConfig.fromMap(Map<String, dynamic> map) {
    final superAppsPaths = (map['superAppsPaths'] as List<dynamic>)
        .map((e) => e.toString())
        .toList();

    return MainConfig(
      kernelPath: map['kernelPath'] as String,
      superAppsPaths: superAppsPaths,
      defaultSuperAppPath: map['defaultSuperAppPath'] as String,
      remoteKernelRef: map['remoteKernelRef'] as String,
    );
  }

  /// Creates a MainConfig from a YAML string
  factory MainConfig.fromYaml(String yamlString) {
    final yamlMap = loadYaml(yamlString) as Map;
    final map = Map<String, dynamic>.from(yamlMap);

    return MainConfig.fromMap(map);
  }
}
