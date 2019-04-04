TERM='screen-256color'

export LANG=ja_JP.UTF-8

autoload colors
colors
PROMPT="%(?.%F{blue}.%F{red})[%n@%m %~]$ %f"
SPROMPT="%{${fg[blue]}%}%r is correct? [n,y,a,e]:%{${reset_color}%} "
[ -n "${REMOTEHOST}${SSH_CONNECTION}" ] && 
  PROMPT="%{${fg[cyan]}%}$(echo ${HOST%%.*} | tr '[a-z]' '[A-Z]') ${PROMPT}"

setopt auto_cd
setopt auto_pushd
setopt correct
setopt list_packed
setopt noautoremoveslash
setopt nolistbeep

bindkey -e

export WORDCHARS='*?_.[]~=&;!#$%^(){}<>'

autoload history-search-end
zle -N history-beginning-search-backward-end history-search-end
zle -N history-beginning-search-forward-end history-search-end
bindkey "^p" history-beginning-search-backward-end
bindkey "^n" history-beginning-search-forward-end
bindkey "\\ep" history-beginning-search-backward-end
bindkey "\\en" history-beginning-search-forward-end
bindkey "\e[Z" reverse-menu-complete

HISTFILE=${HOME}/.zsh_history
HISTSIZE=50000
SAVEHIST=50000
setopt hist_ignore_dups     # ignore duplication command history list
setopt hist_ignore_space    # ignore space-starting command
setopt share_history        # share command history data

autoload zed

function print_known_hosts (){ 
  if [ -f $HOME/.ssh/known_hosts ]; then
    cat $HOME/.ssh/known_hosts | tr ',' ' ' | cut -d' ' -f1 
  fi
}
_cache_hosts=($( print_known_hosts ))

function mkcd() {
  mkdir -p "$@" && cd "$_";
}

function pshort() {
  PROMPT="%(?.%F{green}.%F{red})$ %f"
}

function pdefault() {
  PROMPT="%(?.%F{cyan}.%F{red})[${USER}@${HOST}] %~ $ %f"
}

function o(){
  open "${1:-.}"
}

function do_enter() {
  if [ -n "$BUFFER" ]; then
    zle accept-line
    return 0
  fi
  echo
  ls
  if [ "$(git rev-parse --is-inside-work-tree 2> /dev/null)" = 'true' ]; then
    echo
    echo -e "\e[0;33m--- git status ---\e[0m"
    git status -sb
  fi
  zle reset-prompt
  return 0
}
zle -N do_enter
bindkey '^m' do_enter

function peco-select-history() {
  local tac
  if which tac > /dev/null; then
    tac="tac"
  else
    tac="tail -r"
  fi
  BUFFER=$(history -n 1 | \
    eval $tac | \
    peco --query "$LBUFFER")
      CURSOR=$#BUFFER
      zle clear-screen
    }
  zle -N peco-select-history
    bindkey '^r' peco-select-history

      function peco-checkout-branch() {
        git checkout `git branch | peco | sed -e "s/\* //g" | awk "{print \$1}"`
      }

    function peco-branch-delete() {
      git branch | egrep -v 'master$|production$' | peco | xargs git branch -D
    }

  function peco-src() {
    local selected_dir=$(ghq list --full-path | peco)
    if [ -n "$selected_dir" ]; then
      BUFFER="cd ${selected_dir}"
      zle accept-line
    fi
    zle clear-screen
  }
zle -N peco-src
bindkey '^@' peco-src

function gi() {
  curl https://www.gitignore.io/api/$@
}

function back-to-previous-edit() {
  BUFFER="!v"
  zle accept-line
}
zle -N back-to-previous-edit
bindkey "^o" back-to-previous-edit

function rr() {
  clear
  rg -p -C 5 "$@" | less -FRSX
}

function rv() {
  nvim $(rg -n "$@" | peco --query "$LBUFFER" | awk -F : '{print "-c " $2 " " $1}')
}

