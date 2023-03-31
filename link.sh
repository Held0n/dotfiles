#!/bin/bash
target_dir=$HOME/.config/script

if [[ -d $target_dir ]]; then
    mv $target_dir "$target_dir.bak"
fi

ln -s $PWD/script $target_dir