#!/bin/bash

#   __|    \    _ \  |      _ \   __| __ __| __ __|
#  (      _ \     /  |     (   | (_ |    |      |
# \___| _/  _\ _|_\ ____| \___/ \___|   _|     _|

# cli_scripts/builder_handler/python_versions.sh
# Created 8/15/25 - 8:55 PM UK Time (London) by carlogtt

# Script Paths
script_dir_abs="$(realpath -- "$(dirname -- "${BASH_SOURCE[0]}")")"
declare -r script_dir_abs
cli_scripts_dir_abs="$(realpath -- "${script_dir_abs}/../")"
declare -r cli_scripts_dir_abs
this_icarus_abs_filepath="$(realpath -- "${script_dir_abs}/../../bin/icarus")"
declare -r this_icarus_abs_filepath
this_script_abs_filepath="$(realpath -- "${BASH_SOURCE[0]}")"
declare -r this_script_abs_filepath
cli_script_base="${cli_scripts_dir_abs}/base.sh"
declare -r cli_script_base

# Sourcing base file
source "${cli_script_base}" || echo -e "[$(date '+%Y-%m-%d %T %Z')] [ERROR] Failed to source base.sh"

# Script Options
set -o errexit  # Exit immediately if a command exits with a non-zero status
set -o pipefail # Exit status of a pipeline is the status of the last cmd to exit with non-zero

# User defined variables
python_versions=(
    '3.15'
    '3.14'
    '3.13'
    '3.12'
    '3.11'
    '3.10'
    '3.9'
    '3.8'
    '3.7'
)

html_body=$(curl -sX GET 'https://www.python.org/ftp/python/')

# Loop through each major.minor in the array
for ver in "${python_versions[@]}"; do
    echo "=== Python $ver.x ==="
    echo "$html_body" | awk -v ver="$ver" '
    {
      if (index($0, "href=\"") == 0) next

      start = index($0, "href=\"")
      s = substr($0, start + 6)
      q = index(s, "\"")
      if (q == 0) next
      link = substr(s, 1, q - 1)

      if (substr(link, length(link)) == "/") {
        link = substr(link, 1, length(link) - 1)
      } else {
        next
      }

      ok = 1
      if (index(link, ver) != 1) ok = 0
      rest = substr(link, length(ver) + 1)
      i = 1
      while (i <= length(rest)) {
        if (substr(rest, i, 1) != ".") { ok = 0; break }
        i++
        if (i > length(rest) || substr(rest, i, 1) < "0" || substr(rest, i, 1) > "9") { ok = 0; break }
        while (i <= length(rest)) {
          c = substr(rest, i, 1)
          if (c < "0" || c > "9") break
          i++
        }
      }
      if (!ok) next

      pos = index($0, "</a>")
      date = ""
      if (pos > 0) {
        tail = substr($0, pos + 4)
        gsub(/^[[:space:]]+/, "", tail)
        n = split(tail, f, /[[:space:]]+/)
        if (n >= 2) date = f[1] " " f[2]
      }

      print link "\t" date
    }
  ' \
        | sort -t. -k1,1n -k2,2n -k3,3nr -k4,4nr \
        | column -t -s $'\t'
    echo
done