function p() {
  ps -eo pid,args,lstart,etime | egrep "STARTED|$1" | grep -v grep
}

function qrgen() {
  qrencode -o /tmp/qrcode.png $1 && open /tmp/qrcode.png
}

alias a="alias"
alias be="bundle exec"
alias c='code .'
alias d="docker"
alias dps="docker ps -a"
alias drm="docker rm -f P"
alias drmi="docker image rm -f I"
alias dim="docker images"
alias dc="docker-compose"
alias dcs="docker-compose stop"
alias dcu="docker-compose up -d"
alias dbm="bin/rake db:migrate"
alias dot="cd $HOME/Dropbox/dotfiles"
alias df="df -h"
alias diff="colordiff"
alias dstatall='dstat -tclmdr'
alias du="du -h"
alias kctl="kubectl"
alias ll="ls -l"
alias la="ls -a"
alias lla="ls -la"
alias less="less -R"
alias ga='git add'
alias gb='peco-checkout-branch'
alias gbdelete='peco-branch-delete'
alias gc='git commit'
alias gco='git checkout'
alias gcoh='git checkout HEAD'
alias gconf='git config -l'
alias gd='git diff --no-prefix'
alias gdw='git diff --no-prefix --ignore-space-change'
alias gdc='git diff --cached --no-prefix'
alias gdcw='git diff --cached --no-prefix --ignore-space-change'
alias gdcv='nvim $(git diff --cached --name-only | peco)'
alias gdh='git diff --no-prefix --ignore-space-at-eol HEAD'
alias gdhs='git diff --no-prefix --ignore-space-at-eol HEAD..stash@{0}'
alias gempath="gem environment | grep -A 1 'GEM PATH' | tail -n 1 | tr -s ' ' | cut -d ' ' -f 3"
alias gf='git fetch -p'
alias gh='ghci'
alias gl='git log --graph --all --format="%x09%C(cyan bold)%an%Creset%x09%C(blue)%h%Creset %C(magenta reverse)%d%Creset %s"'
alias gm='git merge'
alias gmt='git mergetool --tool=vimdiff --no-prompt'
alias gpr='git remote prune origin'
alias gs='git show'
alias gsn='git show --name-only'
alias gsw='git show --ignore-space-change'
alias gv='[ -e .git/index ] && nvim .git/index -c "Gitv --all" -c "tabonly" || echo .git/index not found: `pwd`'
alias gas='git add . && git stash'
alias gsp='git stash pop'
alias gsc='git stash clear'
alias gcancelcommit='git reset --soft HEAD^'
alias gcanceladd='git reset HEAD'
alias gt='gtree'
alias goreautoimport='gore -autoimport'
alias gosrc="cd '$(go env GOROOT)/src'"
alias h='cd ..'
alias hh='cd ../..'
alias hhh='cd ../../..'
alias ht='sudo htop'
alias hs='hub browse'
alias l="gls -lt --human-readable --no-group --classify --color --group-directories-first"
alias la="gls -lta --human-readable --no-group --classify --color --group-directories-first"
alias lsfullpath='find `pwd` -maxdepth 1'
alias nv="nvim"
alias -g P='`docker ps -a | tail -n +2 | peco | cut -d" " -f1`'
alias -g I='`docker images | tail -n +2 | peco | tr -s " " | cut -d" " -f3`'
alias sl='l'
alias t="tree -I vendor -I node_modules"
alias u="popd"
alias U="git commit -am 'Update'"
alias v="nvim"
alias vk='nvim -c "au VimEnter * DeniteProjectDir file_rec/git"'
alias dc='code . `git diff --no-prefix --ignore-space-at-eol --name-only --relative`'
alias dv='nvim `git diff --no-prefix --ignore-space-at-eol --name-only --relative`'
alias dcc='code . `git diff --no-prefix --ignore-space-at-eol --cached --name-only --relative`'
alias dcv='nvim `git diff --no-prefix --ignore-space-at-eol --cached --name-only --relative`'
alias f='nvim -c "au VimEnter * VimFilerExplorer -winwidth=50 -no-quit"'
alias vi="nvim"
alias vim="nvim"
alias V="nvim -R -"
alias z='nvim ~/.zshrc'
alias Z='source ~/.zshrc'
alias rs='bin/rails s'
alias rc='bin/rails c'
alias rd='bin/rails db -p'
alias rm='trash'
alias w1='watch --interval 1'
alias xmllint='xmllint --format --encode utf-8'

