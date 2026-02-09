# llms · llama-server run helper

Cross-platform wrapper scripts for [`llama-server`](https://github.com/ggml-org/llama.cpp/releases) that simplify running `.gguf` models with intelligent configuration management.

**Scripts:** `llms` (UNIX/WSL) and `llms.ps1` (PowerShell).

## Key Features

- **Optimal Settings Retention**: Automatically saves and loads optimal settings for each model.
- **Flexible Discovery**: Discover and run models using partial names.
- **Priority-based Config**: Seamlessly handles CLI arguments, environment variables, and config files.
- **Dry-run Capability**: Preview commands without execution.

## Quick Start

1. **Configure Model Directories**:
   Create `~/.config/llms.ini` (or `%APPDATA%\llms.ini` on Windows):
   ```ini
   ModelsDirs = /path/to/your/models
   ```

2. **Run a Model**:
   ```bash
   llms Mistral 64000  # First run: specify context size (saved automatically)
   llms Mistral        # Subsequent runs: settings remembered
   ```

3. **List Models**: `llms list`

## Usage Guide

### Command Syntax
`llms <partial_name> [<context_size>] [llama-server args...] [--dry-run]`

- **Partial Name**: Case-insensitive match against `.gguf` files.
- **Context Size**: Required for first run, optional thereafter.
- **Arguments**: Any `llama-server` flag (e.g., `--mlock`, `--n-gpu-layers 30`).
- **Dry Run**: Use `--dry-run` to preview the command without executing or saving config.

### Multi-Modal Support
Companion `.mmproj-*.gguf` files are detected and loaded automatically.

### Overriding Settings
- **Persistent**: `llms Mistral --n-gpu-layers 30` (saves to `.ini`)
- **Temporary (Global)**: `LLMS_PORT=9090 llms Mistral` (ENV only)

## Configuration System

### Parameter Priority

| Type | Priority Chain |
| :--- | :--- |
| **Per-Model** | CLI Args > `.ini` File > Default Values |
| **Server-Wide** | Environment Variables > `llms.ini` > Default Values |

*Note: PowerShell version 1.3.0+ ignores per-model ENV variables (e.g., `LLMS_CTX_SIZE`) to favor explicit CLI/config settings.*

### File Locations
1. Script directory: `./llms.ini`
2. User config: `~/.config/llms.ini` (UNIX) or `%USERPROFILE%\AppData\Local\llms.ini` (Windows)

### Boolean Flags
- **Persisted (Per-Model)**: `--mlock`, `--no-mmap`, `--jinja`, `--cont-batching`, etc.
- **Transient (Server-Wide)**: `--no-webui`, `--verbose`, `--dry-run`, `--help`.

## Testing

Run [Pester](https://pester.dev/) tests for PowerShell:
```powershell
Invoke-Pester ./llms.tests.ps1
```

## Troubleshooting

- **"No model file found"**: Check `ModelsDirs` in `llms.ini` or run `llms list`.
- **"Specify <context_size>"**: Model has no saved config yet. Run once with a numeric size.
- **"llama-server not found"**: Ensure `llama-server` is in your system `$PATH`.