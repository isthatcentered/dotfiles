# Enable Powerlevel10k instant prompt. Should stay close to the top of ~/.zshrc.
# Initialization code that may require console input (password prompts, [y/n]
# confirmations, etc.) must go above this block; everything else may go below.
if [[ -r "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh" ]]; then
  source "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh"
fi

source /usr/share/cachyos-zsh-config/cachyos-config.zsh

# To customize prompt, run `p10k configure` or edit ~/.p10k.zsh.
[[ ! -f ~/.p10k.zsh ]] || source ~/.p10k.zsh

# >>> Codex installer >>>
export PATH="/home/isthatcentered/.local/bin:$PATH"
# <<< Codex installer <<<


# Aliases 
alias codex='codex --sandbox danger-full-access'
alias sol='codex --model gpt-5.6-sol --config model_reasoning_effort=high'
alias claude='claude --dangerously-skip-permissions'

eval "$(direnv hook zsh)"

export NVM_DIR="$HOME/.nvm"
[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"  # This loads nvm
[ -s "$NVM_DIR/bash_completion" ] && \. "$NVM_DIR/bash_completion"  # This loads nvm bash_completion
export PATH="$(go env GOPATH)/bin:$PATH"

. "$HOME/.atuin/bin/env"

eval "$(atuin init zsh)"

# Enable vim mode in the terminal
bindkey -v
export KEYTIMEOUT=1
