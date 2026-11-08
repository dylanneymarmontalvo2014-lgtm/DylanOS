#!/usr/bin/env bash
# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.

set -euo pipefail

dylanos_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
dylanos_mode="${1:-diagnostic}"
dylanos_jobs="${DYLANOS_BUILD_JOBS:-1}"
dylanos_log_dir="${DYLANOS_BUILD_LOG_DIR:-${dylanos_root}/artifacts/phase-2}"

case "$dylanos_mode" in
    diagnostic)
        dylanos_build_mode=dev
        ;;
    candidate)
        dylanos_build_mode=release
        ;;
    *)
        printf 'Uso: %s [diagnostic|candidate]\n' "$0" >&2
        exit 2
        ;;
esac

mkdir -p "$dylanos_log_dir"
cd "$dylanos_root"

export SURFER_PLATFORM=linux
export SURFER_COMPAT=x86_64
export ZEN_GA_DISABLE_PGO=1

npm run check:environment
npm run surfer -- set brand release
npm run surfer -- set buildMode "$dylanos_build_mode"

if test "$dylanos_mode" = candidate; then
    export ZEN_RELEASE=1
else
    unset ZEN_RELEASE || true
fi

set -o pipefail
dylanos_started_at=$SECONDS
/usr/bin/time -v \
    npm run build -- --jobs "$dylanos_jobs" \
    2>&1 | tee "${dylanos_log_dir}/build-${dylanos_mode}.log"
dylanos_elapsed_seconds=$((SECONDS - dylanos_started_at))

python3 scripts/dylanos/write_build_artifact.py \
    --mode "$dylanos_mode" \
    --elapsed-seconds "$dylanos_elapsed_seconds" \
    --log "${dylanos_log_dir}/build-${dylanos_mode}.log" \
    --output "${dylanos_log_dir}/build-${dylanos_mode}.json"

printf 'Build %s terminado. Log: %s\n' \
    "$dylanos_mode" \
    "${dylanos_log_dir}/build-${dylanos_mode}.log"
