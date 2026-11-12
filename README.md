# Debian Firefox VNC

This container runs Debian, Firefox ESR, TigerVNC, and noVNC.

## Build

```bash
docker build -t debian-firefox-vnc .
```

## Run

For Docker Desktop / restricted container environments, use these flags:

```bash
docker run -d \
  --name debian-firefox-vnc \
  -p 8080:8080 \
  -p 5901:5901 \
  --security-opt seccomp=unconfined \
  --cap-add=SYS_ADMIN \
  debian-firefox-vnc
```

Then open:

- Browser: http://localhost:8080/vnc.html?resize=remote&autoconnect=true
- VNC: localhost:5901

The default VNC password is:

```text
firefox
```

You can override it at runtime:

```bash
docker run -d \
  --name debian-firefox-vnc \
  -p 8080:8080 \
  -p 5901:5901 \
  -e VNC_PASSWORD=yourpass \
  --security-opt seccomp=unconfined \
  --cap-add=SYS_ADMIN \
  debian-firefox-vnc
```
