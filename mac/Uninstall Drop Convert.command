#!/bin/bash
# Removes Drop Convert: the app and its saved bubble position. Your files and ffmpeg are not touched.
pkill -x DropConvert 2>/dev/null
rm -rf "$HOME/Applications/Drop Convert.app" "$HOME/Library/Application Support/DropConvert"
echo 'Drop Convert was removed.'
echo 'If you installed ffmpeg only for it, you can remove that too with: brew uninstall ffmpeg'
