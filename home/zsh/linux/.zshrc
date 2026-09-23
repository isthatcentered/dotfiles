# Show the prompt while the remaining shell configuration loads.
if [[ -r "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh" ]]; then
  source "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh"
fi

# Keep the CachyOS shell plugins and load Powerlevel10k explicitly below.
export ZSH=/usr/share/oh-my-zsh
ZSH_THEME=""
DISABLE_MAGIC_FUNCTIONS=true
ENABLE_CORRECTION=true
COMPLETION_WAITING_DOTS=true
[[ -z "${plugins[*]}" ]] && plugins=(git fzf extract)
source "$ZSH/oh-my-zsh.sh"

export HISTCONTROL=ignoreboth
export HISTORY_IGNORE='(\&|[bf]g|c|clear|history|exit|q|pwd|* --help)'
export LESS_TERMCAP_md="$(tput bold 2>/dev/null; tput setaf 2 2>/dev/null)"
export LESS_TERMCAP_me="$(tput sgr0 2>/dev/null)"
export PROMPT_COMMAND="history -a; $PROMPT_COMMAND"

alias make="make -j`nproc`"
alias ninja="ninja -j`nproc`"
alias n="ninja"
alias c="clear"
alias rmpkg="sudo pacman -Rsn"
alias cleanch="sudo pacman -Scc"
alias fixpacman="sudo rm /var/lib/pacman/db.lck"
alias update="sudo pacman -Syu"
alias apt="man pacman"
alias apt-get="man pacman"
alias please="sudo"
alias tb="nc termbin.com 9999"
# Evaluate the orphan list when cleanup runs, not at every shell startup.
alias cleanup='sudo pacman -Rsn $(pacman -Qtdq)'
alias jctl="journalctl -p 3 -xb"
alias rip="expac --timefmt='%Y-%m-%d %T' '%l\t%n %v' | sort | tail -200 | nl"

source /usr/share/zsh-theme-powerlevel10k/powerlevel10k.zsh-theme
[[ ! -f ~/.p10k.zsh ]] || source ~/.p10k.zsh

source /usr/share/zsh/plugins/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh
source /usr/share/zsh/plugins/zsh-autosuggestions/zsh-autosuggestions.zsh
source /usr/share/zsh/plugins/zsh-history-substring-search/zsh-history-substring-search.zsh
source /usr/share/doc/pkgfile/command-not-found.zsh
export FZF_BASE=/usr/share/fzf

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
