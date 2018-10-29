# Path to your oh-my-zsh configuration.
ZSH=$HOME/.oh-my-zsh

# Set name of the theme to load.
# Look in ~/.oh-my-zsh/themes/
ZSH_THEME="bullet-train"

source <(antibody init)
antibody bundle < ~/.zsh_plugins.txt

export EDITOR=/usr/bin/vim

# Which plugins would you like to load? (plugins can be found in ~/.oh-my-zsh/plugins/*)
plugins=(git)

source $ZSH/oh-my-zsh.sh

# Golang
export GOPATH=$HOME/go

# Customize to your needs...
export PATH=$PATH:$HOME/bin