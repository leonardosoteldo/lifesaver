#!/usr/bin/env bash

# Bash script for managing Moonring savefiles

### Constants definition
######################################################################

declare -g MOONRING_SAVE_DIR LIFESAVER_ARCHIVE_DIR FORCE_FLAG
MOONRING_SAVE_DIR=${MOONRING_SAVE_DIR:-$HOME/.local/share/Moonring/}
LIFESAVER_ARCHIVE_DIR=${LIFESAVER_ARCHIVE_DIR:-$HOME/bin/moonring/save-files/}
FORCE_FLAG='false'

### Help function
######################################################################

function help(){
    cat << END_OF_USAGE

Lifesaver: manage your Moonring savefiles.

 Syntax: lifesaver [OPTIONS]... [FILE]...

 options:
 -h          Print this [h]elp and exit.
 -F          [F]orce defined actions without asking for confirmation
             (this will overwrite any file without asking!)
 -a ARCHIVE  Define [a]rchive to which savefiles are added to.
 -s SAVE_DIR Define the Moonring [s]ave directory to be used.
 -v          Print lifesaver's environmental [v]ariables values.
 -l          [l]ist all files in the archive directory and exit.
 -f FILE     Add current save [f]ile to the archive as FILE.tar.gz
 -u FILE     [u]pdate current Moonring savefile with FILE from the archive.

END_OF_USAGE
}

### Common functions
######################################################################

# $1 = Number of exit status (must be a positive integer)
# ${*:2} = (rest of args) Message to stderr
#
# Exit with exit status error number '$1' and messaging to stderr:
#   $ error_exit 1 "wrong number of arguments"
#   > $caller_script: fatal error
#   > $caller_function: wrong number of arguments
#
# This functon exit with error (1) if an invalid shell exit status is
# used as its first argument ('$1'.) Exit statuses must be integers
# between 1 and 255 (both inclusive.)
function error_exit() {
    local -r exit_status=$1
    local -r err_message=${*:2}
    local -r caller_func=${FUNCNAME[1]}
    local -r caller_script=$(basename "$0")

    # Validate 'exit_status' argument (an integer between 1 to 255)
    local -r regex='^[0-9]+$' # Avoids potential backwards compatibility errors
    if [[ ! $exit_status =~ $regex || $exit_status -le 0 || $exit_status -gt 255 ]]; then
        echo "$caller_script: fatal error" >&2
        echo "error_exit(): argument '\$1' must be an integer between 1 and 255" >&2
        exit 1
    fi

    echo "$caller_script: fatal error"
    echo "$caller_func(): ${err_message:-exited with fatal error}"
    exit "$exit_status"
}

# $* = message to prompt the user Ask for confirmation using $message
# and returns 0 (true) or 1 (false) wheter the user answer with an 'y'
# or a 'n'.
function prompt_y_or_n() {
    local -r message=$*
    [[ $# -gt 0 ]] || error_exit 1 "no arguments given"

    read -rp "$message " prompt;
    while true; do
        case $prompt in
            y | Y ) return 0;;
            n | N ) return 1;;
                 *) read -rp "You must answer with a 'y' or 'n': " prompt
        esac
    done;
}

# Validate that 'LIFESAVER_ARCHIVE_DIR' are bound to an existent and
# valid directory, exiting with '1' if not.
function validate_archive_dir {
    local -r archive_dir_nonexistant="lifesaver archive directory cannot be found
Try using the '-a' option or binding the 'LIFESAVER_ARCHIVE_DIR' environment variable"
    local -r archive_dir_wrong_file="lifesaver archive directory is not a directory
Try using the '-a' option or binding the 'LIFESAVER_ARCHIVE_DIR' environment variable"

    if [[ ! -e $LIFESAVER_ARCHIVE_DIR ]]; then
        error_exit 1 "$archive_dir_nonexistant"
    elif [[ ! -d $LIFESAVER_ARCHIVE_DIR ]]; then
        error_exit 1 "$archive_dir_wrong_file"
    fi
}

# Validate that 'MOONRING_SAVE_DIR' are bound to an existent and
# valid directory, exiting with '1' if not.
function validate_save_dir {
    local -r save_dir_nonexistant="Moonring save directory cannot be found
Try using the '-s' option or binding the 'MOONRING_SAVE_DIR' environment variable"
    local -r save_dir_wrong_file="Specified Moonring save directory file is not a directory
Try using the '-s' option or binding the 'MOONRING_SAVE_DIR' environment variable"

    if [[ ! -e $MOONRING_SAVE_DIR ]]; then
        error_exit 1 "$save_dir_nonexistant"
    elif [[ ! -d $MOONRING_SAVE_DIR ]]; then
        error_exit 1 "$save_dir_wrong_file"
    fi
}

### -v option (print environmental variables of lifesaver)
######################################################################

function print_variables() {
    echo "Current lifesaver environmental variables are:"
    echo "MOONRING_SAVE_DIR = $MOONRING_SAVE_DIR"
    echo "LIFESAVER_ARCHIVE_DIR = $LIFESAVER_ARCHIVE_DIR"
}

### -l option (list content of 'LIFESAVER_ARCHIVE_DIR')
######################################################################

function list-archive() {
    validate_archive_dir
    echo "Current lifesaver archive is: $LIFESAVER_ARCHIVE_DIR"
    echo -e "Its contents are:\n"
    ls --color=never "$LIFESAVER_ARCHIVE_DIR"
}

### -f option (archive current 'MOONRING_SAVE_DIR')
######################################################################

