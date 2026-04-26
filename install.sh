#!/usr/bin/env bash
#
# Zellij Config Installer
# Installs OS-specific Zellij configuration via symlink and optional binary download
#
# Usage:
#   ./install.sh                              # Auto-detect OS, install all (zellij + binary + terminal + autostart)
#   ./install.sh linux                        # Force Linux (zellij + binary + terminal + autostart)
#   ./install.sh darwin                       # Force macOS (zellij + binary + terminal + autostart)
#   ./install.sh --config-only                # Zellij config only (skip binary + terminal)
#   ./install.sh --binary-only                # Zellij binary only (skip config + terminal)
#   ./install.sh --terminal-only              # Terminal setup only (skip zellij)
#   ./install.sh --no-terminal               # Skip terminal setup
#   ./install.sh --autostart                  # Add guarded Zellij autostart to ~/.bashrc and ~/.zshrc
#   ./install.sh --version v0.40.0            # Install config + binary + terminal (pinned version)
#   ./install.sh --binary-dir "$HOME/bin"     # Custom binary install directory
#
# The script will:
#   1. Detect OS (or use provided argument)
#   2. Backup existing config if present
#   3. Symlink the appropriate OS-specific config to ~/.config/zellij/config.kdl
#   4. Download and install the Zellij binary from GitHub Releases
#   5. Install terminal setup (terminal binary + config)
#   6. Configure shell autostart for interactive local shells on full installs
#

set -euo pipefail

# Configuration
CONFIG_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/zellij"
CONFIG_FILE="config.kdl"
REPO_DIR="$(cd "$(dirname "$0")" && pwd)"
BINARY_DIR="$HOME/.local/bin"
ZELLIJ_VERSION=""
INSTALL_BINARY=true
INSTALL_CONFIG=true
INSTALL_TERMINAL=true
INSTALL_AUTOSTART=true

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
  local exit_code="${1:-1}"

  echo "Usage:"
  echo "  $0 [linux|darwin] [options]"
  echo ""
  echo "Options:"
  echo "  linux              Force Linux configuration"
  echo "  darwin             Force macOS configuration"
  echo "  --config-only      Install config only (skip zellij binary + terminal setup)"
  echo "  --binary-only      Install Zellij binary only (skip config + terminal setup)"
  echo "  --terminal-only    Install terminal setup only (skip zellij config + binary)"
  echo "  --no-terminal      Skip terminal setup"
  echo "  --autostart        Add guarded Zellij autostart to ~/.bashrc and ~/.zshrc"
  echo "  --version VERSION  Install specific Zellij version"
  echo "  --binary-dir PATH  Install binary into PATH (default: $HOME/.local/bin)"
  echo "  -h, --help         Show this help message"
  echo ""
  echo "Default: installs zellij config + binary + terminal setup + shell autostart"
  echo ""
  echo "Terminal setup:"
  echo "  Linux:   install Foot via apt-get/apt, dnf, or pacman, then copy config from \$REPO_DIR/foot/"
  echo "  macOS:   install Alacritty via Homebrew, then copy config from \$REPO_DIR/alacritty/"
  exit "$exit_code"
}

# Detect OS
detect_os() {
  local os
  os="$(uname -s)"
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

# Detect CPU architecture
detect_arch() {
  local arch
  arch="$(uname -m)"
  case "$arch" in
  x86_64 | amd64)
    echo "x86_64"
    ;;
  aarch64 | arm64)
    echo "aarch64"
    ;;
  *)
    log_error "Unsupported architecture: $arch"
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

# Map OS and architecture to Rust target triple
os_to_rust_target() {
  local os="$1"
  local arch="$2"

  case "$os:$arch" in
  linux:x86_64)
    echo "x86_64-unknown-linux-musl"
    ;;
  linux:aarch64)
    echo "aarch64-unknown-linux-musl"
    ;;
  darwin:x86_64)
    echo "x86_64-apple-darwin"
    ;;
  darwin:aarch64)
    echo "aarch64-apple-darwin"
    ;;
  *)
    log_error "Unsupported OS/architecture combination: $os/$arch"
    exit 1
    ;;
  esac
}

