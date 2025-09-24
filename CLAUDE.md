# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## 项目概述

这是一个用 Dart 编写的 Git 工作日志自动生成工具，具有 AI 分析功能。工具扫描指定目录中的所有 Git 仓库，收集每日提交记录，并生成带有 AI 分析的综合工作报告。

## 常用命令

### 开发环境
```bash
# 安装依赖
dart pub get

# 运行代码分析
dart analyze

# 运行应用
dart run bin/auto_reflect.dart

# 全局激活（可选）
dart pub global activate --source path .
```

### 应用命令
```bash
# 生成今日工作日志（带 AI 分析）
journal reflect

# 详细输出模式
journal reflect --verbose

# 生成特定日期的工作日志
journal reflect --date 2024-01-15

# 禁用 AI 分析
journal reflect --no-ai

# 忽略指定的文件夹
journal reflect --ignore "temp,node_modules"

# 组合使用多个参数
journal reflect --ignore "temp,.git" --verbose

# 配置设置
journal config

# 显示当前配置
journal config --show

# 设置忽略文件夹
journal config --set-ignore "temp,node_modules,.git"

# 系统健康检查
journal doctor
```

## 架构概览

### 命令模式架构
项目使用 Dart 的 `args` 包实现命令模式，主要命令结构：
- `bin/auto_reflect.dart`: 主入口点，注册所有命令
- `lib/commands/`: 命令实现目录
  - `reflect_command.dart`: 核心功能，生成工作日志
  - `config_command.dart`: 配置管理命令
  - `doctor_command.dart`: 系统诊断命令
  - `version_command.dart`: 版本信息命令

### 服务层架构
业务逻辑分离到专门的服务：
- `lib/services/git_service.dart`: Git 操作服务，负责扫描仓库和获取提交记录，支持文件夹过滤
- `lib/services/generator.dart`: AI 分析服务，处理提交数据的智能分析
- `lib/services/report_service.dart`: 报告生成服务，创建格式化的 Markdown 报告

### 数据模型
- `lib/models/config.dart`: 配置模型，管理 AI 服务设置和路径配置
- `lib/models/git_commit.dart`: Git 提交数据模型
- `lib/models/ai_analysis.dart`: AI 分析结果数据模型

### 工具类
- `lib/utils/logger.dart`: 日志记录工具
- `lib/utils/file_utils.dart`: 文件操作工具

## 核心功能流程

### 工作日志生成流程
1. **初始化**：加载配置并初始化 Git 服务
2. **扫描项目**：遍历代码目录，识别 Git 仓库，支持文件夹过滤
3. **获取提交记录**：按日期和用户筛选提交，过滤合并提交
4. **AI 分析**：可选的智能分析，提供工作模式和洞察
5. **生成报告**：创建包含统计和分析的 Markdown 报告

### 文件夹忽略功能
- **Ignore 功能**：使用 `--ignore` 参数或配置文件中的 `ignore` 设置来跳过指定文件夹
- **实现位置**：`lib/commands/reflect_command.dart:110-130` - `_mergeIgnoreLists` 方法实现合并逻辑
- **合并逻辑**：
  - `lib/commands/reflect_command.dart:195` - 合并配置文件和命令行的 ignore 设置
  - `lib/commands/reflect_command.dart:201-210` - 根据合并后的 ignore 列表分离项目
  - 支持去重和自动过滤空格
- **过滤逻辑**：被忽略的项目不会出现在 AI 分析和最终报告中，但会在统计中显示为 "(ignored)"

### 配置管理
- 配置文件位置：`~/.auto_reflect.yaml`
- 支持的配置项：API 密钥、基础 URL、AI 模型、代码目录、输出目录、忽略文件夹
- 配置优先级：命令行参数 > 配置文件 > 默认值

## 技术特点

### Git 集成
- 自动发现指定目录下的所有 Git 仓库
- 支持文件夹忽略功能，可跳过不需要扫描的项目
- 按日期范围筛选提交记录
- 支持按作者筛选，自动识别当前 Git 用户
- 自动过滤合并提交记录

### AI 分析能力
- 支持任何 OpenAI 兼容的 AI 服务
- 多维度分析：错误识别、任务规划、影响分析、问题发现、学习跟踪
- 智能提取工作模式和改进建议

### 报告生成
- 生成结构化的 Markdown 报告
- 按项目分组显示提交统计
- 支持 Conventional Commits 格式的提交类型分析
- 集成 AI 分析结果和工作洞察

## 依赖管理

### 主要依赖
- `args`: 命令行参数解析
- `process_run`: 进程执行（用于 Git 命令）
- `yaml`: YAML 配置文件解析
- `openai_dart`: OpenAI API 客户端
- `cli_spin`: CLI 加载动画
- `intl`: 国际化和日期格式化

### 开发依赖
- `lints`: Dart 代码风格检查
- `test`: 单元测试框架

## 配置文件格式

```yaml
# Journal CLI Configuration
api_key: your-api-key
base_url: https://api.openai.com/v1
model: gpt-4o
code_dir: /Users/username/Code
output_dir: /Users/username/Reflect
ignore: temp,node_modules,.git
```

## 待实现功能

### 测试覆盖
- **当前状态**：项目中未发现测试文件
- **建议**：为核心服务（GitService、Config、ReportService）添加单元测试
- **测试框架**：使用 Dart 内置的 `test` 包

## 开发注意事项

### 代码风格
- 遵循 Dart 官方代码风格
- 使用 `dart analyze` 进行静态代码分析
- 项目配置了 `lints` 包进行代码质量检查

### 错误处理
- 使用 `handleError` 和 `showSuccess` 函数统一处理命令行输出
- 所有命令都包含适当的错误处理和用户友好的错误信息

### 配置验证
- `Config` 类包含配置验证逻辑
- `doctor` 命令用于检查系统配置和连接状态