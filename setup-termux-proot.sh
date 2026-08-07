#!/usr/bin/env bash
#
# setup-termux-proot.sh
#
# Bootstraps a Ubuntu container under Termux's proot-distro:
#   - installs proot-distro and the Ubuntu container
#   - creates a non-root user with sudo access (username + password configurable)
#   - installs a Nerd Font for correct icon rendering in the prompt
#   - configures a Termux-side `ubuntu` alias that logs straight in as that user
#
# Must be run from Termux itself, not from inside the Ubuntu container.
#
# Usage:
#   ./setup-termux-proot.sh                  interactive mode (prompts for input)
#   ./setup-termux-proot.sh <user> <pass>    non-interactive mode
#   ./setup-termux-proot.sh -h | --help      show this help
#
set -euo pipefail

# ---------------------------------------------------------------------------
# Output helpers
# ---------------------------------------------------------------------------
readonly C_RESET='\033[0m'
readonly C_BLUE='\033[0;34m'
readonly C_GREEN='\033[0;32m'
readonly C_YELLOW='\033[1;33m'
readonly C_RED='\033[0;31m'

log_info()    { printf "${C_BLUE}[INFO]${C_RESET} %s\n" "$1"; }
log_success() { printf "${C_GREEN}[ OK ]${C_RESET} %s\n" "$1"; }
log_warn()    { printf "${C_YELLOW}[WARN]${C_RESET} %s\n" "$1"; }
log_error()   { printf "${C_RED}[FAIL]${C_RESET} %s\n" "$1" >&2; }

trap 'log_error "Script aborted unexpectedly at line $LINENO."' ERR

print_help() {
  sed -n '2,16p' "$0" | sed 's/^# \{0,1\}//'
}

# ---------------------------------------------------------------------------
# Preconditions
# ---------------------------------------------------------------------------
require_termux() {
  if [ -z "${PREFIX:-}" ] || [[ "$PREFIX" != *com.termux* ]]; then
    log_error "This script must be run inside Termux, not inside the Ubuntu container."
    exit 1
  fi
}

# ---------------------------------------------------------------------------
# Credentials (argument-based or interactive)
# ---------------------------------------------------------------------------
collect_credentials() {
  USERNAME="${1:-}"
  PASSWORD="${2:-}"

  if [ -z "$USERNAME" ]; then
    while true; do
      read -rp "Username for the new Ubuntu user (lowercase, no spaces): " USERNAME
      [[ "$USERNAME" =~ ^[a-z_][a-z0-9_-]*$ ]] && break
      log_warn "Invalid username. Example of a valid one: angga"
    done
  fi

  if [ -z "$PASSWORD" ]; then
    while true; do
      read -rsp "Password for '$USERNAME': " PASSWORD; echo
      read -rsp "Confirm password: " PASSWORD_CONFIRM; echo
      if [ -n "$PASSWORD" ] && [ "$PASSWORD" = "$PASSWORD_CONFIRM" ]; then
        break
      fi
      log_warn "Passwords empty or did not match, try again."
    done
  fi

  log_success "Target user: $USERNAME"
}

# ---------------------------------------------------------------------------
# proot-distro + Ubuntu
# ---------------------------------------------------------------------------
install_proot_distro() {
  if command -v proot-distro >/dev/null 2>&1; then
    log_success "proot-distro already installed, skipping"
    return
  fi
  log_info "Installing proot-distro..."
  apt update -y && apt upgrade -y
  apt install -y proot-distro
  log_success "proot-distro installed"
}

install_ubuntu_container() {
  if proot-distro list --installed 2>/dev/null | grep -qi ubuntu; then
    log_success "Ubuntu container already installed, skipping"
    return
  fi
  log_info "Installing Ubuntu container (this can take a few minutes)..."
  proot-distro install ubuntu
  log_success "Ubuntu container installed"
}

# ---------------------------------------------------------------------------
# User provisioning inside the container
# ---------------------------------------------------------------------------
provision_user() {
  log_info "Provisioning user '$USERNAME' inside the Ubuntu container..."
  proot-distro login ubuntu -- env NEWUSER="$USERNAME" NEWPASS="$PASSWORD" bash -c '
    set -e
    if id "$NEWUSER" >/dev/null 2>&1; then
      echo "  User already exists, updating password and sudo access only."
    else
      useradd -m -s /bin/bash "$NEWUSER"
    fi
    echo "$NEWUSER:$NEWPASS" | chpasswd
    apt-get update -y -qq
    apt-get install -y -qq sudo >/dev/null
    usermod -aG sudo "$NEWUSER"
    echo "$NEWUSER ALL=(ALL) NOPASSWD:ALL" > "/etc/sudoers.d/$NEWUSER"
    chmod 0440 "/etc/sudoers.d/$NEWUSER"
  '
  log_success "User '$USERNAME' is ready with passwordless sudo"
}

# ---------------------------------------------------------------------------
# Nerd Font (renders prompt/icon glyphs correctly; must live in Termux)
# ---------------------------------------------------------------------------
install_nerd_font() {
  log_info "Installing JetBrainsMono Nerd Font..."
  mkdir -p "$HOME/.termux"
  curl -fLo "$HOME/.termux/font.ttf" \
    https://github.com/ryanoasis/nerd-fonts/raw/master/patched-fonts/JetBrainsMono/Ligatures/Regular/JetBrainsMonoNerdFont-Regular.ttf
  termux-reload-settings 2>/dev/null || log_warn "Could not auto-reload Termux settings; reload manually via Termux:Style/Properties."
  log_success "Font installed"
}

# ---------------------------------------------------------------------------
# Shell alias so `ubuntu` logs straight in as the provisioned user
# ---------------------------------------------------------------------------
configure_alias() {
  log_info "Configuring 'ubuntu' alias to auto-login as '$USERNAME'..."
  local marker_start="# >>> proot-ubuntu-alias >>>"
  local marker_end="# <<< proot-ubuntu-alias <<<"

  for rc in "$HOME/.bashrc" "$HOME/.zshrc"; do
    [ -f "$rc" ] || touch "$rc"
    sed -i "/${marker_start}/,/${marker_end}/d" "$rc"
    {
      echo ""
      echo "$marker_start"
      echo "alias ubuntu='proot-distro login ubuntu --user $USERNAME'"
      echo "$marker_end"
    } >> "$rc"
  done
  log_success "Alias saved to .bashrc and .zshrc"
}

# ---------------------------------------------------------------------------
# Summary
# ---------------------------------------------------------------------------
print_summary() {
  echo
  log_success "Termux + Ubuntu bootstrap complete."
  cat <<EOF

  Next steps:
    1. Restart Termux (so the font takes effect)
    2. source ~/.bashrc            (or open a new tab)
    3. Run: ubuntu                  -> logs in as '$USERNAME' directly
    4. Inside Ubuntu, run ricing-setup.sh to install zsh/starship/uv/Node.js/AI tools

EOF
}

# ---------------------------------------------------------------------------
# Entry point
# ---------------------------------------------------------------------------
main() {
  if [ "${1:-}" = "-h" ] || [ "${1:-}" = "--help" ]; then
    print_help
    exit 0
  fi

  require_termux
  collect_credentials "${1:-}" "${2:-}"
  install_proot_distro
  install_ubuntu_container
  provision_user
  install_nerd_font
  configure_alias
  print_summary
}

main "$@"
