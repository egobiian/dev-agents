#!/bin/sh
#
# Run audio generation batches one after another, gently on the machine.
#
#     run_batches.sh [--notes <file>] <batch> [<batch> ...] > <log> 2>&1
#
# Where the models run and the command that generates one batch come from the
# project's local notes, audio/tool.local.md by default, which git ignores:
#
#     TOOL_DIR=<the folder the command runs in>
#     GENERATE=<the command; the batch file's absolute path is appended>
#     REST_BETWEEN_BATCHES=<seconds, optional, 300 by default>
#
# Before each batch it waits while macOS reports the CPU throttled, and it
# rests between batches. The rests between sounds inside a batch belong to the
# batch file or to the tool. Exit 0 when every batch ended well, 1 when one
# failed, 2 on bad arguments or missing notes.

set -u

THROTTLE_WAIT=120

notes=audio/tool.local.md
if [ "${1:-}" = "--notes" ]; then
	[ $# -ge 2 ] || { echo "run_batches.sh: --notes needs a file" >&2; exit 2; }
	notes=$2
	shift 2
fi
[ $# -gt 0 ] || { echo "usage: run_batches.sh [--notes <file>] <batch> [<batch> ...]" >&2; exit 2; }
[ -f "$notes" ] || { echo "run_batches.sh: $notes is missing" >&2; exit 2; }

value() { sed -n "s/^$1=//p" "$notes" | head -n 1; }
tool_dir=$(value TOOL_DIR)
generate=$(value GENERATE)
rest=$(value REST_BETWEEN_BATCHES)
rest=${rest:-300}
case "$tool_dir" in "~/"*) tool_dir="$HOME/${tool_dir#\~/}" ;; esac
[ -n "$tool_dir" ] && [ -n "$generate" ] || { echo "run_batches.sh: TOOL_DIR or GENERATE missing in $notes" >&2; exit 2; }
[ -d "$tool_dir" ] || { echo "run_batches.sh: TOOL_DIR $tool_dir is not a folder" >&2; exit 2; }
for batch in "$@"; do
	[ -f "$batch" ] || { echo "run_batches.sh: $batch is missing" >&2; exit 2; }
done

stamp() { date +%H:%M:%S; }

wait_until_cool() {
	command -v pmset >/dev/null 2>&1 || return 0
	while :; do
		limit=$(pmset -g therm | sed -n 's/.*CPU_Speed_Limit[^0-9]*\([0-9]*\).*/\1/p')
		[ -n "$limit" ] && [ "$limit" -lt 100 ] || return 0
		echo "[$(stamp)] CPU limited to ${limit}%, waiting"
		sleep "$THROTTLE_WAIT"
	done
}

failed=0
first=1
for batch in "$@"; do
	# The command runs from the tool's folder, so the batch path has to be absolute.
	folder=$(cd "$(dirname "$batch")" && pwd)
	batch=$folder/$(basename "$batch")
	label=$(basename "$folder")/$(basename "$batch")
	if [ "$first" -eq 0 ]; then
		echo "[$(stamp)] resting ${rest}s"
		sleep "$rest"
	fi
	first=0
	wait_until_cool
	echo "[$(stamp)] start $label"
	(cd "$tool_dir" && eval "$generate \"\$batch\"" </dev/null 2>&1)
	status=$?
	if [ "$status" -eq 0 ]; then
		echo "[$(stamp)] done $label"
	else
		echo "[$(stamp)] failed $label (exit $status)"
		failed=1
	fi
done
echo "[$(stamp)] all done"
exit "$failed"
