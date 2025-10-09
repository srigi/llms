# LLMS Wrapper Scripts

Cross-platform wrapper scripts for [`llama-server`](https://github.com/ggml-org/llama.cpp/releases) that simplify running `.gguf` models, with intelligent configuration management through environment variables, per-model and global configuration files.

**Available Scripts:**
- **`llms`** - Bash script for UNIX systems (Linux, macOS, WSL)
- **`llms.ps1`** - PowerShell script for Windows, Linux, and macOS (PowerShell Core)

## Prerequisites

This project requires `llama-server` to be installed and available in your system PATH. LLMS is a wrapper that simplifies invoking `llama-server` - it does not install or bundle the binary.

**Download llama-server:** [llama.cpp releases](https://github.com/ggml-org/llama.cpp/releases)

Ensure `llama-server` runs correctly on your system before using these scripts.

## Project Intent

This script serves as an intelligent wrapper around `llama-server` that:

- **Remembers per-model settings**: Automatically saves and loads optimal settings for each model
- **Simplifies model management**: Discover and run GGUF models using partial names
- **Provides flexible configuration**: Priority-based system (CLI/ENV > config files > defaults)
- **Offers dry-run capability**: Preview commands before execution
- **Maintains consistent defaults**: Works out-of-the-box with sensible fallback values

## Quick Start

### 1. Configure model directories

Create `~/.config/llms.ini`:
```ini
ModelsDirs = /path/to/your/models
```

_...multiple paths possible, delimite with `,`_

```ini
ModelsDirs = /path/to/your/models,/home/user/.llms
```

### 2. List available models

```bash
llms list
```

### 3. Run a model (first time with context size)

```bash
llms Mistral-Small-3.1-24B 64000
```

### 4. Run the same model again (context size is optional now)

```bash
llms Mistral-Small-3.1-24B
```

The script remembers your settings and uses them automatically!

## Basic Usage

Both scripts share identical command syntax and functionality.

### Parameters

- `list`: List all available `.gguf` models in configured directories
- `<partial_model_name>`: Partial name to match against model files (case-insensitive)
- `[<context_size>]`: **Optional** if model config exists - Context window size for the model
- `[llama-server args...]`: Optional additional arguments passed to `llama-server`, will be saved too, along the context_size, in per-model .ini file!
- `[--dry-run]`: Preview the command without executing it

### List Available Models

```bash
llms list
```

![Terminal showcasing `llms list` command](https://i.postimg.cc/507VKNvn/Clipboard01-1.png)

### Run a Model

**First time (creates model config):**
```bash
llms Mistral-Small-3.1-24B-Instruct-2503-UD-Q4 64000
```

**Subsequent runs (uses saved config):**
```bash
llms Mistral-Small-3.1-24B-Instruct-2503-UD-Q4
```

![Terminal showcasing `llms <partial_model_name>` command](https://i.postimg.cc/jKNBKgzn/Clipboard01.png)

**Note:** Multi-modal models with companion `.mmproj-*.gguf` files are detected automatically.

## Advanced Usage

### Passing Additional llama-server Arguments

```bash
llms GLM-4-32B 24000 --chat-template-file ~/llm/chat-template-chatml.jinja
```

CLI arguments are passed to `llama-server` and saved to per-model config. ENV variables provide temporary overrides without saving.

### Dry-Run Mode

Preview the command that would be executed without running it:

```bash
llms Devstral-Small-2505-UD-Q4 100000 --no-webui --dry-run
```

![Terminal showcasing `llms` with --dry-run option](https://i.postimg.cc/y8WYMYzg/Clipboard03.png)

**Note:** Dry-run mode does not save or update model configuration.

### Overriding Saved Settings

```bash
llms Mistral-Small 32000                   # Override context size
llms Mistral-Small --n-gpu-layers 30       # Persistent (saves to .ini)
LLMS_N_GPU_LAYERS=50 llms Mistral-Small    # Temporary (ENV only, not saved)
```

## Configuration System

LLMS uses a priority-based configuration system with different rules for different parameter types:

**Per-Model Parameters** (performance, model-specific):
1. CLI Arguments (highest)
2. Environment Variables
3. Per-Model Config File (`.ini` next to model)
4. Default Values (lowest)

**Server-Wide Parameters** (`ModelsDirs`, `Host`, `Port`, `ApiKey`):
1. Environment Variables (highest)
2. Config File (`llms.ini`)
3. Default Values (lowest)

**Note:** Combining ENV variables with CLI args is not recommended as it can lead to unexpected behavior. Use one approach consistently.

### Configuration Files

**Global config** (`~/.config/llms.ini` or `$XDG_CONFIG_HOME/llms.ini`):
```ini
ModelsDirs = /home/user/models,/opt/ai-models
Host = 127.0.0.1
Port = 8080
ApiKey = secret
```

**Per-model config** (auto-generated next to `.gguf` file):
```ini
CtxSize = 32000
CacheTypeK = q4_0
Mlock = true
ChatTemplateFile = /home/user/template.jinja
```

### Per-Model Configuration Behavior

**Config is saved when:**
- CLI arguments provided: `llms Mistral 32000 --mlock`
- Context size specified: `llms Mistral 64000`

**Config is NOT saved when:**
- Only ENV variables used: `LLMS_N_GPU_LAYERS=50 llms Mistral`
- Using `--dry-run`: `llms Mistral 32000 --dry-run`

**Features:**
- Only non-default values saved (minimal files)
- Supports all `llama-server` parameters:
  - **Core parameters**: Pre-configured with defaults (`--ctx-size`, `--cache-type-k`, `--n-gpu-layers`)
  - **Custom parameters**: Any additional `llama-server` flags (`--chat-template-file`, `--rope-freq-base`)
- Boolean flags stored as `ParameterName = true`
- Settings auto-load on subsequent runs

### Environment Variables

All options support `LLMS_` prefix environment variables. **ENV overrides are temporary only** and never update config files.

#### Server-Wide Parameters

| Variable | Description | Default |
|----------|-------------|---------|
| `LLMS_MODELS_DIRS` | Model directories (comma-separated) | *Required* |
| `LLMS_HOST` | Server bind address | `127.0.0.1` |
| `LLMS_PORT` | Server port | `8080` |
| `LLMS_API_KEY` | API authentication key | `secret` |

#### Per-Model Parameters

| Variable | Description | Default |
|----------|-------------|---------|
| `LLMS_CACHE_TYPE_K` | K-cache quantization | `q8_0` |
| `LLMS_CACHE_TYPE_V` | V-cache quantization | `q8_0` |
| `LLMS_UBATCH_SIZE` | Micro-batch size | `512` |
| `LLMS_N_GPU_LAYERS` | GPU layer offload count | `99` |
| `LLMS_FLASH_ATTN` | Flash attention (`on`/`off`) | `on` |

**Config file locations** (priority order):
1. Script directory: `./llms.ini`
2. User config: `~/.config/llms.ini` (Linux/macOS) or `%USERPROFILE%\AppData\Local\llms.ini` (Windows)

### Boolean Flags

**Per-model flags** (persisted): `--mlock`, `--no-mmap`, `--jinja`, `--cont-batching`, `--context-shift`, etc.
**Server-wide flags** (not persisted): `--no-webui`, `--verbose`, `--embedding`, `--dry-run`, etc.

Run `llama-server --help` for complete flag list.

## Usage Examples

### Example 1: Basic Workflow

```bash
# 1. Setup - create global config
echo "ModelsDirs = /home/user/models" > ~/.config/llms.ini

# 2. First run - specify settings (saves to per-model .ini)
llms Mistral-Small 32000 --mlock --cache-type-k q4_0

# 3. Subsequent runs - settings remembered
llms Mistral-Small
```

### Example 2: Temporary vs Persistent Overrides

```bash
# Temporary (this run only, not saved)
LLMS_N_GPU_LAYERS=30 llms Mistral-Small

# Persistent (saves to per-model .ini)
llms Mistral-Small --n-gpu-layers 30
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

The bash script has been manually tested on macOS and Linux systems. Automated testing for the bash script is planned for future releases.

## Troubleshooting

### Error: "No model file found"
- Ensure `ModelsDirs` is configured correctly in `llms.ini` or via `LLMS_MODELS_DIRS`
- Verify the partial model name matches an existing `.gguf` file
- Run `llms list` to see available models

### Error: "You must specify a <context_size> parameter"
- This model doesn't have a saved configuration yet
- Run once with a context size: `llms <model_name> <context_size>`
- Future runs will use the saved configuration automatically

### Model runs with wrong settings
- Check for per-model `.ini` file next to the model
- Use environment variables to override: `LLMS_N_GPU_LAYERS=50 llms <model>`
- Use `--dry-run` to preview the command before execution

### llama-server not found
- Ensure `llama-server` is installed and in your PATH
- Download from [llama.cpp releases](https://github.com/ggml-org/llama.cpp/releases)
- Test by running `llama-server --version`
