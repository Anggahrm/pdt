#!/usr/bin/env bash
#
# ricing-setup.sh
#
# Automated environment setup for Ubuntu running under Termux's proot-distro.
# Installs and configures:
#   - zsh + Oh My Zsh + autosuggestions/syntax-highlighting plugins
#   - Starship prompt
#   - eza, bat, neofetch (terminal eye candy)
#   - uv + Python
#   - Node.js LTS
#   - optional AI CLI tools: OpenCode, Claude Code, 9Router, Hermes Agent
#
# Idempotent: safe to re-run, already-installed components are skipped.
#
# Usage:
#   ./ricing-setup.sh                             interactive mode (prompts for AI tools)
#   ./ricing-setup.sh --tools=all                 install every AI tool, no prompt
#   ./ricing-setup.sh --tools=none                skip AI tools entirely, no prompt
#   ./ricing-setup.sh --tools=opencode,hermes     install a specific subset, no prompt
#   ./ricing-setup.sh -h | --help                 show this help
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
  sed -n '2,21p' "$0" | sed 's/^# \{0,1\}//'
}

# ---------------------------------------------------------------------------
# Privilege detection
# ---------------------------------------------------------------------------
SUDO=""
require_privileges() {
  if [ "$(id -u)" -eq 0 ]; then
    SUDO=""
  elif command -v sudo >/dev/null 2>&1; then
    SUDO="sudo"
  else
    log_error "Root or sudo is required. Log in as root first: proot-distro login ubuntu (no --user), then: apt install sudo && usermod -aG sudo <user>"
    exit 1
  fi
}

# ---------------------------------------------------------------------------
# Base packages
# ---------------------------------------------------------------------------
install_base_packages() {
  log_info "Updating package lists and installing base packages..."
  $SUDO apt update -y
  $SUDO apt install -y zsh git curl nano sudo unzip fontconfig fastfetch
  log_success "Base packages ready"
}

# ---------------------------------------------------------------------------
# Oh My Zsh
# ---------------------------------------------------------------------------
install_oh_my_zsh() {
  if [ -d "$HOME/.oh-my-zsh" ]; then
    log_success "Oh My Zsh already installed, skipping"
    return
  fi
  log_info "Installing Oh My Zsh..."
  RUNZSH=no CHSH=no sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)"
  log_success "Oh My Zsh installed"
}

install_zsh_plugins() {
  local zsh_custom="${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}"
  log_info "Installing zsh-autosuggestions and zsh-syntax-highlighting..."
  [ -d "$zsh_custom/plugins/zsh-autosuggestions" ] || \
    git clone --depth=1 https://github.com/zsh-users/zsh-autosuggestions "$zsh_custom/plugins/zsh-autosuggestions"
  [ -d "$zsh_custom/plugins/zsh-syntax-highlighting" ] || \
    git clone --depth=1 https://github.com/zsh-users/zsh-syntax-highlighting "$zsh_custom/plugins/zsh-syntax-highlighting"
  log_success "Plugins ready"
}

# ---------------------------------------------------------------------------
# Starship prompt
# ---------------------------------------------------------------------------
install_starship() {
  if command -v starship >/dev/null 2>&1; then
    log_success "Starship already installed, skipping"
  else
    log_info "Installing Starship..."
    curl -sS https://starship.rs/install.sh | sh -s -- -y
    log_success "Starship installed"
  fi

  mkdir -p "$HOME/.config"
  if [ ! -f "$HOME/.config/starship.toml" ]; then
    log_info "Generating Starship preset (nerd-font-symbols)..."
    starship preset nerd-font-symbols -o "$HOME/.config/starship.toml" 2>/dev/null \
      || log_warn "Could not generate preset, falling back to Starship defaults"
  fi
}

# ---------------------------------------------------------------------------
# Terminal eye candy: eza, bat
# ---------------------------------------------------------------------------
install_cli_eyecandy() {
  log_info "Installing eza and bat..."
  $SUDO apt install -y bat || log_warn "bat failed to install"
  $SUDO apt install -y eza 2>/dev/null || log_warn "eza not available in this repo, skipping (optional)"
}

