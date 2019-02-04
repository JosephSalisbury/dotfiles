#!/bin/sh

dotfiles=(
  './k-mgmt.sh'		'/home/joe/.k-mgmt.sh'

  './git/config'	'/home/joe/.gitconfig'
  './git/template'	'/home/joe/.gittemplate'

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

  echo "Linking ${sourceFile} to ${targetFile}"
  ln -f $sourceFile $targetFile
done	