# Get latest Zellij release version from GitHub API
get_latest_version() {
  local version=""

  if ! command -v curl >/dev/null 2>&1; then
    log_error "curl is required to install the Zellij binary"
    exit 1
  fi

  version=$(curl -sL "https://api.github.com/repos/zellij-org/zellij/releases/latest" | grep -m1 '"tag_name":' | sed -E 's/.*"tag_name":[[:space:]]*"([^"]+)".*/\1/')

  if [ -z "$version" ]; then
    log_error "Failed to determine latest Zellij version from GitHub Releases"
    exit 1
  fi

  echo "$version"
}

# Build GitHub Releases download URL
build_download_url() {
  local os="$1"
  local arch="$2"
  local version="$3"
  local target=""

  target=$(os_to_rust_target "$os" "$arch")
  echo "https://github.com/zellij-org/zellij/releases/download/${version}/zellij-${target}.tar.gz"
}

# Create backup of existing config
backup_existing() {
  local config_path="$1"
  if [ -e "$config_path" ]; then
    local backup_path
    backup_path="${config_path}.backup.$(date +%Y%m%d-%H%M%S)"
    log_info "Backing up existing config to: $backup_path"
    cp -a "$config_path" "$backup_path"
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

# Backup existing file
backup_file() {
  local file_path="$1"
  if [ -e "$file_path" ]; then
    local backup_path
    backup_path="${file_path}.backup.$(date +%Y%m%d-%H%M%S)"
    log_info "Backing up existing file to: $backup_path"
    cp -a "$file_path" "$backup_path"
  fi
}

backup_shell_rc_file() {
  local file_path="$1"
  if [ -e "$file_path" ] || [ -L "$file_path" ]; then
    local backup_path
    backup_path="${file_path}.backup.$(date +%Y%m%d-%H%M%S)"
    log_info "Backing up existing shell rc file to: $backup_path"

    if [ -L "$file_path" ]; then
      cp -aL "$file_path" "$backup_path"
    else
      cp -a "$file_path" "$backup_path"
    fi
  fi
}

append_autostart_snippet() {
  local rc_file="$1"
  local shell_name="$2"
  local marker_start="# >>> zellij-autostart (managed by zellij-dotfiles) >>>"

  if [ -f "$rc_file" ] && grep -Fq "$marker_start" "$rc_file"; then
    log_info "Zellij autostart already configured in: $rc_file"
    return 0
  fi

  if [ -f "$rc_file" ] || [ -L "$rc_file" ]; then
    backup_shell_rc_file "$rc_file"
  fi

  mkdir -p "$(dirname "$rc_file")"
  touch "$rc_file"

  if [ -s "$rc_file" ]; then
    printf '\n' >>"$rc_file"
  fi

  cat <<EOF >>"$rc_file"
# >>> zellij-autostart (managed by zellij-dotfiles) >>>
if [[ \$- == *i* ]] && [ -z "\${SSH_CONNECTION:-}\${SSH_CLIENT:-}\${SSH_TTY:-}" ] && command -v zellij >/dev/null 2>&1; then
  eval "\$(zellij setup --generate-auto-start ${shell_name})"
fi
# <<< zellij-autostart <<<
EOF

  log_info "Configured Zellij autostart in: $rc_file"
}

install_shell_autostart() {
  append_autostart_snippet "$HOME/.bashrc" "bash"
  append_autostart_snippet "$HOME/.zshrc" "zsh"

  log_info "Done! Zellij autostart configured for interactive local bash/zsh shells"
}

# Detect supported Linux package manager for Foot
detect_foot_package_manager() {
  if command -v apt-get >/dev/null 2>&1; then
    echo "apt-get"
    return 0
  fi

  if command -v apt >/dev/null 2>&1; then
    echo "apt"
    return 0
  fi

  if command -v dnf >/dev/null 2>&1; then
    echo "dnf"
    return 0
  fi

  if command -v pacman >/dev/null 2>&1; then
    echo "pacman"
    return 0
  fi

  echo ""
}

check_foot_install_prerequisites() {
  local package_manager=""

  if command -v foot >/dev/null 2>&1; then
    return 0
  fi

  package_manager=$(detect_foot_package_manager)
  if [ -z "$package_manager" ]; then
    log_error "Foot installation is only supported with apt-get, apt, dnf, or pacman"
    exit 1
  fi

  if [ "$(id -u)" -ne 0 ]; then
    log_error "Installing Foot via ${package_manager} requires elevated privileges; install Foot first, then rerun this installer as your normal user"
    exit 1
  fi
}

install_foot_binary() {
  local package_manager=""

  if command -v foot >/dev/null 2>&1; then
    log_info "Foot is already available: $(command -v foot)"
    return 0
  fi

  check_foot_install_prerequisites

  package_manager=$(detect_foot_package_manager)

  log_info "Installing Foot via ${package_manager}"
  case "$package_manager" in
  apt-get)
    if ! DEBIAN_FRONTEND=noninteractive apt-get install -y foot; then
      log_error "Failed to install Foot with apt-get"
      exit 1
    fi
    ;;
  apt)
    if ! DEBIAN_FRONTEND=noninteractive apt install -y foot; then
      log_error "Failed to install Foot with apt"
      exit 1
    fi
    ;;
  dnf)
    if ! dnf install -y foot; then
      log_error "Failed to install Foot with dnf"
      exit 1
    fi
    ;;
  pacman)
    if ! pacman -S --noconfirm foot; then
      log_error "Failed to install Foot with pacman"
      exit 1
    fi
    ;;
  esac

  if ! command -v foot >/dev/null 2>&1; then
    log_error "Foot installation completed but the foot binary is still unavailable in PATH"
    exit 1
  fi

  log_info "Done! Foot installed via ${package_manager}"
}

