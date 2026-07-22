#!/usr/bin/env bash

target=$1

[[ -n "$target" ]] || exit 0

xdg-open "$target" >/dev/null 2>&1 &
