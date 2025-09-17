# Journal - Automatic Git Work Log Generator

A sophisticated Dart command-line tool that automatically scans all Git projects in your code directory, collects daily commit records, and generates comprehensive work logs with AI-powered analysis.

## Features

### Core Functionality
- 🔍 **Automatic Scanning**: Intelligently scans all Git repositories in your code directory
- 📅 **Date Filtering**: Filters commit records by specific date or author
- 📝 **Markdown Reports**: Generates beautifully formatted work logs in Markdown
- 📁 **Smart Output**: Automatically saves reports to your designated output directory
- 🎯 **Flexible Paths**: Supports custom code and output directory paths

### AI-Powered Insights
- 🤖 **Intelligent Analysis**: Uses AI to analyze your commit patterns and work habits
- 🧠 **Multi-dimensional Insights**: Provides comprehensive analysis across 5 key areas:
  - **Errors & Issues**: Identify small mistakes and areas for improvement
  - **Task Planning**: Predict important tasks for the next work day
  - **Impact Analysis**: Analyze beneficial work for customers and industry
  - **Problem Identification**: Highlight strange or troubling issues encountered
  - **Learning Tracking**: Track new tools, methods, and successful experiments

### Advanced Features
- ⚙️ **Configuration Management**: Flexible configuration with CLI and interactive setup
- 🔧 **Command-line Interface**: Full-featured CLI with extensive options
- 🚫 **Merge Filtering**: Automatically filters out merge commit records
- 👤 **User Recognition**: Automatically identifies Git user across repositories
- 📊 **Comprehensive Reporting**: Detailed statistics and project breakdowns

## Installation

### Prerequisites
- Dart SDK 3.5.4 or higher
- Git command line tools
- Access to user home directory for configuration

### Setup
```bash
# Clone or navigate to project directory
cd /path/to/auto_reflect

# Install dependencies
dart pub get

# Activate globally (optional)
dart pub global activate --source path .
```

## Usage

### Basic Usage

```bash
# Generate today's work log with AI analysis
journal reflect

# Verbose output for detailed processing information
journal reflect --verbose

# Generate log without AI analysis
journal reflect --no-ai

# Show help information
journal --help

# Show version information
journal --version
```

### Configuration

#### Interactive Setup
```bash
# Start interactive configuration wizard
journal config
```

#### Command-line Configuration
```bash
# Set API key
journal config --set-api-key "your-api-key-here"

# Set AI service base URL
journal config --set-base-url "https://api.openai.com/v1"

# Set AI model
journal config --set-model "gpt-4o"

# Set custom code directory
journal config --set-code-directory "/custom/path/to/code"

# Set custom output directory
journal config --set-output-directory "/custom/path/to/output"

# Display current configuration
journal config --show
```

#### Configuration File Format
The configuration is saved as `~/.auto_reflect.yaml`:

```yaml
# Journal CLI Configuration
api_key: your-api-key
base_url: https://api.openai.com/v1
model: gpt-4o
code_dir: /Users/username/Code
output_dir: /Users/username/Reflect
```

### Advanced Usage

```bash
# Generate work log for specific date
journal reflect --date 2024-01-15

# Use custom code directory (one-time)
journal reflect --code-dir /path/to/custom/code

# Use custom output directory (one-time)
journal reflect --output-dir /path/to/custom/output

# Combine multiple options
journal reflect --date 2024-01-15 --verbose --no-ai --code-dir /custom/code
```

### System Health Check

```bash
# Check configuration and network connectivity
journal doctor
```

## Command Reference

### Global Options
- `-h, --help`: Show help information
- `-v, --version`: Print version information

### reflect Command
**Purpose**: Generate daily Git work log

**Options**:
- `-v, --verbose`: Enable verbose output mode
- `--no-ai`: Disable AI analysis
- `--date <YYYY-MM-DD>`: Specify analysis date
- `--code-dir <path>`: Override code directory path
- `--output-dir <path>`: Override output directory path

**Examples**:
```bash
journal reflect
journal reflect --verbose
journal reflect --date 2024-12-17
journal reflect --no-ai --code-dir ~/Projects
```

### config Command
**Purpose**: Configure AI service settings

