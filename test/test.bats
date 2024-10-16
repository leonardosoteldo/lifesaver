#!/usr/bin/env bash

# Load bats and its helper libraries. For a reason, putting this
# statements in `setup_file()' didn't load the libs properly.
load "$BATS_TEST_DIRNAME/.bats/test_helper/bats-assert/load.bash"
load "$BATS_TEST_DIRNAME/.bats/test_helper/bats-support/load.bash"
load "$BATS_TEST_DIRNAME/.bats/test_helper/bats-file/load.bash"

setup_file() {
    declare -g PATH BATS_TMPDIR BATS_FILE_TMPDIR
    # Add the project's root dir into $PATH as first
    PATH=$BATS_TEST_DIRNAME/../:$PATH
    # Assign a base directory for creating temp dirs or files
    # shellcheck disable=2034
    BATS_TMPDIR=$BATS_TEST_DIRNAME/tmp
    # Create a temporary directory and assign its path to a variable
    BATS_FILE_TMPDIR="$(temp_make)"
}

teardown_file() {
    # Delete the tmpdir created in `setup_file'
    [ -d "$BATS_FILE_TMPDIR" ] && temp_del "$BATS_FILE_TMPDIR"
    return 0 # Somehow bats is running this repeatedly as a test and
             # fails if this line is omitted as 'temp_del' returns '1'
}

setup() {
    # Declare testing directories variables
    declare -g T_SAVE_DIR T_ARCHIVE_DIR T_ARCHIVE_DIR2
    export T_SAVE_DIR=$BATS_FILE_TMPDIR/Moonring
    export T_ARCHIVE_DIR=$BATS_FILE_TMPDIR/archive
    export T_ARCHIVE_DIR2=$BATS_FILE_TMPDIR/archive2

    # Create files moonring/file{1..3} and moonring/save/file{1..3}
    # at $BATS_FILE_TMPDIR
    mkdir -p "$T_SAVE_DIR/save/"
    touch "$T_SAVE_DIR/file"{1..3} "$T_SAVE_DIR/save/file"{1..3}

    # Create files archive/already_exists.tar.gz and archive/already_exists
    # at $BATS_FILE_TMPDIR
    mkdir "$T_ARCHIVE_DIR"
    touch "$T_ARCHIVE_DIR/already_exists"
    tar -czf "$T_ARCHIVE_DIR/already_exists.tar.gz" \
        "$T_ARCHIVE_DIR/already_exists" >/dev/null 2>&1
    mkdir -p "${T_ARCHIVE_DIR}2/Moonring/savefiles"
    touch "${T_ARCHIVE_DIR}2/Moonring/file"{1..4} \
          "${T_ARCHIVE_DIR}2/Moonring/savefiles/file"{1..4}

    # Declare lifesaver environment variables
    export MOONRING_SAVE_DIR=$T_SAVE_DIR
    export LIFESAVER_ARCHIVE_DIR=$T_ARCHIVE_DIR

    # CRITICAL FAIL if lifesaver ignores the environment variable;
    # otherwise user's files may be compromised by testing processes.
    local env_vars save_var archive_var
    env_vars=$(lifesaver.sh -v)
    # Get values of 'MOONRING_SAVE_DIR' and 'LIFESAVER_ARCHIVE_DIR'
    save_var=$(awk '/MOONRING/ {print $3}' <<< "$env_vars")
    archive_var=$(awk '/ARCHIVE/ {print $3}' <<< "$env_vars")
    if [ "$save_var" != "$T_SAVE_DIR" ] || [ "$archive_var" != "$T_ARCHIVE_DIR" ]; then
        echo "Error: lifesaver is not properly recognizing setup environment variables" >&2
        echo "Testing was aborted to avoid compromising user files" >&2
        return 1
    fi
}

teardown() {
    # Delete the tmpdir contents only
    rm -r "${BATS_FILE_TMPDIR/*:?'BATS_FILE_TMPDIR is unset or null!'}"
    unset MOONRING_SAVE_DIR SAVER_ARCHIVE
}

@test "test bats setup()" {
    # check for created dirs
    assert_dir_exists "$BATS_FILE_TMPDIR"
    assert_dir_exists "$T_SAVE_DIR/save/"
    assert_dir_exists "$T_ARCHIVE_DIR"
    assert_dir_exists "${T_ARCHIVE_DIR}2"
    # check created files
    assert_file_exists "$T_SAVE_DIR/file2"
    assert_file_exists "$T_SAVE_DIR/save/file2"
    assert_file_exists "$T_ARCHIVE_DIR/already_exists.tar.gz"
    # Test the testing setup of environment variables of lifesaver
    assert [ "$MOONRING_SAVE_DIR" == "$T_SAVE_DIR" ]
    assert [ "$LIFESAVER_ARCHIVE_DIR" == "$T_ARCHIVE_DIR" ]

    # create some file for testing teardown() in the next test
    touch "$BATS_FILE_TMPDIR/some-file"
}

@test "test teardown()" {
    # This file was created by the test before this and should not
    # exist as 'teardown()' should delete it
    assert_file_not_exist "$BATS_FILE_TMPDIR/some-file"
}

