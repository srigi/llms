# llms.ps1

A PowerShell wrapper script for `llama-server` that simplifies the process of listing and running `.gguf` models with comprehensive configuration management through environment variables and/or configuration file.

## Project intent

This script serves as an intelligent wrapper around `llama-server` that:
- **Simplifies model management**: Automatically discovers and runs GGUF models from configured directories
- **Provides flexible configuration**: Supports both environment variables and INI file for all parameters
- **Enables partial matching**: Find models using partial names without typing full filenames
- **Handles multi-modal models**: Automatically detects and loads companion `.mmproj-*.gguf` files
- **Offers dry-run capability**: Preview commands before execution
- **Maintains consistent defaults**: Fallback values ensure the script works out-of-the-box

## Basic usage

### List available Models
```powershell
llms list
```
![PowerShell terminal showcasing `llsm list` command](https://i.postimg.cc/507VKNvn/Clipboard01-1.png)

### Run a Model (required parameters)
```powershell
llms <partial_model_name> <context_size>
```

***Note**: `context_size` is now a **required parameter**.*

```powershell
llms Mistral-Small-3.1-24B-Instruct-2503-UD-Q4 64000
```
![PowerShell terminal showcasing `llsm <partial_model_name>` command](https://i.postimg.cc/jKNBKgzn/Clipboard01.png)

### Multi-modal Model support
The script automatically detects companion `.mmproj-*.gguf` files and adds appropriate parameters.

## Advanced usage

### Passing additional llama-server arguments
```powershell
llms <partial_model_name> <context_size> [llama-server args...]
```

Example with custom chat template:
```powershell
llms GLM-4-32B 24000 --chat-template-file C:\Users\srigi\llm\chat-template-chatml.jinja
```

### Dry-Run mode
Preview the command that would be executed without running it:
```powershell
llms Devstral-Small-2505-UD-Q4 100000 --no-webui --dry-run
```
![PowerShell terminal showcasing `llms with --dry-run option](https://i.postimg.cc/y8WYMYzg/Clipboard03.png)

## Configuration System

### Configuration Priority (Highest to Lowest)
1. **Environment Variables** (always override everything)
2. **llms.ini** in current directory
3. **llms.ini** in `%USERPROFILE%\AppData\Local`
4. **Fallback values** in code

### Environment Variables

All configuration options can be set via environment variables:

| Environment Variable | Description | Fallback Value |
|---------------------|-------------|----------------|
| `LLMS_MODELS_DIRS` | Model search directories (comma-separated) | *Required - no fallback* |
| `LLMS_HOST` | IP address for llama-server to bind to | `127.0.0.1` |
| `LLMS_PORT` | Port to listen on | `8080` |
| `LLMS_API_KEY` | API key for authentication | `secret` |
| `LLMS_CACHE_TYPE_K` | Cache type for K | `q8_0` |
| `LLMS_CACHE_TYPE_V` | Cache type for V | `q8_0` |
| `LLMS_UBATCH_SIZE` | Micro-batch size | `1024` |
| `LLMS_N_GPU_LAYERS` | Number of GPU layers | `999` |

### Configuration File (llms.ini)

The script looks for `llms.ini` in these locations (in order):
1. Current directory (`./llms.ini`)
2. User's local app data (`%USERPROFILE%\AppData\Local\llms.ini`)

#### llms.ini Format
```ini
# Model directories (comma-separated paths)
ModelsDirs = C:\path\to\models1,D:\path\to\models2

# Performance settings
CacheTypeK = q8_0
CacheTypeV = q8_0
UbatchSize = 1024
NGpuLayers = 99

# Network settings (can also be set via ENV)
# Host = 127.0.0.1
# Port = 8080
# ApiKey = secret
```

### Configuration Directives Reference

| INI Directive | Environment Variable | Description | Default |
|---------------|---------------------|-------------|---------|
| `ModelsDirs` | `LLMS_MODELS_DIRS` | Comma-separated list of model directories | *Required* |
| `CacheTypeK` | `LLMS_CACHE_TYPE_K` | Cache type for K tensors | `q8_0` |
| `CacheTypeV` | `LLMS_CACHE_TYPE_V` | Cache type for V tensors | `q8_0` |
| `UbatchSize` | `LLMS_UBATCH_SIZE` | Micro-batch size for processing | `1024` |
| `NGpuLayers` | `LLMS_N_GPU_LAYERS` | Number of layers to offload to GPU | `999` |
| `Host` | `LLMS_HOST` | Server bind address | `127.0.0.1` |
| `Port` | `LLMS_PORT` | Server port | `8080` |
| `ApiKey` | `LLMS_API_KEY` | API authentication key | `secret` |

## Configuration Examples

### Example 1: Environment Variables Only
```powershell
$env:LLMS_MODELS_DIRS = "C:\models,D:\ai-models"
$env:LLMS_PORT = "8081"
$env:LLMS_N_GPU_LAYERS = "50"
llms mistral 32000
```

### Example 2: Mixed Configuration
```ini
# llms.ini
ModelsDirs = C:\models,D:\ai-models
UbatchSize = 2048
NGpuLayers = 40
```

```powershell
# Override specific settings via ENV
$env:LLMS_PORT = "8081"  # This overrides any Port setting in llms.ini
llms mistral 32000
```

### Example 3: Complete llms.ini
```ini
# Model locations
ModelsDirs = C:\Users\username\models,D:\shared-models,E:\large-models

# Performance tuning
CacheTypeK = q8_0
CacheTypeV = q8_0
UbatchSize = 1024
NGpuLayers = 99

# Server settings
Host = 0.0.0.0
Port = 8080
ApiKey = my-secret-key
```

## Command Syntax

```powershell
llms list
llms <partial_model_name> <context_size> [llama-server args...] [--dry-run]
```

### Parameters
- `list`: List all available `.gguf` models in configured directories
- `<partial_model_name>`: Partial name to match against model files (case-insensitive)
- `<context_size>`: **Required** - Context window size for the model
- `[llama-server args...]`: Optional additional arguments passed to `llama-server`
- `[--dry-run]`: Preview the command without executing it

## Features

- **Smart model discovery**: Searches multiple directories for `.gguf` files
- **Partial name matching**: Find models without typing complete filenames
- **Multi-modal support**: Automatically loads companion `.mmproj-*.gguf` files
- **Flexible configuration**: Environment variables override INI file settings
- **Fallback defaults**: Works out-of-the-box with sensible defaults
- **Dry-run capability**: Preview commands before execution
- **Color-coded output**: Enhanced terminal display with syntax highlighting
- **Error handling**: Clear error messages for missing configurations and models
- **Cross-platform**: Works on Windows, Linux, and macOS with PowerShell Core

## Notes

- The script uses all available CPU threads automatically
- Flash attention is enabled by default for better performance