# $1 = target_file to write
# $2 = src_dir to archive with tar
# Create a .tar.gz archive of src_dir located at target_file
# Return 0 if succeded or 1 if not.
function compress_dir() {
    local target_file=$1
    local src_dir=$2
    [[ $# -eq 2 ]] || error_exit 1 "need 2 arguments"

    local -r dir_to_tar=$(basename "$src_dir")
    if tar --create --gzip --file="$target_file" \
           --directory="$src_dir/../" "./$dir_to_tar" >/dev/null 2>&1; then
        echo "File written at $target_file"
    else
        error_exit 1 "Something went wrong when creating $target_file
${FUNCNAME[0]} 'tar' command exited with error"
    fi
}

# $1 = target_file to write
# $2 = src_dir to tar
# Prompt the user for confirmation if target_file already exists.
# If user confirms, overwrite it; otherwise echo an "Aborted..."
# message and return 0. If target_file doesn't exists, just write it.
function compress_dir_safely() {
    local target_file=$1
    local src_dir=$2
    [[ $# -eq 2 ]] || error_exit 1 "needs 2 arguments"

    if [[ -e $target_file ]]; then
        echo "File $target_file already exists!"
        if prompt_y_or_n "Do you want to overwrite it? [y/n] "; then
            compress_dir "$target_file" "$src_dir"
        else
            echo "Aborted by the user"
        fi
    else
        compress_dir "$target_file" "$src_dir"
    fi
}

# $1 = target_file to write to
# Archive the current savefile of Moonring game. Create a .tar.gz
# archive at $target_file, using $MOONRING_SAVE_DIR as source
function archive_savefile() {
    local -r filename=$1
    local -r target_file=${LIFESAVER_ARCHIVE_DIR:-./}/$filename
    local -r target_dir=$(dirname "$target_file") # 'filename' may be a path...
    [[ $# -eq 1 ]] || error_exit 1 "needs 1 argument"

    [[ -d $target_dir ]] || error_exit 1 "$target_file is not a valid directory
Try using the '-a' option or binding the 'MOONRING_SAVE_DIR' environment variable"
    validate_save_dir

    if $FORCE_FLAG; then
       compress_dir "$target_file" "$MOONRING_SAVE_DIR";
    else
        echo "A new savefile will be writen at:"
        echo "$target_file"
        if prompt_y_or_n "Are you sure you want to proceed? [y/n] "; then
            compress_dir_safely "$target_file" "$MOONRING_SAVE_DIR"
        else
            echo "Aborted by the user"
        fi
    fi
}

### -u option (update 'MOONRING_SAVE_DIR' with savefile from 'LIFESAVER_ARCHIVE_DIR')
######################################################################

# $1 = compressed_dir to be extracted
# $2 = target_dir into which extract the compressed dir
# Extract a tar (gzip) compressed directory 'compressed_dir' into
# 'target_dir', without asking for confirmation when overwriting
function extract_dir() {
    local -r compressed_dir=$1
    local -r target_dir=$2
    local -r filename=$(basename "$compressed_dir")
    [[ $# -ne 2 ]] && error_exit 1 "2 arguments must be given"

    tar --extract --file="$compressed_dir" --directory="$target_dir" >/dev/null 2>&1 \
        || error_exit 1 "tar couldn't extract $compressed_dir"
    echo "File $filename was extracted at: $target_dir"
}

# TODO: Add a backup hook for '-u' option

# $1 - savefile to be updated as current
#
# Update current Moonring save-dir with the extraction of some
# archived savefile
function update_save_dir() {
    local -r filename=$1
    local -r compressed_dir=$LIFESAVER_ARCHIVE_DIR/$filename
    local -r save_dir=$(dirname "$MOONRING_SAVE_DIR")
    [[ $# -ne 1 ]] && error_exit 1 "1 argument must be given"

    if [[ ! -f $compressed_dir ]]; then
        error_exit 1 "$compressed_dir couldn't be found
Try using the '-a' option or binding the 'MOONRING_SAVE_DIR' environment variable"
    elif [[ ! $(file "$compressed_dir") =~ 'gzip' ]]; then # Is not a valid .tar.gz
        error_exit 1 "$filename is not a valid archive savefile
Archive savefiles must be .tar.gz files"
    fi
    validate_save_dir

    if $FORCE_FLAG; then
        extract_dir "$compressed_dir" "$save_dir"
    else
        echo "$filename will be extracted at: $save_dir"
        echo "Possibly overwriting some files and directories"
        if prompt_y_or_n "Are you sure you want to proceed? [y/n] "; then
            extract_dir "$compressed_dir" "$save_dir"
        else
            echo "Aborted by the user"
        fi
    fi
}

### Options parsing and program flow
######################################################################

# TODO: add a '-b' (backup) option for the 'MOONRING_SAVE_DIR'
# TODO: add validation for writing permission for target files

function parse_options() {
    while getopts :hlFvu:f:a:s: OPT; do
        case $OPT in
            h) help; exit ;;
            F) FORCE_FLAG='true' ;;
            a) LIFESAVER_ARCHIVE_DIR=$OPTARG ;;
            s) MOONRING_SAVE_DIR=$OPTARG ;;
            v) print_variables; exit ;;
            l) list-archive; exit ;;
            f) archive_savefile "$OPTARG"; exit ;;
            u) update_save_dir "$OPTARG"; exit ;;
            :) error_exit 1 "option -$OPTARG requires an argument" ;;
            *) error_exit 1 "unrecognized option '$1'" ;;
        esac
    done

    ## Handle edge cases
    if [[ $# -eq 0 ]]; then
        error_exit 1 "no option given"
    else
        error_exit 1 "unrecognized option '$1'"
    fi
}

parse_options "$@"
