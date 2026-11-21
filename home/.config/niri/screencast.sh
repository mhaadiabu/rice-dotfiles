#!/bin/sh
# Screen recording toggle, bound to Super+Shift+R in niri's config.kdl.
# First press starts a headless OpenScreen recording, the next one stops it.
#
# On Wayland the portal asks which screen or window to share before capture
# begins, so the first press shows a "Share Screen" dialog. Stop is immediate.
# Finished MP4s land in OpenScreen's recordings folder (~/.config/openscreen/recordings).
set -u

PIDFILE="${XDG_RUNTIME_DIR}/openscreen-record.pid"
LOGFILE="${XDG_RUNTIME_DIR}/openscreen-record.log"

pid_of() { cat "$PIDFILE" 2>/dev/null; }

# A pidfile from a recorder that already died would make the next press report a
# bogus stop, so only trust it while the process is alive.
running() {
  p="$(pid_of)"
  [ -n "$p" ] && kill -0 "$p" 2>/dev/null
}

# Second press: stop. SIGINT is the documented stop signal for the CLI and it
# finishes the MP4 properly, unlike a kill.
if running; then
  p="$(pid_of)"
  kill -INT "$p"
  i=0
  while kill -0 "$p" 2>/dev/null && [ "$i" -lt 80 ]; do
    sleep 0.125
    i=$((i + 1))
  done
  rm -f "$PIDFILE"

  done_line="$(grep -o '{"event":"done".*' "$LOGFILE" 2>/dev/null | tail -n 1)"
  saved="$(printf '%s' "$done_line" | sed -n 's/.*"screenVideoPath":"\([^"]*\)".*/\1/p')"
  ms="$(printf '%s' "$done_line" | sed -n 's/.*"durationMs":\([0-9]*\).*/\1/p')"

  # Stopping while the picker is still open saves a few frames of nothing.
  if [ -n "$saved" ] && [ "${ms:-0}" -ge 1000 ]; then
    notify-send "Recording saved" "${saved#"$HOME"/}"
  elif [ -n "$saved" ]; then
    notify-send "Recording cancelled" "Stopped before capture began"
  else
    notify-send "Recording" "Stopped, nothing saved"
  fi
  exit 0
fi

rm -f "$PIDFILE"

# ELECTRON_RUN_AS_NODE turns the Electron binary into plain node, so clear it.
# exec keeps the recorded PID on the recorder itself rather than a wrapper shell.
sh -c 'exec env -u ELECTRON_RUN_AS_NODE openscreen record --json' >"$LOGFILE" 2>&1 &
echo $! >"$PIDFILE"

# Wait for capture to actually start: the window takes a moment and the portal
# dialog waits for a pick. Reporting the start too early looks like a broken toggle.
i=0
while [ "$i" -lt 480 ]; do
  grep -q "Recording started" "$LOGFILE" 2>/dev/null && break
  kill -0 "$(pid_of)" 2>/dev/null || break
  sleep 0.25
  i=$((i + 1))
done

if grep -q "Recording started" "$LOGFILE" 2>/dev/null; then
  notify-send "Recording" "Started"
else
  rm -f "$PIDFILE"
  reason="$(grep -o '"error":"[^"]*"' "$LOGFILE" 2>/dev/null | tail -n 1 | cut -d'"' -f4)"
  notify-send "Recording failed" "${reason:-OpenScreen exited}"
fi
