#!/usr/bin/env bash

# Bash script for managing Moonring save files

###
### Constants definition
###

declare -g MOONRING_SAVE_DIR LIFESAVER_ARCHIVE FORCE_FLAG
MOONRING_SAVE_DIR=${MOONRING_SAVE_DIR:-~/.local/share/Moonring/}
LIFESAVER_ARCHIVE=${LIFESAVER_ARCHIVE:-~/bin/moonring/save-files/}
FORCE_FLAG='false'

## TODO: lifesaver must validate these constant values

###
### Help function
###

function help(){
    cat << END_OF_USAGE

Lifesaver: manage your Moonring save files.

 Syntax: lifesaver [OPTIONS]... [FILE]...

 options:
 -h          Print this [h]elp and exit.
 -F          [F]orce defined actions without asking for confirmation
             (this will overwrite any file witouth asking!)
 -a ARCHIVE  Define [a]rchive to which save files are added to.
 -s SAVE_DIR Define the Moonring [s]ave directory to be used.
 -v          Print lifesaver's environmental [v]ariables values.
 -l          [l]ist all files in the archive directory and exit.
 -f FILE     Add current save [f]ile to the archive as FILE.tar.gz
 -u FILE     [u]pdate current Moonring savefile with FILE from the archive.

END_OF_USAGE
}

###
### Functions definitions
###

# $* = message to prompt the user
# Ask for confirmation using $message and returns 0 (true) or 1 (false)
# wheter the user answer with an 'y' or a 'n'.
function prompt-y-or-n() {
    local -r message=$*
    [[ $# -gt 0 ]] || {
        echo "lifesaver: Exit with error" >&2
        echo "promt-y-or-n(): no parameters given" >&2
        exit 1
    }

    read -rp "$message " prompt;
    while true; do
        case $prompt in
            y|Y)
                return 0
                ;;
            n|N)
                return 1
                ;;
            *)
                read -rp "You must answer with a 'y' or 'n': " prompt
        esac
    done;
}

