unsetopt allexport autoresume bashautolist bsdecho correctall cshjunkiehistory cshjunkiequotes cshnullcmd cshnullglob dvorak kshautoload listbeep promptbang  pushdsilent pushdtohome recexact
setopt aliases alwayslastprompt autolist autoparamkeys autoparamslash autoremoveslash badpattern banghist bareglobqual bgnice caseglob casematch equals functionargzero globalrcs hashlistall listambiguous listtypes promptcr promptpercent promptsp rcs transientrprompt autocd beep completeinword correct rmstarwait braceccl autopushd pushdminus pushdignoredups nomatch noglobdots extendedglob noclobber histallowclobber multios checkjobs nohup autocontinue longlistjobs notify sharehistory appendhistory extendedhistory histnostore histignorealldups histignorespace globcomplete automenu menucomplete completealiases alwaystoend listpacked listrowsfirst autonamedirs cbases cdablevars chasedots chaselinks flowcontrol promptsubst

# autoload -U promptinit
# promptinit
# prompt grb

HISTFILE=~/.zsh_history
SAVEHIST=100000
HISTSIZE=120000
eval `dircolors $HOME/.dircolors 2> /dev/null` || eval `dircolors`
zmodload -i zsh/complist
autoload -Uz compinit && compinit
export EDITOR=vim
export PAGER=less
autoload -U colors && colors
autoload -U zmv
autoload -U keeper && keeper
bindkey '^Xk' insert-kept-result
bindkey '^Xe' expand-word
bindkey -M menuselect 'i' accept-and-menu-complete
autoload -U tetris
zle -N tetris
bindkey "^Xt" tetris
autoload -U history-search-end
zle -N history-beginning-search-backward-end history-search-end
zle -N history-beginning-search-forward-end history-search-end
bindkey "\e[A"  history-beginning-search-backward-end
bindkey "\e[B"  history-beginning-search-forward-end

PROMPT="%11(D.%24(d.%{$fg[green]%}Merry X-Mas! .).)%(?..%{$fg[magenta]%}%? )%(!.%{$fg[red]%}.%{$fg_no_bold[blue]%})%n@%M%1(j. %{$fg_no_bold[yellow]%}%j.)%{$fg_no_bold[cyan]%} %4~%{$reset_color%} %# "
PS2='\%_> ' # printed when zsh needs more information to complete a command
PS3='?# '   # selection prompt used within a select loop
PS4='+%N:%i:%_> ' # the execution trace prompt (setopt xtrace). default: '+%N:%i>'

(( EUID != 0 )) && umask 0077 || umask 0002

bindkey -e

