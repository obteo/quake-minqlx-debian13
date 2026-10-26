#!/usr/bin/env bash
set -Eeuo pipefail
cd /home/container

if [[ -z "${STARTUP:-}" ]]; then
  echo '[ERROR] Missing STARTUP variable.' >&2
  exit 1
fi

REDIS_DIR=/home/container/.redis
mkdir -p "$REDIS_DIR"
[[ -w "$REDIS_DIR" ]] || { echo '[ERROR] Redis directory not writable.' >&2; exit 1; }

redis_pid=''
game_pid=''
stop_redis() {
  if [[ -n "$redis_pid" ]] && kill -0 "$redis_pid" 2>/dev/null; then
    redis-cli -h 127.0.0.1 -p 6379 SHUTDOWN SAVE >/dev/null 2>&1 || true
    kill -TERM "$redis_pid" 2>/dev/null || true
    wait "$redis_pid" 2>/dev/null || true
  fi
}
terminate() {
  trap - INT TERM
  if [[ -n "$game_pid" ]] && kill -0 "$game_pid" 2>/dev/null; then
    kill -TERM "$game_pid" 2>/dev/null || true
    # The game may ignore TERM; Wings can enforce its stop timeout.
    for i in {1..20}; do
      kill -0 "$game_pid" 2>/dev/null || break
      sleep 0.25
    done
    if kill -0 "$game_pid" 2>/dev/null; then kill -KILL "$game_pid" 2>/dev/null || true; fi
  fi
  stop_redis
  exit 143
}
trap terminate TERM INT

redis-server --bind 127.0.0.1 --port 6379 --protected-mode yes \
    --dir "$REDIS_DIR" --appendonly yes --appendfsync everysec --daemonize no &
redis_pid=$!
for i in {1..60}; do
  if ! kill -0 "$redis_pid" 2>/dev/null; then echo '[ERROR] Redis crashed.' >&2; exit 1; fi
  if redis-cli -h 127.0.0.1 ping 2>/dev/null | grep -qx PONG; then break; fi
  sleep 0.2
done
redis-cli -h 127.0.0.1 ping | grep -qx PONG || { echo '[ERROR] Redis not ready.' >&2; exit 1; }

# On first start, stage compiled minqlx files in the persistent Wings volume.
# Existing files are preserved; an opt-in upgrade can replace them after backup.
for filename in minqlx.x64.so minqlx.zip; do
  if [[ ! -e "/home/container/$filename" ]]; then
    cp "/opt/minqlx/$filename" "/home/container/$filename"
    echo "[minqlx] Installed $filename from image."
  fi
done
if [[ ! -e /home/container/run_server_x64_minqlx.sh ]]; then
  cp /opt/minqlx/run_server_x64_minqlx.sh /home/container/run_server_x64_minqlx.sh
fi

startup="$(printf '%s' "$STARTUP" | sed -e 's/{{/${/g' -e 's/}}/}/g')"
printf ':/home/container$ %s\n' "$startup"
# The interactive PTY stdin must remain attached for Pterodactyl's stop command.
/bin/bash -c "exec $startup" </dev/stdin &
game_pid=$!
set +e
wait "$game_pid"
exit_code=$?
set -e
game_pid=''
stop_redis
exit "$exit_code"
