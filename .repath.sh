#!/usr/bin/env bash

dir="$( cd "$( dirname "$0" )" && pwd )"
tmp="$dir/.__tmp.sh"
ruby "$dir/._repath.rb" 1> "$tmp"
source "$tmp"
rm "$tmp"
