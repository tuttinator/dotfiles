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
- **Claude Code alerts on macOS**: `bootstrap.sh` wires Claude Code hooks to `peon-ping` and selects the Warcraft Orc Peon pack

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
