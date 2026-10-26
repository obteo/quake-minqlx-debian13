# Quake Live minqlx + Redis — Debian 13 slim

Self-contained **runtime image** for Pterodactyl v2, based directly on `debian:13-slim`.

- minqlx compiled from pinned upstream commit `fbdd915185337791d8e209dc4b686a1ee60d3721` with Debian 13 / Python 3.13
- Redis running on loopback `127.0.0.1:6379`, with AOF in `/home/container/.redis`
- Debian-packaged Python Redis, ZMQ and Requests modules
- `container` non-root runtime and Wings `STARTUP` integration
- No dependency on the YOB Debian image or the ptero-eggs SteamCMD image

## Important

This image is a runtime, **not the Quake Live game installer**. Keep your existing SteamCMD installation script in the egg. It also does not include proprietary Quake Live game assets.

The startup script must be tested in Pterodactyl with actual `quit` stop commands. In particular, the initial launch and PTY stdin handling still require validation in Wings.

For existing servers: the image does **not overwrite** minqlx binaries in `/home/container` automatically. Before switching from Python 3.9, back up the files, replace **both** `minqlx.x64.so` and `minqlx.zip` with those in `/opt/minqlx`, and test. This image stages these only if missing.

## GHCR

Create a new repository (recommended: `obteo/quake-minqlx-debian13`), upload this project, enable Actions, and make the GHCR package public if pulling anonymously.

First test image: `ghcr.io/obteo/quake-minqlx-debian13:2.0-test`

## Pterodactyl settings

- Docker image: `ghcr.io/obteo/quake-minqlx-debian13:2.0-test`
- Startup: `bash /home/container/run_server_x64_minqlx.sh`
- Stop command: `quit` (must be validated with Wings)
- Redis config: `qlx_redisAddress` `127.0.0.1`, port `6379`, password blank (loopback only)

For Quake Live binaries, keep working `LD_LIBRARY_PATH=./linux64` in the startup script. Set `fs_homepath=/home/container`.

## Rollback

Do not change your existing `ghcr.io/obteo/quake-minqlx:latest` until the new release is proven. A rollback to Python 3.9 requires restoring the original Python 3.9 minqlx binaries from backup.
