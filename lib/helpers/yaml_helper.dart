import 'package:yaml/yaml.dart';

abstract class YamlHelper {
  YamlHelper._();
  static dynamic toMutable(dynamic yaml) {
    if (yaml is YamlMap) {
      return yaml.map((k, v) => MapEntry(k, toMutable(v)));
    } else if (yaml is YamlList) {
      return yaml.map((v) => toMutable(v)).toList();
    }
    return yaml;
  }

  // Format YAML scalars safely.
  static String formatYamlValue(dynamic value) {
    if (value is String) {
      // If the string contains whitespace, a colon, quotes,
      // or starts with a special character, then quote it.
      if (value.isEmpty ||
          value.contains(RegExp(r'\s')) ||
          value.contains(':') ||
          value.contains('"') ||
          value.startsWith('>') ||
          value.startsWith('<') ||
          value.startsWith('-')) {
        final escaped = value.replaceAll(r'\', r'\\').replaceAll('"', r'\"');
        return '"$escaped"';
      } else {
        return value;
      }
    }
    return value.toString();
  }

  static String formatYamlKey(dynamic key) {
    if (key is String) {
      if (key.isEmpty ||
          key.contains(RegExp(r'\s')) ||
          key.contains(':') ||
          key.contains('"') ||
          key.startsWith('>') ||
          key.startsWith('<') ||
          key.startsWith('-')) {
        final escaped = key.replaceAll(r'\', r'\\').replaceAll('"', r'\"');
        return '"$escaped"';
      } else {
        return key;
      }
    }
    return key.toString();
  }

  static String yamlToString(dynamic data, [int indent = 0]) {
    final buffer = StringBuffer();
    final indentation = '  ' * indent;
    if (data is Map) {
      data.forEach((key, value) {
        final formattedKey = formatYamlKey(key);
        if (value is Map || value is List) {
          buffer.writeln('$indentation$formattedKey:');
          buffer.write(yamlToString(value, indent + 1));
        } else {
          buffer
              .writeln('$indentation$formattedKey: ${formatYamlValue(value)}');
        }
      });
    } else if (data is List) {
      for (final element in data) {
        if (element is Map || element is List) {
          buffer.writeln('$indentation-');
          buffer.write(yamlToString(element, indent + 1));
        } else {
          buffer.writeln('$indentation- ${formatYamlValue(element)}');
        }
      }
    } else {
      buffer.writeln('$indentation${formatYamlValue(data)}');
    }
    return buffer.toString();
  }
}
