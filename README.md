# Quake Live + minqlx — Debian 13

Docker image for **Quake Live dedicated servers** running **minqlx** on **Pterodactyl v2**. Built directly from `debian:13-slim`, with Python 3.13 and an embedded Redis server.

**By Teo**

## Features

- Minimal Debian 13 base; `linux/amd64`
- minqlx compiled during the Docker build from pinned upstream commit [`fbdd915185337791d8e209dc4b686a1ee60d3721`](https://github.com/MinoMino/minqlx/commit/fbdd915185337791d8e209dc4b686a1ee60d3721)
- Native Python 3.13 with Redis, PyZMQ and Requests modules
- Embedded Redis (no second container or external Docker network required)
- Redis AOF persistence in `/home/container/.redis`
- Non-root `container` user, Wings `STARTUP` integration and console-based `quit` shutdown
- minqlx plugins remain editable in the server's `minqlx-plugins/` directory

## Docker images

```text
ghcr.io/obteo/quake-minqlx-debian13:2.0.0
ghcr.io/obteo/quake-minqlx-debian13:latest
```

The pre-release test tag is `2.0-test`. For production, prefer the versioned `2.0.0` tag instead of the moving `latest` tag.

**Note:** images must be published successfully to GHCR before they can be pulled. Check [GitHub Actions](https://github.com/obteo/quake-minqlx-debian13/actions) and package visibility first.

## Pterodactyl v2 configuration

This image is the **runtime**, not the Quake Live game installer. Use your existing SteamCMD-based Quake Live egg to install the licensed game files; the image intentionally does not distribute them.

| Setting | Value |
| --- | --- |
| Docker image | `ghcr.io/obteo/quake-minqlx-debian13:2.0.0` |
| Startup command | `bash /home/container/run_server_x64_minqlx.sh` |
| Stop command | `quit` |
| Game home directory | `/home/container` |
| Redis host | `127.0.0.1` |
| Redis port | `6379` |

Set your Quake Live startup script to run from `/home/container`, load `./minqlx.x64.so` via `LD_PRELOAD`, include `./linux64` in `LD_LIBRARY_PATH`, and set `fs_homepath` to `/home/container`.

### server.cfg — Redis settings

```cfg
set qlx_database "Redis"
set qlx_redisAddress "127.0.0.1"
set qlx_redisPort "6379"
set qlx_redisDatabase "0"
set qlx_redisUnixSocket "0"
set qlx_redisPassword ""
```

Redis binds to loopback inside the game container. Do **not** expose port 6379 publicly.

## Existing servers: Python 3.9 to Python 3.13

**Back up the server files and Redis data before changing Docker images.**

The image contains the new minqlx files under `/opt/minqlx/`:

```text
/opt/minqlx/minqlx.x64.so
/opt/minqlx/minqlx.zip
/opt/minqlx/run_server_x64_minqlx.sh
```

At startup, the entrypoint copies these into `/home/container` **only if missing**. It will not overwrite existing Python 3.9 minqlx files.

When migrating an existing server, stop it, back up `minqlx.x64.so` and `minqlx.zip`, replace **both** with the Python 3.13 versions from the image, and then start the server. Keep your working startup script and `server.cfg`.

To inspect or extract the image's files on the Wings node:

```bash
docker create --name minqlx-extract ghcr.io/obteo/quake-minqlx-debian13:2.0.0
docker cp minqlx-extract:/opt/minqlx/minqlx.x64.so ./minqlx.x64.so
docker cp minqlx-extract:/opt/minqlx/minqlx.zip ./minqlx.zip
docker rm minqlx-extract
```

Use normal file management or an appropriate backup-aware copy method to install them into the Pterodactyl server volume. Avoid overwriting live files while the game is running.

## Plugins

Python plugins are kept in `/home/container/minqlx-plugins/`, not baked into the Docker image. Enable them using `qlx_plugins` in `baseq3/server.cfg`. This allows independent plugin updates without rebuilding the image.

The image provides Python Redis, PyZMQ and Requests packages. Other third-party plugins may need additional dependencies or compatibility fixes for Python 3.13. Verify them individually.

## Redis persistence and shutdown

Redis runs on `127.0.0.1:6379` inside the same container. Its AOF files and snapshots are stored in `/home/container/.redis`, inside the Pterodactyl server's persistent storage.

The entrypoint starts Redis before the game and shuts Redis down cleanly when the game exits. Successful tests on Pterodactyl v2 confirmed `quit` stopping Quake Live, Redis flushing data, and Wings reporting the server offline.

Back up `.redis/` along with the other server files. On the Wings host, Redis recommends `vm.overcommit_memory=1`; configure that at the host level if required.

## Build and publishing

The GitHub Actions workflow builds a `linux/amd64` Docker image and publishes it to GHCR. minqlx is compiled **during image build**, not when a Pterodactyl game server starts. The minqlx upstream commit is pinned to avoid unexpected upstream source changes.

Local build:

```bash
docker build --platform linux/amd64 -t quake-minqlx-debian13:local .
docker run --rm --entrypoint /bin/bash quake-minqlx-debian13:local -c 'python3 --version; python3 -c "import redis, zmq, requests; print(\"Python modules OK\")"; ldd /opt/minqlx/minqlx.x64.so'
```

## Tested functionality

The `2.0-test` image was tested with Pterodactyl Wings, Quake Live startup, Steam server connectivity, initialization of the configured minqlx plugins, embedded Redis initialization, and graceful `quit` shutdown.

**Known configuration issue:** one custom `mctf.factories` file was reported as invalid JSON. That file is game-server content, not part of this Docker image. In-game behavior and additional custom plugins should still be tested separately.

## License and credits

- [minqlx — MinoMino](https://github.com/MinoMino/minqlx)
- [Quake Live](https://store.steampowered.com/app/282440/Quake_Live/)
- [Pterodactyl](https://pterodactyl.io/)

Quake Live game assets are not included. This repository provides Docker build configuration and runtime integration; third-party components retain their respective licenses.
