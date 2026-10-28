# ==========================================================================
#  ~/.zshrc  —  Void Linux "void-dark" zsh setup
#  palette: void green (#478061) on a dark background
# ==========================================================================

# ------------------------------------------------------------------ history -
HISTFILE=$HOME/.zsh_history
HISTSIZE=100000
SAVEHIST=100000
setopt EXTENDED_HISTORY
setopt INC_APPEND_HISTORY
setopt SHARE_HISTORY
setopt HIST_IGNORE_ALL_DUPS
setopt HIST_IGNORE_SPACE
setopt HIST_REDUCE_BLANKS
setopt HIST_VERIFY

# --------------------------------------------------------------- behaviour -
setopt AUTO_CD
setopt AUTO_PUSHD
setopt PUSHD_IGNORE_DUPS
setopt INTERACTIVE_COMMENTS
setopt NO_BEEP
setopt PROMPT_SUBST
setopt NUMERIC_GLOB_SORT

# ------------------------------------------------------------- path / bins -
# user binaries: opencode, ~/.local/bin, ~/.cargo/bin, and flatpak app CLI exports
export PATH="$HOME/.opencode/bin:$HOME/.local/bin:$HOME/.cargo/bin:$HOME/.local/share/flatpak/exports/bin:/var/lib/flatpak/exports/bin:$PATH"

# --------------------------------------------------------------- keys/edit -
bindkey -e
WORDCHARS='*?_-.[]~=/&;!#$%^(){}<>'

# ----------------------------------------------------------------- aliases -
if command -v eza >/dev/null 2>&1; then
  alias ls='eza -lh --group-directories-first --icons=auto'
  alias ll='eza -lah --group-directories-first --icons=auto'
  alias la='ls -a'
  alias lt='eza --tree --level=2 --long --icons --git'
  alias lta='eza --tree --level=2 --long --icons --git -lah'
fi
# bat: theme lives in .config/bat/themes and mirrors ~/.colors
if command -v bat >/dev/null 2>&1; then
  export BAT_THEME=void-dark
  alias cat='bat --style=plain --paging=never'
  alias catn='bat --style=numbers,changes --paging=never'
  alias catp='bat --style=full --paging=always'
fi
alias grep='grep --color=auto'
alias ip='ip --color=auto'
alias cp='cp -iv'
alias mv='mv -iv'
alias rm='rm -Iv'
alias mkdir='mkdir -pv'
alias ..='cd ..'
alias ...='cd ../..'
alias g='git'
alias gs='git status -sb'
alias gl='git log --oneline --graph --decorate -20'
# update everything: xbps, flatpak (user + system), opencode
update() {
  emulate -L zsh
  local rc=0

  print -P "%F{#478061}::%f xbps"
  sudo xbps-install -Suy || rc=1

  if command -v flatpak >/dev/null 2>&1; then
    print -P "%F{#478061}::%f flatpak"
    flatpak update -y --noninteractive || rc=1
    if [[ -d /var/lib/flatpak ]]; then
      sudo flatpak update -y --noninteractive || rc=1
    fi
  fi

  if command -v opencode >/dev/null 2>&1; then
    print -P "%F{#478061}::%f opencode"
    opencode upgrade || rc=1
  fi

  if (( rc )); then
    print -P "%F{#c46a6a}::%f finished with errors"
  else
    print -P "%F{#478061}::%f all up to date"
  fi
  return rc
}
alias cls='clear'

export EDITOR=nvim
export MANPAGER='nvim +Man!'

# ------------------------------------------------------------ ls colors ---
export LS_COLORS="di=1;38;5;71:ln=1;38;5;109:so=38;5;176:pi=38;5;176:ex=1;38;5;71:bd=38;5;173:cd=38;5;173:su=38;5;167:sg=38;5;167:tw=1;38;5;71:ow=1;38;5;71:*.tar=38;5;173:*.tgz=38;5;173:*.gz=38;5;173:*.xz=38;5;173:*.zst=38;5;173:*.zip=38;5;173:*.7z=38;5;173:*.png=38;5;176:*.jpg=38;5;176:*.jpeg=38;5;176:*.gif=38;5;176:*.svg=38;5;176:*.mp3=38;5;176:*.flac=38;5;176:*.wav=38;5;176:*.mp4=38;5;176:*.mkv=38;5;176:*.pdf=38;5;167:*.md=38;5;109"

