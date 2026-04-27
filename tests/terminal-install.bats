#!/usr/bin/env bats

load test_helper

setup() {
    TEST_TMPDIR="$(setup_temp_home)"
}

teardown() {
    teardown_temp_home
}

setup_linux_terminal_stub_bin() {
    local stub_bin="$1"

    setup_stub_bin "$stub_bin"
    stub_root_id "$stub_bin"
    stub_apt_get_foot_install "$stub_bin"
    export STUB_BIN="$stub_bin"
    export XDG_CONFIG_HOME="${HOME}/.config"
}

setup_darwin_terminal_stub_bin() {
    local stub_bin="$1"

    setup_stub_bin "$stub_bin"
    stub_brew_alacritty_install "$stub_bin"
    export STUB_BIN="$stub_bin"
    export XDG_CONFIG_HOME="${HOME}/.config"
}

setup_full_install_stub_bin() {
    local stub_bin="$1"

    setup_linux_terminal_stub_bin "$stub_bin"
    stub_zellij_release_tools "$stub_bin"
}

@test "install.sh exists and is executable" {
    local repo_dir
    repo_dir="$(get_repo_dir)"
    local script="${repo_dir}/install.sh"
    [ -f "$script" ]
    [ -x "$script" ]
}

@test "--help prints usage and exits 0" {
    local repo_dir
    repo_dir="$(get_repo_dir)"
    run "${repo_dir}/install.sh" --help
    [ "$status" -eq 0 ]
    [[ "$output" == Usage:* ]]
}

@test "unknown argument exits non-zero" {
    local repo_dir
    repo_dir="$(get_repo_dir)"
    run "${repo_dir}/install.sh" --unknown-arg
    [ "$status" -ne 0 ]
}

@test "default install adds documented zellij integration to bash rc when SHELL is bash" {
    local repo_dir
    repo_dir="$(get_repo_dir)"
    local script="${repo_dir}/install.sh"
    local stub_bin="${HOME}/bin"

    setup_full_install_stub_bin "$stub_bin"

    SHELL=/bin/bash PATH="$stub_bin" run "$script"
    [ "$status" -eq 0 ]

    [ -f "${HOME}/.bashrc" ]
    [ ! -f "${HOME}/.zshrc" ]
    [ -x "${stub_bin}/foot" ]
    [ -f "${XDG_CONFIG_HOME}/foot/foot.ini" ]
    [ -f "${XDG_CONFIG_HOME}/foot/dank-colors.ini" ]

    grep -Fq '# >>> zellij-autostart (managed by zellij-dotfiles) >>>' "${HOME}/.bashrc"
    grep -Fq '[[ $- == *i* ]]' "${HOME}/.bashrc"
    grep -Fq '${SSH_CONNECTION:-}${SSH_CLIENT:-}${SSH_TTY:-}' "${HOME}/.bashrc"
    grep -Fq 'command -v zellij >/dev/null 2>&1' "${HOME}/.bashrc"
    grep -Fq 'export ZELLIJ_AUTO_EXIT=true' "${HOME}/.bashrc"
    grep -Fq 'eval "$(zellij setup --generate-auto-start bash)"' "${HOME}/.bashrc"
}

@test "default install adds documented zellij integration to zsh rc when SHELL is zsh" {
    local repo_dir
    repo_dir="$(get_repo_dir)"
    local script="${repo_dir}/install.sh"
    local stub_bin="${HOME}/bin"

    setup_full_install_stub_bin "$stub_bin"

    SHELL=/bin/zsh PATH="$stub_bin" run "$script"
    [ "$status" -eq 0 ]

    [ ! -f "${HOME}/.bashrc" ]
    [ -f "${HOME}/.zshrc" ]

    grep -Fq '# >>> zellij-autostart (managed by zellij-dotfiles) >>>' "${HOME}/.zshrc"
    grep -Fq 'export ZELLIJ_AUTO_EXIT=true' "${HOME}/.zshrc"
    grep -Fq 'eval "$(zellij setup --generate-auto-start zsh)"' "${HOME}/.zshrc"
}

