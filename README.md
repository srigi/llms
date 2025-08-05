# LLMS Wrapper Scripts

Cross-platform wrapper scripts for [`llama-server`](https://github.com/ggml-org/llama.cpp/releases) that simplify the process of listing and running `.gguf` models with comprehensive configuration management through environment variables and/or configuration files.

**Available Scripts:**
- **`llms.ps1`** - PowerShell script for Windows, Linux, and macOS (PowerShell Core)
- **`llms`** - Bash script for UNIX systems (Linux, macOS, WSL)

## Project intent

This script serves as an intelligent wrapper around `llama-server` that:
- **Simplifies model management**: Automatically discovers and runs GGUF models from configured directories
- **Provides flexible configuration**: Supports both environment variables and INI file for all parameters
- **Enables partial matching**: Find models using partial names without typing full filenames
- **Handles multi-modal models**: Automatically detects and loads companion `.mmproj-*.gguf` files
- **Offers dry-run capability**: Preview commands before execution
- **Maintains consistent defaults**: Fallback values ensure the script works out-of-the-box

## Features

- **Cross-platform support**: PowerShell script for Windows, bash script for UNIX systems
- **Smart model discovery**: Searches multiple directories for `.gguf` files
- **Partial name matching**: Find models without typing complete filenames
- **Multi-modal support**: Automatically loads companion `.mmproj-*.gguf` files
- **Flexible configuration**: Environment variables override INI file settings with platform-appropriate paths
- **Fallback defaults**: Works out-of-the-box with sensible defaults
- **Dry-run capability**: Preview commands before execution
- **Color-coded output**: Enhanced terminal display with syntax highlighting
- **Error handling**: Clear error messages for missing configurations and models
- **Configuration priority**: Script directory configs override user configs

## Basic usage

Both scripts share identical command syntax and functionality.

### Parameters
- `list`: List all available `.gguf` models in configured directories
- `<partial_model_name>`: Partial name to match against model files (case-insensitive)
- `<context_size>`: **Required** - Context window size for the model
- `[llama-server args...]`: Optional additional arguments passed to `llama-server`
- `[--dry-run]`: Preview the command without executing it

### List available Models

```bash
llms list
```

![Terminal showcasing `llms list` command](https://i.postimg.cc/507VKNvn/Clipboard01-1.png)

### Run a Model (required parameters)

```bash
llms <partial_model_name> <context_size>
```

**example:**
```bash
llms Mistral-Small-3.1-24B-Instruct-2503-UD-Q4 64000
```

![Terminal showcasing `llms <partial_model_name>` command](https://i.postimg.cc/jKNBKgzn/Clipboard01.png)

### Multi-modal Model support
The script automatically detects companion `.mmproj-*.gguf` files and adds appropriate parameters.

## Advanced usage

### Passing additional llama-server arguments
```bash
llms <partial_model_name> <context_size> [llama-server args...]
```

**example with custom chat template:**

```bash
llms GLM-4-32B 24000 --chat-template-file ~/llm/chat-template-chatml.jinja
```

### Dry-Run mode
Preview the command that would be executed without running it:
```bash
llms Devstral-Small-2505-UD-Q4 100000 --no-webui --dry-run
```
![Terminal showcasing `llms` with --dry-run option](https://i.postimg.cc/y8WYMYzg/Clipboard03.png)

## Configuration System

### Configuration Priority (Highest to Lowest)
1. **Environment Variables** (always override everything)
2. **llms.ini** in script directory (highest file priority)
3. **llms.ini** in user config directory:
   - **Windows:** `%USERPROFILE%\AppData\Local\llms.ini`
   - **Linux/macOS:** `~/.config/llms.ini` (or `$XDG_CONFIG_HOME/llms.ini`)
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

The scripts look for `llms.ini` in these locations (in priority order):

**Priority 1: Script Directory**
- Same directory as the script (`./llms.ini`)

**Priority 2: User Config Directory**
- **Windows:** `%USERPROFILE%\AppData\Local\llms.ini`
- **Linux/macOS:** `~/.config/llms.ini` (or `$XDG_CONFIG_HOME/llms.ini`)

#### llms.ini format

```ini
# Model directories (comma-separated paths)
ModelsDirs = C:\path\to\models1,D:\path\to\models2

# Performance settings
CacheTypeK = q8_0
CacheTypeV = q8_0
UbatchSize = 1024
NGpuLayers = 99

# Network settings (can also be set via ENV)
Host = 0.0.0.0
Port = 8080
ApiKey = secret
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

**PowerShell:**
```powershell
$env:LLMS_MODELS_DIRS = "C:\models,D:\ai-models"
$env:LLMS_PORT = 8081
$env:LLMS_N_GPU_LAYERS = 50
llms mistral 32000
```

**Bash:**
```bash
LLMS_MODELS_DIRS="/home/user/models,/opt/ai-models" \
LLMS_PORT=8080 \
LLMS_N_GPU_LAYERS=50 \
llms mistral 32000
```

### Example 2: Mixed Configuration

**llms.ini:**
```ini
ModelsDirs = C:\models,D:\ai-models
# or Linux/macOS paths
#ModelsDirs = /home/user/models,/opt/ai-models

UbatchSize = 2048
NGpuLayers = 40
```

**override via environment:**

*PowerShell:*
```powershell
$env:LLMS_PORT = 8081
llms mistral 32000
```

*Bash:*
```bash
LLMS_PORT=8081 \
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

Both scripts use identical syntax:
```bash
llms list
llms <partial_model_name> <context_size> [llama-server args...] [--dry-run]
```

## Testing

### PowerShell Script Testing
This project uses [Pester v5](https://pester.dev/) for testing the PowerShell script. To run the tests:

1. Ensure Pester is installed:
   ```powershell  
   Install-Module -Name Pester -Force -Scope CurrentUser
   ```

2. Run the tests:
   ```powershell
   Invoke-Pester ./llms.tests.ps1
   ```

### Bash Script Testing
The bash script has been manually tested on macOS and should work on Linux systems. Automated testing for the bash script is planned for future releases.
