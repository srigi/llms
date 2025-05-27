# llms.ps1

A PowerShell wrapper script for `llama-server` that simplifies the process of listing and running `.gguf` models with customizable configuration.

## Features
- Searches for `.gguf` models in multiple configured directories
- Supports partial model name matching
- Supports auto-loading of companion `.mmproj-*.gguf` file for multi-modal models
- Configurable via:
  - Environment variables (`LLMS_MODELS_DIRS`, ...)
  - `.ini` file(s) (`llms.ini` in current directory or `%USERPROFILE%/AppData/Local`)
- Stores context size (`CtxSize`) in `context.ini` for persistent configuration
- Allows passing additional `llama-server` arguments
- Provides usage help and model listing capability

## Usage

### Basic Syntax
```powershell
llms [list | <partial_model_name>]
llms [<partial_model_name>] [<context_size>] [<LlamaServerArgs>]
```

#### list
List all available `.gguf` models in configured directories
```powershell
llms list
```
![PowerShell terminal showcasing `llsm list` command](https://i.postimg.cc/507VKNvn/Clipboard01-1.png)


#### `<partial_model_name>`
Run a model matching the partial name
```powershell
llms Mistral-Small-3.1-24B-Instruct-2503-UD-Q4 64000
```
![PowerShell terminal showcasing `llsm <partial_model_name>` command](https://i.postimg.cc/jKNBKgzn/Clipboard01.png)


## Configuration

### Directories
Configure model search paths using:
1. Environment variable: `LLMS_MODELS_DIRS` (comma-separated)
2. `llms.ini` file:
   ```ini
   ModelsDirs = C:\path\to\models1,D:\path\to\models2
   ```
   *`llms.ini` must be in current directory or `%USERPROFILE%/AppData/Local`*

Precedence of ModelsDirs configuration is:

- .ini file in `%USERPROFILE%\AppData\Local` (lowest)
- .ini file in current dir
- ENV var (highest)

### Context Size
- Specify via command line argument: `llms <model> 25000`
- Stored in `context.ini` in the model's directory
- Default: `20000` if not specified

### Passing extra `llama-server` arguments

Run a model with additional arguments of llama-server:

```powershell
llms GLM-4-32B 24000 --chat-template-file C:\Users\srigi\llm\chat-template-chatml.jinja
```

![PowerShell terminal showcasing `llsm with --dry-run option](https://i.postimg.cc/j59R45tb/Clipboard01.png)


#### --dry-run

Print the command that would be executed without actually running it:

```powershell
llms Devstral-Small-2505-UD-Q4 100000 --no-webui --dry-run
```

![PowerShell terminal showcasing `llsm with --dry-run option](https://i.postimg.cc/d0yv6FNP/Clipboard01.png)


## ENV vars
- `LLMS_API_KEY` - API key to use for authentication (default: `secret`)
- `LLMS_HOST` - IP address for llama-server to bind to (127.0.0.1 if not specified)
- `LLMS_MODELS_DIRS` - models search paths (comma-separated)
- `LLMS_PORT` - port to listen on (8080 if not specified)

## .ini files
- `llms.ini` - Configuration for model directories
- `context.ini` - Stores context size for models

## Notes
- The script automatically creates `context.ini` in the model's directory if it doesn't exist
- Color-coded output for model information in terminal
- Error handling for missing configurations and models
- Automatically detects and loads companion `.mmproj-*.gguf` files when present, adding appropriate options to `llama-server`