# Install foot terminal config (Linux)
install_foot_config() {
  local src_dir="${REPO_DIR}/foot"
  local target_dir="${XDG_CONFIG_HOME:-$HOME/.config}/foot"
  local file=""
  local src_file=""
  local target_file=""

  if [ ! -d "$src_dir" ]; then
    log_error "Foot config source not found: $src_dir"
    exit 1
  fi

  mkdir -p "$target_dir"

  for file in foot.ini dank-colors.ini; do
    src_file="${src_dir}/${file}"
    target_file="${target_dir}/${file}"

    if [ ! -f "$src_file" ]; then
      log_error "Source file not found: $src_file"
      exit 1
    fi

    if [ -e "$target_file" ] || [ -L "$target_file" ]; then
      backup_file "$target_file"
      rm -f "$target_file"
    fi

    log_info "Installing $file to $target_file"
    cp -a "$src_file" "$target_file"
  done

  log_info "Done! Foot config installed to: $target_dir"
}

install_alacritty_binary() {
  if command -v alacritty >/dev/null 2>&1; then
    log_info "Alacritty is already available: $(command -v alacritty)"
    return 0
  fi

  if ! command -v brew >/dev/null 2>&1; then
    log_error "Homebrew is required to install Alacritty on macOS"
    exit 1
  fi

  log_info "Installing Alacritty via Homebrew"
  if ! brew install alacritty; then
    log_error "Failed to install Alacritty with Homebrew"
    exit 1
  fi

  if ! command -v alacritty >/dev/null 2>&1; then
    log_error "Alacritty installation completed but the alacritty binary is still unavailable in PATH"
    exit 1
  fi

  log_info "Done! Alacritty installed via Homebrew"
}

preflight_terminal_setup() {
  local os="$1"

  case "$os" in
  linux)
    check_foot_install_prerequisites
    ;;
  darwin)
    if ! command -v alacritty >/dev/null 2>&1 && ! command -v brew >/dev/null 2>&1; then
      log_error "Homebrew is required to install Alacritty on macOS"
      exit 1
    fi
    ;;
  esac
}

