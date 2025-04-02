import 'dart:io';
import 'package:maxit_cli/entiies/main_config.dart';
import 'package:path/path.dart' as path;

class ConfigManager {
  static const String configFileName = 'config.yaml';

  // Singleton pattern implementation
  static final ConfigManager _instance = ConfigManager._internal();

  factory ConfigManager() => _instance;

  // Initialize paths in the constructor
  ConfigManager._internal() {
    _initConfigPaths();
  }

  MainConfig? _config;
  late Directory _configDir;
  late File _configFile;
  bool _initialized = false;

  /// Whether a configuration is currently loaded
  bool get hasConfig => _config != null;

  /// The current configuration
  MainConfig? get config => _config;

  /// Initialize the config directory and file path
  void _initConfigPaths() {
    if (_initialized) return;

    final homeDir = _getHomeDirectory();
    _configDir = Directory(path.join(homeDir, '.config', 'maxit_cli'));
    _configFile = File(path.join(_configDir.path, configFileName));
    _initialized = true;
  }

  /// Get home directory path for current platform
  String _getHomeDirectory() {
    if (Platform.isWindows) {
      return Platform.environment['USERPROFILE'] ?? '';
    } else {
      return Platform.environment['HOME'] ?? '';
    }
  }

  /// Ensure config directory exists
  Future<void> _ensureConfigDirExists() async {
    if (!await _configDir.exists()) {
      await _configDir.create(recursive: true);
    }
  }

  /// Loads configuration from disk
  Future<MainConfig?> load() async {
    await _ensureConfigDirExists();

    if (!await _configFile.exists()) {
      return null;
    }

    try {
      final yamlString = await _configFile.readAsString();
      _config = MainConfig.fromYaml(yamlString);
      return _config;
    } catch (e) {
      // Log error instead of printing
      return null;
    }
  }

  /// Deletes configuration file
  Future<void> deleteConfig() async {
    await _ensureConfigDirExists();

    if (await _configFile.exists()) {
      await _configFile.delete();
    }
    _config = null;
  }

  /// Saves configuration to disk
  Future<void> save({MainConfig? config}) async {
    await _ensureConfigDirExists();

    if (_config == null && config == null) {
      throw Exception('Cannot save: No configuration loaded');
    }

    if (config != null) {
      _config = config;
    }

    final configYaml = _config!.toYaml();
    await _configFile.writeAsString(configYaml);
  }

  /// Adds a super app path to configuration
  ///
  /// If [setAsDefault] is true, this super app will be set as the default
  Future<void> addSuperAppPath(String superAppPath,
      {bool setAsDefault = false}) async {
    final normalizedPath = path.normalize(superAppPath);

    // Initialize config if needed
    if (_config == null) {
      await load();
    }

    // Create initial config if none exists
    if (_config == null) {
      _config = MainConfig(
        kernelPath: '',
        superAppsPaths: [normalizedPath],
        defaultSuperAppPath: setAsDefault ? normalizedPath : '',
        remoteKernelRef: 'origin/main',
      );
    } else {
      // Get current super apps list
      final superAppsList = List<String>.from(_config!.superAppsPaths);

      // Add if not already present
      if (!superAppsList.contains(normalizedPath)) {
        superAppsList.add(normalizedPath);
      }

      // Determine default based on existing config and setAsDefault parameter
      String defaultPath = _config!.defaultSuperAppPath;
      if (setAsDefault || defaultPath.isEmpty) {
        defaultPath = normalizedPath;
      }

      // Update config
      _config = MainConfig(
        kernelPath: _config!.kernelPath,
        superAppsPaths: superAppsList,
        defaultSuperAppPath: defaultPath,
        remoteKernelRef: _config!.remoteKernelRef,
      );
    }

    await save();
  }

  /// Saves kernel and super app paths
  Future<void> saveConfig(String kernelPath, String superAppPath) async {
    final normalizedKernelPath = path.normalize(kernelPath);

    // Add the super app path first
    await addSuperAppPath(superAppPath,
        setAsDefault: _config?.defaultSuperAppPath?.isEmpty ?? true);

    // Update kernel path
    _config = MainConfig(
      kernelPath: normalizedKernelPath,
      superAppsPaths: _config!.superAppsPaths,
      defaultSuperAppPath: _config!.defaultSuperAppPath,
      remoteKernelRef: _config!.remoteKernelRef ?? 'origin/main',
    );

    await save();
  }

  /// Sets a super app as the default
  Future<void> setDefaultSuperApp(String superAppPath) async {
    if (_config == null) {
      await load();
      if (_config == null) {
        throw Exception('Cannot set default: No configuration loaded');
      }
    }

    final normalizedPath = path.normalize(superAppPath);

    // Verify the path exists in our list
    if (!_config!.superAppsPaths.contains(normalizedPath)) {
      throw Exception('Super app path does not exist in configuration');
    }

    _config = MainConfig(
      kernelPath: _config!.kernelPath,
      superAppsPaths: _config!.superAppsPaths,
      defaultSuperAppPath: normalizedPath,
      remoteKernelRef: _config!.remoteKernelRef,
    );

    await save();
  }

  /// Updates remote kernel reference
  Future<void> updateRemoteKernelRef(String remoteRef) async {
    if (_config == null) {
      await load();
      if (_config == null) {
        throw Exception('Cannot update: No configuration loaded');
      }
    }

    _config = MainConfig(
      kernelPath: _config!.kernelPath,
      superAppsPaths: _config!.superAppsPaths,
      defaultSuperAppPath: _config!.defaultSuperAppPath,
      remoteKernelRef: remoteRef,
    );

    await save();
  }
}
