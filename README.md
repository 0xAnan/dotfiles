# dotfiles

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
| `yazi` | File manager |
| `bat` | Cat replacement |
| `zsh` | Zsh config (.zshrc) |

## Install on a fresh system

```bash
# Install stow
sudo pacman -S stow

# Clone the repo
git clone git@github.com:0xAnan/dotfiles.git ~/dotfiles
cd ~/dotfiles

# Back up any existing configs that would conflict
for pkg in hypr waybar dunst kitty swaync wlogout tofi cava nvim tmux starship yazi bat; do
    [ -e ~/.config/$pkg ] && mv ~/.config/$pkg ~/.config/${pkg}.bak
done
[ -f ~/.zshrc ] && mv ~/.zshrc ~/.zshrc.bak

# Stow everything
stow */

# Or stow individual packages
stow hypr waybar kitty
```

## Unstow a package

```bash
stow -D waybar   # removes symlinks for waybar
```

## Add a new config

```bash
mkdir -p ~/dotfiles/newpkg/.config/newpkg
mv ~/.config/newpkg/* ~/dotfiles/newpkg/.config/newpkg/
cd ~/dotfiles && stow newpkg
```
