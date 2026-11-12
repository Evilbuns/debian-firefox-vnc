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
    if xdpyinfo -display "$DISPLAY" >/dev/null 2>&1; then
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
# Firefox sandboxing is usually blocked in containerized environments
# (Docker Desktop / restricted namespaces), so disable it here.
# This keeps the browser usable in a VNC/noVNC container setup.
sudo -u firefox env \
    DISPLAY=:1 \
    HOME=/home/firefox \
    XDG_RUNTIME_DIR=/tmp/runtime-firefox \
    MOZ_DISABLE_CONTENT_SANDBOX=1 \
    MOZ_DISABLE_RDD_SANDBOX=1 \
    firefox --no-sandbox --disable-dev-shm-usage &

sleep 8
wmctrl -r "Firefox" -b add,maximized_vert,maximized_horz || true

# Keep the container alive so the VNC and noVNC endpoints remain reachable.
tail -f /dev/null
EOF

RUN chmod +x /start.sh

EXPOSE 8080 5901

CMD ["/start.sh"]
