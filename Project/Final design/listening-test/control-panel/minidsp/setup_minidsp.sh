#!/usr/bin/env bash
# One-time setup of minidsp-rs for the listening-test control panel (Linux x86_64, Omarchy/Arch).
#   bash setup_minidsp.sh          install minidsp + minidspd v0.1.12 into ~/.local/bin, copy the config
#   bash setup_minidsp.sh --udev   also install the USB permission rule (asks for sudo), then replug the MiniDSP
# Safe to re-run. Sends nothing to the MiniDSP except a read-only 'minidsp probe' at the end.
set -euo pipefail
VER=v0.1.12
HERE="$(cd "$(dirname "$0")" && pwd)"
URL="https://github.com/mrene/minidsp-rs/releases/download/$VER/minidsp.x86_64-unknown-linux-gnu.tar.gz"

if command -v minidsp >/dev/null && minidsp --version | grep -q "${VER#v}"; then
  echo "minidsp ${VER#v} already installed: $(command -v minidsp)"
else
  tmp="$(mktemp -d)"; trap 'rm -rf "$tmp"' EXIT
  echo "Downloading $URL"
  curl -fsSL "$URL" -o "$tmp/minidsp.tar.gz"
  tar xzf "$tmp/minidsp.tar.gz" -C "$tmp"
  mkdir -p ~/.local/bin
  for b in minidsp minidspd; do
    f="$(find "$tmp" -type f -name "$b" | head -1)"
    [ -n "$f" ] && install -m 755 "$f" ~/.local/bin/ && echo "installed ~/.local/bin/$b"
  done
fi
case ":$PATH:" in *":$HOME/.local/bin:"*) ;; *) echo "WARNING: ~/.local/bin is not on PATH; the panel will not find minidsp";; esac

mkdir -p ~/.config/minidsp
cp -n "$HERE/config.toml" ~/.config/minidsp/config.toml 2>/dev/null || true
cp "$HERE/99-minidsp.rules" ~/.config/minidsp/99-minidsp.rules

if [ "${1:-}" = "--udev" ]; then
  sudo install -Dm644 "$HERE/99-minidsp.rules" /etc/udev/rules.d/99-minidsp.rules
  sudo udevadm control --reload-rules && sudo udevadm trigger
  echo "udev rule installed: unplug and replug the MiniDSP USB cable now."
else
  echo "USB rule not installed. Run: bash $0 --udev   (needs sudo)"
fi

echo; minidsp --version
lsusb | grep -i 2752 || echo "No MiniDSP (vendor 2752) on USB right now."
minidsp probe || true
