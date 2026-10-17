#!/usr/bin/env bash
set -Eeuo pipefail

usage() {
  cat <<'USAGE'
Usage: sudo ./install-deps.sh

Install the host packages required by scripts/build.sh to create a Debian Live ISO.
USAGE
}

if [[ "${1:-}" == "--help" || "${1:-}" == "-h" ]]; then
  usage
  exit 0
fi
if [[ "$#" -ne 0 ]]; then
  usage >&2
  exit 2
fi
if [[ "${EUID}" -ne 0 ]]; then
  printf 'Run this script as root, for example: sudo %s\n' "$0" >&2
  exit 1
fi
if ! command -v apt-get >/dev/null 2>&1; then
  printf 'This helper requires apt-get on a Debian-based system.\n' >&2
  exit 1
fi

if [[ ! -r /etc/os-release ]]; then
  printf 'Cannot identify this system: /etc/os-release is missing.\n' >&2
  exit 1
fi
# shellcheck source=/etc/os-release
. /etc/os-release
if [[ "${ID:-}" != 'debian' && " ${ID_LIKE:-} " != *' debian '* && "${ID:-}" != 'ubuntu' ]]; then
  printf 'Unsupported system: %s. Use Debian or Ubuntu.\n' "${PRETTY_NAME:-unknown}" >&2
  exit 1
fi

export DEBIAN_FRONTEND=noninteractive
apt-get update -o APT::Update::Error-Mode=any
apt-get install --yes --no-install-recommends \
  live-build \
  debootstrap \
  squashfs-tools \
  xorriso

printf 'DylanOS build dependencies are installed.\n'
