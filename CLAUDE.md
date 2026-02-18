# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

Clawkit is a Ruby CLI tool for bidirectional file synchronization between local machines and remote hosts running OpenClaw agents. It uses SSHKit for SSH orchestration and rsync for efficient file transfer. The primary use case is managing agent workspace files (memory, SOUL.md, configs) when agents accumulate garbage context or need updates.

## Setup & Commands

```bash
bundle install                # Install dependencies
bin/bootstrap                 # One-time: install rsync on remote hosts
bin/sync                      # Sync all configured items
bin/sync my-agent             # Sync a specific item by name
bin/console                   # SSH to first configured host
bin/console 10.0.0.5          # SSH to a specific host
```

There are no tests, linting, or build steps in this project.

## Architecture

**Ruby 3.4.7** with Bundler. No compilation — scripts run directly.

### Entry Points (`bin/`)

All three commands load `.env` and `config.yml` via the shared `Clawkit` module, then use SSHKit for remote execution.

- **`bin/sync`** (~530 lines) — The main command. See detailed breakdown below.
- **`bin/bootstrap`** — Installs rsync on remote hosts via `apt-get`.
- **`bin/console`** — Execs native `ssh` to a remote host.

### `bin/sync` Flow

The script is one large procedural file. It runs through these phases sequentially:

**1. Initialization (lines 1–225)**
Loads config, builds a `sync_items` array from `directories:` and `files:` config entries. Each item is a hash with `name`, `source` (local path relative to project root), `target` (remote path relative to `remote_path`), and `type` (`"directory"` or `"file"`). ARGV filters items by name. Validates all paths with `safe_path?`.

**2. Gateway stop (lines 227–234)**
Stops the OpenClaw gateway on the remote host via `openclaw gateway stop` to prevent the agent from modifying files during sync.

**3. Per-item sync loop (lines 238–513)**
Iterates `sync_items`. For each item:

- **Change detection**: Two rsync dry-runs (`--dry-run --itemize-changes --checksum`) — one local→remote, one remote→local. The itemize output is filtered to remove timestamp-only lines (regex `/\A\.[fd]\.\.T\.+\s/`), then parsed by `parse_itemize()` into `{ modified: [], new: [], deleted: [] }`.
- **Diff generation**: Remote file copies needed for diffing are fetched into a tmpdir via rsync `--files-from`. `generate_diffs()` runs `diff -u` on each changed file pair and builds unified diff output, handling binary files, new files, and deletions.
- **Status display**: A `TTY::Table` shows the item name, latest mtime on each side (newer side highlighted green), and file change counts.
- **User prompt**: Three scenarios based on which sides have changes:
  - Both differ → Upload / Download / Compare / Skip
  - Local only → Upload / Compare / Skip
  - Remote only → Download / Compare / Skip
  - "Compare" pages the colorized diff via `less -R` and re-prompts.
- **Execution**: Runs rsync with `--checksum` (and `--delete` for directories) in the chosen direction. Directories use `-rlz`, files use `-lz`.

**4. Gateway restart (lines 518–529)**
Always restarts the gateway via `ensure` block, even on `Interrupt` (Ctrl+C). This guarantees the agent is never left with its gateway down.

### Helper Functions in `bin/sync`

- `spin(text) { }` — Wraps a block with a `TTY::Spinner`, calls `.success` or `.error`.
- `parse_itemize(lines)` — Parses rsync `--itemize-changes` output into categorized file lists. Recognizes `*deleting`, `<f+++`/`>f+++` (new), and `<f`/`>f` (modified) patterns.
- `generate_diffs(local_dir, remote_dir, local_files, remote_files)` — Produces unified diff sections for all changed files. Deduplicates modified files across both directions. Handles binary detection, new-only files (shown as all-`+` lines), and deleted files (shown as all-`-` lines).
- `colorize_diff(text)` — ANSI-colors diff output: bold headers, cyan hunks, green additions, red deletions.
- `binary_file?(path)` — Reads first 8KB and checks for null bytes.
- `with_silent_sshkit { }` — Temporarily replaces SSHKit's output with a `NullOutput` instance to prevent log lines from corrupting spinner output.

### Shared Module (`lib/clawkit.rb`)

Stateless utility module providing: `.load_env` (parses `.env`), `.load_config` (loads `config.yml`), `.resolve_hosts` (ENV override or config fallback), `.safe_path?` (injection prevention via regex).

### Configuration

- **`config.yml`** (gitignored) — SSH user, remote path, hosts, sync items. See `config.yml.sample`.
- **`.env`** (gitignored) — `HOSTS=` override, comma-separated.
- Sync items come from `directories:` (recursive dir sync) and `files:` (individual file sync or `"*"` wildcard for entire remote path).

## Key Design Decisions

- **`--checksum` over mtime**: rsync compares by content hash because local (macOS) and remote (Linux) always have different timestamps.
- **`-rlz` over `-a`**: Archive mode (`-a`) preserves permissions/owner/group which differ cross-platform and cause false positives.
- **Timestamp-only filter**: Even with `--checksum`, rsync reports mtime-only diffs in `--itemize-changes` output. Lines matching `/\A\.[fd]\.\.T\.+\s/` are filtered out.
- **Gateway lifecycle**: `bin/sync` always stops the gateway before syncing and restarts it after, preventing agent interference during file transfer.
- **Single host**: Despite multi-host config support, `bin/sync` only syncs to `hosts.first`.

## Code Conventions

- `frozen_string_literal: true` pragma on all Ruby files.
- UI via TTY gems: `tty-spinner` (progress), `tty-prompt` (selection), `tty-table` (status display), `tty-pager` (diff viewing).
- `Pastel` for ANSI coloring. Global `PASTEL` constant in `bin/sync`.
- `NullOutput` class silences SSHKit logging during spinner phases to prevent log lines from breaking terminal output.
- Path safety validated with `Clawkit.safe_path?` regex `/\A[\w.\/-]+\z/` before any rsync call.
