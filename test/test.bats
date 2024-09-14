#!/usr/bin/env bash

# Load bats and its helper libraries. For a reason, putting this
# statements in `setup_file()' didn't load the libs properly.
load "$BATS_TEST_DIRNAME/.bats/test_helper/bats-assert/load.bash"
load "$BATS_TEST_DIRNAME/.bats/test_helper/bats-support/load.bash"
load "$BATS_TEST_DIRNAME/.bats/test_helper/bats-file/load.bash"

setup_file() {
    # Add the project's root dir into $PATH as first
    PATH="$BATS_TEST_DIRNAME/../:$PATH"
    # Assign a base directory for creating temp dirs or files
    # shellcheck disable=2034
    BATS_TMPDIR="$BATS_TEST_DIRNAME/tmp/"
    # Create a temporary directory and assign its path to a variable
    BATS_FILE_TMPDIR="$(temp_make)"
}

teardown_file() {
    # Delete the tmpdir created in `setup_file'
    temp_del "$BATS_FILE_TMPDIR"
}

setup() {
    local -r save_dir="$BATS_FILE_TMPDIR/moonring/save"
    local -r archive_dir="$BATS_FILE_TMPDIR/archive"
    # create files moonring/file{1..3} and moonring/save/file{1..3}
    # at $BATS_FILE_TMPDIR
    mkdir -p "$save_dir"
    touch "$save_dir/../file"{1..3} "$save_dir/file"{1..3}
    # create files archive/already_exists.tar.gz and archive/already_exists
    # at $BATS_FILE_TMPDIR
    mkdir "$archive_dir"
    touch "$archive_dir/already_exists.tar.gz" "$archive_dir/already_exists"
}

teardown() {
    # Delete the tmpdir contents only
    rm -r "${BATS_FILE_TMPDIR:?}/"*
}

@test "test bats setup" {
    local -r save_dir="$BATS_FILE_TMPDIR/moonring"
    local -r archive_dir="$BATS_FILE_TMPDIR/archive"
    # check for created dirs
    assert_dir_exists "$BATS_FILE_TMPDIR"
    assert_dir_exists "$save_dir/save"
    assert_dir_exists "$archive_dir"
    # check created files
    assert_file_exists "$save_dir/file2"
    assert_file_exists "$save_dir/save/file2"
    assert_file_exists "$archive_dir/already_exists.tar.gz"
    # create some file for testing teardown in subsequent test
    touch "$BATS_FILE_TMPDIR/some-file"
}

@test "test bats teardown" {
    assert_file_not_exists "$BATS_FILE_TMPDIR/some-file"
}
