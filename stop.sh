#!/bin/bash

cmd="docker kill dockerbug"
echo + $cmd
eval $cmd >/dev/null 2>&1 || true