# ------------------------------------------------------------ eza colors ---
# truecolor (38;2;R;G;B) built from the void-dark palette
__vd_rgb() { print -rn -- "38;2;$((16#${1:0:2}));$((16#${1:2:2}));$((16#${1:4:2}))"; }
export EZA_COLORS="\
di=1;$(__vd_rgb 478061):\
fi=$(__vd_rgb c9d1cf):\
ex=1;$(__vd_rgb 6fae86):\
pi=$(__vd_rgb d8b26b):\
so=$(__vd_rgb b184c9):\
bd=$(__vd_rgb e6c88a):\
cd=$(__vd_rgb e6c88a):\
ln=$(__vd_rgb 68b0a8):\
or=1;$(__vd_rgb c46a6a):\
mp=$(__vd_rgb 68b0a8):\
sp=$(__vd_rgb d8b26b):\
oc=$(__vd_rgb 5b626b):\
ur=$(__vd_rgb 478061):\
uw=$(__vd_rgb 719d85):\
ux=$(__vd_rgb 9cbaaa):\
ue=$(__vd_rgb 9cbaaa):\
gr=$(__vd_rgb c6d7ce):\
gw=$(__vd_rgb f0f4f2):\
gx=$(__vd_rgb cbd0d0):\
tr=$(__vd_rgb a6abaf):\
tw=$(__vd_rgb 80878d):\
tx=$(__vd_rgb 5b626b):\
su=1;$(__vd_rgb b184c9):\
sf=1;$(__vd_rgb b184c9):\
xa=$(__vd_rgb 5b626b):\
sn=$(__vd_rgb 6fae86):\
sb=$(__vd_rgb 5b626b):\
uu=1;$(__vd_rgb 478061):\
uR=1;$(__vd_rgb c46a6a):\
un=$(__vd_rgb 8b949e):\
gu=$(__vd_rgb 6fae86):\
gR=1;$(__vd_rgb c46a6a):\
gn=$(__vd_rgb d8b26b):\
lc=$(__vd_rgb 5b626b):\
lm=$(__vd_rgb 5b626b):\
df=$(__vd_rgb 5b626b):\
ds=$(__vd_rgb 5b626b):\
in=$(__vd_rgb 5b626b):\
bl=$(__vd_rgb 5b626b):\
hd=1;$(__vd_rgb 6fae86):\
lp=$(__vd_rgb 5b626b):\
cc=$(__vd_rgb b184c9):\
xx=$(__vd_rgb 5b626b):\
da=$(__vd_rgb 8b949e):\
ga=$(__vd_rgb 6fae86):\
gm=$(__vd_rgb d8b26b):\
gd=$(__vd_rgb c46a6a):\
gv=$(__vd_rgb 68b0a8):\
gt=$(__vd_rgb b184c9):\
gi=$(__vd_rgb 5b626b):\
gc=1;$(__vd_rgb c46a6a):\
Gm=1;$(__vd_rgb 6fae86):\
Go=$(__vd_rgb 6f9fd1):\
Gc=$(__vd_rgb 6fae86):\
Gd=$(__vd_rgb d8b26b):\
im=$(__vd_rgb b184c9):\
vi=$(__vd_rgb c79ed6):\
mu=$(__vd_rgb 68b0a8):\
lo=$(__vd_rgb 84c6bf):\
cr=$(__vd_rgb d8b26b):\
do=$(__vd_rgb 6f9fd1):\
co=$(__vd_rgb d8b26b):\
tm=$(__vd_rgb 5b626b):\
cm=$(__vd_rgb 8b949e):\
bu=$(__vd_rgb 6fae86):\
sc=$(__vd_rgb 6fae86):\
*.tar=$(__vd_rgb d8b26b):*.tgz=$(__vd_rgb d8b26b):*.gz=$(__vd_rgb d8b26b):*.xz=$(__vd_rgb d8b26b):*.zst=$(__vd_rgb d8b26b):*.zip=$(__vd_rgb d8b26b):*.7z=$(__vd_rgb d8b26b):\
*.png=$(__vd_rgb b184c9):*.jpg=$(__vd_rgb b184c9):*.jpeg=$(__vd_rgb b184c9):*.gif=$(__vd_rgb b184c9):*.svg=$(__vd_rgb b184c9):\
*.mp3=$(__vd_rgb 68b0a8):*.flac=$(__vd_rgb 68b0a8):*.wav=$(__vd_rgb 68b0a8):\
*.mp4=$(__vd_rgb c79ed6):*.mkv=$(__vd_rgb c79ed6):\
*.pdf=$(__vd_rgb 6f9fd1):*.md=$(__vd_rgb 6fae86)"
unset -f __vd_rgb

# ------------------------------------------------------- completion styling -
autoload -Uz compinit
compinit -u

zstyle ':completion:*' menu select
zstyle ':completion:*' matcher-list 'm:{a-zA-Z}={A-Za-z}'
zstyle ':completion:*' list-colors "${(s.:.)LS_COLORS}"
zstyle ':completion:*:descriptions' format '%F{#6fae86}-- %d --%f'
zstyle ':completion:*:warnings' format '%F{#c46a6a}-- no matches --%f'
zstyle ':completion:*' group-name ''

# ------------------------------------------------------------------ zoxide -
if command -v zoxide >/dev/null 2>&1; then
  eval "$(zoxide init zsh)"
  alias cd='z'