# $1 = target_file to write
# $2 = src_dir to archive with tar
# Create a .tar.gz archive of src_dir located at target_file
# Return 0 if succeded or 1 if not. Note that the actual dir is not
# archived, only its contents.
function write-tar-file-from-dir() {
    local target_file=$1
    local src_dir=$2
    [[ $# -eq 2 ]] || {
        echo "lifesaver: Exit with error" >&2
        echo "write-tar-file-from-dir(): Need 2 parameters" >&2
        exit 1
    }

    local -r dir_to_tar=$(basename "$src_dir")
    if tar --create --gzip --file="$target_file" \
           --directory="$src_dir/../" "./$dir_to_tar" >/dev/null 2>&1; then
        echo "File writed at $target_file"
        return 0;
    else
        echo "Something went wrong when creating $target_file" >&2
        echo "File couldn't be written correctly or at all." >&2
        exit 1
    fi;
}

# $1 = target_file to write
# $2 = src_dir to tar
# Prompt the user for confirmation if target_file already exists.
# If user confirms, overwrite it; otherwise echo an "Aborted..."
# message and return 0. If target_file doesn't exists, just write it.
function write-tar-file-from-dir-safely() {
    local target_file=$1
    local src_dir=$2
    [[ $# -eq 2 ]] || {
        echo "lifesaver: Exit with error" >&2
        echo "write-tar-file-from-dir-safely(): Needs 2 parameters" >&2
        exit 1
    }

    if [[ -e $target_file ]]; then
        echo "File $target_file already exists!"
        if prompt-y-or-n "Do you want to overwrite it? [y/n] "; then
            write-tar-file-from-dir "$target_file" "$src_dir"
            return;
        else
            echo "Aborted by the user."
            return 0
        fi;
    else
        write-tar-file-from-dir "$target_file" "$src_dir"
        return
    fi;
}

# $1 = target_file to write to
# $2 = save_dir to tar
# Archive the current save file of Moonring game. Create a .tar.gz
# archive at $target_file, using $save_dir as source. $save_dir is
# usually $MOONRING_SAVE_DIR, located at "~/.local/share/Moonring/"
function archive-save-file() {
    local target_file=$1
    local save_dir=$2
    [[ $# -eq 2 ]] || {
        echo "lifesaver: Exit with error" >&2
        echo "archive-save-file(): Needs 2 parameters" >&2
        exit 1
    }

    if $FORCE_FLAG; then
       write-tar-file-from-dir "$target_file" "$MOONRING_SAVE_DIR";
    else
        echo "A new save file will be writen at:"
        echo "    $target_file"
        if prompt-y-or-n "Are you sure you want to proceed? [y/n] "; then
            write-tar-file-from-dir-safely "$target_file" "$save_dir"
            return;
        else
            echo "Aborted by the user."
            return 0;
        fi
    fi;
}


# $1 - path to savefile to update into current
# $2 - moonring save dir
update-moonring-savefile() {
    local -r savefile=$1
    local -r save_dir=$2/../ # Target dir where 'MOONRING_SAVE_DIR' is
                             # located to overwrite 'MOONRING_SAVE_DIR'
    [[ $# -ne 2 ]] && {
        echo "lifesaver: Exit with error" >&2
        echo "update-moonring-savefile(): 2 arguments must be given" >&2
        exit 1
    }

    if [[ -f $savefile ]]; then
        tar --extract --verbose --file="$savefile" \
            --directory="$save_dir" || {
            echo "lifesaver: File couldn't be extracted" >&2
            exit 1
        }
    else
        echo "lifesaver: Exit with error"
        echo "$savefile" "couldn't be found"
        exit 1
    fi
}

###
### Options parsing and program flow
###

## TODO: input file must be validated. If its a path that makes
## $target_file resolve to a path that doesn't exist, then
## lifesaver exits with error messages from the tar command.
##
## e.g. "lifesaver -f /path/that/dont/exists"

main() {
    while getopts :hlFvu:f:a:s: OPT; do
        case $OPT in
            h)
                help
                exit
                ;;
            F)
                FORCE_FLAG='true'
                ;;
            a)
                LIFESAVER_ARCHIVE=$OPTARG
                ;;
            s)
                MOONRING_SAVE_DIR=$OPTARG
                ;;
            v)
                echo "Current lifesaver environmental variables are:"
                echo "MOONRING_SAVE_DIR = $MOONRING_SAVE_DIR"
                echo "LIFESAVER_ARCHIVE = $LIFESAVER_ARCHIVE"
                exit
                ;;
            l)
                ls "$LIFESAVER_ARCHIVE"
                exit
                ;;
            f)
                local -r target_file=$LIFESAVER_ARCHIVE/$OPTARG
                archive-save-file "$target_file" "$MOONRING_SAVE_DIR"
                exit
                ;;
            u)
                local -r file_to_extract=$LIFESAVER_ARCHIVE/$OPTARG
                update-moonring-savefile "$file_to_extract" "$MOONRING_SAVE_DIR"
                exit
                ;;
            :)
                echo "lifesaver: option -$OPTARG requires an argument" >&2
                echo "Try 'lifesaver -h' for more information." >&2
                exit 1
                ;;
            ?)
                echo "lifesaver: unrecognized option '$1'" >&2
                echo "Try 'lifesaver -h' for more information." >&2
                exit 1
        esac
    done

    ## Handle edge cases
    if [[ $# -eq 0 ]] ; then  # No parameter given
        echo "lifesaver: no option given" >&2
        echo "Try 'lifesaver -h' for more information." >&2
        exit 1;
    else                      # No dash preceding the options
        echo "lifesaver: unrecognized option '$1'" >&2
        echo "Try 'lifesaver -h' for more information." >&2
        exit 1;
    fi
}

main "$@"
