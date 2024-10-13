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
    local -r save_dir=$BATS_FILE_TMPDIR/Moonring # Must be capitalized
    local -r archive_dir=$BATS_FILE_TMPDIR/archive

    # Create files moonring/file{1..3} and moonring/save/file{1..3}
    # at $BATS_FILE_TMPDIR
    mkdir -p "$save_dir/save/"
    touch "$save_dir/file"{1..3} "$save_dir/save/file"{1..3}

    # Create files archive/already_exists.tar.gz and archive/already_exists
    # at $BATS_FILE_TMPDIR
    mkdir "$archive_dir"
    mkdir "${archive_dir}2"
    touch "$archive_dir/already_exists.tar.gz" "$archive_dir/already_exists"

    # Declare lifesaver environment variables
    export MOONRING_SAVE_DIR=$save_dir
    export LIFESAVER_ARCHIVE=$archive_dir

    # CRITICAL FAIL: if lifesaver ignores the environment variable;
    # otherwise user's files may be compromised by testing processes.
    local env_vars save_var archive_var
    env_vars=$(lifesaver.sh -v)
    # Print the third column of every line containing '/WORD/' from
    # "$env_vars" used as a here document:
    save_var=$(awk '/MOONRING/ {print $3}' <<< "$env_vars")
    archive_var=$(awk '/ARCHIVE/ {print $3}' <<< "$env_vars")
    if [ "$save_var" != "$save_dir" ] || [ "$archive_var" != "$archive_dir" ]; then
        echo "Error: lifesaver is not properly recognizing setup environment variables" >&2
        echo "Testing was aborted to avoid compromising user files" >&2
        return 1
    fi
}

teardown() {
    # Delete the tmpdir contents only
    rm -r "${BATS_FILE_TMPDIR/*:?'BATS_FILE_TMPDIR is unset or null!'}"
    unset MOONRING_SAVE_DIR LIFESAVER_ARCHIVE
}

@test "test bats setup" {
    local -r save_dir=$BATS_FILE_TMPDIR/Moonring
    local -r archive_dir=$BATS_FILE_TMPDIR/archive
    # check for created dirs
    assert_dir_exists "$BATS_FILE_TMPDIR"
    assert_dir_exists "$save_dir/save/"
    assert_dir_exists "$archive_dir"
    assert_dir_exists "${archive_dir}2"
    # check created files
    assert_file_exists "$save_dir/file2"
    assert_file_exists "$save_dir/save/file2"
    assert_file_exists "$archive_dir/already_exists.tar.gz"
    # create some file for testing teardown in subsequent test
    touch "$BATS_FILE_TMPDIR/some-file"
    # Test the testing setup of environment variables of lifesaver
    assert [ "$MOONRING_SAVE_DIR" == "$save_dir" ]
    assert [ "$LIFESAVER_ARCHIVE" == "$archive_dir" ]
}

@test "test bats teardown" {
    assert_file_not_exists "$BATS_FILE_TMPDIR/some-file"
}

#
# bats-assert functions:
#
# assert / refute                 = Assert a given expression evaluates to true or false.
# assert_equal                    = Assert two parameters are equal.
# assert_not_equal                = Assert two parameters are not equal.
# assert_success / assert_failure = Assert exit status is 0 or 1.
# assert_output / refute_output   = Assert output does (or does not) contain given content.
# assert_line / refute_line       = Assert a specific line of output does (or does not)
#                                   contain given content.
# assert_regex / refute_regex     = Assert a parameter does (or does not) match given pattern.
#

# The environment variables are defined in the 'setup()' which are
# executed before every bats test. Is important to have this test up
# in priority so it fails fast and no changes are made to the actual
# lifesaver's files used by the user.
@test "test lifesaver environment variables functionality" {
    run lifesaver.sh -l
    assert_output "$(ls "$BATS_FILE_TMPDIR/archive/")"
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

@test "test lifesaver -l (list) option" {
    local -r archive_dir=$BATS_FILE_TMPDIR/archive
    run lifesaver.sh -a "$archive_dir" -l
    assert_success
    assert_output "$(ls "$archive_dir")"
}

# Note that the -F (--force) option is almos always used, as a way to
# avoid the need to mock interactive use in testing

# As -F is used saving a new file and overwriting is the same action
@test "test 'lifesaver -Ff already_exists.tar.gz'" {
    run lifesaver.sh -Ff already_exists.tar.gz
    assert_file_exists "$BATS_FILE_TMPDIR/archive/already_exists.tar.gz"
    # Assert that the tarred file's contents are correct
    assert tar --diff \
           --file="$BATS_FILE_TMPDIR/archive/already_exists.tar.gz" \
           --directory="$BATS_FILE_TMPDIR" './Moonring'
}

@test "test 'lifesaver -s save_dir -a archive_dir -v'" {
    run lifesaver.sh \
        -s "$BATS_FILE_TMPDIR/Moonring/save/" \
        -a "$BATS_FILE_TMPDIR/archive2/" \
        -v # Print lifesaver environmental variables values
    assert_output --partial "$BATS_FILE_TMPDIR/Moonring/save/"
    assert_output --partial "$BATS_FILE_TMPDIR/archive2/"

    # Test if environment variables are unchanged (this must be in the
    # same test function, to test that -a nor -s mutates the state.)
    local env_vars save_dir archive_dir
    env_vars=$(lifesaver.sh -v)
    # Print the 3º column of lines matching '/WORD/' in 'env_vars'
    save_dir=$(awk '/MOONRING/ {print $3}' <<< "$env_vars")
    archive_dir=$(awk '/ARCHIVE/ {print $3}' <<< "$env_vars")
    # Compare this values against the values of environmental vars
    assert [ "$archive_dir" == "$BATS_FILE_TMPDIR/archive" ]
    assert [ "$save_dir" == "$BATS_FILE_TMPDIR/Moonring" ]
}
