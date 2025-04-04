import 'dart:io';
import 'package:mason_logger/mason_logger.dart';
import 'package:maxit_cli/entities/main_config.dart';
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

  MaxitConfig? _config;
  late Directory _configDir;
  late File _configFile;
  bool _initialized = false;

  /// Whether a configuration is currently loaded
  bool get hasConfig => _config != null;

  /// The current configuration
  MaxitConfig? get config => _config;

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
  Future<MaxitConfig?> load() async {
    await _ensureConfigDirExists();

    if (!await _configFile.exists()) {
      return null;
    }

    try {
      final yamlString = await _configFile.readAsString();
      _config = MaxitConfig.fromYaml(yamlString);
      return _config;
    } catch (e, stk) {
      Logger().err("Error loading config $e,$stk");
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
  Future<void> save({MaxitConfig? config}) async {
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
      _config = MaxitConfig(
        kernelPath: '',
        superAppsPaths: [normalizedPath],
        defaultSuperAppPath: setAsDefault ? normalizedPath : '',
        remoteKernelRef: 'origin/main',
        defaultEditor: "",
        kernelPkgsPaths: [],
        superAppPkgsPaths: [],
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
      _config = MaxitConfig(
        kernelPath: _config!.kernelPath,
        superAppsPaths: superAppsList,
        defaultSuperAppPath: defaultPath,
        remoteKernelRef: _config!.remoteKernelRef,
        defaultEditor: _config!.defaultEditor,
        kernelPkgsPaths: _config!.kernelPkgsPaths,
        superAppPkgsPaths: _config!.superAppPkgsPaths,
      );
    }

    await save();
  }

  /// Saves kernel and super app paths
  Future<void> saveConfig({
    required String kernelPath,
    required String superAppPath,
    String remoteKernelPath = '',
    String remoteKernelRef = 'main',
  }) async {
    final normalizedKernelPath = path.normalize(kernelPath);

    // Add the super app path first
    await addSuperAppPath(superAppPath,
        setAsDefault: _config?.defaultSuperAppPath?.isEmpty ?? true);

    // Update all config values at once
    _config = MaxitConfig(
      kernelPath: normalizedKernelPath,
      superAppsPaths: _config!.superAppsPaths,
      defaultSuperAppPath: _config!.defaultSuperAppPath,
      remoteKernelPath: remoteKernelPath.isNotEmpty
          ? remoteKernelPath
          : (_config!.remoteKernelPath ?? ''),
      remoteKernelRef: remoteKernelRef.isNotEmpty
          ? remoteKernelRef
          : (_config!.remoteKernelRef ?? 'main'),
      defaultEditor: _config!.defaultEditor ?? '',
      kernelPkgsPaths: _config!.kernelPkgsPaths ?? [],
      superAppPkgsPaths: _config!.superAppPkgsPaths ?? [],
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

    _config = MaxitConfig(
      kernelPath: _config!.kernelPath,
      superAppsPaths: _config!.superAppsPaths,
      defaultSuperAppPath: normalizedPath,
      remoteKernelRef: _config!.remoteKernelRef,
      defaultEditor: _config!.defaultEditor,
      kernelPkgsPaths: _config!.kernelPkgsPaths ?? [],
      superAppPkgsPaths: _config!.superAppPkgsPaths ?? [],
    );

    await save();
  }

  /// Updates remote kernel reference
  Future<void> updateDefaultEditor(String defaultEditor) async {
    if (_config == null) {
      await load();
      if (_config == null) {
        throw Exception('Cannot update: No configuration loaded');
      }
    }

    _config = MaxitConfig(
      kernelPath: _config!.kernelPath,
      superAppsPaths: _config!.superAppsPaths,
      defaultSuperAppPath: _config!.defaultSuperAppPath,
      remoteKernelRef: _config!.remoteKernelRef,
      defaultEditor: defaultEditor,
      kernelPkgsPaths: _config!.kernelPkgsPaths ?? [],
      superAppPkgsPaths: _config!.superAppPkgsPaths ?? [],
    );

    await save();
  }

  Future<void> updateRemoteKernelRef(String remoteRef) async {
    if (_config == null) {
      await load();
      if (_config == null) {
        throw Exception('Cannot update: No configuration loaded');
      }
    }

    _config = MaxitConfig(
      kernelPath: _config!.kernelPath,
      superAppsPaths: _config!.superAppsPaths,
      defaultSuperAppPath: _config!.defaultSuperAppPath,
      remoteKernelRef: remoteRef,
      defaultEditor: _config!.defaultEditor,
      kernelPkgsPaths: _config!.kernelPkgsPaths ?? [],
      superAppPkgsPaths: _config!.superAppPkgsPaths ?? [],
    );

    await save();
  }

  /// Updates kernel packages paths in configuration
  Future<void> updateKernelPkgsPaths(List<String> kernelPkgsPaths) async {
    // Initialize config if needed
    if (_config == null) {
      await load();
      if (_config == null) {
        throw Exception(
            'Cannot update kernel packages paths: No configuration loaded');
      }
    }

    // Normalize all paths
    final normalizedPaths =
        kernelPkgsPaths.map((p) => path.normalize(p)).toList();

    // Update config
    _config = MaxitConfig(
      kernelPath: _config!.kernelPath,
      superAppsPaths: _config!.superAppsPaths,
      defaultSuperAppPath: _config!.defaultSuperAppPath,
      remoteKernelRef: _config!.remoteKernelRef,
      defaultEditor: _config!.defaultEditor,
      kernelPkgsPaths: normalizedPaths,
      superAppPkgsPaths: _config!.superAppPkgsPaths ?? [],
    );

    await save();
  }

  /// Updates super app packages paths in configuration
  Future<void> updateSuperAppPkgsPaths(List<String> superAppPkgsPaths) async {
    // Initialize config if needed
    if (_config == null) {
      await load();
      if (_config == null) {
        throw Exception(
            'Cannot update super app packages paths: No configuration loaded');
      }
    }

    // Normalize all paths
    final normalizedPaths =
        superAppPkgsPaths.map((p) => path.normalize(p)).toList();

    // Update config
    _config = MaxitConfig(
      kernelPath: _config!.kernelPath,
      superAppsPaths: _config!.superAppsPaths,
      defaultSuperAppPath: _config!.defaultSuperAppPath,
      remoteKernelRef: _config!.remoteKernelRef,
      defaultEditor: _config!.defaultEditor,
      kernelPkgsPaths: _config!.kernelPkgsPaths ?? [],
      superAppPkgsPaths: normalizedPaths,
    );

    await save();
  }

  /// Adds a kernel packages path to the existing list
  Future<void> addKernelPkgsPath(String kernelPkgsPath) async {
    // Initialize config if needed
    if (_config == null) {
      await load();
      if (_config == null) {
        throw Exception(
            'Cannot add kernel packages path: No configuration loaded');
      }
    }

    final normalizedPath = path.normalize(kernelPkgsPath);
    final currentPaths = List<String>.from(_config!.kernelPkgsPaths ?? []);

    // Add if not already present
    if (!currentPaths.contains(normalizedPath)) {
      currentPaths.add(normalizedPath);
    }

    await updateKernelPkgsPaths(currentPaths);
  }

  /// Adds a super app packages path to the existing list
  Future<void> addSuperAppPkgsPath(String superAppPkgsPath) async {
    // Initialize config if needed
    if (_config == null) {
      await load();
      if (_config == null) {
        throw Exception(
            'Cannot add super app packages path: No configuration loaded');
      }
    }

    final normalizedPath = path.normalize(superAppPkgsPath);
    final currentPaths = List<String>.from(_config!.superAppPkgsPaths ?? []);

    // Add if not already present
    if (!currentPaths.contains(normalizedPath)) {
      currentPaths.add(normalizedPath);
    }

    await updateSuperAppPkgsPaths(currentPaths);
  }
}
