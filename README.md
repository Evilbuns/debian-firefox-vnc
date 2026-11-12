# Debian Firefox VNC

This container runs Debian, Firefox ESR, Openbox, TigerVNC, and noVNC, giving you
a disposable, browser-accessible Firefox desktop.

## Pull

```bash
docker pull evilbuns/debian-firefox-vnc:latest
# or a pinned version
docker pull evilbuns/debian-firefox-vnc:1.0.1
```

## Build locally

```bash
docker build -t debian-firefox-vnc .
```

## Run

```bash
docker run -d \
  --name debian-firefox-vnc \
  -p 8080:8080 \
  -p 5901:5901 \
  evilbuns/debian-firefox-vnc
```

Then open:

- Browser: http://localhost:8080/vnc.html?resize=remote&autoconnect=true
- VNC client: localhost:5901

The default VNC password is:

```text
firefox
```

## Environment variables

| Variable                  | Default   | Description                                                                 |
|----------------------------|-----------|-------------------------------------------------------------------------------|
| `VNC_PASSWORD`              | `firefox` | VNC login password, regenerated at container start.                          |
| `SCREEN_RESOLUTION`         | `1920x1080` | Resolution of the virtual X display.                                        |
| `DISABLE_FIREFOX_SANDBOX`   | `false`   | Set to `true` on container runtimes that block unprivileged user namespaces (e.g. rootless Docker under WSL), where Firefox's sandbox fails with `EPERM`. Leave `false` on hosts that support it (e.g. Unraid) to keep the real sandbox enabled. |

Example with overrides:

```bash
docker run -d \
  --name debian-firefox-vnc \
  -p 8080:8080 \
  -p 5901:5901 \
  -e VNC_PASSWORD=yourpass \
  -e SCREEN_RESOLUTION=1280x800 \
  -e DISABLE_FIREFOX_SANDBOX=true \
  evilbuns/debian-firefox-vnc
```

## Health check / autoheal

The image defines a `HEALTHCHECK` (Xvnc running, display responding, noVNC web
server reachable) and the label `autoheal=true`, so tools like
[autoheal](https://github.com/willfarrell/autoheal) or Unraid's built-in
Autoheal feature (7.4.0+) can automatically restart the container if it
becomes unhealthy.

## Notes

- `/tmp` state (VNC display lock/socket) is cleaned up automatically on
  startup, so restarting the container (without removing it) works reliably.
- No `--security-opt` / `--cap-add` flags are required for normal operation;
  use `DISABLE_FIREFOX_SANDBOX=true` instead if your runtime blocks Firefox's
  own sandbox.
