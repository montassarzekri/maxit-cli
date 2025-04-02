import 'package:path/path.dart' as path;

class PathHelper {
  /// Calculates the relative path from the [sourceDirectory] to the [targetDirectory].
  ///
  /// Returns a path string that represents how to navigate from [sourceDirectory]
  /// to [targetDirectory].
  ///
  /// Example:
  /// ```dart
  /// // If sourceDirectory is '/home/user/projects'
  /// // and targetDirectory is '/home/user/documents/reports'
  /// // This will return '../documents/reports'
  /// final relativePath = getRelativePath(
  ///   sourceDirectory: '/home/user/projects',
  ///   targetDirectory: '/home/user/documents/reports'
  /// );
  /// ```
  static String getRelativePath(
      {required String sourceDirectory, required String targetDirectory}) {
    // Normalize both paths to handle any formatting inconsistencies
    final normalizedSource = path.normalize(sourceDirectory);
    final normalizedTarget = path.normalize(targetDirectory);

    // Calculate the relative path from source to target
    return path.relative(
      normalizedTarget,
      from: normalizedSource,
    );
  }
}
