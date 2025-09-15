# Auto Reflect - 自动Git工作日志生成器

一个Dart命令行工具，用于自动扫描用户Code文件夹中的所有Git项目，收集当天的提交记录并生成格式化的工作日志，支持AI智能分析。

## 功能特性

- 🔄 自动扫描Code文件夹中的所有Git项目
- 📅 按日期筛选提交记录
- 📝 生成Markdown格式的工作日志
- 📁 自动输出到Reflect文件夹
- 🎯 支持自定义文件夹路径
- 🔧 支持命令行参数配置
- 🤖 **新增** AI智能分析工作内容
- 🔍 **新增** 自动识别当前Git用户
- 🚫 **新增** 过滤Merge提交记录
- ⚙️ **新增** 配置AI服务设置

## 安装依赖

```bash
dart pub get
```

## 使用方法

### 基本使用

```bash
# 生成今天的工作日志（默认使用AI分析）
dart run bin/auto_reflect.dart

# 详细输出模式
dart run bin/auto_reflect.dart --verbose

# 不使用AI分析
dart run bin/auto_reflect.dart --no-ai

# 查看帮助信息
dart run bin/auto_reflect.dart --help
```

### AI配置

```bash
# 配置AI服务
dart run bin/auto_reflect.dart config

# 显示当前配置
dart run bin/auto_reflect.dart show-config
```

### 高级使用

```bash
# 指定特定日期
dart run bin/auto_reflect.dart --date 2024-01-15

# 自定义Code文件夹路径
dart run bin/auto_reflect.dart --code-dir /path/to/your/code

# 自定义Reflect输出文件夹
dart run bin/auto_reflect.dart --output-dir /path/to/output

# 组合使用多个参数
dart run bin/auto_reflect.dart --date 2024-01-15 --verbose --output-dir /path/to/logs
```

## 命令行参数

- `-h, --help`: 显示帮助信息
- `-v, --verbose`: 详细输出模式
- `--no-ai`: 不使用AI分析
- `--date`: 指定日期 (格式: YYYY-MM-DD)
- `--code-dir`: Code文件夹路径
- `--output-dir`: Reflect输出文件夹路径

## 命令

- `config`: 配置AI服务设置
- `show-config`: 显示当前配置

## AI分析功能

当配置了AI服务后，程序会自动分析您的Git提交记录，提供以下洞察：

1. **发现的小错误或问题**: 识别可能存在的问题或改进点
2. **下一个工作日最重要的任务**: 预测明天最需要处理的工作
3. **对客户或行业有益的事情**: 分析工作对业务的积极影响
4. **工作亮点**: 突出今天做得好的地方

## AI配置

配置AI服务时需要提供：
- **Base URL**: AI服务的API地址（如: https://api.openai.com/v1）
- **Model**: 使用的模型（如: gpt-3.5-turbo, gpt-4）
- **API Key**: API访问密钥

配置文件会保存在用户主目录的`.auto_reflect`文件中，并设置为仅用户可读写。

## 输出格式

生成的日志文件格式如下：

```markdown
# 工作日志 - 2024年01月15日

**总提交数**: 42
**涉及项目**: 3

## 项目1

- **09:30** 修复登录页面样式问题
- **10:15** 添加用户管理功能
- **14:20** 优化数据库查询性能

## 项目2

- **11:30** 重构代码结构
- **13:45** 添加新的API接口
```

## 默认路径

- **Code文件夹**: `~/Code`
- **Reflect文件夹**: `~/Reflect`
- **输出文件**: `~/Reflect/YYYY-MM-DD.md`

## 系统要求

- Dart SDK 3.0.0 或更高版本
- Git 命令行工具
- 访问用户主文件夹的权限

## 注意事项

1. 确保Code文件夹中的项目都是Git仓库
2. 程序会自动创建Reflect文件夹（如果不存在）
3. 每次运行会生成一个新的日志文件，文件名为日期格式
4. 如果当天没有提交记录，会显示相应的提示信息