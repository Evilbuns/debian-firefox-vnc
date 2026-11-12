FROM debian:stable-slim

ENV DEBIAN_FRONTEND=noninteractive

# Install required packages
RUN apt update && apt install -y --no-install-recommends \
    firefox-esr \
    xfce4 \
    tigervnc-standalone-server \
    tigervnc-tools \
    novnc \
    websockify \
    dbus-x11 \
    x11-xserver-utils \
    sudo \
    curl \
    bash \
    wmctrl \
    openbox \
    x11-utils \
    && apt clean

# Created user for running Firefox and VNC
RUN useradd -m firefox && \
    echo "firefox:firefox" | chpasswd && \
    usermod -aG sudo firefox

# VNC-related setup
RUN mkdir -p /home/firefox/.vnc && \
    echo "firefox" | vncpasswd -f > /home/firefox/.vnc/passwd && \
    chown -R firefox:firefox /home/firefox/.vnc && \
    chmod 600 /home/firefox/.vnc/passwd

# Startup-script
RUN cat << 'EOF' > /start.sh
#!/bin/bash

# --- ENVIRONMENT VARIABLES ---
export DISPLAY=:1
export VNC_PASSWORD_FILE="/home/firefox/.vnc/passwd"
export SCREEN_RESOLUTION="${SCREEN_RESOLUTION:-1920x1080}"
export VNC_PASSWORD="${VNC_PASSWORD:-firefox}"

# --- PREPARE USER ---
mkdir -p /tmp/.X11-unix
chmod 1777 /tmp/.X11-unix
mkdir -p /tmp/runtime-firefox
chmod 700 /tmp/runtime-firefox
mkdir -p /home/firefox/.vnc
mkdir -p /home/firefox/.config/tigervnc
chown -R firefox:firefox /home/firefox
chown -R firefox:firefox /tmp/runtime-firefox

# --- CLEANUP STALE LOCKS/SOCKETS FROM PREVIOUS RUN ---
# /tmp persists across container restarts (as long as the container
# itself isn't removed), so a leftover lock/socket from a previous
# Xvnc process will make the new one refuse to start on the same
# display, even though nothing is actually running anymore.
DISPLAY_NUM="${DISPLAY#:}"
pkill -u firefox Xvnc 2>/dev/null || true
rm -f "/tmp/.X${DISPLAY_NUM}-lock"
rm -f "/tmp/.X11-unix/X${DISPLAY_NUM}"

# --- GENERATE VNC PASSWORD ---
echo "$VNC_PASSWORD" | vncpasswd -f > "$VNC_PASSWORD_FILE"
chmod 600 "$VNC_PASSWORD_FILE"
chown firefox:firefox "$VNC_PASSWORD_FILE"

# --- START TIGERVNC (Xvnc) ---
echo "Starting TigerVNC (Xvnc)"
sudo -u firefox /usr/bin/Xvnc $DISPLAY \
    -geometry $SCREEN_RESOLUTION \
    -depth 24 \
    -rfbauth "$VNC_PASSWORD_FILE" \
    -localhost=no \
    -SecurityTypes=VncAuth &
sleep 1

# --- START NOVNC ---
echo "Starting noVNC"
websockify --web=/usr/share/novnc/ 8080 localhost:5901 &
sleep 1

# --- WAIT FOR X DISPLAY ---
for i in $(seq 1 30); do
    if sudo -u firefox xdpyinfo -display "$DISPLAY" >/dev/null 2>&1; then
        break
    fi
    sleep 1
done

# --- START WINDOW MANAGER ---
echo "Starting Openbox"
sudo -u firefox env \
    DISPLAY=:1 \
    HOME=/home/firefox \
    XDG_RUNTIME_DIR=/tmp/runtime-firefox \
    /usr/bin/openbox &

sleep 3

# --- START FIREFOX ---
echo "Starting Firefox"
# Firefox's sandbox needs unprivileged user namespaces, which some
# container runtimes (e.g. rootless Docker) block with EPERM. Default
# to enabled since it works on the target host (Unraid), but allow
# falling back via DISABLE_FIREFOX_SANDBOX=true on hosts that don't
# support it (e.g. rootless Docker in WSL).
export DISABLE_FIREFOX_SANDBOX="${DISABLE_FIREFOX_SANDBOX:-false}"

FIREFOX_ENV=(DISPLAY=:1 HOME=/home/firefox XDG_RUNTIME_DIR=/tmp/runtime-firefox)
FIREFOX_ARGS=(--disable-dev-shm-usage)

if [ "$DISABLE_FIREFOX_SANDBOX" = "true" ]; then
    FIREFOX_ENV+=(MOZ_DISABLE_CONTENT_SANDBOX=1 MOZ_DISABLE_RDD_SANDBOX=1)
    FIREFOX_ARGS+=(--no-sandbox)
fi

sudo -u firefox env "${FIREFOX_ENV[@]}" firefox "${FIREFOX_ARGS[@]}" &

sleep 8
wmctrl -r "Firefox" -b add,maximized_vert,maximized_horz || true

# Keep the container alive so the VNC and noVNC endpoints remain reachable.
tail -f /dev/null
EOF

RUN chmod +x /start.sh

# --- HEALTHCHECK SCRIPT ---
# Verifies that Xvnc is alive, the X display actually accepts
# connections, and the noVNC web server on 8080 is responding.
# Unraid's autoheal (and the "Autoheal" feature in 7.4.0) reads this
# status and restarts the container automatically if it goes unhealthy.
RUN cat << 'EOF' > /healthcheck.sh
#!/bin/bash
set -e

pgrep -u firefox Xvnc >/dev/null
sudo -u firefox xdpyinfo -display :1 >/dev/null 2>&1
curl -sf http://localhost:8080/ >/dev/null
EOF

RUN chmod +x /healthcheck.sh

LABEL autoheal=true

HEALTHCHECK --interval=30s --timeout=5s --start-period=30s --retries=3 \
    CMD /healthcheck.sh || exit 1

EXPOSE 8080 5901

CMD ["/start.sh"]
