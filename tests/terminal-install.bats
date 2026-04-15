#!/usr/bin/env bats

load test_helper

setup() {
    TEST_TMPDIR="$(setup_temp_home)"
}

teardown() {
    teardown_temp_home
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
    [ "${output[0]}" = "Usage:" ]
}

@test "unknown argument exits non-zero" {
    local repo_dir
    repo_dir="$(get_repo_dir)"
    run "${repo_dir}/install.sh" --unknown-arg
    [ "$status" -ne 0 ]
}

@test "--terminal-only installs foot config on Linux" {
    local repo_dir
    repo_dir="$(get_repo_dir)"
    local script="${repo_dir}/install.sh"

    export XDG_CONFIG_HOME="${HOME}/.config"

    run "$script" --terminal-only
    [ "$status" -eq 0 ]

    [ -f "${XDG_CONFIG_HOME}/foot/foot.ini" ]
    [ -f "${XDG_CONFIG_HOME}/foot/dank-colors.ini" ]
}

@test "--terminal-only installs alacritty config on Darwin" {
    local repo_dir
    repo_dir="$(get_repo_dir)"
    local script="${repo_dir}/install.sh"

    export XDG_CONFIG_HOME="${HOME}/.config"

    run "$script" darwin --terminal-only
    [ "$status" -eq 0 ]

    [ -f "${XDG_CONFIG_HOME}/alacritty/alacritty.toml" ]
    [ -f "${XDG_CONFIG_HOME}/alacritty/dank-theme.toml" ]
}

@test "existing terminal config is backed up with timestamp" {
    local repo_dir
    repo_dir="$(get_repo_dir)"
    local script="${repo_dir}/install.sh"

    export XDG_CONFIG_HOME="${HOME}/.config"

    mkdir -p "${XDG_CONFIG_HOME}/foot"
    echo "existing config" > "${XDG_CONFIG_HOME}/foot/foot.ini"

    run "$script" --terminal-only
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

    mv "${repo_dir}/foot" "${repo_dir}/foot.bak"

    run "${repo_dir}/install.sh" --terminal-only
    [ "$status" -ne 0 ]

    mv "${repo_dir}/foot.bak" "${repo_dir}/foot"
}

@test "destination directory is created automatically" {
    local repo_dir
    repo_dir="$(get_repo_dir)"
    local script="${repo_dir}/install.sh"

    export XDG_CONFIG_HOME="${HOME}/.config"
    rm -rf "${XDG_CONFIG_HOME}/foot"

    run "$script" --terminal-only
    [ "$status" -eq 0 ]
    [ -d "${XDG_CONFIG_HOME}/foot" ]
}

@test "alacritty.toml imports dank-theme.toml" {
    local repo_dir
    repo_dir="$(get_repo_dir)"
    local script="${repo_dir}/install.sh"

    export XDG_CONFIG_HOME="${HOME}/.config"

    run "$script" darwin --terminal-only
    [ "$status" -eq 0 ]

    grep -q 'import.*dank-theme.toml' "${XDG_CONFIG_HOME}/alacritty/alacritty.toml"
}