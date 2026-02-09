# LLMS Project - AI Agent Memory

**Project:** LLMS - Cross-platform wrapper scripts for llama-server
**Version:** 1.3.1
**Maintenance:** Update the [CHANGELOG.md](CHANGELOG.md) after each completed task.

---

## Project Overview

LLMS is an intelligent wrapper around `llama-server` that simplifies running `.gguf` language models with automatic configuration management.

### Core Philosophy
**"Configure Once, Run Always"** - Settings are specified once and remembered in per-model `.ini` files.

---

## Architecture & Configuration

### Configuration Hierarchy
1. **Per-Model Parameters** (performance, model-specific):
   - **Priority (PS):** CLI args > `.ini` file > Defaults
   - **Priority (Bash):** CLI args > ENV > `.ini` file > Defaults
   - **Storage:** `<model>.ini` next to `.gguf` file
   - **Examples:** `CtxSize`, `CacheTypeK`, `NGpuLayers`, `Mlock`

2. **Server-Wide Parameters** (global settings):
   - **Priority:** ENV > `llms.ini` > Defaults
   - **Storage:** `~/.config/llms.ini` or script directory
   - **Examples:** `ModelsDirs`, `Host`, `Port`, `ApiKey`

### Boolean Flag Classification
- **Server-Wide (Never Persisted):** `--help`, `--version`, `--dry-run`, `--no-webui`, `--verbose`, etc.
- **Per-Model (Always Persisted):** `--mlock`, `--no-mmap`, `--jinja`, `--cont-batching`, etc.

---

## Code Conventions & Mandates

### Naming Conventions
- **.ini Keys:** CamelCase (e.g., `CtxSize`, `CacheTypeK`)
- **Environment Variables:** `LLMS_` prefix + SNAKE_CASE (e.g., `LLMS_CTX_SIZE`)
- **Internal Variables (Bash):** SNAKE_CASE

### File Format Specifications (.ini)
- **Format:** `Key = value` (single space around `=`)
- **Ordering:** `CtxSize` first, then alphabetically sorted.
- **Quoting:** Single quotes for values with spaces.
- **Booleans:** Stored as `Key = true` (lowercase).

---

## Development Workflow

### Testing Changes
- **Bash:** `./llms TestModel 32000 --dry-run`
- **PowerShell:** `Invoke-Pester ./llms.tests.ps1` or `.\llms.ps1 TestModel 32000 -DryRun`

### Best Practices
- **POSIX Compliance:** Bash script must remain `#!/bin/sh` compatible.
- **Feature Parity:** Keep Bash and PowerShell scripts functionally identical.
- **No Associations:** Bash uses temp files instead of associative arrays for portability.
- **ENV Naming:** Always use `LLMS_` prefix for environment variables.
- **Dry-Run Safety:** `--dry-run` must NEVER save or modify configuration files.

---

## Notes for Future Agents
- Values in per-model `.ini` files should only be non-default values (minimalism).
- ENV variables for per-model settings are being phased out (removed in PS v1.3.0).
- Always use `--dry-run` to verify command assembly before execution.
- Maintain [CHANGELOG.md](CHANGELOG.md) for all project history.