@test "default autostart is idempotent across repeated full installs" {
    local repo_dir
    repo_dir="$(get_repo_dir)"
    local script="${repo_dir}/install.sh"
    local bash_count
    local stub_bin="${HOME}/bin"

    setup_full_install_stub_bin "$stub_bin"

    SHELL=/bin/bash PATH="$stub_bin" run "$script"
    [ "$status" -eq 0 ]

    SHELL=/bin/bash PATH="$stub_bin" run "$script"
    [ "$status" -eq 0 ]

    bash_count=$(grep -cF '# >>> zellij-autostart (managed by zellij-dotfiles) >>>' "${HOME}/.bashrc")
    [ "$bash_count" -eq 1 ]
    [ ! -f "${HOME}/.zshrc" ]
}

@test "existing bash rc file is backed up during default autostart setup" {
    local repo_dir
    repo_dir="$(get_repo_dir)"
    local script="${repo_dir}/install.sh"
    local bash_backup_count
    local stub_bin="${HOME}/bin"

    setup_full_install_stub_bin "$stub_bin"

    echo "# existing bash config" > "${HOME}/.bashrc"

    SHELL=/bin/bash PATH="$stub_bin" run "$script"
    [ "$status" -eq 0 ]

    bash_backup_count=$(find "$HOME" -maxdepth 1 -name '.bashrc.backup.*' | wc -l)
    [ "$bash_backup_count" -ge 1 ]
}

@test "existing zsh rc file is backed up during default autostart setup" {
    local repo_dir
    repo_dir="$(get_repo_dir)"
    local script="${repo_dir}/install.sh"
    local zsh_backup_count
    local stub_bin="${HOME}/bin"

    setup_full_install_stub_bin "$stub_bin"

    echo "# existing zsh config" > "${HOME}/.zshrc"

    SHELL=/bin/zsh PATH="$stub_bin" run "$script"
    [ "$status" -eq 0 ]

    zsh_backup_count=$(find "$HOME" -maxdepth 1 -name '.zshrc.backup.*' | wc -l)
    [ "$zsh_backup_count" -ge 1 ]
}

@test "symlinked bash rc file gets a real-content backup during default autostart setup" {
    local repo_dir
    repo_dir="$(get_repo_dir)"
    local script="${repo_dir}/install.sh"
    local bash_target="${HOME}/bashrc-source"
    local bash_backup
    local stub_bin="${HOME}/bin"

    setup_full_install_stub_bin "$stub_bin"

    printf '# bash target\n' > "$bash_target"
    ln -s "$bash_target" "${HOME}/.bashrc"

    SHELL=/bin/bash PATH="$stub_bin" run "$script"
    [ "$status" -eq 0 ]

    bash_backup=$(find "$HOME" -maxdepth 1 -name '.bashrc.backup.*' | head -n 1)
    [ -n "$bash_backup" ]
    [ ! -L "$bash_backup" ]
    grep -Fq '# bash target' "$bash_backup"
}

@test "symlinked zsh rc file gets a real-content backup during default autostart setup" {
    local repo_dir
    repo_dir="$(get_repo_dir)"
    local script="${repo_dir}/install.sh"
    local zsh_target="${HOME}/zshrc-source"
    local zsh_backup
    local stub_bin="${HOME}/bin"

    setup_full_install_stub_bin "$stub_bin"

    printf '# zsh target\n' > "$zsh_target"
    ln -s "$zsh_target" "${HOME}/.zshrc"

    SHELL=/bin/zsh PATH="$stub_bin" run "$script"
    [ "$status" -eq 0 ]

    zsh_backup=$(find "$HOME" -maxdepth 1 -name '.zshrc.backup.*' | head -n 1)
    [ -n "$zsh_backup" ]
    [ ! -L "$zsh_backup" ]
    grep -Fq '# zsh target' "$zsh_backup"
}

