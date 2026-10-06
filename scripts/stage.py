#!/usr/bin/env python3
"""Install DylanOS into an explicit staging root, never the host."""
import argparse
from pathlib import Path
import shutil
import re

ROOT = Path(__file__).resolve().parent.parent


def stage(destination):
    dest = Path(destination).resolve()
    if dest == Path("/") or dest == ROOT or dest in ROOT.parents:
        raise ValueError("El destino debe ser un directorio de staging independiente.")
    dest.mkdir(parents=True, exist_ok=True)

    def copy(source, target):
        source, target = ROOT / source, dest / target.lstrip("/")
        target.parent.mkdir(parents=True, exist_ok=True)
        if source.is_dir():
            shutil.copytree(source, target, dirs_exist_ok=True, ignore=shutil.ignore_patterns("__pycache__", "*.pyc", "tests"))
        else:
            shutil.copy2(source, target)

    def write(target, text, mode=0o644):
        target = dest / target.lstrip("/")
        target.parent.mkdir(parents=True, exist_ok=True)
        target.write_text(text, encoding="utf-8")
        target.chmod(mode)

    for source, target in [
        ("apps/workspace", "/usr/share/dylanos/workspace"),
        ("branding/logo.png", "/usr/share/icons/hicolor/512x512/apps/distributor-logo-dylanos.png"),
        ("branding/wallpapers/DylanOS-Dark.png", "/usr/share/wallpapers/DylanOS/DylanOS-Dark.png"),
        ("branding/wallpapers/DylanOS-Light.png", "/usr/share/wallpapers/DylanOS/DylanOS-Light.png"),
        ("themes/colors", "/usr/share/color-schemes"),
        ("themes/plasma/DylanOS-Tahoe", "/usr/share/plasma/desktoptheme/DylanOS-Tahoe"),
        ("themes/aurorae/DylanOS-Tahoe", "/usr/share/aurorae/themes/DylanOS-Tahoe"),
        ("themes/aurorae/DylanOS-Tahoe-Light", "/usr/share/aurorae/themes/DylanOS-Tahoe-Light"),
        ("themes/lookandfeel/org.dylanos.tahoe", "/usr/share/plasma/lookandfeel/org.dylanos.tahoe"),
        ("themes/sddm/DylanOS-Tahoe", "/usr/share/sddm/themes/DylanOS-Tahoe"),
        ("themes/grub/DylanOS-Grub", "/usr/share/grub/themes/dylanos"),
        ("themes/plymouth/DylanOS-Plymouth", "/usr/share/plymouth/themes/dylanos"),
        ("configs/plasma/skel", "/etc/skel/.config"),
        ("branding/wallpapers/DylanOS-Dark.png", "/usr/share/grub/themes/dylanos/background.png"),
    ]:
        copy(source, target)
    globals_path = dest / "etc/skel/.config/kdeglobals"
    scheme = (ROOT / "themes/colors/DylanOSDark.colors").read_text()
    with globals_path.open("a") as handle:
        handle.write("\n" + scheme[scheme.index("[Colors:"):])
    write("/usr/bin/dylanos", '#!/bin/sh\nexec /usr/bin/python3 /usr/share/dylanos/workspace/main.py "$@"\n', 0o755)
    for key, name, icon, category in [
        ("welcome", "Bienvenido a DylanOS", "distributor-logo-dylanos", "Utility"),
        ("files", "Archivos", "system-file-manager", "System;FileTools;FileManager"),
        ("notes", "Notas", "accessories-text-editor", "Utility;TextEditor"),
        ("dev", "Desarrollo DylanOS", "applications-development", "Development"),
        ("monitor", "Monitor DylanOS", "utilities-system-monitor", "System;Monitor"),
        ("store", "Software DylanOS", "system-software-install", "Settings;PackageManager"),
        ("settings", "Ajustes DylanOS", "preferences-system", "Settings"),
    ]:
        write(f"/usr/share/applications/org.dylanos.{key}.desktop", f"[Desktop Entry]\nType=Application\nName={name}\nExec=dylanos --page {key}\nIcon={icon}\nTerminal=false\nCategories={category};\nStartupNotify=true\n")
    write("/etc/xdg/autostart/dylanos-welcome.desktop", "[Desktop Entry]\nType=Application\nName=Bienvenido a DylanOS\nExec=dylanos-welcome\nIcon=distributor-logo-dylanos\nOnlyShowIn=KDE;\n")
    write("/usr/bin/dylanos-welcome", '''#!/bin/sh
state="${XDG_STATE_HOME:-$HOME/.local/state}/dylanos"
if [ ! -e "$state/welcome-seen" ]; then
    mkdir -p "$state"
    if dylanos --page welcome; then touch "$state/welcome-seen"; fi
fi
''', 0o755)
    write("/etc/sddm.conf.d/10-dylanos.conf", "[Theme]\nCurrent=DylanOS-Tahoe\nCursorTheme=breeze_cursors\n\n[General]\nInputMethod=\n")
    write("/etc/default/grub.d/dylanos.cfg", 'GRUB_DISTRIBUTOR="DylanOS"\nGRUB_THEME="/usr/share/grub/themes/dylanos/theme.txt"\nGRUB_CMDLINE_LINUX_DEFAULT="quiet splash"\n')
    write("/etc/hostname", "dylanos\n")
    write("/etc/hosts", "127.0.0.1 localhost\n127.0.1.1 dylanos\n::1 localhost ip6-localhost ip6-loopback\n")
    write("/etc/dylanos-release", "DylanOS 1.0 Beta\nBase: Debian 13 (trixie)\n")
    write("/usr/lib/os-release", 'PRETTY_NAME="DylanOS 1.0 Beta"\nNAME="DylanOS"\nID=dylanos\nID_LIKE=debian\nVERSION_ID="1.0"\nVERSION="1.0 Beta (trixie)"\nVERSION_CODENAME=trixie\nHOME_URL="https://github.com/dylanneymarmontalvo2014-lgtm/DylanOS"\n')
    calamares = dest / "etc/calamares/settings.conf"
    if calamares.exists():
        content = re.sub(r"(?m)^branding:.*$", "branding: dylanos", calamares.read_text())
        # The image already contains both GRUB targets and cryptsetup. Debian's
        # media jobs expect a live-build APT mirror, which this ISO does not have.
        content = re.sub(r"(?m)^\s+- (sources-media|sources-media-unmount|sources-final|bootloader-config)\s*$", "", content)
        calamares.write_text(content)
    write("/etc/initramfs-tools/conf.d/dylanos-permissions", "UMASK=0077\n")
    write("/usr/share/applications/calamares-install-debian.desktop", "[Desktop Entry]\nType=Application\nName=Instalar DylanOS\nComment=Instalar DylanOS 1.0 Beta en un disco\nExec=calamares-install-debian\nIcon=distributor-logo-dylanos\nTerminal=false\nCategories=System;\nStartupWMClass=calamares\nStartupNotify=true\n")
    write("/etc/calamares/modules/welcome.conf", "---\nshowSupportUrl: true\nshowKnownIssuesUrl: true\nshowReleaseNotesUrl: true\nrequirements:\n  requiredStorage: 25\n  requiredRam: 2.0\n  check: [storage, ram, power, root]\n  required: [storage, ram, root]\n")
    copy("installer/calamares/beta", "/etc/calamares/branding/dylanos")
    copy("branding/logo.png", "/etc/calamares/branding/dylanos/logo.png")
    branding_desc = dest / "etc/calamares/branding/dylanos/branding.desc"
    branding_content = branding_desc.read_text(encoding="utf-8")
    branding_content = re.sub(r"(?m)^(\s*product(?:Logo|Icon):\s*)\S+\s*$", r"\1logo.png", branding_content)
    branding_desc.write_text(branding_content, encoding="utf-8")
    copy("branding/wallpapers/DylanOS-Dark.png", "/etc/calamares/branding/dylanos/background.png")
    write("/etc/calamares/modules/unpackfs.conf", '---\nunpack:\n  - source: /run/live/medium/live/filesystem.squashfs\n    sourcefs: squashfs\n    destination: ""\n')
    write("/etc/calamares/modules/displaymanager.conf", '---\ndisplaymanagers: [sddm]\nbasicSetup: false\n')
    write("/etc/dpkg/origins/dylanos", "Vendor: DylanOS\nVendor-URL: https://github.com/dylanneymarmontalvo2014-lgtm/DylanOS\nParent: Debian\n")
    print(f"Payload DylanOS instalado en {dest}")


if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument("destination")
    stage(parser.parse_args().destination)
