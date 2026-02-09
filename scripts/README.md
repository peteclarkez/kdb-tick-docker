## scripts — Customising or Replacing the Tick Capture Implementation

Purpose
- The `scripts/` folder contains the files loaded into the container at runtime to provide schema, feed handlers and optional custom helpers for the tick capture system. It is intended to be the main extension point for light customisations and can also be entirely replaced for a full custom implementation.

Two common approaches
- Live customization (no image rebuild): mount or edit files inside `scripts/` and restart the container. This is the fastest way to change schemas, feed handlers or small logic.
- Full replacement (custom engine or logic): replace the runtime tick implementation (files under `kdb-tick/`) and rebuild the Docker image, or mount a complete custom implementation into the container at runtime.

Key files and load order
- `sym.q` — defines table schemas used by the TP and RDB. Edit this to change the expected table layout.
- `feed.q` — optional feed script launched by `docker/tick.sh` (if present). Use it to publish test data or implement an internal feedhandler.
- `gw_custom.q`, `rdb_custom.q`, `hdb_custom.q` — loaded after core files to provide custom gateway, RDB or HDB helpers.

Quick examples
- Restarting with live script changes (compose):

```bash
docker compose --env-file kdbx.env up -d
docker compose --env-file kdbx.env restart
```

- Running the container with a host `scripts` mount (no rebuild required):

```bash
docker run -v $(pwd)/scripts:/opt/kx/kdb-tick/scripts \
	-v $(pwd)/data:/opt/kx/kdb-tick/data \
	-v $(pwd)/logs:/opt/kx/kdb-tick/logs \
	-e KDB_SETTINGS=... your-image:tag
```

- Replace core tick implementation and rebuild image:

1. Replace or add your q files under `kdb-tick/` (for example `kdb-tick/tick.q`, `kdb-tick/tick/gw.q`, `kdb-tick/tick/u.q`).
2. Rebuild the Docker image and restart with `docker compose --env-file kdbx.env up -d --build`.

Advanced runtime mount (swap implementation at runtime)
- You can mount a complete custom tick tree over the default at container start:

```bash
docker run -v $(pwd)/my-tick:/opt/kx/kdb-tick -v $(pwd)/scripts:/opt/kx/kdb-tick/scripts ...
```

Runtime notes
- `docker/tick.sh` configures directories and starts the processes; keep the same mount points (`./data`, `./logs`, `./tplogs`, `./scripts`) unless you update the script and compose file.
- End-of-day persistence and manual saves can be triggered from the gateway (see `triggerEOD` in `kdb-tick/tick/gw.q`).
- Logs and tick persistence files live under `./logs`, `./tplogs` and `./data` — keep these mounted to retain state across container restarts.

Practical tips
- Quick schema change: edit `sym.q` then restart the container.
- Local testing: implement a simple `feed.q` that publishes sample messages to the TP for functional testing.
- Full custom behaviour: replace `kdb-tick/` and either rebuild the image or mount your implementation at runtime.

If you'd like, I can create a small example `feed.q` or a replacement `sym.q` demonstrating a custom schema—tell me which tables or fields you need.