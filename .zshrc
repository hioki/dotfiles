source $HOME/zsh-defer/zsh-defer.plugin.zsh
zsh-defer -c 'eval "$(~/.local/bin/mise activate bash)"'
zsh-defer -c 'autoload -U compinit && compinit -u'

TERM='screen-256color'

# export LC_ALL=ja_JP.UTF-8
# export LANG=ja_JP.UTF-8
# export LANGUAGE=ja_JP.UTF-8

autoload colors
colors

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

cdfzfrepo() {
  local selected=$(echo "$WORK_REPO" | fzf)
  if [ -n "$selected" ]; then
    local repo=$(echo "$selected" | cut -f2)
    BUFFER="cd $repo"
    zle accept-line
  fi
  zle clear-screen
}
zle -N cdfzfrepo
bindkey '^\^' cdfzfrepo

function fzf-select-history() {
  local selected
  selected=$(history -n 1 | fzf --no-sort --tac --query "$LBUFFER") || return
  selected=${selected##*  }
  BUFFER="$selected"
  zle accept-line
}
zle -N fzf-select-history
bindkey '^r' fzf-select-history

function fzf-checkout-branch() {
  git checkout "$(git branch --format='%(refname:short)' | fzf)"
}

function fzf-branch-delete() {
  git branch --sort=-committerdate | grep -Ev 'master$|production$' | fzf -m | xargs git branch -D
}

function fzf-src() {
  local selected_dir=$(ghq list --full-path | fzf)
  if [ -n "$selected_dir" ]; then
    BUFFER="cd ${selected_dir}"
    zle accept-line
  fi
  zle clear-screen
}
zle -N fzf-src
bindkey '^@' fzf-src

function gi() {
  curl https://www.gitignore.io/api/$@
}

function back-to-previous-edit() {
  BUFFER="!v"
  zle accept-line
}
zle -N back-to-previous-edit
# bindkey "^o" back-to-previous-edit

function rr() {
  clear
  rg --fixed-strings --hidden -p -C 5 "$@" | less -FRSX
}

function rv() {
  local selected
  selected=$(rg --hidden --line-number --no-heading --color=always "$@" |
    fzf --ansi --delimiter : \
        --preview 'bat --style=numbers --color=always --highlight-line {2} {1}' \
        --preview-window '+{2}-10') || return

  local file=$(echo "$selected" | cut -d':' -f1)
  local line=$(echo "$selected" | cut -d':' -f2)
  nvim +"$line" "$file"
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

function chpwd() {
  if command -v exa > /dev/null; then
    exa
  else
    ls
  fi
}

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

function fmten() {
  pbpaste | tr '\n' ' ' | sed -e 's/  / /g' -e 's/^ //' -e 's/\. /\.\n\n/g' | pbcopy
  pbpaste
}

function aws_set_account() {
  AWS_VAULT_SHELL=1 aws-vault exec $1 -- $SHELL
}

function aws_unset_account() {
  if [ $AWS_VAULT_SHELL ]; then
    unset AWS_VAULT_SHELL
    exit 0
  fi
}

function awsenv() {
  if [[ ! -z $AWS_VAULT ]]; then
    unset AWS_VAULT
  fi
  local env=$(grep -oP '(?<=^\[profile ).*(?=])' ~/.aws/config | fzf --query "$LBUFFER")
  AWS_VAULT_SHELL=1 aws-vault exec $env -- $SHELL
}

function hankakuToZenkaku() {
  awk '{
      leading_space_count = 0
      while (substr($0, 1, 1) == " ") {
          leading_space_count++
          $0 = substr($0, 2)
      }
      while (leading_space_count > 1) {
          printf "　"
          leading_space_count -= 2
      }
      if (leading_space_count == 1) {
          printf " "
      }
      print
  }' $1
}

function grepopen() {
  nvim $(git grep --name-only $1)
}

function switch_main_branch() {
  local branches=("main" "master" "develop")
  for branch in "${branches[@]}"; do
    if git show-ref --verify --quiet "refs/heads/$branch" &>/dev/null; then
      echo "Switching to branch: $branch"
      git switch "$branch"
      return
    fi
  done
  echo "No suitable branch found (main, master, develop)" >&2
  return 1
}

ssh_clean_control_files() {
  setopt localoptions nullglob

  local files=(~/.ssh/control-*)
  if (( ${#files[@]} == 0 )); then
    echo "No ~/.ssh/control-* files found."
    return 0
  fi

  echo "Removing the following files:"
  print -l -- "${files[@]}"
  rm -f -- "${files[@]}"
  echo "Removed."
}

calculate_average() {
    sum=0
    count=0
    for num in "$@"; do
        sum=$((sum + num))
        count=$((count + 1))
    done
    if [ $count -eq 0 ]; then
        echo "Arguments are required. (e.g. \`calculate_average 1 2\`)"
    else
        average=$(echo "$sum / $count" | bc -l)
        printf "Average: %.2f\n" $average
    fi
}

fzfssh() {
  local local_hosts=$(cat ~/.ssh/visited_local_hosts)
  local private_hosts=$(grep --no-filename -oP '(?<=^Host ).*' ~/.ssh/config.d/* | grep -Ev '^st-|^sdwire')
  local selected_host=$(echo "${local_hosts}\n${private_hosts}" | fzf --query "$LBUFFER")
  if [ -n "$selected_host" ]; then
    BUFFER="ssh ${selected_host}"
    zle accept-line
  fi
  zle clear-screen
}
zle -N fzfssh
bindkey '^]' fzfssh


fzfsshstsdwire() {
  local selected_host=$(grep --no-filename -oP '(?<=^Host ).*' ~/.ssh/config.d/* | grep -E '^st-|^sdwire' | fzf --query "$LBUFFER")
  if [ -n "$selected_host" ]; then
    BUFFER="ssh ${selected_host}"
    zle accept-line
  fi
  zle clear-screen
}
zle -N fzfsshstsdwire
bindkey '^\' fzfsshstsdwire

ssh() {
  local host="$1"
  if [[ "$host" == *.local ]]; then
    local file=~/.ssh/visited_local_hosts
    [ -f "$file" ] || touch "$file"
    if ! grep -qx "$host" "$file"; then
        echo "$host" >> "$file"
    fi
  fi
  command ssh "$@"
}

alias a="alias"
alias c='code .'
alias ca='cargo'
alias cr='cargo run --quiet'
alias cb='cargo watch -x build'
alias checkip='curl -s checkip.amazonaws.com'
alias cutn="cut -d' ' -f$1"
alias cov="cargo llvm-cov test --html --open"
alias d="docker"
alias dps="docker ps -a"
alias drm="docker rm -f P"
alias drmi="docker image rm -f I"
alias dkill="docker kill PS"
alias dim="docker images"
alias dc="docker-compose"
alias dcs="docker-compose stop"
alias dcu="docker-compose up -d"
alias df="df -h"
alias diff="colordiff"
alias dstatall='dstat -tclmdr'
alias du="du -h"
alias dc='code . `git diff --no-prefix --ignore-space-at-eol --name-only --relative`'
alias dv='nvim `git diff --no-prefix --ignore-space-at-eol --name-only --relative`'
alias dcc='code . `git diff --no-prefix --ignore-space-at-eol --cached --name-only --relative`'
alias dcv='nvim `git diff --no-prefix --ignore-space-at-eol --cached --name-only --relative`'
alias f='fvim'
alias fb='fbat'
alias fbat='f=$(fzf) && [ -f "$f" ] && bat "$f"'
alias fv='fvim'
alias fvim='f=$(fzf) && [ -f "$f" ] && vim "$f"'
alias fo='fopen'
alias fopen='f=$(fzf) && [ -f "$f" ] && open "$f"'
alias ga='git add'
alias gb='fzf-checkout-branch'
alias gbdelete='fzf-branch-delete'
alias gc='git commit'
alias cg='git commit'
alias gcam='git commit --am'
alias gco='git checkout'
alias gcoh='git checkout HEAD'
alias gconf='git config -l'
alias gd='git diff --no-prefix'
alias gdw='git diff --no-prefix --ignore-space-change'
alias gdc='git diff --cached --no-prefix'
alias gdcw='git diff --cached --no-prefix --ignore-space-change'
alias gdcv='nvim $(git diff --cached --name-only | fzf)'
alias gdh='git diff --no-prefix --ignore-space-at-eol HEAD'
alias gdhs='git diff --no-prefix --ignore-space-at-eol HEAD..stash@{0}'
alias gempath="gem environment | grep -A 1 'GEM PATH' | tail -n 1 | tr -s ' ' | cut -d ' ' -f 3"
alias gf='git fetch -p'
alias gg='ghq get'
alias gl='git log --graph --all --format="%x09%C(cyan bold)%an%Creset%x09%C(blue)%h%Creset %C(magenta reverse)%d%Creset %s"'
alias gm='switch_main_branch'
alias gmt='git mergetool --tool=vimdiff --no-prompt'
alias gp='git pull origin $(git branch --show-current)'
alias gs='git show'
alias gsm='git submodule'
alias gsn='git show --name-only'
alias gsw='git show --ignore-space-change'
alias gas='git add . && git stash'
alias gsp='git stash pop'
alias gsc='git stash clear'
alias gcancelcommit='git reset --soft HEAD^'
alias gcanceladd='git restore --staged .'
alias gcanceladd_old='git reset HEAD'
alias gt='gtree'
alias goreautoimport='gore -autoimport'
alias gho="gh repo view --web"
alias gr="gh run view --web"
alias h='cd ..'
alias hh='cd ../..'
alias hhh='cd ../../..'
alias ht='sudo htop'
alias kctl="kubectl"
alias less="less -R"
alias lsfullpath='find `pwd` -maxdepth 1'
alias m="switch_main_branch"
alias nv="nvim"
alias rgs='rg -E sjis'
alias rust-musl-builder='docker run --rm -it -v "$(pwd)":/home/rust/src ekidd/rust-musl-builder'
alias rsyncj="rsync --progress -avz -e 'ssh -J hioki-bastion'"
alias scpj='scp -J hioki-bastion'
alias sl='l'
alias t="tree -a -I 'vendor|node_modules|target|__pycache__|.idea|.vscode|.git|.venv|.ruff_cache|.terraform'"
alias tree="tree -a"
alias tf="terraform"
alias tfp="terraform plan"
alias tfa="terraform apply"
alias u="popd"
alias U="git commit -am 'wip'"
alias UU="git commit -am '[ci skip] wip'"
alias v="nvim"
alias vk='nvim -c "au VimEnter * Denite -start-filter=1 -buffer-name=gtags_path gtags_path"'
alias vshiftjis='nvim -c ":e ++enc=shift_jis"'
alias vi="nvim"
alias vim="nvim"
alias vsm="nvim src/main.rs"
alias vcargo="nvim ./Cargo.toml"
alias V="nvim -R -"
alias VV="jq . | nvim -R - -c 'set filetype=json'"
alias w1='watch --interval 1'
alias x="mise x --"
alias xmllint='xmllint --format --encode utf-8'
alias z='nvim ~/.zshrc'
alias zl='nvim ~/.zshrc.local'
alias Z='source ~/.zshrc'
alias ZL='source ~/.zshrc.local'
alias -g P='`docker ps -a | tail -n +2 | fzf | cut -d" " -f1`'
alias -g PS='`docker ps | tail -n +2 | fzf | cut -d" " -f1`'
alias -g I='`docker images | tail -n +2 | fzf | tr -s " " | cut -d" " -f3`'

if [[ $(ulimit -n) -lt 1024 ]]; then
  ulimit -n 1024
fi

export EDITOR=nvim
export PGDATA=/usr/local/var/postgres

export FZF_DEFAULT_OPTS="--reverse --multi"

# Go
export GOPATH=$HOME/go
export GOBIN=$GOPATH/bin

# Rust
if [ -f $HOME/.cargo/env ]; then
  zsh-defer source $HOME/.cargo/env
fi

# Python
#export PATH="/usr/local/opt/python/libexec/bin:$PATH:$(python -m site --user-base)/bin"

export PATH="/usr/local/bin:/usr/local/sbin:$PATH"
export PATH="$PATH:$GOBIN:$GOENV_ROOT/bin"
export PATH="$PATH:/usr/local/share/git-core/contrib/diff-highlight"
export PATH="$PATH:/Applications/Visual Studio Code.app/Contents/Resources/app/bin"
export PATH="/usr/local/opt/binutils/bin:$PATH"
export PATH="/usr/local/opt/findutils/libexec/gnubin:$PATH"
export PATH="$PATH:$HOME/bin"
export PATH="$PATH:$HOME/.local/bin"

test -e "${HOME}/.iterm2_shell_integration.zsh" && zsh-defer source "${HOME}/.iterm2_shell_integration.zsh"

test -e "${HOME}/.rsyncignore" && alias rsync="rsync --exclude-from ${HOME}/.rsyncignore"

if command -v direnv > /dev/null; then
  eval "$(direnv hook zsh)"
fi

export PATH="$HOME/.poetry/bin:$PATH"

# tenv
export TENV_AUTO_INSTALL=true

export FZF_DEFAULT_COMMAND='rg --hidden --no-ignore --files'

if [ -f ~/.zplug/repos/zsh-users/zsh-autosuggestions/zsh-autosuggestions.zsh ]; then
    zsh-defer source ~/.zplug/repos/zsh-users/zsh-autosuggestions/zsh-autosuggestions.zsh
fi

# The following lines have been added by Docker Desktop to enable Docker CLI completions.
fpath=(/Users/hioki/.docker/completions $fpath)
# End of Docker CLI completions

# The next line updates PATH for the Google Cloud SDK.
if [ -f "$HOME/google-cloud-sdk/path.zsh.inc" ]; then . "$HOME/google-cloud-sdk/path.zsh.inc"; fi

# The next line enables shell command completion for gcloud.
if [ -f "$HOME/google-cloud-sdk/completion.zsh.inc" ]; then . "$HOME/google-cloud-sdk/completion.zsh.inc"; fi

[ -f $HOME/.zshrc.`uname` ] && source $HOME/.zshrc.`uname`
[ -f $HOME/.tenv.completion.zsh ] && source $HOME/.tenv.completion.zsh
[ -f $HOME/.zshrc.local ] && source $HOME/.zshrc.local
