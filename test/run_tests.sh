#!/bin/bash

cd $(dirname $0)

rm -rf results.txt
vim -u vimrc -S runner.vim -c qa
cat results.txt

if grep -qw "FAILED" results.txt; then
  exit 1
fi