# Install alacritty terminal config (macOS)
install_alacritty_config() {
  local src_dir="${REPO_DIR}/alacritty"
  local target_dir="${XDG_CONFIG_HOME:-$HOME/.config}/alacritty"

  if [ ! -d "$src_dir" ]; then
    log_error "Alacritty config source not found: $src_dir"
    exit 1
  fi

  mkdir -p "$target_dir"

  if [ ! -f "${src_dir}/alacritty.toml" ]; then
    log_error "Source file not found: ${src_dir}/alacritty.toml"
    exit 1
  fi

  local target_file="${target_dir}/alacritty.toml"
  if [ -e "$target_file" ] || [ -L "$target_file" ]; then
    backup_file "$target_file"
    rm -f "$target_file"
  fi

  log_info "Installing alacritty.toml to $target_file"
  cp -a "${src_dir}/alacritty.toml" "$target_file"

  log_info "Done! Alacritty config installed to: $target_dir"
}

# Install terminal binary based on OS
install_terminal_binary() {
  local os="$1"
  case "$os" in
  linux)
    install_foot_binary
    ;;
  darwin)
    install_alacritty_binary
    ;;
  esac
}

# Install terminal setup based on OS
install_terminal_setup() {
  local os="$1"

  install_terminal_binary "$os"

  case "$os" in
  linux)
    install_foot_config
    ;;
  darwin)
    install_alacritty_config
    ;;
  esac
}

# Check for existing Zellij binary installation
check_existing_binary() {
  local binary_path=""
  local binary_version=""

  for binary_path in "$HOME/.local/bin/zellij" "/usr/local/bin/zellij"; do
    if [ -x "$binary_path" ]; then
      binary_version=$("$binary_path" --version 2>/dev/null || true)
      echo "$binary_version"
      return 0
    fi
  done

  # shellcheck disable=SC2230
  binary_path=$(which zellij 2>/dev/null || true)
  if [ -n "$binary_path" ] && [ -x "$binary_path" ]; then
    binary_version=$("$binary_path" --version 2>/dev/null || true)
    echo "$binary_version"
    return 0
  fi

  echo ""
}

# Install Zellij binary from GitHub Releases
install_binary() {
  local os="$1"
  local version="$2"
  local install_dir="$3"
  local tmp_dir=""
  local arch=""
  local download_url=""
  local archive_path=""
  local install_path="${install_dir}/zellij"
  local resolved_version="$version"
  local existing_version=""
  local backup_path=""

  cleanup_binary_install() {
    if [ -n "${tmp_dir:-}" ] && [ -d "$tmp_dir" ]; then
      rm -rf "$tmp_dir"
    fi
  }

  if ! command -v curl >/dev/null 2>&1; then
    log_error "curl is required to install the Zellij binary"
    exit 1
  fi

  if ! command -v tar >/dev/null 2>&1; then
    log_error "tar is required to install the Zellij binary"
    exit 1
  fi

  existing_version=$(check_existing_binary)
  if [ -n "$existing_version" ]; then
    log_info "Existing Zellij binary detected: $existing_version"
  fi

  if [ -z "$resolved_version" ]; then
    resolved_version=$(get_latest_version)
    log_info "Resolved latest Zellij version: $resolved_version"
  fi

  arch=$(detect_arch)
  download_url=$(build_download_url "$os" "$arch" "$resolved_version")

  tmp_dir=$(mktemp -d)
  archive_path="${tmp_dir}/zellij.tar.gz"
  trap cleanup_binary_install RETURN

  log_info "Downloading Zellij ${resolved_version} for ${os}/${arch}"
  if ! curl -fL "$download_url" -o "$archive_path"; then
    log_error "Failed to download Zellij from: $download_url"
    exit 1
  fi

  log_info "Extracting archive"
  tar -xzf "$archive_path" -C "$tmp_dir"

  if [ ! -f "$tmp_dir/zellij" ]; then
    log_error "Extracted archive does not contain zellij binary"
    exit 1
  fi

  mkdir -p "$install_dir"

  if [ -e "$install_path" ]; then
    backup_path="${install_path}.backup.$(date +%Y%m%d-%H%M%S)"
    log_info "Backing up existing binary to: $backup_path"
    mv "$install_path" "$backup_path"
  fi

  log_info "Installing binary to: $install_path"
  mv "$tmp_dir/zellij" "$install_path"
  chmod +x "$install_path"

  if ! "$install_path" --version >/dev/null 2>&1; then
    log_error "Installed binary verification failed: $install_path --version"
    exit 1
  fi

  log_info "Done! Zellij binary installed to: $install_path"
  log_info "Installed version: $("$install_path" --version)"
}

