#!/bin/bash
cd "$(dirname "$0")" || exit 1
/bin/bash install.sh "$@"
status=$?
if [[ -t 0 ]]; then
  printf '\nPress Enter to close / 按回车关闭…'
  read -r _
fi
exit "$status"
