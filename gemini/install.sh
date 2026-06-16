#!/bin/sh

SCRIPT_DIR="$(dirname "$(readlink -f "$0")")"

mkdir -p ~/.gemini
ln -sf "$SCRIPT_DIR/system.md" ~/.gemini/

mkdir -p ~/bin
ln -sf "$SCRIPT_DIR/gemini.sh" ~/bin/gemini