@test "--terminal-only does not modify shell rc files unless --autostart is added" {
    local repo_dir
    repo_dir="$(get_repo_dir)"
    local script="${repo_dir}/install.sh"
    local stub_bin="${HOME}/bin"

    setup_linux_terminal_stub_bin "$stub_bin"

    PATH="$stub_bin" run "$script" --terminal-only
    [ "$status" -eq 0 ]

    [ ! -f "${HOME}/.bashrc" ]
    [ ! -f "${HOME}/.zshrc" ]
}

@test "--autostart still enables bash shell integration for scoped installs when SHELL is bash" {
    local repo_dir
    repo_dir="$(get_repo_dir)"
    local script="${repo_dir}/install.sh"
    local stub_bin="${HOME}/bin"

    setup_linux_terminal_stub_bin "$stub_bin"

    SHELL=/bin/bash PATH="$stub_bin" run "$script" --autostart --terminal-only
    [ "$status" -eq 0 ]
    [ -f "${HOME}/.bashrc" ]
    [ ! -f "${HOME}/.zshrc" ]
}

@test "scoped install autostart override is order-independent" {
    local repo_dir
    repo_dir="$(get_repo_dir)"
    local script="${repo_dir}/install.sh"
    local stub_bin="${HOME}/bin"

    setup_linux_terminal_stub_bin "$stub_bin"

    SHELL=/bin/bash PATH="$stub_bin" run "$script" --terminal-only --autostart
    [ "$status" -eq 0 ]
    [ -f "${HOME}/.bashrc" ]
    [ ! -f "${HOME}/.zshrc" ]
}

@test "--autostart also enables shell integration for --config-only" {
    local repo_dir
    repo_dir="$(get_repo_dir)"
    local script="${repo_dir}/install.sh"

    SHELL=/bin/bash run "$script" --config-only --autostart
    [ "$status" -eq 0 ]
    [ -f "${HOME}/.bashrc" ]
    [ ! -f "${HOME}/.zshrc" ]
}

@test "--autostart also enables shell integration for --binary-only" {
    local repo_dir
    repo_dir="$(get_repo_dir)"
    local script="${repo_dir}/install.sh"
    local stub_bin="${HOME}/bin"

    setup_stub_bin "$stub_bin"
    stub_zellij_release_tools "$stub_bin"
    export STUB_BIN="$stub_bin"

    SHELL=/bin/bash PATH="$stub_bin" run "$script" --binary-only --autostart
    [ "$status" -eq 0 ]
    [ -f "${HOME}/.bashrc" ]
    [ ! -f "${HOME}/.zshrc" ]
}

@test "unsupported SHELL skips autostart changes without failing the install" {
    local repo_dir
    repo_dir="$(get_repo_dir)"
    local script="${repo_dir}/install.sh"
    local stub_bin="${HOME}/bin"

    setup_full_install_stub_bin "$stub_bin"

    SHELL=/bin/fish PATH="$stub_bin" run "$script"
    [ "$status" -eq 0 ]
    [[ "$output" == *"Unsupported shell for Zellij autostart: fish"* ]]
    [ ! -f "${HOME}/.bashrc" ]
    [ ! -f "${HOME}/.zshrc" ]
}

@test "unset SHELL skips autostart changes without failing the install" {
    local repo_dir
    repo_dir="$(get_repo_dir)"
    local script="${repo_dir}/install.sh"
    local stub_bin="${HOME}/bin"

    setup_full_install_stub_bin "$stub_bin"

    env -u SHELL PATH="$stub_bin" "$script" >"${HOME}/install.log" 2>&1

    grep -Fq 'SHELL is unset; skipping Zellij autostart configuration' "${HOME}/install.log"
    [ ! -f "${HOME}/.bashrc" ]
    [ ! -f "${HOME}/.zshrc" ]
}

@test "autostart target follows SHELL even when invoked from a different shell" {
    local repo_dir
    repo_dir="$(get_repo_dir)"
    local script="${repo_dir}/install.sh"
    local stub_bin="${HOME}/bin"

    setup_full_install_stub_bin "$stub_bin"

    SHELL=/bin/zsh PATH="$stub_bin" bash "$script"

    [ ! -f "${HOME}/.bashrc" ]
    [ -f "${HOME}/.zshrc" ]
    grep -Fq 'eval "$(zellij setup --generate-auto-start zsh)"' "${HOME}/.zshrc"
}

