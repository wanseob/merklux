#!/bin/bash

source $(dirname "$0")/utils.sh
check_truffle_project
trap kill_ganache SIGINT SIGTERM SIGTSTP
run_ganache 8546
run_test
kill_ganache
exit 0
