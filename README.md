# Journal - Automatic Git Work Log Generator

A sophisticated Dart command-line tool that automatically scans all Git projects in your code directory, collects daily commit records, and generates comprehensive work logs with AI-powered analysis.

## Features

### Core Functionality
- 🔍 **Automatic Scanning**: Intelligently scans all Git repositories in your code directory
- 📅 **Date Filtering**: Filters commit records by specific date and author
- 📝 **Markdown Reports**: Generates beautifully formatted work logs in Markdown
- 📁 **Smart Output**: Automatically saves reports to your designated output directory
- 🎯 **Flexible Paths**: Supports custom code and output directory paths
- 🚫 **Folder Ignore**: Smart filtering to skip specific folders during scanning

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
- 🔀 **Ignore Merging**: Intelligently merges configuration file and command-line ignore settings

## Installation

### macOS (Homebrew)

```bash
# Add the tap repository
brew tap CalsRanna/tap

# Install the CLI
brew install journal
```

### Windows (Scoop)

```powershell
# Add the bucket repository
scoop bucket add scoop-bucket https://github.com/CalsRanna/scoop-bucket

# Install the CLI
scoop install journal
```

### Build from Source

```bash
git clone https://github.com/CalsRanna/auto_reflect.git
cd auto_reflect
dart pub get
./compile.sh  # Outputs build/journal
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

With AI enabled, all commit diffs from each project are sent together in one
request. AI combines related commits into work items describing the project's
completed work; the number of items is independent of the commit count.
Project summary generation is attempted up to three times if a
request fails or returns incomplete output, with an increased output-token
budget. A failed project does not stop processing other projects. If any projects
still fail, the command exits with an error and does not write or overwrite the
report. Original commit messages are used only when `--no-ai` is explicitly set.

Report section content has hard character limits: work summary 9999; learnings,
highlights, and mistakes 999 each; next tasks 400; customer/industry benefits 2000.
The section heading is excluded; spaces, newlines, Markdown bullets, and project
subheadings are included. Prompts request concise output, and any remaining
overflow is shortened with an ellipsis when the report is written.

With AI enabled, Friday reports prioritize identifying at least one mistake or
failure grounded in the work. If no evidence-based entry is generated, that
section is omitted, other content is saved normally, and a warning is printed
after completion. This section is optional on other days. The rule uses the report
date (including `--date`) and does not read historical reports.

### Folder Ignore Feature

```bash
# Ignore specific folders (comma-separated)
journal reflect --ignore "temp,node_modules,.git"

# Combine with other options
journal reflect --ignore "temp,node_modules" --verbose

# Set ignore folders in configuration
journal config --set-ignore "temp,node_modules,.git"
```

**Ignore Logic**:
- Command-line `--ignore` parameter and configuration file `ignore` setting are automatically merged
- Duplicate entries are automatically removed
- Spaces in folder names are automatically trimmed
- Ignored projects are shown in statistics but excluded from AI analysis and final reports

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

# Set ignore folders
journal config --set-ignore "temp,node_modules,.git"

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
ignore:
  - temp
  - node_modules
  - .git
```

### Advanced Usage

```bash
# Generate work log for specific date
journal reflect --date 2024-01-15

# Use custom code directory (one-time)
journal reflect --code-dir /path/to/custom/code

# Use custom output directory (one-time)
journal reflect --output-dir /path/to/custom/output

# Combine multiple options with ignore
journal reflect --date 2024-01-15 --verbose --ignore "temp,.git" --code-dir /custom/code
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
- `--ignore <folders>`: Comma-separated list of folders to ignore

**Examples**:
```bash
journal reflect
journal reflect --verbose
journal reflect --date 2024-12-17
journal reflect --no-ai --code-dir ~/Projects
journal reflect --ignore "temp,node_modules"
```

### config Command
**Purpose**: Configure AI service settings

**Options**:
- `--set-api-key <key>`: Set API key
- `--set-base-url <url>`: Set API base URL
- `--set-model <model>`: Set AI model
- `--set-code-directory <path>`: Set default code directory
- `--set-output-directory <path>`: Set default output directory
- `--set-ignore <folders>`: Set default ignore folders (comma-separated)
- `--show`: Display current configuration

**Examples**:
```bash
journal config
journal config --show
journal config --set-api-key "sk-..."
journal config --set-model "claude-3-sonnet-20240229"
journal config --set-ignore "temp,node_modules,.git"
```

### doctor Command
**Purpose**: Check configuration and connection status

**Examples**:
```bash
journal doctor
journal doctor -v
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

### AI Analysis Prompt

The tool uses a sophisticated engineering-focused prompt that:
- Analyzes commit records from a professional software development consultant perspective
- Uses concise, objective tone avoiding self-praise and exaggeration
- Returns structured JSON format with 5 analysis categories
- Handles empty results gracefully with empty arrays

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