# ---------------------------------------------------------------------------
# uv + Python
# ---------------------------------------------------------------------------
install_uv_and_python() {
  if command -v uv >/dev/null 2>&1; then
    log_success "uv already installed, skipping"
  else
    log_info "Installing uv..."
    curl -LsSf https://astral.sh/uv/install.sh | sh
  fi
  export PATH="$HOME/.local/bin:$PATH"

  log_info "Installing Python via uv..."
  "$HOME/.local/bin/uv" python install 3.12 2>/dev/null || uv python install 3.12 \
    || log_warn "Failed to install Python via uv, check network connectivity"
  log_success "uv + Python ready"
}

# ---------------------------------------------------------------------------
# Node.js LTS
# ---------------------------------------------------------------------------
install_nodejs_lts() {
  if command -v node >/dev/null 2>&1; then
    log_success "Node.js already installed ($(node -v)), skipping"
    return
  fi
  log_info "Installing Node.js LTS via NodeSource..."
  curl -fsSL https://deb.nodesource.com/setup_lts.x | $SUDO -E bash - >/dev/null
  $SUDO apt install -y nodejs
  log_success "Node.js $(node -v) and npm $(npm -v) installed"
}

# ---------------------------------------------------------------------------
# Optional AI CLI tools
# ---------------------------------------------------------------------------
readonly AVAILABLE_TOOLS=(opencode claude-code 9router hermes)
declare -A TOOL_LABELS=(
  [opencode]="OpenCode - open-source AI coding agent for the terminal"
  [claude-code]="Claude Code - Anthropic's official coding agent CLI"
  [9router]="9Router - multi-provider AI request router with quota fallback"
  [hermes]="Hermes Agent - Nous Research's self-improving agent framework"
)
SELECTED_TOOLS=()

select_ai_tools_interactive() {
  echo
  log_info "Optional AI CLI tools available for this environment:"
  local i=1
  for key in "${AVAILABLE_TOOLS[@]}"; do
    printf "  %d) %s\n" "$i" "${TOOL_LABELS[$key]}"
    i=$((i + 1))
  done
  echo
  read -rp "Select tools to install (e.g. '1,3', 'all', or 'none'): " selection

  case "$selection" in
    "" | none | None | NONE) SELECTED_TOOLS=() ;;
    all | All | ALL) SELECTED_TOOLS=("${AVAILABLE_TOOLS[@]}") ;;
    *)
      IFS=',' read -ra parts <<< "${selection// /,}"
      for p in "${parts[@]}"; do
        [ -z "$p" ] && continue
        if [[ "$p" =~ ^[0-9]+$ ]] && [ "$p" -ge 1 ] && [ "$p" -le "${#AVAILABLE_TOOLS[@]}" ]; then
          SELECTED_TOOLS+=("${AVAILABLE_TOOLS[$((p - 1))]}")
        else
          log_warn "Ignoring invalid selection: '$p'"
        fi
      done
      ;;
  esac
}

select_ai_tools_from_flag() {
  case "$TOOLS_ARG" in
    all) SELECTED_TOOLS=("${AVAILABLE_TOOLS[@]}") ;;
    none) SELECTED_TOOLS=() ;;
    *)
      IFS=',' read -ra parts <<< "$TOOLS_ARG"
      for p in "${parts[@]}"; do
        [ -z "$p" ] && continue
        local match=0
        for key in "${AVAILABLE_TOOLS[@]}"; do
          if [ "$key" = "$p" ]; then
            SELECTED_TOOLS+=("$key")
            match=1
            break
          fi
        done
        [ "$match" -eq 0 ] && log_warn "Unknown tool in --tools flag: '$p'"
      done
      ;;
  esac
}

install_opencode() {
  if command -v opencode >/dev/null 2>&1; then
    log_success "OpenCode already installed, skipping"
    return
  fi
  log_info "Installing OpenCode..."
  npm install -g opencode-ai
  log_success "OpenCode installed"
}

install_claude_code() {
  if command -v claude >/dev/null 2>&1; then
    log_success "Claude Code already installed, skipping"
    return
  fi
  log_info "Installing Claude Code..."
  npm install -g @anthropic-ai/claude-code
  log_success "Claude Code installed (run 'claude' once to authenticate)"
}

install_9router() {
  if command -v 9router >/dev/null 2>&1; then
    log_success "9Router already installed, skipping"
    return
  fi
  log_info "Installing 9Router..."
  npm install -g 9router
  log_success "9Router installed (run '9router' to launch the dashboard on port 20128)"
}

