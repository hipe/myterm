#!/usr/bin/env bash

bin_folder="`pwd`/bin"
if [[ ! -d $bin_folder ]] ; then
  echo "not a directory, won't add to PATH: $bin_folder"
  exit 1;
fi

regex="(^|:)$bin_folder($|:)"

if [[ $PATH =~ $regex ]] ; then
  echo "path already contains: $bin_folder"
else
  export PATH="$bin_folder:$PATH"
  echo "preprended PATH with $bin_folder"
fi
