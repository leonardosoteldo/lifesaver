#!/usr/bin/env bash

# Set the project's root dir into $PATH
setup_file() {
    PATH="$BATS_TEST_DIRNAME/../:$PATH"

    # load .bats/bats/load.bash #bats-core
    # load .bats/test_helper/bats-assert/load.bash
    # load .bats/test_helper/bats-support/load.bash
    # load .bats/test_helper/bats-file/load.bash
}
