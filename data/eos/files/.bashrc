#
# ~/.bashrc
#
# EndeavourOS default bashrc (2024)
#
## October 2021: removed many obsolete functions.
## January 2024: separate target bashrc from livesession

# If not running interactively, don't do anything
[[ $- != *i* ]] && return

alias ls='ls --color=auto'
alias ll='ls -lav --ignore=..'                # show long listing of all except ".."
alias l='ls -lav --ignore=.?*'                # show long listing but no hidden dotfiles except "."

# prompt
PS1='[\[\e[1m\]\u\[\e[0m\]@\h:\[\e[1m\]\w\[\e[0m\]]\$ '

[ "$(whoami)" = "root" ] && return            # root stops here

# $FUNCNEST defines the maximum allowed function nesting level; see 'man bash'
[ "$FUNCNEST" ] || export FUNCNEST=100

## Use the up and down arrow keys for finding a command in history
## (you can write some initial letters of the command first).
bind '"\e[A":history-search-backward'
bind '"\e[B":history-search-forward'

################################################################################
## Some generally useful functions.
## Consider uncommenting aliases below to start using these functions.
################################################################################

_open_files_for_editing() {
    # Open any given document file(s) for editing (or just viewing). Mime bindings are used.
    # Note: you may need (e.g. a file manager) to set the desired mime bindings.

    local prog file

    for prog in /bin/exo-open /bin/kde-open /bin/xdg-open
    do
        if [ -x $prog ] ; then
            case "$prog" in
                */exo-open)
                    echo "$prog $@" >&2
                    setsid $prog "$@" >& /dev/null
                    ;;
                *)
                    for file in "$@" ; do
                        echo "$prog '$file'" >&2
                        setsid $prog "$file" >& /dev/null
                    done
                    ;;
            esac
            return
        fi
    done

    echo "${FUNCNAME[0]}: sorry, none of package alternatives (exo, kde-cli-tools, xdg-utils) is installed." >&2
}

################################################################################
## Aliases for the functions above.
## Uncomment an alias if you want to use it.
################################################################################

# alias ef='_open_files_for_editing'     # 'ef' opens given file(s) for editing
# alias pacdiff=eos-pacdiff              # 'pacdiff' helps maintaining pacnew, pacsave and pacorig files