_bkdate() { BUFFER="$BUFFER$(date '+%F')"; CURSOR=$#BUFFER; }
zle -N _bkdate
bindkey '^Ed' _bkdate

alias grep="grep -i --color=auto"
alias ...='../..'
alias ....='../../..'
alias ls='ls -F --color=auto'
alias aus="su -c 'shutdown -h now'"
alias lsbig='ls -Slh | head'
alias lssmall='ls -Slhr | head'
alias lsnew='ls -tlh | head'
alias lsold='ls -tlh | tail'
alias la='ls -A'
alias ll='ls -l'
alias lla='ls -lA'
alias llh='ls -lh'
alias l='ls -lhA'
alias dfh='df -H'
alias wget='wget -U="Mozilla/5.0 (X11; Linux x86_64; rv:34.0) Gecko/20100101 Firefox/34.0"'
alias 7zultra='7z a -t7z -mx=9 -mfb=64 -md=32m -ms=on'
alias -s txt=vim
alias -s de=$BROWSER
alias -s com=$BROWSER
alias -s org=$BROWSER
alias -s odt=lowriter
alias -s doc=lowriter
alias -s docx=lowriter
alias -g G='|& grep -i --colour=auto'
alias -g P='| $PAGER'
alias -g T='| tail'
alias -g H='| head'
alias d='dirs -v'
alias j='jobs -l'
alias dropbox_reset="echo fs.inotify.max_user_watches=100000 | sudo tee -a /etc/sysctl.conf; sudo sysctl -p"
alias Kleentex="mv (*.toc|*.aux|*.log|*.out|*_lavim.tex) /tmp"
alias Nohidden="dconf reset /org/gtk/settings/file-chooser/show-hidden"

global-alias-space(){
	local ga="$LBUFFER[(w)-1]"
	[[ -n $ga ]] && LBUFFER[(w)-1]="${${galiases[$ga]}:-$ga}"
	zle self-insert
}
zle -N global-alias-space
bindkey ' ' global-alias-space

chpwd() {
	[[ $TERM == (xterm*|*rxvt*) ]] && print -Pn "\e]0;$TERM (%j): %~\a"
}

preexec() {
	[[ $TERM == (xterm*|*rxvt*) ]] && print -Pn "\e]0;$TERM (%j): $2\a"
}

sex simple-extract () {
if [[ -f $1 ]]
then
	case $1 in
	*.7z)		7z x $1			;;
	*.7z.001)	7z x $1			;;
	*.lzma)		unlzma $1		;;
	*.tar.bz2)	tar -xvjf $1		;;
	*.tar.gz)	tar -xvzf $1		;;
	*.rar)		unrar x $1		;;
	*.deb)		ar -x $1		;;
	*.bz2)		bzip2 -d $1		;;
	*.lzh)		lha x $1		;;
	*.gz)		gunzip -d --verbose $1  ;;
	*.tar)		tar -xvf $1		;;
	*.tgz)		tar -xvzf $1		;;
	*.tbz2)		tar -xvjf $1		;;
	*.txz)		tar -xvJf $1		;;
	*.tar.xz)	tar -xvJf $1		;;
	*.xz)		7z x $1			;;
	*.zip)		unzip $1		;;
	*.Z)		uncompress $1		;;
	*)		echo "'$1' Error. This is no compression type \
			      known to simple-extract." ;;
	esac
else
	echo "'$1' is not a valid file"
fi
}

# braucht mencoder und mplayer
avijoin () {
	# TODO checken ob mencoder da ist!
	cat $* > movie_tmp.avi; # TODO Frage nach finalem Namen
	mencoder -forceidx -oac copy -ovc copy movie_tmp.avi -o ./movie_final.avi
}

for c in shred rm wipe rmdir; do
	eval "alias $c=' $c'"
done

zstyle ':completion:*' format 'Completing %d'
zstyle ':completion:*' verbose yes
zstyle ':completion:*' group-name ''
zstyle ':completion:*:kill:*' command \
	'ps xf -u $USER -o pid,%cpu,cmd'
zstyle ':completion:*:*:kill:*:processes' \
	list-colors '=(#b) #([0-9]#)*=0=01;31'
zstyle ':completion:*:descriptions' format '%S%d%s'
zstyle ':completion:*:corrections' format $'%S%d (errors: %e)%s'
zstyle ':completion:*:messages' format '%S%d%s'
zstyle ':completion:*:warnings' format '%S%d%s'
#zstyle ':completion:(^rm):(all-|)files' ignored-patterns "(*.o|*.aux|*.toc|*.swp|*~)"
#zstyle ':completion:rm:(all-|)files' ignored-patterns '' # verhindert, daß die oben zu ignorierenden Dateien auch bei rm ignoriert werden
zstyle ':completion:*' menu select=2
zstyle ':completion:*:default' select-prompt '%S Treffer %M	%P%s'
zstyle ':completion:*:default' list-colors ${(s.:.)LS_COLORS}
zstyle ':completion:*' completer _complete _match _ignored _correct _approximate _prefix _history
zstyle ':completion:*:approximate:*' max-errors 'reply=( $(( ($#PREFIX+$#SUFFIX)/3 )) numeric )'
zstyle ':completion::complete:*' rehash true
zstyle ':completion::*:ssh:*:*' tag-order 'users hosts'
zstyle ':completion::*:-command-:*:*' tag-order '! aliases functions'
zstyle ':completion:*:*:rm:*' file-patterns \
	'*.o:object-files:object\ files
