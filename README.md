# 🏠 Dotfiles

Personal dotfiles for macOS setup with Starship prompt, Zsh configuration, and development tools.

```text
      ██            ██     ████ ██  ██
     ░██           ░██    ░██░ ░░  ░██
     ░██  ██████  ██████ ██████ ██ ░██  █████   ██████
  ██████ ██░░░░██░░░██░ ░░░██░ ░██ ░██ ██░░░██ ██░░░░
 ██░░░██░██   ░██  ░██    ░██  ░██ ░██░███████░░█████
░██  ░██░██   ░██  ░██    ░██  ░██ ░██░██░░░░  ░░░░░██
░░██████░░██████   ░░██   ░██  ░██ ███░░██████ ██████
 ░░░░░░  ░░░░░░     ░░    ░░   ░░ ░░ ░░░░░░ ░░░░░░
```

## 🚀 Quick Setup

For a fresh macOS installation, run the bootstrap script:

```bash
git clone https://github.com/your-username/dotfiles.git ~/dotfiles
cd ~/dotfiles
./bootstrap.sh
```

## 📦 What's Included

- **Homebrew packages**: Development tools, CLI utilities, and applications
- **Zsh configuration**: Custom `.zshrc` with plugins managed by Antidote
- **Starship prompt**: Beautiful, fast shell prompt with Git integration
- **Git configuration**: Global `.gitconfig` and `.gitignore_global`
- **Neovim setup**: Editor configuration
- **macOS defaults**: Sensible system preferences
- **SSH key generation**: Automatic setup for GitHub

## 🛠 Manual Setup

If you prefer to set things up manually:

1. **Install Homebrew**:

   ```bash
   /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
   ```

2. **Install packages**:

   ```bash
   brew bundle install
   ```

3. **Symlink dotfiles**:

   ```bash
   ln -sf ~/dotfiles/zsh/.zshrc ~/.zshrc
   ln -sf ~/dotfiles/.config/starship.toml ~/.config/starship.toml
   ln -sf ~/dotfiles/git/.gitconfig ~/.gitconfig
   ln -sf ~/dotfiles/git/.gitignore_global ~/.gitignore_global
   ln -sf ~/dotfiles/tmux/.tmux.conf ~/.tmux.conf
   ```

4. **Setup Zsh plugins**:

   ```bash
   antidote bundle < zsh/zsh_plugins.txt > ~/.zsh_plugins.sh
   ```

5. **Generate SSH keys**:

   ```bash
   ssh-keygen -t ed25519 -C "your-email@example.com"
   ```

## 🪟 Windows Setup

Windows hosts the GUI apps; WSL2 + Ubuntu hosts the dev tooling. The Linux
side reuses `bootstrap-linux.sh`, so the zsh/tmux/nvim/mise setup lives in one
place.

1. Clone the repo to `C:\Users\<you>\dotfiles`.
2. Open an **elevated** PowerShell (Run as Administrator), then:

   ```powershell
   cd $HOME\dotfiles
   .\bootstrap-windows.ps1
   ```

   This installs the apps listed in `winget.json` and sets up WSL2 + Ubuntu.
   If WSL asks for a reboot, reboot and re-run with `-SkipApps` to finish.

3. Launch Ubuntu from the Start Menu (first launch asks for a username +
   password), then inside Ubuntu:

   ```bash
   sudo apt-get update && sudo apt-get install -y git
   git clone https://github.com/calebtutty/dotfiles.git ~/dotfiles
   cd ~/dotfiles && ./bootstrap-linux.sh
   ```

4. Launch Tailscale from the Start Menu and sign in. The WSL side needs its
   own `sudo tailscale up --ssh` — WSL doesn't share the Windows host's
   tailnet identity.

Edit `winget.json` to add/remove apps. Find package IDs with
`winget search <name>`.

## 🍓 Headless Raspberry Pi Provisioning

`bootstrap-pi-sd.sh` provisions a Raspberry Pi SD card from your Mac so the Pi
comes up on your Wi-Fi, joins your Tailscale tailnet, and runs
`bootstrap-linux.sh` — all without a screen or keyboard.

### One-time setup

