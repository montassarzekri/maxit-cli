import 'package:args/command_runner.dart';
import 'package:mason_logger/mason_logger.dart';
import 'package:maxit_cli/core/config/config_manager.dart';

class ListProjectsCommand extends Command<int> {
  final Logger _logger;
  final ConfigManager _configManager;

  ListProjectsCommand(this._logger, this._configManager);

  @override
  String get description => 'List all Flutter projects in the monorepo';

  @override
  String get name => 'list-projects';

  @override
  Future<int> run() async {
    if (!_configManager.hasConfig) {
      _logger.err(
          'Configuration not found. Run "flutter_monorepo_cli init" first.');
      return 1;
    }

    //    _logger.info('Flutter projects in the monorepo:');
    // //   final projects = _configManager.projectPaths;

    //    if (projects.isEmpty) {
    //      _logger.info('No Flutter projects found.');
    //      return 0;
    //    }

    //    for (final project in projects) {
    //      _logger.info('  - $project');
    //    }

    return 0;
  }
}