# Main
main() {
  local os=""
  local config_file=""
  local scoped_install=false
  local autostart_explicit=false

  # Parse arguments
  while [ $# -gt 0 ]; do
    arg=$(printf '%s' "$1" | tr '[:upper:]' '[:lower:]')
    case "$arg" in
    linux)
      os="linux"
      ;;
    darwin | macos)
      os="darwin"
      ;;
    --config-only)
      INSTALL_BINARY=false
      INSTALL_TERMINAL=false
      scoped_install=true
      ;;
    --binary-only)
      INSTALL_BINARY=true
      INSTALL_CONFIG=false
      INSTALL_TERMINAL=false
      scoped_install=true
      ;;
    --terminal-only)
      INSTALL_BINARY=false
      INSTALL_CONFIG=false
      INSTALL_TERMINAL=true
      scoped_install=true
      ;;
    --no-terminal)
      INSTALL_TERMINAL=false
      ;;
    --autostart)
      autostart_explicit=true
      ;;
    --version)
      if [ $# -lt 2 ]; then
        log_error "Missing value for --version"
        usage 1
      fi
      ZELLIJ_VERSION="$2"
      INSTALL_BINARY=true
      shift
      ;;
    --binary-dir)
      if [ $# -lt 2 ]; then
        log_error "Missing value for --binary-dir"
        usage 1
      fi
      BINARY_DIR="$2"
      shift
      ;;
    -h | --help | help)
      usage 0
      ;;
    *)
      log_error "Unknown argument: $1"
      usage 1
      ;;
    esac
    shift
  done

  if [ "$scoped_install" = true ] && [ "$autostart_explicit" = false ]; then
    INSTALL_AUTOSTART=false
  else
    INSTALL_AUTOSTART=true
  fi

  if [ -z "$os" ]; then
    os=$(detect_os)
    log_info "Detected OS: $os"
  fi

  if [ "$INSTALL_TERMINAL" = true ]; then
    preflight_terminal_setup "$os"
  fi

  if [ "$INSTALL_CONFIG" = true ]; then
    config_file=$(os_to_config "$os")

    # Verify config file exists
    local src_path="$REPO_DIR/$config_file"
    if [ ! -f "$src_path" ]; then
      log_error "Config file not found: $src_path"
      log_error "Make sure you're running this script from the dotfiles directory."
      exit 1
    fi

    # Install config
    local target_path="$CONFIG_DIR/$CONFIG_FILE"
    log_info "Installing $os config: $config_file"
    install_config "$src_path" "$target_path"

    log_info "Done! Zellij config installed to: $target_path"
    log_info "Restart Zellij or press Ctrl+G twice to reload configuration."
  fi

  if [ "$INSTALL_TERMINAL" = true ]; then
    log_info "Installing terminal setup for $os"
    install_terminal_setup "$os"
  fi

  if [ "$INSTALL_BINARY" = true ]; then
    install_binary "$os" "$ZELLIJ_VERSION" "$BINARY_DIR"
    log_info "Add $BINARY_DIR to PATH if it is not already available in your shell."
  fi

  if [ "$INSTALL_AUTOSTART" = true ]; then
    install_shell_autostart
  fi
}

main "$@"