@test "test lifesaver edge cases input handling" {
    # Next test case does not work because interactive nature of the
    # script.

    # Wrong filename given
    # run lifesaver.sh -f this/is/a/path
    # assert_failure
    # assert_output --partial "given FILE parameter cannot be a path"

    # No parameter given
    run lifesaver.sh
    assert_failure
    assert_line --index 0 "lifesaver: no option given"

    # No preceeding dash with options
    run  lifesaver.sh hls
    assert_failure
    assert_line --index 0 "lifesaver: unrecognized option 'hls'"

    # Invalid option given alone
    run lifesaver.sh -x
    assert_failure
    assert_line "lifesaver: unrecognized option '-x'"

    # Invalid option given preceeding a valid option
    run lifesaver.sh -xh
    assert_failure
    assert_line --index 0 "lifesaver: unrecognized option '-xh'"

    # Invalid options given after a valid option
    run lifesaver.sh -hxc
    assert_success
}

@test "test lifesaver help display" {
    run lifesaver.sh -h
    assert_success
    assert_line --index 0 "Lifesaver: manage your Moonring save files."
}

### '-v' (print variables) option
######################################################################

@test "test '-v' option" {
    # the '-F' is used to avoid validations that will fail the test
    run lifesaver.sh \
        -s "$T_SAVE_DIR/save/" \
        -a "$T_ARCHIVE_DIR2/" \
        -v
    assert_output --partial "$T_SAVE_DIR/save/"
    assert_output --partial "$T_ARCHIVE_DIR2/"

    # Test if environment variables are unchanged (this must be in the
    # same test, to assure that -a nor -s don't mutate shell state.)
    local env_vars save_dir archive_dir
    env_vars=$(lifesaver.sh -v)
    # Print the 3º column of lines matching '/WORD/' in 'env_vars'
    save_dir=$(awk '/MOONRING/ {print $3}' <<< "$env_vars")
    archive_dir=$(awk '/ARCHIVE/ {print $3}' <<< "$env_vars")
    # Compare this values against the values of testing env vars
    assert [ "$archive_dir" == "$T_ARCHIVE_DIR" ]
    assert [ "$save_dir" == "$T_SAVE_DIR" ]
}

@test "test '-v' option bad input handling" {
    local -r non_existant_dir=$BATS_FILE_TMPDIR/this_dont_exist/
    local -r not_a_dir=$T_ARCHIVE_DIR/already_exists.tar.gz
    refute lifesaver.sh -a "$non_existant_dir" -v
    refute lifesaver.sh -s "$non_existant_dir" -v
    refute lifesaver.sh -a "$not_a_dir" -v
    refute lifesaver.sh -s "$not_a_dir" -v
    # To check some of the actual output
    run lifesaver.sh -a "$non_existant_dir" -v
    assert_output --partial "cannot be found"
}

### '-l' (list archive dir) option
######################################################################

@test "test '-l' option" {
    run lifesaver.sh -a "$T_ARCHIVE_DIR" -l
    assert_success
    assert_output --partial "$(ls --color=never "$T_ARCHIVE_DIR")"
}

@test "test '-l' option bad input handling" {
    local -r non_existant_dir=$BATS_FILE_TMPDIR/this_dont_exist/
    local -r not_a_dir=$T_ARCHIVE_DIR/already_exists.tar.gz
    refute lifesaver.sh -a "$non_existant_dir" -l
    refute lifesaver.sh -a "$not_a_dir" -l
    # To check some of the actual outputs
    run lifesaver.sh -a "$non_existant_dir" -l
    assert_output --partial "cannot be found"
}

### '-f' (archive save dir) option
######################################################################

# As -F is used saving a new file and overwriting is the same action
@test "test '-f' option" {
    run lifesaver.sh -Ff already_exists.tar.gz
    assert_file_exists "$T_ARCHIVE_DIR/already_exists.tar.gz"
    # Assert that the tarred file's contents are correct
    local -r save_dir_name=$(basename "$T_SAVE_DIR")
    assert tar --diff \
           --file="$T_ARCHIVE_DIR/already_exists.tar.gz" \
           --directory="$T_SAVE_DIR/.." "./$save_dir_name"
}

@test "test '-f' option bad input handling" {
    local -r non_existant_dir=$BATS_FILE_TMPDIR/this_dont_exist/
    local -r not_a_dir=$T_ARCHIVE_DIR/already_exists.tar.gz
    refute lifesaver.sh -Ff # no argument
    refute lifesaver.sh -a "$non_existant_dir" -Ff 'some_file'
    refute lifesaver.sh -s "$non_existant_dir" -Ff 'some_file'
    refute lifesaver.sh -a "$not_a_dir" -Ff "$not_a_dir"
    refute lifesaver.sh -s "$not_a_dir" -Ff "$not_a_dir"
    # To check some of the actual outputs
    run lifesaver.sh -a "$non_existant_dir" -Ff 'some_file'
    assert_output --partial "not a valid location"
}


### '-u' (update current save dir) option
######################################################################

@test "test '-u' option" {
    # Create an archive to update different than MOONRING_SAVE_DIR
    lifesaver.sh -s "$T_ARCHIVE_DIR2/Moonring" -Ff 'savefile.tar.gz' >/dev/null 2>&1
    run lifesaver.sh -Fu 'savefile.tar.gz'
    assert_success
    # Assert the current savefile was updated correctly
    local -r save_dir_name=$(basename "$T_SAVE_DIR")
    assert tar --diff \
           --file="$T_ARCHIVE_DIR/savefile.tar.gz" \
           --directory="$T_SAVE_DIR/.." "./$save_dir_name"
}