@test "--terminal-only installs Foot via apt-get and copies Linux config" {
    local repo_dir
    repo_dir="$(get_repo_dir)"
    local script="${repo_dir}/install.sh"
    local stub_bin="${HOME}/bin"

    setup_linux_terminal_stub_bin "$stub_bin"

    PATH="$stub_bin" run "$script" --terminal-only
    [ "$status" -eq 0 ]

    [ -x "${stub_bin}/foot" ]
    [ -f "${XDG_CONFIG_HOME}/foot/foot.ini" ]
    [ -f "${XDG_CONFIG_HOME}/foot/dank-colors.ini" ]
    grep -Fq 'install -y foot' "${stub_bin}/apt-get.log"
}

@test "--terminal-only installs Alacritty via Homebrew and copies macOS config" {
    local repo_dir
    repo_dir="$(get_repo_dir)"
    local script="${repo_dir}/install.sh"
    local stub_bin="${HOME}/bin"

    setup_darwin_terminal_stub_bin "$stub_bin"

    PATH="$stub_bin" run "$script" darwin --terminal-only
    [ "$status" -eq 0 ]

    [ -x "${stub_bin}/alacritty" ]
    [ -f "${XDG_CONFIG_HOME}/alacritty/alacritty.toml" ]
    grep -Fq 'install alacritty' "${stub_bin}/brew.log"
}

@test "existing terminal config is backed up with timestamp" {
    local repo_dir
    repo_dir="$(get_repo_dir)"
    local script="${repo_dir}/install.sh"
    local stub_bin="${HOME}/bin"

    setup_linux_terminal_stub_bin "$stub_bin"

    mkdir -p "${XDG_CONFIG_HOME}/foot"
    echo "existing config" > "${XDG_CONFIG_HOME}/foot/foot.ini"

    PATH="$stub_bin" run "$script" --terminal-only
    [ "$status" -eq 0 ]

    local backup_count
    backup_count=$(find "${XDG_CONFIG_HOME}/foot" -name "foot.ini.backup.*" | wc -l)
    [ "$backup_count" -ge 1 ]

    [ -f "${XDG_CONFIG_HOME}/foot/foot.ini" ]
    ! grep -q "existing config" "${XDG_CONFIG_HOME}/foot/foot.ini"
}

@test "missing source file fails with clear error" {
    local repo_dir
    repo_dir="$(get_repo_dir)"
    local stub_bin="${HOME}/bin"
    local foot_backup="${repo_dir}/foot.bak"

    setup_linux_terminal_stub_bin "$stub_bin"

    mv "${repo_dir}/foot" "$foot_backup"

    cleanup_missing_source_fixture() {
        if [ -d "$foot_backup" ]; then
            mv "$foot_backup" "${repo_dir}/foot"
        fi
    }

    trap cleanup_missing_source_fixture RETURN

    PATH="$stub_bin" run "${repo_dir}/install.sh" --terminal-only
    [ "$status" -ne 0 ]
}

@test "destination directory is created automatically" {
    local repo_dir
    repo_dir="$(get_repo_dir)"
    local script="${repo_dir}/install.sh"
    local stub_bin="${HOME}/bin"

    setup_linux_terminal_stub_bin "$stub_bin"
    rm -rf "${XDG_CONFIG_HOME}/foot"

    PATH="$stub_bin" run "$script" --terminal-only
    [ "$status" -eq 0 ]
    [ -d "${XDG_CONFIG_HOME}/foot" ]
}

