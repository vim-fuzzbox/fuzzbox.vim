#!/bin/bash

cd $(dirname $0)

rm -rf results.txt
TEST_FILE=$1 vim -u vimrc -U NONE -i NONE --not-a-term -S runner.vim -c qa
cat results.txt

if grep -qw "FAILED" results.txt; then
  exit 1
fi
