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

setup_stub_bin() {
    local stub_bin="$1"
    local cmd=""
    local cmd_path=""

    mkdir -p "$stub_bin"

    for cmd in bash dirname pwd uname tr grep sed date cp rm ln mkdir touch which mktemp mv chmod cat id; do
        cmd_path="$(command -v "$cmd")"
        if [ -n "$cmd_path" ]; then
            ln -sf "$cmd_path" "${stub_bin}/${cmd}"
        fi
    done
}

stub_zellij_release_tools() {
    local stub_bin="$1"

    cat > "${stub_bin}/curl" <<'EOF'
#!/usr/bin/env bash
printf '{"tag_name":"v0.0.0"}\n'
EOF

    cat > "${stub_bin}/tar" <<'EOF'
#!/usr/bin/env bash
out_dir=""
while [ $# -gt 0 ]; do
    case "$1" in
        -C)
            out_dir="$2"
            shift 2
            ;;
        *)
            shift
            ;;
    esac
done
printf '#!/usr/bin/env bash\nexit 0\n' > "${out_dir}/zellij"
EOF

    chmod +x "${stub_bin}/curl" "${stub_bin}/tar"
}

stub_root_id() {
    local stub_bin="$1"

    rm -f "${stub_bin}/id"

    cat > "${stub_bin}/id" <<'EOF'
#!/usr/bin/env bash
if [ "${1:-}" = "-u" ]; then
    printf '0\n'
    exit 0
fi

exec /usr/bin/id "$@"
EOF

    chmod +x "${stub_bin}/id"
}

stub_non_root_id() {
    local stub_bin="$1"

    rm -f "${stub_bin}/id"

    cat > "${stub_bin}/id" <<'EOF'
#!/usr/bin/env bash
if [ "${1:-}" = "-u" ]; then
    printf '1000\n'
    exit 0
fi

exec /usr/bin/id "$@"
EOF

    chmod +x "${stub_bin}/id"
}

stub_apt_get_foot_install() {
    local stub_bin="$1"

    cat > "${stub_bin}/apt-get" <<'EOF'
#!/usr/bin/env bash
printf '%s\n' "$*" >> "${STUB_BIN}/apt-get.log"
if [ "${1:-}" = "install" ]; then
    printf '#!/usr/bin/env bash\nexit 0\n' > "${STUB_BIN}/foot"
    chmod +x "${STUB_BIN}/foot"
fi
EOF

    chmod +x "${stub_bin}/apt-get"
}

stub_brew_alacritty_install() {
    local stub_bin="$1"

    cat > "${stub_bin}/brew" <<'EOF'
#!/usr/bin/env bash
printf '%s\n' "$*" >> "${STUB_BIN}/brew.log"
if [ "${1:-}" = "install" ] && [ "${2:-}" = "alacritty" ]; then
    printf '#!/usr/bin/env bash\nexit 0\n' > "${STUB_BIN}/alacritty"
    chmod +x "${STUB_BIN}/alacritty"
fi
EOF

    chmod +x "${stub_bin}/brew"
}
