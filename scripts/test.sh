#!/usr/bin/env bash
set -Eeuo pipefail

ROOT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

for script in scripts/*.sh; do
  bash -n "$script"
done
bash -n "$ROOT_DIR/install-deps.sh"

info_tool="$ROOT_DIR/configs/system/rootfs/usr/bin/dylanos-info"
wallpaper_tool="$ROOT_DIR/configs/system/rootfs/usr/bin/dylanos-wallpaper"
[[ -f "$info_tool" ]] || { printf 'Missing executable: %s\\n' "$info_tool" >&2; exit 1; }
sh "$info_tool" --help >/dev/null
[[ -f "$wallpaper_tool" ]] || { printf 'Missing system command: wallpaper helper\\n' >&2; exit 1; }
sh "$wallpaper_tool" --help >/dev/null
sh "$info_tool" --version | grep -q '^DylanOS'
if sh "$info_tool" --unsupported >/dev/null 2>&1; then
  printf 'dylanos-info unexpectedly accepted an invalid option\\n' >&2
  exit 1
fi
if sh "$wallpaper_tool" --unsupported >/dev/null 2>&1; then
  printf 'dylanos-wallpaper accepted an invalid option\\n' >&2
  exit 1
fi

python3 - <<'PY'
from pathlib import Path
import re
import struct
import xml.etree.ElementTree as ET

root = Path('.')
required_dirs = [
    'branding/icons', 'branding/splash', 'branding/wallpapers',
    'configs/bash', 'configs/plasma', 'configs/system', 'configs/zsh',
    'installer/calamares', 'packages/default', 'packages/development',
    'packages/gaming', 'packages/iot', 'themes/grub', 'themes/gtk',
    'themes/plasma', 'themes/sddm',
]
errors = []
for name in required_dirs:
    path = root / name
    if not path.is_dir() or not any(p.is_file() and p.name != '.gitkeep' for p in path.rglob('*')):
        errors.append(f'no implementation files in {name}')

markers = list(root.rglob('.gitkeep'))
if markers:
    errors.append('placeholder markers remain: ' + ', '.join(str(p) for p in markers))

for package_file in sorted((root / 'packages').glob('*/packages.list')):
    names = []
    for line_no, line in enumerate(package_file.read_text().splitlines(), 1):
        item = line.split('#', 1)[0].strip()
        if not item:
            continue
        if not re.fullmatch(r'[a-z0-9][a-z0-9+.-]*', item):
            errors.append(f'{package_file}:{line_no}: invalid package name {item!r}')
        names.append(item)
    if not names:
        errors.append(f'empty package list: {package_file}')
    if len(names) != len(set(names)):
        errors.append(f'duplicate package names in {package_file}')

for svg in sorted(root.rglob('*.svg')):
    try:
        ET.parse(svg)
    except ET.ParseError as exc:
        errors.append(f'invalid SVG {svg}: {exc}')

for png in [root / 'branding/splash/dylanos.png', root / 'branding/wallpapers/dylanos.png', root / 'themes/grub/background.png']:
    try:
        with png.open('rb') as stream:
            header = stream.read(24)
        if len(header) != 24 or header[:8] != b'\x89PNG\r\n\x1a\n':
            errors.append(f'invalid PNG header: {png}')
        else:
            width, height = struct.unpack('>II', header[16:24])
            if width < 1 or height < 1:
                errors.append(f'invalid PNG dimensions: {png}')
    except OSError as exc:
        errors.append(f'missing image {png}: {exc}')

for name in ['installer/calamares/settings.conf', 'installer/calamares/modules/unpackfs.conf', 'themes/grub/theme.txt']:
    if not (root / name).is_file() or (root / name).stat().st_size == 0:
        errors.append(f'missing or empty required config: {name}')

# Calamares expects a sequence of grouped show/exec phases, each containing
# module names, rather than a separate YAML mapping for every module.
settings = (root / 'installer/calamares/settings.conf').read_text().splitlines()
try:
    sequence_start = settings.index('sequence:')
    phase_lines = [line for line in settings[sequence_start + 1:] if line.startswith('  - ')]
    if phase_lines != ['  - show:', '  - exec:', '  - show:']:
        errors.append('Calamares sequence must group its show, exec, and finished phases')
    expected_modules = [
        '      - welcome', '      - locale', '      - keyboard', '      - partition',
        '      - users', '      - summary', '      - partition', '      - mount',
        '      - unpackfs', '      - machineid', '      - fstab', '      - locale',
        '      - keyboard', '      - localecfg', '      - users', '      - displaymanager',
        '      - networkcfg', '      - hwclock', '      - bootloader', '      - umount',
        '      - finished',
    ]
    actual_modules = [line for line in settings[sequence_start + 1:] if line.startswith('      - ')]
    if actual_modules != expected_modules:
        errors.append('Calamares sequence is missing or misordering required view/job modules')
except ValueError:
    errors.append('Calamares settings has no sequence section')

if errors:
    print('DylanOS checks failed:')
    for error in errors:
        print(f' - {error}')
    raise SystemExit(1)
print('DylanOS static checks passed.')
PY