fi

# --------------------------------------------------------------------- fzf -
# must come after compinit; gives ^R fzf history search, ^T file picker
# and **<tab> fuzzy completion
if command -v fzf >/dev/null 2>&1; then
  source /usr/share/fzf/key-bindings.zsh
  source /usr/share/fzf/completion.zsh
  export FZF_DEFAULT_OPTS="--color=bg+:#252b30,bg:#1b1f23,fg:#c9d1cf,hl:#6fae86,hl+:#478061,info:#8b949e,prompt:#478061,pointer:#6fae86,marker:#b184c9,spinner:#68b0a8,header:#8b949e,border:#505a63"
  if command -v fd >/dev/null 2>&1; then
    export FZF_DEFAULT_COMMAND='fd --type f --hidden --follow --exclude .git'
  fi
fi

# ---------------------------------------------------------- autosuggestions -
ZSH_AUTOSUGGEST_HIGHLIGHT_STYLE='fg=#565f6a'
ZSH_AUTOSUGGEST_STRATEGY=(history completion)
ZSH_AUTOSUGGEST_BUFFER_MAX_SIZE=30
if [[ -r /usr/share/zsh/plugins/zsh-autosuggestions/zsh-autosuggestions.zsh ]]; then
  source /usr/share/zsh/plugins/zsh-autosuggestions/zsh-autosuggestions.zsh
fi

# ---------------------------------------------------- syntax highlighting -
# Must be sourced last so it can wrap the line editor.
if [[ -r /usr/share/zsh/plugins/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh ]]; then
  source /usr/share/zsh/plugins/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh
fi

# ==========================================================================
#  void-dark palette
# ==========================================================================
# main accent: the actual Void Linux green (darker than before)
typeset -g VD_GREEN='%F{#478061}'
# grayscale for everything else
typeset -g VD_FG='%F{#c8ccd0}'         # light gray  (paths / values)
typeset -g VD_GRAY='%F{#8b949e}'       # mid gray    (labels)
typeset -g VD_DIM='%F{#5b626b}'        # dim gray    (punct / separators)
typeset -g VD_RST='%f'

# --------------------------------------------------- duration + git prompt -
zmodload zsh/datetime
autoload -Uz add-zsh-hook

__vd_preexec() { __vd_start=$EPOCHREALTIME }

__vd_precmd() {
  # --- last command duration (ms) ---------------------------------------
  local dur=''
  if [[ -n $__vd_start ]]; then
    local -F ms
    (( ms = (EPOCHREALTIME - __vd_start) * 1000 ))
    dur="${ms%.*}ms"
    unset __vd_start
  fi

  # --- git branch@commit ------------------------------------------------
  local branch sha gp='' gc=''
  if git rev-parse --is-inside-work-tree &>/dev/null; then
    branch=$(git symbolic-ref --quiet --short HEAD 2>/dev/null)
    sha=$(git rev-parse --short HEAD 2>/dev/null)
    if [[ -n $branch && -n $sha ]]; then
      gp="${branch}@${sha}"
      gc="${VD_GREEN}${branch}${VD_DIM}@${VD_GRAY}${sha}${VD_RST}"
    elif [[ -n $sha ]]; then
      gp="${sha}"
      gc="${VD_GRAY}${sha}${VD_RST}"
    fi
  fi

  # --- build left + right, right-align the right segment to the terminal --
  local disp=$(print -P '%~')
  local plain_left="${USER}:(${disp})"

  local plain_right="| time: ${dur:-0ms}"
  [[ -n $gp ]] && plain_right+=" git: ${gp}"

  local cols=${COLUMNS:-80}
  local pad=$(( cols - 1 - ${#plain_left} - ${#plain_right} ))
  (( pad < 1 )) && pad=1
  printf -v __vd_pad '%*s' "$pad" ''

  local right="${VD_DIM}|${VD_RST} ${VD_GRAY}time:${VD_RST} ${VD_GREEN}${dur:-0ms}${VD_RST}"
  [[ -n $gc ]] && right+=" ${VD_GRAY}git:${VD_RST} ${gc}"

  PROMPT="${VD_GREEN}${USER}${VD_RST}${VD_DIM}:(${VD_FG}${disp}${VD_DIM})${VD_RST}${__vd_pad}${right}"$'\n'$'%F{#478061}%(!.#.$) %f'
  RPROMPT=''
}

add-zsh-hook preexec __vd_preexec
add-zsh-hook precmd  __vd_precmd

# ---------------------------------------------------------------- greeting -
# (uncomment for a little void art on new shells)
# print -P "%F{#478061}   __     __     __  %f"
# print -P "%F{#6fae86}  |  |   /  \\  /  | %f  ~ keep it simple ~"

if command -v pfetch >/dev/null 2>&1; then
  pfetch
fi