export PATH="/usr/local/bin:/usr/local/sbin:$PATH"
export EDITOR=nvim
export CC=/usr/bin/gcc
export PGDATA=/usr/local/var/postgres

export GOPATH=$HOME/go
export GOBIN=$GOPATH/bin
export PATH="$PATH:$GOBIN:$GOENV_ROOT/bin"

export PATH="$PATH:/usr/local/share/git-core/contrib/diff-highlight"
export PATH="$PATH:/Applications/Visual Studio Code.app/Contents/Resources/app/bin"

export PATH="$HOME/.anyenv/bin:$PATH"
eval "$(anyenv init -)"
eval "$(rbenv init - zsh)"
eval "$(nodenv init -)"

USER_BASE_PATH=$(python -m site --user-base)
export PATH=$PATH:$USER_BASE_PATH/bin

test -e "${HOME}/.iterm2_shell_integration.zsh" && source "${HOME}/.iterm2_shell_integration.zsh"

eval "$(direnv hook zsh)"

fpath=(/usr/local/share/zsh-completions $fpath)
fpath=($(brew --prefix)/share/zsh/site-functions $fpath)

autoload -U compinit
compinit -u

[ -f $HOME/.zshrc.local ] && source $HOME/.zshrc.local

function is_exists() { type "$1" >/dev/null 2>&1; return $?; }
function is_screen_running() { [ ! -z "$STY" ]; }
function is_tmux_runnning() { [ ! -z "$TMUX" ]; }
function is_screen_or_tmux_running() { is_screen_running || is_tmux_runnning; }
function shell_has_started_interactively() { [ ! -z "$PS1" ]; }
function is_ssh_running() { [ ! -z "$SSH_CONECTION" ]; }
function tmux_automatically_attach_session() {
  if is_screen_or_tmux_running; then
    ! is_exists 'tmux' && return 1

    if is_tmux_runnning; then
    elif is_screen_running; then
      echo "This is on screen."
    fi
  else
    if shell_has_started_interactively && ! is_ssh_running; then
      if ! is_exists 'tmux'; then
        echo 'Error: tmux command not found' 2>&1
        return 1
      fi

      if tmux has-session >/dev/null 2>&1 && tmux list-sessions | grep -qE '.*]$'; then
        # detached session exists
        tmux list-sessions
        echo -n "Tmux: attach? (y/N/num) "
        read
        if [[ "$REPLY" =~ ^[Yy]$ ]] || [[ "$REPLY" == '' ]]; then
          tmux attach-session
          if [ $? -eq 0 ]; then
            echo "$(tmux -V) attached session"
            return 0
          fi
        elif [[ "$REPLY" =~ ^[0-9]+$ ]]; then
          tmux attach -t "$REPLY"
          if [ $? -eq 0 ]; then
            echo "$(tmux -V) attached session"
            return 0
          fi
        fi
      fi

      if is_exists 'reattach-to-user-namespace'; then
        tmux_config=$(cat $HOME/.tmux.conf <(echo 'set-option -g default-command "reattach-to-user-namespace -l $SHELL"'))
        tmux -f <(echo "$tmux_config") new-session && echo "$(tmux -V) created new session supported OS X"
      else
        tmux new-session && echo "tmux created new session"
      fi
    fi
  fi
}
tmux_automatically_attach_session
