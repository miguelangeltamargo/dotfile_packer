# Setup fzf
# ---------
if [[ ! "$PATH" == */Users/miguel/.fzf/bin* ]]; then
  PATH="${PATH:+${PATH}:}/Users/miguel/.fzf/bin"
fi

source <(fzf --zsh)
