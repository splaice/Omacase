# shellcheck shell=bash
# `omacase usage` — btop-style agent usage dashboard (Claude, Codex, Grok).
# All logic lives in lib/usage.py; this wrapper only routes subcommands.
#   omacase usage            render (collects first when state is stale)
#   omacase usage update     refresh the state records (the background
#                            usage-tracker extra runs this every 15 min)
#   omacase usage json       raw records for scripts

omacase_usage() {
  have python3 || abort "python3 is required for omacase usage"
  python3 "$OMACASE_ROOT/lib/usage.py" "${@:-show}"
}