1. Copy the example config and fill in the `[pi]` section:

   ```bash
   cp dotfiles.local.toml.example dotfiles.local.toml
   $EDITOR dotfiles.local.toml
   ```

   You'll need Wi-Fi credentials, a user password, and a Tailscale auth key
   from https://login.tailscale.com/admin/settings/authkeys (reusable +
   pre-approved is easiest). `dotfiles.local.toml` is gitignored — don't check
   it in.

2. Install Raspberry Pi Imager if you haven't already:

   ```bash
   brew install --cask raspberry-pi-imager
   ```

### Provisioning a card (default, safe path)

1. Flash Raspberry Pi OS Lite (64-bit) to the SD card using the Raspberry Pi
   Imager GUI. Leave all "advanced options" blank — our script replaces them.
2. After flashing, the `bootfs` partition auto-mounts at `/Volumes/bootfs`.
   With the card still inserted, run:

   ```bash
   ./bootstrap-pi-sd.sh kitchen
   ```

   The suffix (`kitchen`) is appended to `[pi].hostname_prefix` to form the
   final hostname (e.g. `pi-kitchen`).

3. The script drops `custom.toml`, `firstrun.sh`, and patches `cmdline.txt`
   onto the boot partition, then ejects. It includes the public keys from this
   machine's `~/.ssh/*.pub` files in `custom.toml`, so Raspberry Pi OS firstboot
   installs them for the Pi user. Insert the card into the Pi and power it on.
   Within ~5 minutes it should appear on your tailnet:

   ```bash
   tailscale status | grep pi-kitchen
   ssh caleb@pi-kitchen     # passwordless via your local SSH key
   ```

### Optional: flash-and-prepare in one shot

If you'd rather have the script flash the card too, pass `--flash` with the
target device. **Destructive — double-check the disk!**

```bash
diskutil list external physical    # find your SD card
./bootstrap-pi-sd.sh kitchen --flash /dev/disk6
```

The script refuses to write to low-numbered disks and requires you to retype
the device path to confirm.

### Troubleshooting

If the Pi doesn't appear on the tailnet after ~5 min, boot it with a monitor
and check:

```bash
sudo cat /boot/firmware/firstrun.log
```

Common causes: wrong Wi-Fi country code, expired/invalid Tailscale auth key,
Wi-Fi password with special characters that got mangled (the script writes
TOML, so `"` and `\` in the PSK need escaping in `dotfiles.local.toml`).

If `firstrun.log` shows repeated failed `ping -c1 -W2 1.1.1.1` attempts or
`Temporary failure resolving`, the Pi did not have usable network/DNS during
first boot. The script disables the one-shot boot hook so the Pi can boot
normally; after fixing Wi-Fi, you can manually rerun:

```bash
sudo bash -x /boot/firmware/firstrun.sh
```

## 📁 Structure

```text
.
├── bootstrap.sh              # Automated setup script
├── Brewfile                  # Homebrew packages
├── .config/
│   ├── starship.toml         # Starship prompt configuration
│   └── nvim/                 # Neovim configuration
├── git/
│   ├── .gitconfig           # Git global configuration
│   └── .gitignore_global    # Global gitignore patterns
├── zsh/
│   ├── .zshrc              # Zsh configuration
│   └── zsh_plugins.txt     # Antidote plugin list
├── tmux/
│   └── .tmux.conf          # Tmux configuration
├── iterm2/                 # iTerm2 color schemes
└── rectangle/              # Rectangle window manager config
```

## 🎨 Features

- **Beautiful terminal**: Starship prompt with Git status, language versions, and more
- **Plugin management**: Zsh plugins for autosuggestions, syntax highlighting, and completions
- **Development tools**: Node.js, Python, Go, Rust, and other language toolchains
- **Window management**: Rectangle for window snapping and organization
- **Version management**: mise for managing multiple language versions
- **Claude Code alerts on macOS**: `bootstrap.sh` wires Claude Code hooks to `peon-ping` and selects a pack

## 🔧 Customization

Feel free to customize any configuration files to match your preferences:

- Edit `.zshrc` for shell customization
- Modify `starship.toml` for prompt styling
- Update `Brewfile` to add/remove packages
- Adjust `zsh_plugins.txt` for different plugins

## 📝 Notes

- The bootstrap script will backup existing configuration files
- Some changes require a terminal restart to take effect
- SSH keys will be generated and should be added to your GitHub account
