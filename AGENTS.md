# PROJECT KNOWLEDGE BASE

**Generated:** 2026-04-26 13:44 WIB
**Commit:** 96811d2
**Branch:** main
**Type:** Zellij dotfiles repository

## OVERVIEW

Cross-platform Zellij dotfiles with a single installer entry point. The repo ships OS-specific Zellij configs, optional Zellij binary install, and terminal config deployment for Foot on Linux and Alacritty on macOS.

## STRUCTURE

```text
./
├── install.sh              # Primary entry point: config symlink + binary + terminal install
├── config.Linux.kdl        # Linux Zellij config; shared plugin/default blocks are inlined here
├── config.Darwin.kdl       # macOS Zellij config; shared plugin/default blocks are inlined here
├── foot/
│   ├── foot.ini            # Linux terminal config
│   └── dank-colors.ini     # Foot color palette included by foot.ini
├── alacritty/
│   └── alacritty.toml      # macOS terminal config
├── tests/
│   ├── terminal-install.bats
│   └── test_helper.bash
├── README.md
└── AGENTS.md
```

## WHERE TO LOOK

| Task | Location | Notes |
|---|---|---|
| Installer behavior | `install.sh` | Argument parsing, OS detection, backup policy, binary download, terminal install |
| Linux Zellij keybindings | `config.Linux.kdl` | `secondary_modifier "Alt"`; shared defaults duplicated inline |
| macOS Zellij keybindings | `config.Darwin.kdl` | `secondary_modifier "Super"`; shared defaults duplicated inline |
| Foot terminal config | `foot/` | Copied into `~/.config/foot/` via `./install.sh --terminal-only` |
| Alacritty terminal config | `alacritty/` | Copied into `~/.config/alacritty/` via `./install.sh --terminal-only` |
| Installer tests | `tests/terminal-install.bats` | Bats coverage for terminal-only install, backups, missing-source failure |
| Test helpers | `tests/test_helper.bash` | Temp HOME/XDG setup and repo path helpers |

## CODE MAP

| Symbol / Block | Type | Location | Role |
|---|---|---|---|
| `detect_os` | function | `install.sh:80` | Resolves `linux` vs `darwin` for config and terminal flow |
| `os_to_config` | function | `install.sh:116` | Maps OS to `config.Linux.kdl` or `config.Darwin.kdl` |
| `install_config` | function | `install.sh:199` | Backs up existing `config.kdl`, then recreates the symlink |
| `install_foot_config` | function | `install.sh:229` | Copies `foot.ini` and `dank-colors.ini` into XDG config |
| `install_alacritty_config` | function | `install.sh:262` | Copies `alacritty.toml` into XDG config |
| `install_binary` | function | `install.sh:328` | Downloads release tarball, installs `zellij`, verifies `--version` |
| `main` | function | `install.sh:410` | Parses CLI flags and orchestrates config, terminal, and binary install |
| `plugins {}` | root block | `config.Linux.kdl`, `config.Darwin.kdl` | Shared plugin declarations duplicated into both OS configs |
| `load test_helper` | Bats load | `tests/terminal-install.bats:3` | Pulls helper functions into the test suite |
| `setup_temp_home` | function | `tests/test_helper.bash:5` | Isolates tests from the real home directory |

## CONVENTIONS

- Shared Zellij defaults are **not** stored in a separate tracked `config.shared.kdl`; both OS-specific KDL files inline the shared plugin/default blocks.
- `install.sh` is the authoritative deployment path. Config changes are applied by rerunning the installer, not by editing runtime files under `~/.config`.
- Zellij config is installed as a symlink, but terminal configs are copied file-by-file with backup creation first.
- Tests use Bats with a temporary HOME/XDG layout so installer behavior can be validated without touching the real user config.

## ANTI-PATTERNS (THIS PROJECT)

- Do not edit `~/.config/zellij/config.kdl` directly; it is replaced by `install.sh`.
- Do not assume `config.shared.kdl` exists in this repo; shared blocks currently live inline in both OS-specific files.
- Do not commit backup artifacts such as `*.backup.*`, `*.bak`, or `*.userbak-*`.
- Do not treat this as an app repo with CI/build pipelines; validation is targeted and script-driven.
- Do not edit installed terminal configs under `~/.config/foot/` or `~/.config/alacritty/` when the source of truth is the repo copy.

## UNIQUE STYLES

- Backup naming is timestamp-based and consistent across config, terminal files, and binary replacement.
- OS choice affects both the Zellij config symlink target and which terminal subtree is deployed.
- Binary installation is bundled into the same script as config deployment, so CLI flags meaningfully change which subsystems run.

## COMMANDS

```bash
# Full install: config + binary + terminal config + shell autostart
./install.sh

# Force specific OS
./install.sh linux
./install.sh darwin

# Scope-specific install modes
./install.sh --config-only
./install.sh --binary-only
./install.sh --terminal-only
./install.sh --no-terminal
./install.sh --autostart   # add autostart during scoped installs too

# Binary install variants
./install.sh --version v0.40.0
./install.sh --binary-dir "$HOME/bin"

# Script and installer validation
bats tests/terminal-install.bats
shellcheck install.sh

# Check active config symlink
ls -la ~/.config/zellij/config.kdl
```

## NOTES

- No child `AGENTS.md` files are warranted right now; `foot/`, `alacritty/`, and `tests/` are small enough to stay covered by root guidance.
- `./install.sh --help` handling is currently inconsistent: `tests/terminal-install.bats` expects exit 0, but `usage()` in `install.sh` exits 1.
- Terminal install tests cover help/unknown-arg handling, Linux Foot by default, Darwin Alacritty when the OS argument is forced, backups, missing-source failure, and destination directory creation.
- Full installs append managed bash/zsh snippets using `zellij setup --generate-auto-start ...`, wrapped in an interactive-shell check and a `zellij`-exists guard.
- `./install.sh --autostart` remains useful for scoped modes like `--terminal-only`, `--config-only`, or `--binary-only`.
- Manual verification after config edits still means rerunning `./install.sh` and reloading or restarting Zellij.
