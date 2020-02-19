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

function gosrc() {
  cd "$(go env GOROOT)/src"
}

function git-delete-merged-branches() {
  git branch --merged | grep -vE '^\*|master$|develop$' | xargs -I % git branch -d %
}

function catp() {
  pygmentize $1
  cat $1 | pbcopy
}

function pullconf() {
  local a="$(ghq root)/github.com/hioki-daichi"
  (cd "${a}/dotfiles"; git pull origin master) &
  (cd "${a}/nvim-config"; git pull origin master) &
  (cd "${a}/Personal-Rules-For-Karabiner-Elements"; git pull origin master; ./update.sh) &
  wait
}

function ppcsv() {
  nkf $1 | xsv table -
}

function csvcat() {
  column -s, -t $1
}

function git_grep_and_blame() {
  git grep -E -n $1 | while IFS=: read i j k; do git blame -L $j,$j $i | cat; done
}

function head_with_index() {
  head -n1 $1 | ruby -e 'puts $stdin.read.split(",").map.with_index(1) { |s, idx| "#{idx} #{s}" }'
}

function search_yaml() {
  ruby -ryaml -e "puts YAML.load_file(ARGV[0]).select { |k, v| k =~ Regexp.new(ARGV[1]) }.map { |k, v| \"#{v} #{k}\" }" $1 $2
}

function rg_with_head() {
  search_word="(^|,|,\")$1($|,|\",)"
  max_count=$((${2:-100}))
  target_dir=${3:-./csv}

  for filepath in $(rg -E sjis -l $search_word $target_dir)
  do
    echo ${filepath}:
    echo $(nkf $filepath | head -n 1) $(rg -E sjis --max-count $max_count $search_word $filepath) | xsv table -
    echo
  done
}

function chpwd() { exa }

function install-rust-devtools {
  rustup component add \
    rustfmt \
    rust-analysis \
    rust-src \
    rls-preview

  cargo install \
    cargo-watch \
    cargo-web \
    racer
}

function gsnv() {
  ruby -e 'prefix = `git rev-parse --show-cdup`.chomp; files = `git show --pretty="" --name-only`.split.map { |s| prefix + s }.join(" "); system("nvim #{files}")'
}

alias a="alias"
alias c='clion .'
alias ca='cargo'
alias checkip='curl -s checkip.amazonaws.com'
alias cutn="cut -d' ' -f$1"
alias d="docker"
alias dps="docker ps -a"
alias drm="docker rm -f P"
alias drmi="docker image rm -f I"
alias dim="docker images"
alias dc="docker-compose"
alias dcs="docker-compose stop"
alias dcu="docker-compose up -d"
alias dot="cd $(ghq root)/github.com/hioki-daichi/dotfiles"
alias df="df -h"
alias diff="colordiff"
alias dstatall='dstat -tclmdr'
alias du="du -h"
alias dc='code . `git diff --no-prefix --ignore-space-at-eol --name-only --relative`'
alias dv='nvim `git diff --no-prefix --ignore-space-at-eol --name-only --relative`'
alias dcc='code . `git diff --no-prefix --ignore-space-at-eol --cached --name-only --relative`'
alias dcv='nvim `git diff --no-prefix --ignore-space-at-eol --cached --name-only --relative`'
alias f='nvim -c "au VimEnter * VimFilerExplorer -winwidth=50 -no-quit"'
alias fooe="$EDITOR ~/foo.txt"
alias foo="cat ~/foo.txt"
function foox() { cat ~/foo.txt | cargo run --bin $1 }
alias ga='git add'
alias gb='peco-checkout-branch'
alias gbdelete='peco-branch-delete'
alias gc='git commit'
alias gcam='git commit --am'
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
alias gl='git log --graph --all --format="%x09%C(cyan bold)%an%Creset%x09%C(blue)%h%Creset %C(magenta reverse)%d%Creset %s"'
alias gm='git merge'
alias gmt='git mergetool --tool=vimdiff --no-prompt'
alias gpr='git remote prune origin'
alias gpo='git push origin'
alias gpof='git push --force-with-lease origin'
alias gs='git show'
alias gsn='git show --name-only'
alias gsw='git show --ignore-space-change'
alias gas='git add . && git stash'
alias gsp='git stash pop'
alias gsc='git stash clear'
alias gcancelcommit='git reset --soft HEAD^'
alias gcanceladd='git reset HEAD'
alias gt='gtree'
alias goreautoimport='gore -autoimport'
alias h='cd ..'
alias hh='cd ../..'
alias hhh='cd ../../..'
alias ht='sudo htop'
alias hs='hub browse'
alias kctl="kubectl"
alias ls="exa"
alias less="less -R"
alias l="exa -ahl --git"
alias la="gls -lta --human-readable --no-group --classify --color --group-directories-first"
alias lsfullpath='find `pwd` -maxdepth 1'
alias nv="nvim"
alias rgs='rg -E sjis'
alias rm='trash'
alias rust-musl-builder='docker run --rm -it -v "$(pwd)":/home/rust/src ekidd/rust-musl-builder'
alias s='spt' # spotify-tui
alias sl='l'
alias t="tree -I vendor -I node_modules -I target"
alias tf="terraform"
alias tfp="terraform plan"
alias tfa="terraform apply"
alias u="popd"
alias U="git commit -am 'wip'"
alias v="nvim"
alias vk='nvim -c "au VimEnter * Denite -start-filter=1 -buffer-name=gtags_path gtags_path"'
alias vshiftjis='nvim -c ":e ++enc=shift_jis"'
alias vi="nvim"
alias vim="nvim"
alias vsm="nvim src/main.rs"
alias vcargo="nvim ./Cargo.toml"
alias V="nvim -R -"
alias w1='watch --interval 1'
alias xmllint='xmllint --format --encode utf-8'
alias z='nvim ~/.zshrc'
alias Z='source ~/.zshrc'
alias -g P='`docker ps -a | tail -n +2 | peco | cut -d" " -f1`'
alias -g I='`docker images | tail -n +2 | peco | tr -s " " | cut -d" " -f3`'

export EDITOR=nvim
export CC=/usr/bin/gcc
export PGDATA=/usr/local/var/postgres

# Go
export GOPATH=$HOME/go
export GOBIN=$GOPATH/bin

# Rust
source $HOME/.cargo/env

export PATH="/usr/local/bin:/usr/local/sbin:$PATH"
export PATH="$HOME/.anyenv/bin:$PATH"
export PATH="$PATH:$GOBIN:$GOENV_ROOT/bin"
export PATH="$PATH:/usr/local/share/git-core/contrib/diff-highlight"
export PATH="$PATH:/Applications/Visual Studio Code.app/Contents/Resources/app/bin"
export PATH="$PATH:$(python -m site --user-base)/bin"
export PATH="$PATH:/usr/local/opt/binutils/bin"

fpath=($(brew --prefix)/share/zsh-completions $fpath)
fpath=($(brew --prefix)/share/zsh/site-functions $fpath)
fpath=($HOME/.zfunc $fpath)

autoload -U compinit
compinit -u

eval "$(anyenv init -)"
eval "$(rbenv init - zsh)"
eval "$(nodenv init -)"
eval "$(direnv hook zsh)"

test -e "${HOME}/.iterm2_shell_integration.zsh" && source "${HOME}/.iterm2_shell_integration.zsh"

[ -f $HOME/.zshrc.local ] && source $HOME/.zshrc.local
