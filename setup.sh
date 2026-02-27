#!/usr/bin/env bash
set -euo pipefail

#=================Print Banner=====================#

print_banner_rainbow() {
  local colors=("\e[31m" "\e[33m" "\e[32m" "\e[36m" "\e[34m" "\e[35m") # R O Y G B P
  local i=0

  while IFS= read -r line; do
    echo -e "${colors[i % ${#colors[@]}]}$line\e[0m"
    ((i++))
  done <<'EOF'
##################################################
##           Markusssssu(Mark)                  
##                                              
##     ⢠⣿⣿⣿⣿⣿⢻⣿⣿⣿⣿⣿⣿⣿⣿⣯⢻⣿⣿⣿⣿⣆           
##    ⣼⢀⣿⣿⣿⣿⣏⡏⠄⠹⣿⣿⣿⣿⣿⣿⣿⣿⣧⢻⣿⣿⣿⣿⡆        
##    ⡟⣼⣿⣿⣿⣿⣿⠄⠄⠄⠈⠻⣿⣿⣿⣿⣿⣿⣿⣇⢻⣿⣿⣿⣿       
##    ⢰⠃⣿⣿⠿⣿⣿⣿⠄⠄⠄⠄⠄⠄⠙⠿⣿⣿⣿⣿⣿⠄⢿⣿⣿⣿⡄    
##    ⢸⢠⣿⣿⣧⡙⣿⣿⡆⠄⠄⠄⠄⠄⠄⠄⠈⠛⢿⣿⣿⡇⠸⣿⡿⣸⡇   
##    ⠈⡆⣿⣿⣿⣿⣦⡙⠳⠄⠄⠄⠄⠄⠄⢀⣠⣤⣀⣈⠙⠃⠄⠿⢇⣿⡇   
##    ⡇⢿⣿⣿⣿⣿⡇⠄⠄⠄⠄⠄⣠⣶⣿⣿⣿⣿⣿⣿⣷⣆⡀⣼⣿⡇   
##    ⢹⡘⣿⣿⣿⢿⣷⡀⠄⢀⣴⣾⣟⠉⠉⠉⠉⣽⣿⣿⣿⣿⠇⢹⣿⠃   
##    ⢷⡘⢿⣿⣎⢻⣷⠰⣿⣿⣿⣿⣦⣀⣀⣴⣿⣿⣿⠟⢫⡾⢸⡟    
##    ⠻⣦⡙⠿⣧⠙⢷⠙⠻⠿⢿⡿⠿⠿⠛⠋⠉⠄⠂⠘⠁⠞   
##           ⠈⠙⠑⣠⣤⣴⡖⠄⠿⣋⣉⣉⡁⠄⢾⣦   
##
##
#################################################
EOF
}

