# Brew setup (for Apple Silicon)
eval "$(/opt/homebrew/bin/brew shellenv)"


# Bash completion
if [ -f /opt/homebrew/etc/profile.d/bash_completion.sh ]; then
  source /opt/homebrew/etc/profile.d/bash_completion.sh
fi


# Google Cloud SDK (moved out of Downloads)
if [ -f /usr/local/google-cloud-sdk/path.bash.inc ]; then
  source /usr/local/google-cloud-sdk/path.bash.inc
fi

if [ -f /usr/local/google-cloud-sdk/completion.bash.inc ]; then
  source /usr/local/google-cloud-sdk/completion.bash.inc
fi


# Ensure kubectl is in PATH early
export PATH="/usr/local/google-cloud-sdk/bin:$PATH"


# Kubectl autocomplete
if type kubectl &>/dev/null; then
  source <(kubectl completion bash)
  alias k=kubectl
  complete -F __start_kubectl k
fi


# Bash history settings
HISTSIZE=10000               # Number of commands to remember in memory
HISTFILESIZE=20000           # Number of lines in .bash_history file
HISTCONTROL=ignoredups:erasedups
HISTIGNORE="ls:bg:fg:history"  # Ignore trivial commands
shopt -s histappend          # Append to history, don’t overwrite it
PROMPT_COMMAND="history -a; history -n"  # Save new commands and reload


# Enable history-based completion (reverse search)
bind '"\e[A": history-search-backward'
bind '"\e[B": history-search-forward'
