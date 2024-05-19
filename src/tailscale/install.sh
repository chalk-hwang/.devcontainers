#!/usr/bin/env bash


set -e

# Clean up
rm -rf /var/lib/apt/lists/*


VERSION=${VERSION:-1.66.3}
ARCH="$(uname -m)"
case ${ARCH} in
x86_64) ARCH="amd64" ;;
aarch64 | armv8*) ARCH="arm64" ;;
aarch32 | armv7* | armvhf*) ARCH="arm" ;;
i?86) ARCH="386" ;;
*)
	echo "(!) Architecture ${ARCH} unsupported"
	exit 1
	;;
esac

set -euo pipefail

tailscale_url="https://pkgs.tailscale.com/stable/tailscale_${VERSION}_${ARCH}.tgz"

download() {
  if command -v curl &> /dev/null; then
    curl -fsSL "$1"
  elif command -v wget &> /dev/null; then
    wget -qO - "$1"
  else
    echo "Must install curl or wget to download $1" 1&>2
    return 1
  fi
}

script_dir="$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )"
scratch_dir="/tmp/tailscale"
mkdir -p "$scratch_dir"
trap 'rm -rf "$scratch_dir"' EXIT

download "$tailscale_url" |
  tar -xzf - --strip-components=1 -C "$scratch_dir"
install "$scratch_dir/tailscale" /usr/local/bin/tailscale
install "$scratch_dir/tailscaled" /usr/local/sbin/tailscaled
install "$script_dir/tailscaled-entrypoint.sh" /usr/local/sbin/tailscaled-entrypoint

mkdir -p /var/lib/tailscale /var/run/tailscale

if ! command -v iptables >& /dev/null; then
  if command -v apt-get >& /dev/null; then
    apt-get update
    DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends iptables
    rm -rf /var/lib/apt/lists/*
  else
    echo "WARNING: iptables not installed. tailscaled might fail."
  fi
fi