### Ignore Folder Processing
- **Merging Strategy**: Command-line ignore and configuration ignore are merged with automatic deduplication
- **Format Processing**: Comma-separated values with automatic space trimming
- **Display**: Ignored projects appear in statistics with "(ignored)" marker but are excluded from AI analysis

### Environment Variables
The tool respects standard environment variables:
- `HOME`: User home directory (Unix/Linux)
- `USERPROFILE`: User profile directory (Windows)

## Technical Details

### Architecture
- **Command Pattern**: Modular command structure using Dart's `args` package
- **Service Layer**: Separated business logic into dedicated services:
  - `GitService`: Git operations and repository scanning
  - `Generator`: AI analysis and commit processing
  - `ReportService`: Markdown report generation
- **Configuration Management**: YAML-based configuration with validation
- **Error Handling**: Comprehensive error handling with user-friendly messages

### Project Structure
```
lib/
├── commands/           # Command implementations
│   ├── reflect_command.dart    # Main work log generation
│   ├── config_command.dart     # Configuration management
│   ├── doctor_command.dart     # System health checks
│   └── version_command.dart    # Version information
├── services/           # Business logic services
│   ├── git_service.dart        # Git repository operations
│   ├── generator.dart          # AI analysis processing
│   └── report_service.dart     # Report generation
├── models/             # Data models
│   ├── config.dart            # Configuration data model
│   ├── git_commit.dart        # Git commit data model
│   └── ai_analysis.dart       # AI analysis results
└── utils/              # Utility functions
    ├── logger.dart            # Logging utilities
    └── file_utils.dart        # File system operations
```

### Dependencies
- `args ^2.6.0`: Command-line argument parsing
- `cli_spin ^1.0.1`: CLI loading animations
- `http ^1.2.2`: HTTP client for API communication
- `openai_dart ^0.4.5`: OpenAI API client
- `process_run ^1.2.2`: Process execution for Git commands
- `yaml ^3.1.2`: YAML configuration parsing
- `intl ^0.18.1`: Internationalization and date formatting
- `path ^1.8.3`: Path manipulation utilities

### Key Implementation Details

#### Git Integration
- **Repository Discovery**: Scans code directory for `.git` folders recursively
- **Commit Filtering**: Filters by date, author, and excludes merge commits
- **User Detection**: Automatically detects current Git user configuration
- **Format Extraction**: Uses `git log --pretty=format:` for structured data extraction

#### Ignore System
- **Smart Merging**: Combines configuration and command-line ignore settings
- **Efficient Filtering**: Filters projects before AI analysis and report generation
- **Visual Feedback**: Shows ignored projects in statistics with clear marking

#### AI Analysis
- **Structured Output**: Enforces JSON response format for reliable parsing
- **Error Resilience**: Gracefully handles JSON parsing failures
- **Professional Tone**: Engineering-focused prompt for objective analysis
- **Context Preservation**: Includes project context in AI analysis

## Report Format

Generated reports follow this structure:

```markdown
# Reflect Today - YYYY/MM/dd

## Work Summary

### Project1
- Commit message 1
- Commit message 2

### Project2
- Commit message 3

## What did I learn for the purpose of future winning...
- Learning point 1
- Learning point 2

## Things at work or in the industry that are strange...
- Issue observation 1
- Issue observation 2

[Other AI analysis sections...]
```

## Troubleshooting

### Common Issues

1. **"No Git commits found today"**
   - Ensure you have made commits on the specified date
   - Verify the code directory path is correct
   - Check Git repository initialization

2. **"AI configuration is invalid or missing"**
   - Run `journal config` to set up AI service
   - Verify API key and service URL are correct
   - Check network connectivity with `journal doctor`

3. **"Code directory does not exist"**
   - Create the directory or update the configuration
   - Use `--code-dir` to specify an alternative path

4. **Git Command Failures**
   - Ensure Git is installed and accessible
   - Verify repository permissions
   - Check for corrupted Git repositories

5. **Ignore Folders Not Working**
   - Verify folder names match exactly (case-sensitive)
   - Check that ignore setting is saved in configuration
   - Use `journal config --show` to verify ignore settings

### Debug Mode
Use `--verbose` flag to see detailed processing information and debug issues.

### Health Check
Run `journal doctor` to verify:
- API configuration validity
- Network connectivity to AI service
- Configuration file integrity
- Ignore folder settings

## Development

### Adding New Features
1. Follow the established command pattern in `lib/commands/`
2. Add new services in `lib/services/` for business logic
3. Create appropriate data models in `lib/models/`
4. Update configuration schema if needed
5. Add comprehensive error handling

### Testing
- Use `dart analyze` for static code analysis
- Test with various Git repository configurations
- Verify ignore functionality with different folder patterns
- Test AI analysis with different commit patterns

## License

This project is licensed under the MIT License - see the LICENSE file for details.

## Support

For issues, questions, or feature requests, please use the project's issue tracker or contact the maintainers directly.