**Options**:
- `--set-api-key <key>`: Set API key
- `--set-base-url <url>`: Set API base URL
- `--set-model <model>`: Set AI model
- `--set-code-directory <path>`: Set default code directory
- `--set-output-directory <path>`: Set default output directory
- `--show`: Display current configuration

**Examples**:
```bash
journal config
journal config --show
journal config --set-api-key "sk-..."
journal config --set-model "claude-3-sonnet-20240229"
```

### doctor Command
**Purpose**: Check configuration and connection status

**Examples**:
```bash
journal doctor
```

## AI Analysis

The AI analysis provides comprehensive insights into your work patterns:

### Analysis Categories

1. **Errors and Issues**
   - Small mistakes made during development
   - Areas for improvement in workflow
   - Common pitfalls to avoid

2. **Next Important Tasks**
   - Priority tasks for the following work day
   - Upcoming deadlines and milestones
   - Blocking issues that need resolution

3. **Beneficial Work**
   - Features and improvements that help customers
   - Industry contributions and best practices
   - Business value created by your work

4. **Work Highlights**
   - Unusual or interesting challenges encountered
   - Industry trends and observations
   - Troubleshooting complex problems

5. **Learnings and Growth**
   - New tools and technologies mastered
   - Successful experiments and approaches
   - Knowledge gained for future success

### AI Service Requirements

The tool supports any AI service with OpenAI-compatible API:
- **OpenAI**: GPT-3.5, GPT-4, GPT-4o, etc.
- **Anthropic Claude**: Via OpenAI-compatible endpoints
- **Local Models**: Through local AI services
- **Other Providers**: Any OpenAI-compatible API

## Configuration

### Default Paths
- **Configuration File**: `~/.auto_reflect.yaml`
- **Code Directory**: `~/Code` (default)
- **Output Directory**: `~/Reflect` (default)
- **Report Files**: `~/Reflect/YYYY-MM-DD.md`

### Configuration Priority
1. Command-line arguments (highest priority)
2. Configuration file settings
3. Default values (lowest priority)

### Environment Variables
The tool respects standard environment variables:
- `HOME`: User home directory (Unix/Linux)
- `USERPROFILE`: User profile directory (Windows)

## Technical Details

### Architecture
- **Command Pattern**: Modular command structure using Dart's `args` package
- **Service Layer**: Separated business logic into dedicated services
- **Configuration Management**: YAML-based configuration with validation
- **Error Handling**: Comprehensive error handling and user-friendly messages

### Dependencies
- `args ^2.6.0`: Command-line argument parsing
- `cli_spin ^1.0.1`: CLI loading animations
- `http ^1.2.2`: HTTP client for API communication
- `openai_dart ^0.4.5`: OpenAI API client
- `package_info_plus ^8.1.1`: Package information
- `process_run ^1.2.2`: Process execution for Git commands
- `yaml ^3.1.2`: YAML configuration parsing
- `intl ^0.18.1`: Internationalization and date formatting
- `path ^1.8.3`: Path manipulation utilities

### Supported Git Operations
- Repository discovery in directory trees
- Commit history extraction by date and author
- Merge commit filtering
- User email/author recognition
- Branch-aware commit analysis

## Troubleshooting

### Common Issues

1. **"No Git commits found today"**
   - Ensure you have made commits on the specified date
   - Verify the code directory path is correct
   - Check Git repository initialization

2. **"AI configuration is invalid or missing"**
   - Run `journal config` to set up AI service
   - Verify API key and service URL are correct
   - Check network connectivity

3. **"Code directory does not exist"**
   - Create the directory or update the configuration
   - Use `--code-dir` to specify an alternative path

4. **Git Command Failures**
   - Ensure Git is installed and accessible
   - Verify repository permissions
   - Check for corrupted Git repositories

### Debug Mode
Use `--verbose` flag to see detailed processing information and debug issues.

## Contributing

This project is designed to be extensible and maintainable. When contributing:

1. Follow the established command pattern
2. Maintain separation of concerns
3. Add comprehensive error handling
4. Update documentation for new features
5. Test thoroughly across different environments

## License

This project is licensed under the MIT License - see the LICENSE file for details.

## Support

For issues, questions, or feature requests, please use the project's issue tracker or contact the maintainers directly.