*(~|.(old|bak|BAK)):backup-files:backup\ files
*~*(~|.(o|old|bak|BAK)):all-files:all\ files'
zstyle ':completion:*' matcher-list 'm:{a-zA-Z}={A-Za-z}'
zstyle ':completion:*:rm:*' ignore-line yes

# manpage colors
# export LESS_TERMCAP_mb=$'\E[00;34m'     # begin blinking
export LESS_TERMCAP_mb=$'\E[00;36m'     # begin blinking
# export LESS_TERMCAP_md=$'\E[00;36m'     # begin bold
export LESS_TERMCAP_md=$'\E[00;34m'     # begin bold
export LESS_TERMCAP_me=$'\E[0m'         # end mode
export LESS_TERMCAP_se=$'\E[0m'         # end standout-mode
# export LESS_TERMCAP_so=$'\E[00;100;97m' # begin standout-mode - info box
export LESS_TERMCAP_so=$'\E[00;102;37m' # begin standout-mode - info box
export LESS_TERMCAP_ue=$'\E[0m'         # end underline
# export LESS_TERMCAP_us=$'\E[00;31m'     # begin underline
export LESS_TERMCAP_us=$'\E[00;35m'     # begin underline
export GROFF_NO_SGR=1

# Erstellt aus .flac-Dateien .m4a-Dateien:
transcode.m4a() {
while [[ $# -gt 0 ]]; do
    if [[ -f $1 ]]
    then
        flac --decode --stdout $1 | faac -q 192 -o $1.m4a -;
        shift;
    else
        # TODO error handling
        exit
    fi
done
}

Hitparade() {
    fc -ln 1|awk '{print $1}' |sort|uniq -c | sort -rn |head -n 10
}

if [[ -x /usr/lib/command-not-found || -x /usr/share/command-not-found/command-not-found ]]; then
    function command_not_found_handler {
    if [[ -x /usr/lib/command-not-found ]]; then
        /usr/bin/python /usr/lib/command-not-found -- "$1"
        return $?
    elif [[ -x /usr/share/command-not-found/command-not-found ]]; then
        /usr/bin/python /usr/share/command-not-found/command-not-found -- "$1"
        return $?
    else
        printf "%s: command not found\n" "$1" >&2
        return 127
    fi
}
fi

# autoload -Uz bashcompinit && bashcompinit

# if [[ -x "/usr/bin/dnf" ]]; then
	# source $HOME/.HOME/dnf-completion.bash
# fi
#
# # source /etc/bash_completion.d/cowsay.bashcomp
# # source /etc/bash_completion.d/cabal
#
# # Add environment variable COCOS_CONSOLE_ROOT for cocos2d-x
# export COCOS_CONSOLE_ROOT=/home/xha/Software/cocos2d-x/tools/cocos2d-console/bin
# export PATH=$COCOS_CONSOLE_ROOT:$PATH
#
# # Add environment variable COCOS_TEMPLATES_ROOT for cocos2d-x
# export COCOS_TEMPLATES_ROOT=/home/xha/Software/cocos2d-x/templates
# export PATH=$COCOS_TEMPLATES_ROOT:$PATH
#
# # Add environment variable NDK_ROOT for cocos2d-x
# export NDK_ROOT=/home/xha/Software/Android/android-ndk-r10e/
# export PATH=$NDK_ROOT:$PATH
#
# # Add environment variable ANDROID_SDK_ROOT for cocos2d-x
# export ANDROID_SDK_ROOT=/home/xha/Software/Android/android-sdk-linux/
# export PATH=$ANDROID_SDK_ROOT:$PATH
# export PATH=$ANDROID_SDK_ROOT/tools:$ANDROID_SDK_ROOT/platform-tools:$PATH
#
# # Add environment variable ANT_ROOT for cocos2d-x
# export ANT_ROOT=/usr/bin
# export PATH=$ANT_ROOT:$PATH
#