install_hermes() {
  if command -v hermes >/dev/null 2>&1; then
    log_success "Hermes Agent already installed, skipping"
    return
  fi
  log_info "Installing Hermes Agent (manages its own bundled Node.js runtime)..."
  curl -fsSL https://hermes-agent.nousresearch.com/install.sh | bash
  log_success "Hermes Agent installed (run 'hermes model' to pick a provider)"
}

install_selected_ai_tools() {
  if [ ${#SELECTED_TOOLS[@]} -eq 0 ]; then
    log_info "No AI CLI tools selected, skipping this section"
    return
  fi
  for tool in "${SELECTED_TOOLS[@]}"; do
    case "$tool" in
      opencode) install_opencode ;;
      claude-code) install_claude_code ;;
      9router) install_9router ;;
      hermes) install_hermes ;;
    esac
  done
}

# ---------------------------------------------------------------------------
# Shell configuration
# ---------------------------------------------------------------------------
configure_zshrc() {
  local zshrc="$HOME/.zshrc"
  log_info "Updating .zshrc..."

  if grep -q '^plugins=(' "$zshrc" 2>/dev/null; then
    sed -i 's/^plugins=(.*)/plugins=(git zsh-autosuggestions zsh-syntax-highlighting)/' "$zshrc"
  else
    echo 'plugins=(git zsh-autosuggestions zsh-syntax-highlighting)' >> "$zshrc"
  fi

  grep -q 'starship init zsh' "$zshrc" 2>/dev/null || echo 'eval "$(starship init zsh)"' >> "$zshrc"
  grep -q '.local/bin"' "$zshrc" 2>/dev/null || echo 'export PATH="$HOME/.local/bin:$PATH"' >> "$zshrc"

  local marker_start="# >>> ricing-setup >>>"
  local marker_end="# <<< ricing-setup <<<"
  sed -i "/${marker_start}/,/${marker_end}/d" "$zshrc"
  {
    echo ""
    echo "$marker_start"
    echo "command -v eza >/dev/null 2>&1 && alias ls='eza --icons'"
    echo "command -v batcat >/dev/null 2>&1 && alias cat='batcat'"
    echo "command -v bat >/dev/null 2>&1 && alias cat='bat'"
    echo "command -v fastfetch >/dev/null 2>&1 && fastfetch"
    echo "$marker_end"
  } >> "$zshrc"

  log_success ".zshrc updated"
}

set_default_shell() {
  if [ "${SHELL:-}" = "$(command -v zsh)" ]; then
    return
  fi
  log_info "Setting zsh as the default shell..."
  $SUDO chsh -s "$(command -v zsh)" "$(whoami)" \
    || log_warn "chsh failed, run manually: chsh -s \$(which zsh)"
}

# ---------------------------------------------------------------------------
# Summary
# ---------------------------------------------------------------------------
print_summary() {
  echo
  log_success "Setup complete."
  cat <<EOF

  Next steps:
    1. Nerd Font is already handled if you ran setup-termux-proot.sh first;
       otherwise install it manually in Termux.
    2. Reload the shell: source ~/.zshrc   (or exit and log back in)
    3. Ubuntu ships 'bat' as 'batcat' -- the alias above already handles that.
    4. Check uv/Python: uv --version && python3 --version
    5. Check Node.js:   node -v && npm -v
EOF
  if [ ${#SELECTED_TOOLS[@]} -gt 0 ]; then
    printf "    6. Installed AI tools: %s\n" "${SELECTED_TOOLS[*]}"
  fi
  echo
}

# ---------------------------------------------------------------------------
# Entry point
# ---------------------------------------------------------------------------
TOOLS_ARG=""

parse_args() {
  for arg in "$@"; do
    case "$arg" in
      --tools=*) TOOLS_ARG="${arg#--tools=}" ;;
      -h|--help) print_help; exit 0 ;;
    esac
  done
}

main() {
  parse_args "$@"
  require_privileges
  install_base_packages
  install_oh_my_zsh
  install_zsh_plugins
  install_starship
  install_cli_eyecandy
  install_uv_and_python
  install_nodejs_lts

  if [ -n "$TOOLS_ARG" ]; then
    select_ai_tools_from_flag
  else
    select_ai_tools_interactive
  fi
  install_selected_ai_tools

  configure_zshrc
  set_default_shell
  print_summary
}

main "$@"
