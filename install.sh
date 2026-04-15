#!/usr/bin/env bash
#
# Zellij Config Installer
# Installs OS-specific Zellij configuration via symlink
#
# Usage:
#   ./install.sh          # Auto-detect OS
#   ./install.sh linux    # Force Linux config
#   ./install.sh darwin   # Force macOS config
#
# The script will:
#   1. Detect OS (or use provided argument)
#   2. Backup existing config if present
#   3. Symlink the appropriate OS-specific config to ~/.config/zellij/config.kdl
#

set -euo pipefail

# Configuration
CONFIG_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/zellij"
CONFIG_FILE="config.kdl"
REPO_DIR="$(cd "$(dirname "$0")" && pwd)"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Logging functions
log_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Show usage
usage() {
    echo "Usage: $0 [linux|darwin]"
    echo ""
    echo "Options:"
    echo "  linux    Force Linux configuration (Alt as secondary modifier)"
    echo "  darwin   Force macOS configuration (Shift+Cmd as secondary modifier)"
    echo "  (none)   Auto-detect OS"
    exit 1
}

# Detect OS
detect_os() {
    local os="$(uname -s)"
    case "$os" in
        Linux*)
            echo "linux"
            ;;
        Darwin*)
            echo "darwin"
            ;;
        *)
            log_error "Unsupported OS: $os"
            exit 1
            ;;
    esac
}

# Map OS to config file
os_to_config() {
    local os="$1"
    case "$os" in
        linux)
            echo "config.Linux.kdl"
            ;;
        darwin)
            echo "config.Darwin.kdl"
            ;;
        *)
            log_error "Unknown OS: $os"
            exit 1
            ;;
    esac
}

# Create backup of existing config
backup_existing() {
    local config_path="$1"
    if [ -e "$config_path" ]; then
        local backup_path="${config_path}.backup.$(date +%Y%m%d-%H%M%S)"
        log_info "Backing up existing config to: $backup_path"
        cp "$config_path" "$backup_path"
    fi
}

# Install config via symlink
install_config() {
    local src_file="$1"
    local target_link="$2"

    # Create parent directory if needed
    mkdir -p "$(dirname "$target_link")"

    # Backup existing config
    if [ -e "$target_link" ] || [ -L "$target_link" ]; then
        backup_existing "$target_link"
        rm "$target_link"
    fi

    # Create symlink
    log_info "Creating symlink: $target_link -> $src_file"
    ln -s "$src_file" "$target_link"
}

# Main
main() {
    local os=""
    local config_file=""

    # Parse arguments
    if [ $# -eq 0 ]; then
        os=$(detect_os)
        log_info "Detected OS: $os"
    elif [ $# -eq 1 ]; then
        case "$1" in
            linux|Linux|LINUX)
                os="linux"
                ;;
            darwin|Darwin|DARWIN|macos|macOS|MACOS)
                os="darwin"
                ;;
            -h|--help|help)
                usage
                ;;
            *)
                log_error "Unknown argument: $1"
                usage
                ;;
        esac
    else
        usage
    fi

    config_file=$(os_to_config "$os")

    # Verify config file exists
    local src_path="$REPO_DIR/$config_file"
    if [ ! -f "$src_path" ]; then
        log_error "Config file not found: $src_path"
        log_error "Make sure you're running this script from the dotfiles directory."
        exit 1
    fi

    # Install
    local target_path="$CONFIG_DIR/$CONFIG_FILE"
    log_info "Installing $os config: $config_file"
    install_config "$src_path" "$target_path"

    log_info "Done! Zellij config installed to: $target_path"
    log_info "Restart Zellij or press Ctrl+G twice to reload configuration."
}

main "$@"