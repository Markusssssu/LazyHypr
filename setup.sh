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

install_yay() {
  if command -v yay >/dev/null 2>&1; then
    ok "yay already installed."
    return
  fi

  local tmp
  tmp="$(mktemp -d)"

  git clone https://aur.archlinux.org/yay.git "$tmp/yay" || {
    err "Failed to clone yay."
    rm -rf "$tmp"
    exit 1
  }

  (
    cd "$tmp/yay"
    makepkg -si --noconfirm
  ) && ok "yay installed." || err "Failed to build yay."

  rm -rf "$tmp"
}

link_configs() {
  mkdir -p "$TARGET_DOTS"
  rsync -a --delete "$DOTS_SRC/" "$TARGET_DOTS/"

  for entry in "$TARGET_DOTS"/*; do
    [ -e "$entry" ] || continue
    local name target
    name="$(basename "$entry")"
    target="$HOME/.config/$name"

    if [ -L "$target" ] && [ "$(readlink "$target")" = "$entry" ]; then
      continue
    fi

    [ -e "$target" ] && mv "$target" "$target.backup.$(date +%s)"
    ln -sfn "$entry" "$target"
    ok "Linked $name"
  done
}

setup_powerlevel10k() {
  local repo="$HOME/powerlevel10k"

  if [ ! -d "$repo" ]; then
    git clone --depth=1 https://github.com/romkatv/powerlevel10k.git "$repo"
  fi

  local zshrc="$HOME/.zshrc"
  touch "$zshrc"
  local line="source ~/powerlevel10k/powerlevel10k.zsh-theme"

  grep -qxF "$line" "$zshrc" || echo "$line" >> "$zshrc"
}

set_default_shell() {
  local zsh_path
  zsh_path="$(command -v zsh || true)"
  [ -z "$zsh_path" ] && return

  local current
  current="$(getent passwd "$USER" | cut -d: -f7)"

  if [ "$current" != "$zsh_path" ]; then
    confirm "Set zsh as default shell?" && chsh -s "$zsh_path" "$USER"
  fi
}

set_default_wallpaper() {
  local wp_dir="$TARGET_DOTS/wallpapers"

  if [ ! -d "$wp_dir" ]; then
    warn "Wallpapers directory not found: $wp_dir"
    return
  fi

  local first_wallpaper
  first_wallpaper=$(find "$wp_dir" -type f | head -n 1 || true)

  if [ -z "$first_wallpaper" ]; then
    warn "No wallpapers found."
    return
  fi

  if command -v hyprctl >/dev/null 2>&1; then
    hyprctl hyprpaper preload "$first_wallpaper" 2>/dev/null || true
    hyprctl hyprpaper wallpaper ",$first_wallpaper" 2>/dev/null || true
    ok "Default wallpaper set."
  else
    warn "hyprctl not found. Skipping wallpaper setup."
  fi
}

#================= Execution =====================#

info "Starting Arch setup..."
require_arch

step "1/6: Install core packages"
confirm "Install zsh git base-devel?" && install_packages zsh git base-devel

step "2/6: Install yay"
confirm "Install yay (AUR helper)?" && install_yay

step "3/6: Install hyprpanel"
if confirm "Install hyprpanel?"; then
  if command -v yay >/dev/null 2>&1; then
    yay -S --noconfirm --needed hyprpanel \
      && ok "hyprpanel installed." \
      || warn "hyprpanel installation failed."
  else
    warn "yay not available; skipping hyprpanel."
  fi
fi

step "4/6: Setup powerlevel10k"
confirm "Setup powerlevel10k?" && setup_powerlevel10k && ok "powerlevel10k ready"

step "5/6: Deploy dotfiles"
[ -d "$DOTS_SRC" ] && link_configs || warn "dots directory missing"

step "6/6: Set default shell"
set_default_shell

set_default_wallpaper

ok "Setup finished."

#================================================#