# Функция для вывода радужного текста (LGBT/Pride style)
pride_echo() {
  local msg="$1"
  local colors=("\e[31m" "\e[38;5;208m" "\e[33m" "\e[32m" "\e[34m" "\e[35m")
  for (( i=0; i<${#msg}; i++ )); do
    echo -ne "${colors[i % ${#colors[@]}]}${msg:$i:1}"
  done
  echo -e "\e[0m"
}

#================================================#

print_banner_rainbow

DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
DOTS_SRC="$DIR/dots"
TARGET_DOTS="$HOME/.config/dots"

NO_PROMPT=0
while getopts ":y" opt; do
  case $opt in
    y) NO_PROMPT=1 ;;
    *) echo "Usage: $0 [-y]"; exit 1 ;;
  esac
done

c() { echo -e "\e[$1m$2\e[0m"; }
info(){ c 34 "==> $*"; }
step(){ echo; c 33 ">>> $*"; }
ok(){ c 32 "✔ $*"; }
warn(){ c 33 "! $*"; }
err(){ c 31 "✖ $*"; }

confirm() {
  [ "$NO_PROMPT" -eq 1 ] && return 0
  read -rp "$1 [y/N]: " ans
  [[ "$ans" =~ ^[Yy]$ ]]
}

require_arch() {
  command -v pacman >/dev/null || {
    err "pacman not found — Arch only."
    exit 1
  }
}

install_packages() {
  sudo pacman -Syu --noconfirm --needed "$@" \
    && ok "Installed: $*" \
    || { err "Failed installing: $*"; exit 1; }
}

install_rust() {
  pride_echo "Installing Rust... Stay fabulous! 🌈"
  if command -v rustup >/dev/null 2>&1; then
    ok "Rust (rustup) is already installed."
  else
    # Используем официальный скрипт rustup
    curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y
    source "$HOME/.cargo/env"
    ok "Rust installed successfully."
  fi
}

# ... (остальные функции link_configs, install_yay и т.д. остаются без изменений) ...

install_yay() {
  if command -v yay >/dev/null 2>&1; then
    ok "yay already installed."
    return
  fi
  local tmp; tmp="$(mktemp -d)"
  git clone https://aur.archlinux.org/yay.git "$tmp/yay" || { err "Failed clone yay"; exit 1; }
  (cd "$tmp/yay" && makepkg -si --noconfirm) && ok "yay installed." || err "Failed build yay."
  rm -rf "$tmp"
}

link_configs() {
  mkdir -p "$TARGET_DOTS"
  rsync -a --delete "$DOTS_SRC/" "$TARGET_DOTS/"
  for entry in "$TARGET_DOTS"/*; do
    [ -e "$entry" ] || continue
    local name target; name="$(basename "$entry")"; target="$HOME/.config/$name"
    [ -L "$target" ] && [ "$(readlink "$target")" = "$entry" ] && continue
    [ -e "$target" ] && mv "$target" "$target.backup.$(date +%s)"
    ln -sfn "$entry" "$target"
    ok "Linked $name"
  done
}

setup_powerlevel10k() {
  local repo="$HOME/powerlevel10k"
  [ ! -d "$repo" ] && git clone --depth=1 https://github.com/romkatv/powerlevel10k.git "$repo"
  local zshrc="$HOME/.zshrc"; touch "$zshrc"
  local line="source ~/powerlevel10k/powerlevel10k.zsh-theme"
  grep -qxF "$line" "$zshrc" || echo "$line" >> "$zshrc"
}

set_default_shell() {
  local zsh_path; zsh_path="$(command -v zsh || true)"
  [ -z "$zsh_path" ] && return
  local current; current="$(getent passwd "$USER" | cut -d: -f7)"
  if [ "$current" != "$zsh_path" ]; then
    confirm "Set zsh as default shell?" && chsh -s "$zsh_path" "$USER"
  fi
}

set_default_wallpaper() {
  local wp_dir="$TARGET_DOTS/wallpapers"
  [ ! -d "$wp_dir" ] && { warn "No wallpapers dir"; return; }
  local first_wallpaper; first_wallpaper=$(find "$wp_dir" -type f | head -n 1 || true)
  [ -z "$first_wallpaper" ] && return
  if command -v hyprctl >/dev/null 2>&1; then
    hyprctl hyprpaper preload "$first_wallpaper" 2>/dev/null || true
    hyprctl hyprpaper wallpaper ",$first_wallpaper" 2>/dev/null || true
    ok "Default wallpaper set."
  fi
}

#================= Execution =====================#

info "Starting Arch setup..."
require_arch

step "1/7: Install core packages"
confirm "Install zsh git base-devel?" && install_packages zsh git base-devel

step "2/7: Install yay"
confirm "Install yay (AUR helper)?" && install_yay

step "3/7: Install Rust"
confirm "Install Rust (rustup)?" && install_rust

step "4/7: Install hyprpanel"
if confirm "Install hyprpanel?"; then
  if command -v yay >/dev/null 2>&1; then
    yay -S --noconfirm --needed hyprpanel && ok "hyprpanel installed." || warn "failed"
  else
    warn "yay missing"
  fi
fi

step "5/7: Setup powerlevel10k"
confirm "Setup powerlevel10k?" && setup_powerlevel10k && ok "powerlevel10k ready"

step "6/7: Deploy dotfiles"
[ -d "$DOTS_SRC" ] && link_configs || warn "dots directory missing"

step "7/7: Set default shell"
set_default_shell

set_default_wallpaper

ok "Setup finished."