@test "--terminal-only fails with a clear privilege error when Foot install needs elevation" {
    local repo_dir
    repo_dir="$(get_repo_dir)"
    local script="${repo_dir}/install.sh"
    local stub_bin="${HOME}/bin"

    setup_stub_bin "$stub_bin"
    stub_non_root_id "$stub_bin"
    stub_apt_get_foot_install "$stub_bin"
    export STUB_BIN="$stub_bin"
    export XDG_CONFIG_HOME="${HOME}/.config"

    PATH="$stub_bin" run "$script" --terminal-only
    [ "$status" -ne 0 ]
    [[ "$output" == *"requires elevated privileges"* ]]
    [[ "$output" == *"rerun this installer as your normal user"* ]]
}

@test "--terminal-only fails with a clear error for unsupported Linux package managers" {
    local repo_dir
    repo_dir="$(get_repo_dir)"
    local script="${repo_dir}/install.sh"
    local stub_bin="${HOME}/bin"

    setup_stub_bin "$stub_bin"
    export XDG_CONFIG_HOME="${HOME}/.config"

    PATH="$stub_bin" run "$script" --terminal-only
    [ "$status" -ne 0 ]
    [[ "$output" == *"Foot installation is only supported with apt-get, apt, dnf, or pacman"* ]]
}

@test "darwin terminal setup fails with a clear error when Homebrew is unavailable" {
    local repo_dir
    repo_dir="$(get_repo_dir)"
    local script="${repo_dir}/install.sh"
    local stub_bin="${HOME}/bin"

    setup_stub_bin "$stub_bin"
    export XDG_CONFIG_HOME="${HOME}/.config"

    PATH="$stub_bin" run "$script" darwin --terminal-only
    [ "$status" -ne 0 ]
    [[ "$output" == *"Homebrew is required to install Alacritty on macOS"* ]]
}

@test "default install fails before writing config when Linux terminal install needs elevation" {
    local repo_dir
    repo_dir="$(get_repo_dir)"
    local script="${repo_dir}/install.sh"
    local stub_bin="${HOME}/bin"

    setup_stub_bin "$stub_bin"
    stub_non_root_id "$stub_bin"
    stub_apt_get_foot_install "$stub_bin"
    stub_zellij_release_tools "$stub_bin"
    export STUB_BIN="$stub_bin"
    export XDG_CONFIG_HOME="${HOME}/.config"

    PATH="$stub_bin" run "$script"
    [ "$status" -ne 0 ]
    [ ! -e "${XDG_CONFIG_HOME}/zellij/config.kdl" ]
    [ ! -f "${HOME}/.bashrc" ]
    [ ! -f "${HOME}/.zshrc" ]
}

@test "--terminal-only skips package-manager install when Foot is already available" {
    local repo_dir
    repo_dir="$(get_repo_dir)"
    local script="${repo_dir}/install.sh"
    local stub_bin="${HOME}/bin"

    setup_stub_bin "$stub_bin"
    stub_non_root_id "$stub_bin"
    export STUB_BIN="$stub_bin"
    export XDG_CONFIG_HOME="${HOME}/.config"

    cat > "${stub_bin}/foot" <<'EOF'
#!/usr/bin/env bash
exit 0
EOF
    chmod +x "${stub_bin}/foot"

    PATH="$stub_bin" run "$script" --terminal-only
    [ "$status" -eq 0 ]
    [ -f "${XDG_CONFIG_HOME}/foot/foot.ini" ]
    [ ! -f "${stub_bin}/apt-get.log" ]
}

@test "darwin terminal setup skips Homebrew when Alacritty is already available" {
    local repo_dir
    repo_dir="$(get_repo_dir)"
    local script="${repo_dir}/install.sh"
    local stub_bin="${HOME}/bin"

    setup_stub_bin "$stub_bin"
    export STUB_BIN="$stub_bin"
    export XDG_CONFIG_HOME="${HOME}/.config"

    cat > "${stub_bin}/alacritty" <<'EOF'
#!/usr/bin/env bash
exit 0
EOF
    chmod +x "${stub_bin}/alacritty"

    PATH="$stub_bin" run "$script" darwin --terminal-only
    [ "$status" -eq 0 ]
    [ -f "${XDG_CONFIG_HOME}/alacritty/alacritty.toml" ]
    [ ! -f "${stub_bin}/brew.log" ]
}
