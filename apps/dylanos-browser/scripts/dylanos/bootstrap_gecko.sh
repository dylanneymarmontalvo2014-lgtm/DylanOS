#!/usr/bin/env bash
# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.

set -euo pipefail

dylanos_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
dylanos_log_dir="${DYLANOS_BOOTSTRAP_LOG_DIR:-${dylanos_root}/artifacts/bootstrap}"
dylanos_cargo_bin="$(python3 -c 'from pathlib import Path; print(Path.home() / ".cargo" / "bin")')"

mkdir -p "$dylanos_log_dir"
cd "$dylanos_root"

dylanos_run_logged() {
    local dylanos_log_name="$1"
    shift
    "$@" 2>&1 | tee "${dylanos_log_dir}/${dylanos_log_name}.log"
}

dylanos_run_logged environment-check npm run check:environment
dylanos_run_logged environment-before \
    npm run manifest:environment -- \
    --output "${dylanos_log_dir}/environment-before-bootstrap.json"
dylanos_run_logged npm-ci npm ci
dylanos_run_logged download npm run download
dylanos_run_logged import npm run import
dylanos_run_logged bootstrap npm run bootstrap
dylanos_run_logged environment-after \
    npm run manifest:environment -- \
    --output "${dylanos_log_dir}/environment.json" \
    --require-clang
dylanos_run_logged surfer-brand npm run surfer -- set brand release
dylanos_run_logged surfer-build-mode npm run surfer -- set buildMode dev
dylanos_run_logged mozconfig env SURFER_MOZCONFIG_ONLY=1 npm run build

pushd "${dylanos_root}/engine" >/dev/null
dylanos_run_logged configure ./mach configure
popd >/dev/null

dylanos_run_logged lint env \
    PATH="${dylanos_cargo_bin}:${PATH}" \
    npm run lint

npm run test:dylanos
npm run lc
npm audit --omit=dev

printf 'Bootstrap de Gecko verificado. Evidencias: %s\n' "$dylanos_log_dir"
