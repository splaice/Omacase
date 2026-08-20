# Omacase developer tasks. `just` lists them; `just check` runs what CI used to.
#
# Lint runs shellcheck ONE FILE PER PROCESS and without `-x`, deliberately:
# ShellCheck inlines every `source`d file that is on its command line (all of
# them with `-x`), and Omacase's lib files source each other heavily, so one
# shared invocation expanded bin/omacase into ~170 inlined copies of lib/ and
# cost ~48 s and ~7.7 GB of RAM for zero extra findings. Per-file runs finish
# in about a second and stay under ~150 MB each.

set shell := ["bash", "-euo", "pipefail", "-c"]

# Show available recipes.
default:
    @just --list --unsorted

# shellcheck every bash source (one process per file, no -x) + parse the zsh completion.
lint:
    #!/usr/bin/env bash
    set -euo pipefail
    command -v shellcheck >/dev/null || { echo "shellcheck not found — brew install shellcheck" >&2; exit 1; }
    shopt -s nullglob   # migrations/ may be empty after a squash
    files=(bin/omacase lib/*.sh boot.sh site/install macos/defaults.sh
           migrations/*.sh tests/run.sh assets/launcher/OmacaseLauncher.sh)
    printf '%s\n' "${files[@]}" | xargs -n1 -P4 shellcheck --severity=warning
    zsh -n completions/_omacase
    echo "lint ok (${#files[@]} files shellchecked, completion parses)"

# Run the test suite.
test:
    bash tests/run.sh

# Lint + tests — run before pushing.
check: lint test
