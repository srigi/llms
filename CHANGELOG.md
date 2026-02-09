# LLMS Project - Changelog

This file tracks the history of changes made by AI agents to the LLMS project.

---

## History Log

### [2026-02-09] New Default for HTTP Threads

**Version:** 1.3.2

**Summary:**

Introduced a new default for `--threads-http` to improve server performance under concurrent load. The parameter is now enforced as a core setting with persistence in model-specific configurations.

**Key Changes:**

- **New Default:** Set default `HttpThreads` to `8` in both PowerShell and Bash scripts.
- **Core Parameter Integration:** Integrated `--threads-http` (PowerShell: `HttpThreads`) into the core configuration hierarchy (CLI > Model Config > Default).
- **Persistence:** Added logic to save `HttpThreads` to model-specific `.ini` files if specified via CLI and differing from the default.

---

### [2026-02-09] Multi-Modal Companion Detection Fix

**Version:** 1.3.1

**Summary:**

Fixed issues with multi-modal companion model detection and main model selection. Improved the robust discovery of `.mmproj` files using a prefix-based matching strategy.

**Key Changes:**

- **Bash Parity:** Synchronized bash `llms` script with all version 1.3.x features and logic.
- **Main Model Filtering:** Fixed bug where `mmproj` companion files were incorrectly identified as main models in `llms list` and model search.
- **Prefix-Based Companion Matching:** Implemented a flexible matching strategy where companion files are selected based on the longest matching prefix with the main model filename.
- **Documentation:** Updated `README.md` with clear naming convention instructions for companion files.
- **Version Bump:** Updated project version to 1.3.1.

**Testing:**

1. ✅ Verified `llms list` excludes `mmproj` files.
2. ✅ Verified correct main model selection when `mmproj` files are present in the same directory.
3. ✅ Verified prefix-based matching with `Qwen3-VL` models (Q4/Q8 main models with shared F16 mmproj).
4. ✅ All existing Pester tests pass.

---

### [2026-02-09] Removal of Per-Model ENV Support

**Version:** 1.3.0

**Summary:**

Simplified the configuration system for both PowerShell and Bash scripts by removing support for per-model environment variables. Model-specific settings are now managed exclusively through CLI arguments and per-model `.ini` files.

**Key Changes:**

- **Simplified Priority Chain:** Per-model parameters now follow `CLI > ModelConfig > Default` priority.
- **Removed ENV Processing:** `LLMS_CACHE_TYPE_K`, `LLMS_CACHE_TYPE_V`, `LLMS_N_GPU_LAYERS`, and `LLMS_FLASH_ATTN` are no longer processed by `llms.ps1` or `llms`.
- **Server-Wide Consistency:** Maintained ENV support for `LLMS_MODELS_DIRS`, `LLMS_HOST`, `LLMS_PORT`, and `LLMS_API_KEY`.

**Testing:**

1. ✅ **Updated Test Suite:** Rewrote `llms.tests.ps1` to be Pester 3.4.0 compatible and verify new logic.
2. ✅ Verified `llms.ps1` correctly uses CLI arguments.
3. ✅ Verified `llms.ps1` correctly loads from `.ini` files.
4. ✅ Verified `llms.ps1` ignores previously supported per-model ENV variables.
5. ✅ Verified server-wide parameters still work with ENV variables.

---

### [2025-10-24] Bash Config Merging Fix and Test Suite Improvements

**Version:** 1.2.1

**Summary:**

Fixed critical config merging bug in bash `llms` script. Refactored the test suite to remove all dependencies on actual `.gguf` model files and `llama-server` execution.

**Key Changes:**

- **Config Merging:** Bash script now preserves existing parameters when updating via CLI
- **Test Independence:** Removed all `.gguf` and server execution dependencies from test suite
- **Feature Parity:** Bash and PowerShell variants now have identical configuration behavior
- **Spacing Normalization:** .ini files maintain consistent formatting (` = `)

**Testing:**

1. ✅ Config merging when updating individual params
2. ✅ CLI overrides persist, ENV overrides temporary
3. ✅ Server-wide booleans not saved
4. ✅ Spacing normalization and alphabetical sorting

---

### [2025-10-10] PowerShell Script Feature Parity Update

**Version:** 1.2.0

**Summary:**

Updated `llms.ps1` PowerShell script to achieve complete feature parity with the bash variant. Implemented the same per-model configuration system, priority-based parameter handling, and smart boolean classification.

**Key Changes:**

- **Complete Rewrite:** Refactored entire script to match bash functionality
- **Helper Functions:** Added 5 new helper functions for config management
- **Configuration Priority:** Implemented CLI > ENV > ModelConfig > Default hierarchy
- **ENV Override Fix:** ENV variables now properly temporary (not persisted to .ini)
- **Config Merging:** Save function now merges with existing config instead of overwriting
- **Dry-Run Order Fix:** Moved dry-run check before save to prevent config updates during dry-run
- **Reserved Variable Fix:** Renamed `$host` to `$serverHost`

**Testing:**

1. ✅ Config creation (ctx size, booleans, custom params)
2. ✅ Config loading (optional context size)
3. ✅ Priority system (CLI > ENV > ModelConfig > Default)
4. ✅ ENV overrides are temporary
5. ✅ CLI overrides persist correctly
6. ✅ Server-wide vs per-model boolean distinction
7. ✅ .ini file ordering and CamelCase conversion

**Bugs Fixed:**

1. **Quote Escaping** - Fixed regex for PS single quote handling
2. **Reserved Variable** - Renamed `$host` to `$serverHost`
3. **Array Slicing Edge Case** - Fixed PS array slicing bug `[1..0]`
4. **Argument Assembly** - Split flags and values into separate array elements
5. **Command Execution** - Used `& llama-server $llmsArgs` for correct expansion

---

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
- **`README.md`** - Streamlined documentation (v1.2.0)
- **`POWERSHELL_UPDATE_SPEC.md`** - Created specification for PowerShell update

**Breaking Changes:**

1. **ENV Variables No Longer Persist**
   - **Migration:** Use CLI args to persist: `llms Mistral --n-gpu-layers 50`
2. **Context Size Optional**
   - **Impact:** Existing workflows continue to work, new flexibility added
3. **Per-Model .ini Format Changed**
   - **Impact:** Existing .ini files still work, new files are cleaner

**Default Value Changes:**

- `NGpuLayers`: Changed from `999` to `99`
