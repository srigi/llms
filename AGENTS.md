# LLMS Project - AI Agent Memory File

**Project:** LLMS - Cross-platform wrapper scripts for llama-server
**Last Updated:** 2025-10-10
**Version:** 1.2.0

---

## Table of Contents

- [Project Overview](#project-overview)
- [Architecture](#architecture)
- [Key Files](#key-files)
- [Code Conventions](#code-conventions)
- [Development Workflow](#development-workflow)
- [Updating This File](#updating-this-file)
- [History Log](#history-log)

---

## Project Overview

### Purpose

LLMS is an intelligent wrapper around `llama-server` (from llama.cpp) that simplifies running `.gguf` language models with automatic configuration management. It eliminates the need to remember and type complex command-line arguments for each model.

### Core Philosophy

**"Configure Once, Run Always"** - Users specify settings once (context size, GPU layers, custom parameters), and LLMS remembers them in per-model configuration files.

### Key Features

1. **Per-Model Configuration** - Each model gets its own `.ini` file with saved settings
2. **Partial Name Matching** - Run models using partial names (e.g., `llms Mistral` instead of full filename)
3. **Multi-Modal Support** - Automatically detects and loads `.mmproj` companion files
4. **Flexible Configuration** - Priority-based system (CLI/ENV > config files > defaults)
5. **Universal Parameter Support** - Supports all `llama-server` parameters (core and custom)
6. **Smart Boolean Classification** - Distinguishes between per-model and server-wide flags

### Target Users

- AI/ML developers working with local LLMs
- Researchers testing multiple model configurations
- Users who want simplified model management without memorizing command-line flags

---

## Architecture

### System Design

```
User Input (llms Mistral 32000 --mlock)
         ↓
    Argument Parser
         ↓
    ┌──────────────────────────────────────┐
    │  Per-Model Priority:                 │
    │  CLI > ENV > .ini > defaults         │
    │                                      │
    │  Server-Wide Priority:               │
    │  ENV > config file > defaults        │
    └──────────────────────────────────────┘
         ↓
    Command Assembly
         ↓
    llama-server --model ... --ctx-size 32000 --mlock ...
         ↓
    Save Config (if CLI args present)
```

### Configuration Hierarchy

#### Per-Model Parameters
- **Scope:** Model-specific performance and behavior settings
- **Storage:** `<model>.ini` file next to `.gguf` file
- **Priority:** CLI args > ENV > per-model .ini > defaults
- **Examples:** `CtxSize`, `CacheTypeK`, `NGpuLayers`, `Mlock`, `ChatTemplateFile`

#### General Parameters
- **Scope:** Global server settings
- **Storage:** `~/.config/llms.ini` or script directory `llms.ini`
- **Priority:** ENV > script dir .ini > user config .ini > defaults
- **Examples:** `ModelsDirs`, `Host`, `Port`, `ApiKey`

### Data Flow

```
[User Input] → [Parse Args] → [Load Model Config] → [Apply Priority]
                                                           ↓
[Execute Command] ← [Assemble Command] ← [Build Additional Args]
         ↓
[Save Config] (only if CLI args present and not --dry-run)
```

---

## Key Files

### Core Scripts

#### `llms` (Bash)
- **Language:** POSIX shell script (sh)
- **Platform:** Linux, macOS, WSL
- **Status:** ✅ Feature complete (v1.2.0)
- **Key Functions:**
  - `load_config()` - Load global .ini files (lines 23-46)
  - `load_model_config()` - Load per-model .ini (lines 94-117)
  - `save_model_config()` - Save per-model .ini (lines 119-200)
  - `is_server_wide_boolean()` - Classify boolean flags (lines 75-79)
- **Key Sections:**
  - Server-wide booleans list (lines 48-73)
  - Argument parser (lines 332-376)
  - Configuration priority (lines 380-441)
  - Additional args builder (lines 455-513)

#### `llms.ps1` (PowerShell)
- **Language:** PowerShell
- **Platform:** Windows, Linux, macOS (PowerShell Core)
- **Status:** ✅ Feature complete (v1.2.0)
- **Key Functions:**
  - `Load-ModelConfig()` - Load per-model .ini (lines 56-79)
  - `Save-ModelConfig()` - Save per-model .ini with merge (lines 81-121)
  - `Is-ServerWideBoolean()` - Classify boolean flags (lines 40-54)
  - `Convert-ToCamelCase()` - Converts dash-separated to CamelCase (lines 14-25)
  - `Convert-ToDashSeparated()` - Converts CamelCase to dash-separated (lines 27-38)
- **Key Sections:**
  - Server-wide booleans list (lines 43-51)
  - Argument parser (lines 248-281)
  - Configuration priority (lines 334-362)
  - Additional args builder (lines 375-430)
  - Dry-run check (lines 456-469)
  - Save config (lines 471-527)

### Configuration Files

#### Global Configuration: `llms.ini`
- **Locations:**
  - Script directory: `$(script_dir)/llms.ini` (priority 1)
  - User config: `~/.config/llms.ini` or `$XDG_CONFIG_HOME/llms.ini` (priority 2)
- **Format:** INI with `Key = value` pairs
- **Contains:** General parameters only (`ModelsDirs`, `Host`, `Port`, `ApiKey`)

#### Per-Model Configuration: `<model>.ini`
- **Location:** Next to `.gguf` file with same basename
- **Format:** INI with `Key = value` pairs (CamelCase keys)
- **Contains:** All per-model parameters (core and custom)
- **Example:**
  ```ini
  CtxSize = 32000
  CacheTypeK = q4_0
  Mlock = true
  ChatTemplateFile = /path/to/template.jinja
  ```

### Documentation

#### `README.md`
- **Purpose:** User-facing documentation
- **Audience:** End users
- **Status:** ✅ Up to date with v1.2.0 (streamlined, concise)
- **Sections:** Quick start, configuration system, examples, troubleshooting

#### `POWERSHELL_UPDATE_SPEC.md`
- **Purpose:** Specification for PowerShell script update
- **Audience:** Future AI agents
- **Contains:** Complete implementation guide, testing checklist, code examples

#### `AGENT.md` (this file)
- **Purpose:** AI agent memory and project reference
- **Audience:** AI agents working on this project
- **Maintenance:** Update history log after each completed task

### Test Files

#### `llms.tests.ps1`
- **Framework:** Pester v5.7
- **Platform:** PowerShell
- **Status:** ✅ Complete (v1.2.0) - 53 tests, 100% passing
- **Coverage:** Helper functions, config management, argument parsing, priority system, integration tests

---

## Code Conventions

### Naming Conventions

#### Configuration Keys
- **File Format:** CamelCase (e.g., `CtxSize`, `CacheTypeK`, `ModelsDirs`)
- **Environment Variables:** `LLMS_` prefix + SNAKE_CASE (e.g., `LLMS_CTX_SIZE`, `LLMS_CACHE_TYPE_K`)
- **Internal Variables:** SNAKE_CASE in bash (e.g., `CTX_SIZE`, `CACHE_TYPE_K`)

#### Conversion Examples
```
CLI Arg             → .ini Key           → ENV Var
--cache-type-k      → CacheTypeK         → LLMS_CACHE_TYPE_K
--chat-template-file → ChatTemplateFile  → LLMS_CHAT_TEMPLATE_FILE
--mlock             → Mlock              → LLMS_MLOCK
```

### Boolean Flag Classification

#### Server-Wide (Never Persisted):
```
--help, --usage, --version, --dry-run
--no-webui, --offline
--log-disable, --log-verbose, --verbose
--reranking, --metrics, --slots
```

#### Per-Model (Always Persisted):
```
--mlock, --no-mmap, --jinja
--cont-batching, --ignore-eos
--kv-unified, --context-shift
--no-mmproj, --check-tensors
... (all others not in server-wide list)
```

### Default Values

```bash
DEFAULT_CACHE_TYPE_K="q8_0"
DEFAULT_CACHE_TYPE_V="q8_0"
DEFAULT_UBATCH_SIZE="512"
DEFAULT_N_GPU_LAYERS="99"
DEFAULT_FLASH_ATTN="on"
DEFAULT_HOST="127.0.0.1"
DEFAULT_PORT="8080"
DEFAULT_API_KEY="secret"
```

### File Format Specifications

#### Per-Model .ini File
- **Encoding:** UTF-8
- **Line Endings:** Unix (LF) preferred, Windows (CRLF) acceptable
- **Format:** `Key = value` with single space around `=`
- **Comments:** Not generated (but tolerated when reading)
- **Ordering:**
  1. `CtxSize` always first
  2. Other parameters alphabetically sorted
- **Quoting:** Single quotes for values with spaces
- **Booleans:** Stored as `Key = true` (lowercase)

**Example:**
```ini
CtxSize = 32000
CacheTypeK = q4_0
ChatTemplateFile = '/path/with spaces/template.jinja'
Mlock = true
```

---

## Development Workflow

### Testing Changes

#### Bash Script
```bash
# Test basic functionality
./llms list

# Test config creation
rm -f ~/.llm/TestModel*.ini
./llms TestModel 32000 --mlock --cache-type-k q4_0 --dry-run

# Test config loading
./llms TestModel --dry-run

# Test ENV overrides (temporary)
LLMS_N_GPU_LAYERS=50 ./llms TestModel --dry-run

# Test CLI overrides (persistent)
./llms TestModel --n-gpu-layers 50 --dry-run
```

#### PowerShell Script
```powershell
# Run Pester tests
Invoke-Pester ./llms.tests.ps1

# Manual testing
.\llms.ps1 list
.\llms.ps1 TestModel 32000 -DryRun
```

### Common Tasks

#### Adding a New Default Parameter
1. Add default value constant (e.g., `DEFAULT_NEW_PARAM="value"`)
2. Add to configuration priority chain
3. Add to `save_model_config()` (only if non-default)
4. Add to command assembly
5. Update README.md
6. Update POWERSHELL_UPDATE_SPEC.md

#### Adding a Server-Wide Boolean
1. Add to `SERVER_WIDE_BOOLEANS` list (lines 49-73 in bash)
2. Flag will automatically be excluded from persistence
3. Update README.md Per-Model Boolean Flags section

#### Changing Default Values
1. Update constant (e.g., `DEFAULT_N_GPU_LAYERS`)
2. Update default in priority chain
3. Update `save_model_config()` comparison
4. Update README.md tables
5. Update POWERSHELL_UPDATE_SPEC.md

### Best Practices

1. **POSIX Compliance:** Keep bash script compatible with `#!/bin/sh`
2. **No Associative Arrays:** Use temp files instead (bash portability)
3. **Careful Quoting:** Handle paths with spaces correctly
4. **Subshell Awareness:** Variables set in `while` loops need temp files
5. **ENV Naming:** Always use `LLMS_` prefix for environment variables
6. **Test Both Paths:** Test with and without existing .ini files
7. **Dry-Run Testing:** Use `--dry-run` to verify command assembly
8. **Cross-Platform:** Consider Windows paths when updating PowerShell

---

## Updating This File

### When to Update

**⚠️ IMPORTANT:** Only update the History Log section when the user explicitly indicates that a task is completed. Do NOT update during planning or mid-task.

### What to Include in History Log

When a task is complete and user confirms, add an entry with:

1. **Date** - ISO format (YYYY-MM-DD)
2. **Version** - If applicable
3. **Task Title** - Clear, descriptive title
4. **Summary** - 1-2 paragraphs describing what was done
5. **Key Changes** - Bulleted list of major changes
6. **Technical Details** - Code examples, file modifications, implementation notes
7. **Testing** - What was tested and results
8. **Files Modified** - List of changed files with brief descriptions
9. **Breaking Changes** - If any (with migration guide)
10. **Future Work** - Related tasks or follow-ups

### History Log Format

```markdown
### [YYYY-MM-DD] Task Title

**Version:** X.Y.Z (if applicable)

**Summary:**
Brief description of what was accomplished...

**Key Changes:**
- Change 1
- Change 2
- Change 3

**Technical Details:**
Detailed explanation with code examples...

**Testing:**
What was tested and results...

**Files Modified:**
- `file1` - Description
- `file2` - Description

**Breaking Changes:** (if any)
Description and migration guide...

**Future Work:**
Related tasks...
```

---

## History Log

### [2025-10-09] Per-Model Configuration System Implementation

**Version:** 1.1.0

**Summary:**

Implemented a comprehensive per-model configuration system for the bash `llms` script that enables a "configure once, run always" workflow. The system automatically saves and restores model-specific settings, distinguishes between persistent CLI arguments and temporary ENV overrides, and supports all `llama-server` parameters (both known and unknown). This fundamental enhancement transforms LLMS from a simple wrapper into an intelligent model configuration manager.

**Key Changes:**

- **CLI Arguments Persist:** Any `--parameter value` or `--boolean-flag` now updates the per-model .ini file
- **ENV Variables Are Temporary:** ENV overrides (e.g., `LLMS_N_GPU_LAYERS=50`) no longer update configuration files
- **Universal Parameter Support:** Custom parameters (e.g., `--chat-template-file`) are automatically saved and restored
- **Smart Boolean Classification:** 25 per-model booleans are persisted, 15 server-wide booleans pass through only
- **Minimal Storage:** Only non-default values are saved to .ini files
- **Optional Context Size:** Context size parameter is now optional if per-model config exists

**Technical Details:**

Three-stage pipeline implementation:

1. **Argument Parsing** (lines 332-376) - Categorizes CLI args into key-value pairs, per-model booleans, and server-wide passthroughs
2. **Configuration Priority** (lines 380-441) - Applies CLI > ENV > .ini > defaults hierarchy for each parameter
3. **Command Assembly & Save** (lines 455-541) - Builds command and saves config if CLI args present (not dry-run)

**Key Functions:**

- **`save_model_config()`** (lines 119-200) - Saves per-model .ini with only non-default values, `CtxSize` first, alphabetically sorted
- **`load_model_config()`** (lines 94-117) - Loads per-model .ini, exports with `MODEL_CONFIG_` prefix
- **`is_server_wide_boolean()`** (lines 75-79) - Classifies boolean flags (15 server-wide vs 25+ per-model)
- **`to_camel_case()`** (lines 135-144) - Converts `--dash-separated` to `CamelCase` for .ini keys (POSIX-compliant awk)
- **Additional Args Builder** (lines 455-513) - Builds extra parameters from CLI args, booleans, and model config

**Testing:**

Comprehensive testing performed: config creation/loading, ENV overrides (temporary), CLI overrides (persistent), custom parameters, server-wide flag passthrough, and non-default value storage.

**Files Modified:**

- **`llms` (bash script)** - Complete rewrite of configuration system
  - Added: Server-wide booleans list (lines 48-73)
  - Added: Helper functions for arg parsing (lines 75-92)
  - Modified: `load_model_config()` to handle quotes (lines 94-117)
  - Rewritten: `save_model_config()` for generalized parameters (lines 119-200)
  - Added: CLI argument parser (lines 332-376)
  - Modified: Configuration priority chains (lines 380-441)
  - Added: Additional args builder (lines 455-513)
  - Modified: Dry-run detection (lines 530-538)

- **`README.md`** - Streamlined documentation (v1.2.0)
  - Updated: Configuration priorities for per-model and server-wide parameters
  - Replaced: "known/unknown" with "core/custom" parameter terminology
  - Added: Warning about mixing ENV and CLI args
  - Condensed: 5 examples reduced to 2 essential ones
  - Removed: Redundant sections and duplications (429→274 lines, 36% reduction)

- **`POWERSHELL_UPDATE_SPEC.md`** - Created specification for PowerShell update with implementation guide and testing checklist

**Breaking Changes:**

1. **ENV Variables No Longer Persist**
   - **Old Behavior:** `LLMS_N_GPU_LAYERS=50 llms Mistral` updated .ini file
   - **New Behavior:** ENV overrides are temporary only
   - **Migration:** Use CLI args to persist: `llms Mistral --n-gpu-layers 50`

2. **Context Size Optional**
   - **Old Behavior:** Context size always required
   - **New Behavior:** Optional if per-model .ini exists
   - **Impact:** Existing workflows continue to work, new flexibility added

3. **Per-Model .ini Format Changed**
   - **Old Behavior:** All parameters saved regardless of defaults
   - **New Behavior:** Only non-default values saved
   - **Impact:** Existing .ini files still work, new files are cleaner
   - **Note:** No manual migration needed

**Default Value Changes:**

- `NGpuLayers`: Changed from `999` to `99`
  - Reason: More reasonable default for most hardware
  - Existing configs unchanged (values already saved)

**Future Work:**

1. ~~**PowerShell Script Update**~~ - ✅ **COMPLETED (2025-10-10)**
   - Applied same functionality to `llms.ps1`
   - Feature parity achieved with bash script
   - Manual testing completed (test suite update deferred)

2. **Automated Testing** - Create test suite for bash script
   - Unit tests for helper functions
   - Integration tests for config management
   - Edge case coverage

3. **Configuration Migration Tool** - Optional utility to update old .ini files
   - Remove default values from existing configs
   - Alphabetically sort parameters
   - Add CtxSize if missing

4. **Documentation Enhancements**
   - Add troubleshooting guide for config issues
   - Create video tutorial showing configuration workflow
   - Document all `llama-server` parameters with recommendations

5. **Feature Additions**
   - Config profiles (e.g., `llms Mistral --profile performance`)
   - Config export/import for sharing settings
   - Interactive config wizard for first-time setup
   - Validation of parameter values before saving

**Related Commits:**

- Initial per-model config implementation: be61ddb
- Documentation updates: 541f199
- Bug fixes and refinements: (current working state)

---

### [2025-10-10] PowerShell Script Feature Parity Update

**Version:** 1.2.0

**Summary:**

Updated `llms.ps1` PowerShell script to achieve complete feature parity with the bash variant. Implemented the same per-model configuration system, priority-based parameter handling, and smart boolean classification. The PowerShell implementation now supports the "configure once, run always" workflow with identical behavior across both platforms.

**Key Changes:**

- **Complete Rewrite:** Refactored entire script to match bash functionality
- **Helper Functions:** Added 5 new helper functions for config management
- **Configuration Priority:** Implemented CLI > ENV > ModelConfig > Default hierarchy
- **ENV Override Fix:** ENV variables now properly temporary (not persisted to .ini)
- **Config Merging:** Save function now merges with existing config instead of overwriting
- **Dry-Run Order Fix:** Moved dry-run check before save to prevent config updates during dry-run
- **Reserved Variable Fix:** Renamed `$host` to `$serverHost` (PowerShell reserved variable)

**Technical Details:**

PowerShell-specific implementation considerations:

1. **Parameter Handling** - Used `[Parameter(ValueFromRemainingArguments)]` to capture all args after model pattern
2. **Hashtables** - Used PowerShell hashtables for config storage (equivalent to bash associative arrays/temp files)
3. **Quote Escaping** - Special regex pattern for PowerShell: `'^[''"]|[''"]$'` (escaped single quotes)
4. **Reserved Variables** - Avoided `$host` (reserved in PowerShell), used `$serverHost` and `$serverPort`
5. **Section Ordering** - Dry-run check must come before save to prevent config updates during preview

**Key Functions Implemented:**

- **`Convert-ToCamelCase`** (lines 14-25) - Converts `cache-type-k` to `CacheTypeK`
- **`Convert-ToDashSeparated`** (lines 27-38) - Reverse conversion using `-creplace`
- **`Is-ServerWideBoolean`** (lines 40-54) - Array-based classification (15 flags)
- **`Load-ModelConfig`** (lines 56-79) - Loads and parses .ini with quote removal
- **`Save-ModelConfig`** (lines 81-121) - Merges and saves with CtxSize first, alphabetically sorted

**Testing:**

Comprehensive testing performed with small LLM:

1. ✅ Config creation with multiple parameters (context size, booleans, custom params)
2. ✅ Config loading on subsequent runs (optional context size)
3. ✅ Priority system verification (CLI > ENV > ModelConfig > Default)
4. ✅ ENV overrides are temporary (not persisted to .ini)
5. ✅ CLI overrides persist correctly
6. ✅ Server-wide vs per-model boolean distinction (--mlock persists, --no-webui doesn't)
7. ✅ Custom parameter handling with CamelCase conversion (--rope-freq-base → RopeFreqBase)
8. ✅ Path quoting for values with spaces
9. ✅ List command functionality
10. ✅ .ini file ordering (CtxSize first, alphabetical sorting)
11. ✅ Dry-run does NOT save config (verified after fix)

All tests conducted using sub-agents to minimize context usage from verbose llama-server output.

**Bugs Fixed During Implementation:**

1. **Quote Escaping** (line 71) - Fixed regex pattern for PowerShell single quote handling
2. **Reserved Variable** (lines 357-358, 440-441) - Renamed `$host` to `$serverHost`, `$port` to `$serverPort`
3. **ENV Override Persistence** (lines 485-507) - Only save core params if they came from CLI, not ENV
4. **Config Overwrite** (lines 89-95) - Changed Save-ModelConfig to merge with existing config instead of overwriting
5. **Dry-Run Save Order** (lines 456-469) - Moved dry-run check before save config to prevent updates during preview
6. **Array Slicing Edge Case** (lines 244-248) - Fixed PowerShell array slicing bug where `$arr[1..0]` wraps around and returns original element instead of empty array, causing context size to be passed as duplicate argument (`error: invalid argument: 32000`)
7. **Argument Assembly** (lines 436-462, 306-307, 382-383, 421-422) - Split parameter flags and values into separate array elements instead of concatenated strings for proper argument passing
8. **Command Execution** (line 553) - Changed from `Start-Process -ArgumentList` to `& llama-server $llmsArgs` for correct array expansion to llama-server

**Files Modified:**

- **`llms.ps1`** - Complete rewrite matching bash functionality (531 lines)
  - Lines 14-54: Helper functions (Convert-ToCamelCase, Convert-ToDashSeparated, Is-ServerWideBoolean)
  - Lines 56-121: Config management (Load-ModelConfig, Save-ModelConfig with merge)
  - Lines 248-281: CLI argument parser (separates key-value, booleans, passthrough)
  - Lines 334-362: Configuration priority application
  - Lines 375-430: Additional args builder
  - Lines 456-469: Dry-run handling (moved before save)
  - Lines 471-527: Save logic with CLI-only persistence check

- **`AGENTS.md`** - Updated project memory file
  - Lines 120-133: Added PowerShell script status and key sections
  - Lines 464-467: Marked PowerShell update as completed
  - Lines 495-595: Added this history log entry

**Breaking Changes:**

None - maintains backward compatibility with existing workflows while adding new functionality.

**Comparison with Bash Script:**

The PowerShell implementation achieves exact parity:
- Same 15 server-wide boolean flags
- Same configuration priority system
- Same .ini file format (UTF-8, CamelCase keys, alphabetical sorting)
- Same default values
- Same "configure once, run always" philosophy
- Same ENV variable behavior (temporary only)

**Future Work:**

1. ~~**Test Suite Update**~~ - ✅ **COMPLETED (2025-10-10)**
   - Rewrote `llms.tests.ps1` with 53 comprehensive tests
   - All tests passing (100% success rate)
   - Covers helper functions, config management, priority system, and integration workflows
2. **Cross-Platform Testing** - Test PowerShell Core on Linux/macOS
3. **Performance Optimization** - Profile for large model collections
4. **Error Handling** - Add more robust error messages for edge cases

---

*End of History Log*

---

## Notes for Future Agents

- This project values backward compatibility - avoid breaking existing user workflows
- The bash script must remain POSIX-compliant (`#!/bin/sh`)
- PowerShell script should maintain feature parity with bash script
- Test with real `llama-server` when possible, not just dry-run
- User experience is paramount - keep commands simple and intuitive
- Configuration should be transparent and discoverable
- Defaults should work for most users out-of-the-box

**Common Questions:**

Q: Should we add feature X to the global .ini?
A: Only if it's truly global (like `ModelsDirs`, `Host`, `Port`). Model-specific settings belong in per-model .ini.

Q: Should we persist this ENV variable?
A: No. ENV variables are always temporary overrides. Use CLI args to persist.

Q: How do I test without running llama-server?
A: Use `--dry-run` flag to preview commands without execution.

Q: Where should new boolean flags go?
A: Check if it's server-wide (UI, logging, endpoints) or per-model (performance, inference). Add to appropriate list.

---

*This file is maintained by AI agents working on the LLMS project. Update the History Log only when tasks are completed and confirmed by the user.*
