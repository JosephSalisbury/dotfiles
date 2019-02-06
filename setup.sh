#!/bin/sh

set -eu

dotfiles=(
  './dunst/config'      '/home/joe/.config/dunst/dunstrc'

  './git/config'	'/home/joe/.gitconfig'
  './git/template'	'/home/joe/.gittemplate'

  './bin/k-mgmt.sh'	'/home/joe/.bin/k-mgmt.sh'
  './bin/kubectl-roll'	'/home/joe/.bin/kubectl-roll'

  './i3/brightness'	'/home/joe/.i3-brightness.sh'
  './i3/config'		'/home/joe/.config/i3/config'
  './i3/status'		'/home/joe/.i3-status.sh'

  './tmux/config'	'/home/joe/.tmux.conf'
  './tmux/status'	'/home/joe/.tmux-status.sh'

  './zsh/aliases'	'/home/joe/.zsh_aliases'
  './zsh/config'	'/home/joe/.zshrc'
)

for ((i=0; i<${#dotfiles[@]}; i+=2)); do
  sourceFile=${dotfiles[i]}
  targetFile=${dotfiles[i+1]}

  dir=$(dirname $targetFile)
  if [ ! -d $dir ]; then
    echo "Making directory $dir"
    mkdir -p $dir
  fi

  echo "Linking ${sourceFile} to ${targetFile}"
  ln -f $sourceFile $targetFile
done	

