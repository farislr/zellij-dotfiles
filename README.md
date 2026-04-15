# Zellij Dotfiles

Cross-platform Zellij configuration with Linux/macOS support.

## Quick Start

```bash
git clone https://github.com/farislr/zellij-dotfiles.git ~/.config/zellij
cd ~/.config/zellij && ./install.sh
```

## Structure

```
config.shared.kdl    # Shared config (plugins, themes)
config.Linux.kdl     # Linux keybindings (Alt modifier)
config.Darwin.kdl    # macOS keybindings (Shift+Cmd modifier)
install.sh           # OS-aware installer
```

## Keybindings

| Modifier | Linux | macOS |
|----------|-------|-------|
| Secondary | `Alt` | `Shift+Cmd` |

See `config.Linux.kdl` or `config.Darwin.kdl` for full keybind documentation.

## Reinstall

```bash
./install.sh         # Auto-detect OS
./install.sh linux   # Force Linux
./install.sh darwin  # Force macOS
```

## Update Config

1. Edit `config.Linux.kdl` and/or `config.Darwin.kdl`
2. Run `./install.sh` to apply changes

## Backup

Old configs are backed up with timestamp: `config.kdl.backup.YYYYMMDD-HHMMSS`
