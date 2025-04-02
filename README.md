# maxit-cli

A lightweight command-line interface tool built with Dart to enhance Flutter development workflows.

## Installation

```bash
dart pub global activate --source git https://github.com/montassarzekri/maxit-cli.git
```

After installation, ensure that the Dart SDK's bin directory is in your PATH environment variable to access the CLI from anywhere.

## Requirements

- Dart SDK 2.12.0 or higher
- Flutter SDK (for Flutter-specific features)

## Available Commands

The CLI is built using the [args](https://pub.dev/packages/args) package in Dart, with the following commands:

### Help & Version

```bash
maxit --help    # Display help information
maxit --version # Display the current version
```

### Generate Commands

```bash
maxit generate [type] [name] [options]
```

Where `[type]` can be:
- `crud`: Generate CRUD operations for a model
- `model`: Generate a data model class
- `view`: Generate a view with optional controller

#### Options:

- `--output-dir`: Specify the output directory
- `--json-file`: Specify a JSON file for model generation
- `--fields`: Define fields for model generation

## Examples

Generate a user model:
```bash
maxit generate model User --fields="name:String,email:String,age:int"
```

Generate CRUD operations:
```bash
maxit generate crud User
```

Generate a view:
```bash
maxit generate view UserProfile
```

## Project Structure

```
lib/
├── commands/
│   ├── generate/
│   │   ├── crud_generator.dart
│   │   ├── model_generator.dart
│   │   └── view_generator.dart
│   └── generate_command.dart
├── templates/
│   ├── crud_template.dart
│   ├── model_template.dart
│   └── view_template.dart
├── utils/
│   └── string_utils.dart
└── main.dart
```

## Contributing Guide

### Setting Up Development Environment

1. **Clone the repository**
   ```bash
   git clone https://github.com/montassarzekri/maxit-cli.git
   cd maxit-cli
   ```

2. **Install dependencies**
   ```bash
   dart pub get
   ```

3. **Run in development mode**
   ```bash
   dart run bin/maxit.dart
   ```

### Development Workflow

1. **Create a feature branch**
   ```bash
   git checkout -b feature/your-feature-name
   ```

2. **Implement your changes**
   - Add new commands in the `lib/commands/` directory
   - Add templates in the `lib/templates/` directory
   - Update main command parser in `lib/main.dart`

3. **Adding a new command**
   - Create a new command class that extends `Command` from the `args` package
   - Register your command in the main command runner

   Example:
   ```dart
   class NewCommand extends Command {
     @override
     final name = 'new-command';
     
     @override
     final description = 'Description of your new command';
     
     @override
     void run() {
       // Implementation
     }
   }
   ```

4. **Testing your changes**
   - Write unit tests for your commands
   - Test manually by running the CLI with your new commands

5. **Submit a pull request**
   - Write a clear description of the changes
   - Reference any related issues

### Code Style Guidelines

- Follow the [Dart style guide](https://dart.dev/guides/language/effective-dart/style)
- Use meaningful variable and function names
- Add comments for complex logic
- Include documentation for public APIs

### Versioning

We use [semantic versioning](https://semver.org/). When updating the version:
- Increment major version for breaking changes
- Increment minor version for new features
- Increment patch version for bug fixes

## License

This project is licensed under the MIT License - see the LICENSE file for details.
