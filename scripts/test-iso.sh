#!/usr/bin/env bash
set -Eeuo pipefail

usage() {
  printf 'Usage: %s path/to/dylanos.iso\n' "$0"
  printf 'Requires xorriso, unsquashfs, qemu-system-x86_64, timeout, and OVMF firmware.\n'
}

if [[ "${1:-}" == '--help' || "${1:-}" == '-h' ]]; then
  usage
  exit 0
fi
if [[ "$#" -ne 1 ]]; then
  usage >&2
  exit 2
fi

ISO_PATH=$1
if [[ ! -f "$ISO_PATH" ]]; then
  printf 'ISO file not found: %s\n' "$ISO_PATH" >&2
  exit 1
fi
ISO_PATH="$(cd -- "$(dirname -- "$ISO_PATH")" && pwd)/$(basename -- "$ISO_PATH")"
QEMU_TIMEOUT_SECONDS="${DYLANOS_QEMU_TIMEOUT:-900}"
if [[ ! "$QEMU_TIMEOUT_SECONDS" =~ ^[0-9]+$ || "$QEMU_TIMEOUT_SECONDS" -lt 1 ]]; then
  printf 'DYLANOS_QEMU_TIMEOUT must be a positive integer.\n' >&2
  exit 2
fi

for command_name in xorriso unsquashfs qemu-system-x86_64; do
  if ! command -v "$command_name" >/dev/null 2>&1; then
    printf 'Missing test dependency: %s\n' "$command_name" >&2
    exit 1
  fi
done

find_ovmf_pair() {
  local code vars
  for code in \
    /usr/share/OVMF/OVMF_CODE_4M.fd \
    /usr/share/OVMF/OVMF_CODE.fd \
    /usr/share/edk2/x64/OVMF_CODE.4m.fd \
    /usr/share/edk2/x64/OVMF_CODE.fd; do
    vars="${code/OVMF_CODE/OVMF_VARS}"
    if [[ -r "$code" && -r "$vars" ]]; then
      printf '%s\n%s\n' "$code" "$vars"
      return 0
    fi
  done
  return 1
}

TMP_DIR="$(mktemp -d)"
QEMU_PID=''
cleanup() {
  if [[ -n "$QEMU_PID" ]] && kill -0 "$QEMU_PID" 2>/dev/null; then
    kill -TERM "$QEMU_PID" 2>/dev/null || true
    wait "$QEMU_PID" 2>/dev/null || true
  fi
  rm -rf -- "$TMP_DIR"
}
trap cleanup EXIT

printf 'Inspecting ISO boot catalog...\n'
xorriso -indev "$ISO_PATH" -report_el_torito plain >"$TMP_DIR/boot-catalog.txt" 2>&1
printf 'Checking Calamares and DylanOS utilities in the live filesystem...\n'
xorriso -osirrox on -indev "$ISO_PATH" -extract /live/filesystem.squashfs "$TMP_DIR/filesystem.squashfs" >"$TMP_DIR/extract.log" 2>&1
unsquashfs -ll "$TMP_DIR/filesystem.squashfs" >"$TMP_DIR/filesystem.list"
for required_path in \
  usr/bin/calamares \
  usr/bin/dylanos-info \
  usr/bin/dylanos-welcome \
  etc/calamares/settings.conf \
  etc/xdg/autostart/dylanos-welcome.desktop; do
  if ! grep -Fq "squashfs-root/$required_path" "$TMP_DIR/filesystem.list"; then
    printf 'Required file missing from live filesystem: /%s\n' "$required_path" >&2
    exit 1
  fi
done

run_qemu_boot() {
  local mode=$1
  local log_file="$TMP_DIR/$mode-serial.log"
  local code_file=''
  local vars_file=''
  local -a qemu_args=(
    -accel tcg
    -m 4096
    -smp 2
    -display none
    -monitor none
    -serial "file:$log_file"
    -no-reboot
    -cdrom "$ISO_PATH"
    -boot order=d
  )

  if [[ "$mode" == 'uefi' ]]; then
    local firmware_data
    local -a firmware_pair=()
    if ! firmware_data=$(find_ovmf_pair); then
      printf 'OVMF firmware files not found; install the ovmf package.\n' >&2
      return 1
    fi
    mapfile -t firmware_pair <<< "$firmware_data"
    code_file=${firmware_pair[0]}
    vars_file="$TMP_DIR/OVMF_VARS.fd"
    cp -- "${firmware_pair[1]}" "$vars_file"
    qemu_args+=(
      -drive "if=pflash,format=raw,readonly=on,file=$code_file"
      -drive "if=pflash,format=raw,file=$vars_file"
    )
  fi

  printf 'Booting ISO in QEMU (%s, timeout %ss)...\n' "$mode" "$QEMU_TIMEOUT_SECONDS"
  qemu-system-x86_64 "${qemu_args[@]}" &
  QEMU_PID=$!

  for ((elapsed=0; elapsed<QEMU_TIMEOUT_SECONDS; elapsed+=5)); do
    if grep -Fq 'Started sddm.service' "$log_file" 2>/dev/null; then
      kill -TERM "$QEMU_PID" 2>/dev/null || true
      wait "$QEMU_PID" 2>/dev/null || true
      QEMU_PID=''
      printf 'QEMU %s boot reached SDDM.\n' "$mode"
      return 0
    fi
    if ! kill -0 "$QEMU_PID" 2>/dev/null; then
      if wait "$QEMU_PID"; then
        printf 'QEMU exited before SDDM started (%s).\n' "$mode" >&2
      else
        printf 'QEMU failed before SDDM started (%s).\n' "$mode" >&2
      fi
      QEMU_PID=''
      break
    fi
    sleep 5
  done

  if [[ -n "$QEMU_PID" ]] && kill -0 "$QEMU_PID" 2>/dev/null; then
    kill -TERM "$QEMU_PID" 2>/dev/null || true
    wait "$QEMU_PID" 2>/dev/null || true
    QEMU_PID=''
  fi
  printf 'No SDDM-ready marker received in %s mode. Serial log tail:\n' "$mode" >&2
  tail -n 40 "$log_file" >&2 || true
  return 1
}

run_qemu_boot bios
run_qemu_boot uefi
printf 'ISO smoke tests passed: boot catalog, live files, Calamares payload, BIOS boot, and UEFI boot.\n'
