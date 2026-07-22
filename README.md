# 🏠 anan's dotfiles

Arch Linux + Hyprland rice managed with [GNU Stow](https://www.gnu.org/software/stow/).

## Packages

| Package | Description |
|---------|-------------|
| `hypr` | Hyprland, Hypridle, Hyprlock configs + scripts |
| `waybar` | Status bar config + style |
| `dunst` | Notification daemon |
| `kitty` | Terminal emulator |
| `swaync` | Notification center |
| `wlogout` | Logout menu |
| `tofi` | App launcher |
| `cava` | Audio visualizer |
| `nvim` | Neovim (Lazy) |
| `tmux` | Terminal multiplexer + scripts |
| `starship` | Shell prompt |
| `fish` | Fish shell |
| `yazi` | File manager |
| `bat` | Cat replacement |
| `zsh` | Zsh config (.zshrc) |

## Usage

### Install on a fresh system

```bash
# Clone the repo
git clone https://github.com/YOUR_USERNAME/dotfiles.git ~/dotfiles

# Stow everything
cd ~/dotfiles
stow */

# Or stow individual packages
stow hypr waybar kitty
```

### Unstow a package

```bash
stow -D waybar   # removes symlinks for waybar
```

### Add a new config

```bash
mkdir -p ~/dotfiles/newpkg/.config/newpkg
mv ~/.config/newpkg/* ~/dotfiles/newpkg/.config/newpkg/
cd ~/dotfiles && stow newpkg
```
