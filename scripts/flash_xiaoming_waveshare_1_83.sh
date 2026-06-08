#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
FIRMWARE="${ROOT_DIR}/releases/waveshare-esp32-s3-touch-lcd-1.83-xiaoming-merged-binary.bin"
ZIP_FILE="${ROOT_DIR}/releases/v2.2.6_waveshare-esp32-s3-touch-lcd-1.83.zip"
PORT="${1:-}"
BAUD="${BAUD:-921600}"

if [[ ! -f "${FIRMWARE}" ]]; then
  mkdir -p "${ROOT_DIR}/releases"
  if [[ ! -f "${ZIP_FILE}" ]]; then
    if ! command -v gh >/dev/null 2>&1; then
      echo "Firmware not found and gh is unavailable: ${FIRMWARE}" >&2
      exit 1
    fi
    echo "Downloading latest xiaozhi-firmware artifact..."
    run_id="$(gh run list --workflow 'Build 小明同学 Firmware' --branch main --status success --limit 1 --json databaseId --jq '.[0].databaseId')"
    if [[ -z "${run_id}" || "${run_id}" == "null" ]]; then
      echo "No successful firmware workflow run found." >&2
      exit 1
    fi
    tmp_dir="$(mktemp -d)"
    gh run download "${run_id}" -n xiaozhi-firmware -D "${tmp_dir}"
    found_zip="$(find "${tmp_dir}" -maxdepth 1 -name '*.zip' -print -quit)"
    if [[ -z "${found_zip}" ]]; then
      echo "Downloaded artifact does not contain a firmware zip." >&2
      exit 1
    fi
    cp "${found_zip}" "${ZIP_FILE}"
    rm -rf "${tmp_dir}"
  fi

  echo "Extracting merged binary from ${ZIP_FILE}"
  unzip -p "${ZIP_FILE}" merged-binary.bin > "${FIRMWARE}"
fi

if [[ -z "${PORT}" ]]; then
  PORTS=()
  while IFS= read -r candidate; do
    PORTS+=("${candidate}")
  done < <(ls /dev/cu.usb* /dev/cu.SLAB* /dev/cu.wchusb* /dev/cuwchusb* 2>/dev/null || true)
  if [[ "${#PORTS[@]}" -eq 1 ]]; then
    PORT="${PORTS[0]}"
  else
    echo "Usage: $0 /dev/cu.YOUR_ESP32_PORT" >&2
    echo "Detected candidate ports:" >&2
    printf '  %s\n' "${PORTS[@]:-<none>}" >&2
    exit 1
  fi
fi

echo "Flashing ${FIRMWARE}"
echo "Port: ${PORT}"
echo "Baud: ${BAUD}"

esptool.py --chip esp32s3 -p "${PORT}" -b "${BAUD}" write_flash 0x0 "${FIRMWARE}"
