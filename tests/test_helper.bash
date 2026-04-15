#!/usr/bin/env bash
# Test helper for terminal-install.sh tests

# Create a temporary HOME directory for testing
setup_temp_home() {
    TEST_TMPDIR="${BATS_TMPDIR:-/tmp}/terminal-install-$$-$(date +%s)"
    mkdir -p "$TEST_TMPDIR"
    export HOME="$TEST_TMPDIR"
    unset XDG_CONFIG_HOME
    echo "$TEST_TMPDIR"
}

# Create a temp HOME with XDG_CONFIG_HOME set
setup_temp_xdg() {
    TEST_TMPDIR="${BATS_TMPDIR:-/tmp}/terminal-install-$$-$(date +%s)"
    mkdir -p "$TEST_TMPDIR/config"
    export HOME="$TEST_TMPDIR"
    export XDG_CONFIG_HOME="$TEST_TMPDIR/config"
    echo "$TEST_TMPDIR"
}

# Cleanup temp directory
teardown_temp_home() {
    if [ -n "$TEST_TMPDIR" ] && [ -d "$TEST_TMPDIR" ]; then
        rm -rf "$TEST_TMPDIR"
    fi
}

# Get the repo directory (parent of tests/)
get_repo_dir() {
    dirname "${BATS_TEST_DIRNAME}"
}

# Check if bats is available
check_bats() {
    command -v bats >/dev/null 2>&1
}

# Check if shellcheck is available
check_shellcheck() {
    command -v shellcheck >/dev/null 2>&1
}