#!/usr/bin/env python3
"""Install DylanOS into an explicit staging root, never the host."""
import argparse
import os
from pathlib import Path
import shutil
import re

ROOT = Path(__file__).resolve().parent.parent


def stage(destination, installer_dist=None, version=None):
    dest = Path(destination).resolve()
    if dest == Path("/") or dest == ROOT or dest in ROOT.parents:
        raise ValueError("El destino debe ser un directorio de staging independiente.")
    dest.mkdir(parents=True, exist_ok=True)

    def copy(source, target):
        # El frontend recién compilado se copia abajo desde installer_dist;
        # no intentes leer un dist viejo o inexistente dentro del checkout.
        source, target = ROOT / source, dest / target.lstrip("/")
        if source == ROOT / "installer/dylanos-installer/dist":
            if installer_dist is not None:
                return
            if not source.is_dir() and target.is_dir():
                # iso.sh re-stages after build; keep the fresh frontend already
                # copied from /tmp when the checkout intentionally has no dist.
                return
            if not source.is_dir():
                # Static staging/tests can run before npm has built the frontend.
                return
        target.parent.mkdir(parents=True, exist_ok=True)
        if source.is_dir():
            shutil.copytree(source, target, dirs_exist_ok=True, ignore=shutil.ignore_patterns("__pycache__", "*.pyc", "tests"))
        else:
            shutil.copy2(source, target)

    def write(target, text, mode=0o644):
        target = dest / target.lstrip("/")
        target.parent.mkdir(parents=True, exist_ok=True)
        if target.exists():
            target.chmod(0o644)
        target.write_text(text, encoding="utf-8")
        target.chmod(mode)
    def remove(target):
        """Borra un artefacto obsoleto del staging anterior, si existe.

        El staging debe ser idempotente sobre un chroot reutilizado
        (`build.sh --resume`): solo escribir no basta, porque los archivos de
        versiones anteriores permanecerían y provocarían el comportamiento
        viejo (por ejemplo, un autostart del instalador ya eliminado).
        """
        target_path = dest / target.lstrip("/")
        if target_path.is_symlink() or target_path.is_file():
            target_path.unlink()
        elif target_path.is_dir():
            shutil.rmtree(target_path, ignore_errors=True)



    for source, target in [
        ("apps/workspace", "/usr/share/dylanos/workspace"),
        ("branding/logo.png", "/usr/share/dylanos/workspace/assets/logo.png"),
        ("branding/logo.png", "/usr/share/icons/hicolor/512x512/apps/distributor-logo-dylanos.png"),
        ("branding/icons/dylanos-store.png", "/usr/share/icons/hicolor/512x512/apps/dylanos-store.png"),
        ("branding/logo.png", "/usr/share/dylanos/configuration/assets/logo.png"),
        ("branding/wallpapers/dylanos-default.png", "/usr/share/wallpapers/DylanOS/dylanos-default.png"),
        ("branding/wallpapers/DylanOS-Dark.png", "/usr/share/wallpapers/DylanOS/DylanOS-Dark.png"),
        ("branding/wallpapers/DylanOS-Light.png", "/usr/share/wallpapers/DylanOS/DylanOS-Light.png"),
        ("themes/colors", "/usr/share/color-schemes"),
        ("themes/gtk/DylanOS-Crimson-Light", "/usr/share/themes/DylanOS-Crimson-Light"),
        ("themes/gtk/DylanOS-Crimson", "/usr/share/themes/DylanOS-Crimson"),
        ("themes/plasma/DylanOS-Crimson", "/usr/share/plasma/desktoptheme/DylanOS-Crimson"),
        ("themes/aurorae/DylanOS-Crimson", "/usr/share/aurorae/themes/DylanOS-Crimson"),
        ("themes/aurorae/DylanOS-Crimson-Light", "/usr/share/aurorae/themes/DylanOS-Crimson-Light"),
        ("themes/lookandfeel/org.dylanos.crimson", "/usr/share/plasma/look-and-feel/org.dylanos.crimson"),
        ("themes/sddm/DylanOS-Crimson", "/usr/share/sddm/themes/DylanOS-Crimson"),
        ("themes/grub/DylanOS-Grub", "/usr/share/grub/themes/dylanos"),
        ("themes/plymouth/DylanOS-Plymouth", "/usr/share/plymouth/themes/dylanos"),
        ("branding/logo.png", "/usr/share/plymouth/themes/dylanos/logo.png"),
        ("configs/plasma/skel", "/etc/skel/.config"),
        ("branding/wallpapers/DylanOS-Dark.png", "/usr/share/grub/themes/dylanos/background.png"),
        ("apps/dylanos-spotlight", "/usr/share/dylanos/spotlight"),
        ("apps/com.dylanos.activeapp", "/usr/share/plasma/plasmoids/com.dylanos.activeapp"),
        ("apps/com.dylanos.dock", "/usr/share/plasma/plasmoids/com.dylanos.dock"),
        ("apps/com.dylanos.search", "/usr/share/plasma/plasmoids/com.dylanos.search"),
        ("apps/com.dylanos.dashboard", "/usr/share/plasma/plasmoids/com.dylanos.dashboard"),
        ("apps/dylanos-control-center", "/usr/share/plasma/plasmoids/com.dylanos.controlcenter"),
        ("installer/dylanos-installer/dist", "/usr/share/dylanos/installer/dist"),
        ("installer/dylanos-installer/backend", "/usr/share/dylanos/installer/backend"),
        ("installer/dylanos-installer/native", "/usr/share/dylanos/installer/native"),
        ("configs/kitty/kitty.conf", "/etc/skel/.config/kitty/kitty.conf"),
        ("configs/kitty/kitty.conf", "/etc/xdg/kitty/kitty.conf"),
        ("configs/neofetch/config.conf", "/etc/skel/.config/neofetch/config.conf"),
        ("configs/neofetch/config.conf", "/etc/xdg/neofetch/config.conf"),
        ("branding/logo.png", "/usr/share/dylanos/neofetch/logo.png"),
        ("configs/bash/dylanos.bashrc", "/etc/skel/.bashrc"),
        ("configs/bash/dylanos-ghost.sh", "/usr/share/dylanos/shell/dylanos-ghost.sh"),
        ("MAINTAINERS.txt", "/usr/share/dylanos/MAINTAINERS.txt"),
        ("branding/icons/dylanos-console.svg", "/usr/share/icons/hicolor/scalable/apps/dylanos-console.svg"),
        ("branding/icons/dylanos-console.png", "/usr/share/icons/hicolor/512x512/apps/dylanos-console.png"),
    ]:
        copy(source, target)
    legacy_lf = dest / "usr/share/plasma/lookandfeel/org.dylanos.crimson"
    if legacy_lf.is_dir() and not legacy_lf.is_symlink():
        shutil.rmtree(legacy_lf)
    if not legacy_lf.exists() and not legacy_lf.is_symlink():
        legacy_lf.parent.mkdir(parents=True, exist_ok=True)
        try:
            legacy_lf.symlink_to("../look-and-feel/org.dylanos.crimson")
        except FileExistsError:
            pass
    if installer_dist is not None:
        source = Path(installer_dist).resolve()
        index = source / "index.html"
        if not index.is_file() or index.stat().st_size == 0:
            raise FileNotFoundError(
                f"Falta index.html no vacío del frontend del instalador en {source}"
            )
        target = dest / "usr/share/dylanos/installer/dist"
        if target.exists():
            shutil.rmtree(target)
        shutil.copytree(source, target)
    globals_path = dest / "etc/skel/.config/kdeglobals"
    scheme = (ROOT / "themes/colors/DylanOSDark.colors").read_text()
    with globals_path.open("a") as handle:
        handle.write("\n" + scheme[scheme.index("[Colors:"):])
    write("/usr/bin/dylanos", '#!/bin/sh\nexec /usr/bin/python3 /usr/share/dylanos/workspace/main.py "$@"\n', 0o755)
    write("/usr/bin/about", '#!/usr/bin/python3\n"""Show DylanOS maintainers from the project\'s maintained credits file."""\nfrom pathlib import Path\nimport os\nimport re\nimport sys\n\nMAINTAINERS = Path(os.environ.get("DYLANOS_MAINTAINERS_FILE", "/usr/share/dylanos/MAINTAINERS.txt"))\ntry:\n    text = MAINTAINERS.read_text(encoding="utf-8")\nexcept OSError as error:\n    print(f"about: no se pudo leer la lista de mantenedores: {error}", file=sys.stderr)\n    raise SystemExit(1)\nlines = text.splitlines()\nnames = [lines[i + 2].strip() for i in range(len(lines) - 2) if lines[i].strip() == "MANTENEDOR" and lines[i + 1] and set(lines[i + 1]) == {"-"} and lines[i + 2].strip()]\nif not names:\n    print("about: no hay mantenedores registrados.", file=sys.stderr)\n    raise SystemExit(1)\nif len(names) == 1:\n    creditos = names[0]\nelse:\n    creditos = ", ".join(names[:-1]) + " y " + names[-1]\nprint("Gracias a " + creditos + ", podemos mantener este bonito sistema.")\n', 0o755)
    write("/usr/bin/dylanos-spotlight", '#!/bin/sh\nexec /usr/bin/python3 /usr/share/dylanos/spotlight/main.py "$@"\n', 0o755)
    write("/usr/share/applications/org.dylanos.spotlight.desktop", "[Desktop Entry]\nType=Application\nName=DylanOS Spotlight\nGenericName=Búsqueda rápida\nComment=Buscar aplicaciones, proyectos, archivos y cálculos\nExec=dylanos-spotlight\nIcon=system-search\nTerminal=false\nCategories=Utility;\nStartupNotify=false\n")
    write("/usr/bin/dylanos-installer", '''#!/bin/sh
# Instalador nativo de DylanOS: ventana propia de escritorio (Qt WebEngine).
# Ejecuta la aplicación nativa, que arranca su propio backend REST local;
# nunca se abre un navegador externo.
exec /usr/bin/python3 /usr/share/dylanos/installer/native/main.py "$@"
''', 0o755)
    write("/usr/share/applications/dylanos-installer.desktop", "[Desktop Entry]\nType=Application\nName=Instalar DylanOS\nComment=Asistente oficial de instalación de DylanOS\nExec=/usr/bin/dylanos-installer\nTryExec=/usr/bin/dylanos-installer\nIcon=distributor-logo-dylanos\nTerminal=false\nCategories=System;\nStartupNotify=true\nStartupWMClass=dylanos-installer\n")
    # Acceso directo en el escritorio live: Plasma muestra los archivos de
    # XDG_DESKTOP_DIR como iconos de escritorio. Permisos 0o755 para que Plasma
    # lo marque como lanzador de confianza y el usuario pueda hacer doble clic
    # sin el diálogo "¿Ejecutar o mostrar?".
    #
    # La sesión live es un escritorio de vista previa (X11), NO un arranque
    # directo al instalador: por eso el ejecutable queda en el escritorio y NO
    # se añade ninguna entrada a /etc/xdg/autostart. La carpeta de escritorio
    # depende del idioma (xdg-user-dirs: ~/Desktop o ~/Escritorio según el
    # locale), así que el lanzador se escribe en ambas.
    installer_shortcut = (
        "[Desktop Entry]\nType=Application\nName=Instalar DylanOS\n"
        "Comment=Haz doble clic para instalar DylanOS en tu equipo\n"
        "Exec=/usr/bin/dylanos-installer\nTryExec=/usr/bin/dylanos-installer\n"
        "Icon=distributor-logo-dylanos\nTerminal=false\nCategories=System;\n"
        "StartupNotify=true\nStartupWMClass=dylanos-installer\n"
        "X-KDE-SubstituteUID=false\n"
    )
    write("/etc/skel/Desktop/instalar-dylanos.desktop", installer_shortcut, 0o755)
    write("/etc/skel/Escritorio/instalar-dylanos.desktop", installer_shortcut, 0o755)
    # El instalador ya NO se autoejecuta en la sesión live (es un escritorio de
    # vista previa). Se elimina la entrada de autostart de builds anteriores:
    # sin este borrado, un chroot reutilizado la conservaría y el instalador
    # seguiría abriéndose solo.
    remove("/etc/xdg/autostart/dylanos-installer.desktop")
    # La tienda nativa (dylanos-store) reemplaza a plasma-discover: los
    # chroots reutilizados pueden conservar entradas obsoletas de Discover.
    remove("/usr/share/applications/org.kde.discover.desktop")
    remove("/usr/share/applications/org.kde.discover.urlhandler.desktop")
    remove("/usr/share/applications/org.kde.discover.snap.desktop")
    remove("/usr/share/applications/org.kde.discover.apt.urlhandler.desktop")
    remove("/usr/share/applications/org.kde.discover.notifier.desktop")
    remove("/usr/share/applications/plasma-discover.desktop")
    remove("/etc/xdg/autostart/org.kde.discover.notifier.desktop")
    # Un solo explorador y una sola calculadora: los .desktop de dolphin y
    # kcalc no deben existir (build.sh purga los paquetes; esto cubre chroots
    # reutilizados de builds anteriores).
    remove("/usr/share/applications/org.kde.dolphin.desktop")
    remove("/usr/share/applications/org.kde.kcalc.desktop")
    # DylanOS Console (Kitty) sustituye a Konsole y al lanzador genérico de Kitty.
    remove("/usr/share/applications/org.kde.konsole.desktop")
    remove("/usr/share/applications/konsole.desktop")
    # Artefactos de Konsole/fastfetch en chroots reutilizados.
    remove("/etc/skel/.config/konsolerc")
    remove("/etc/skel/.local/share/konsole/DylanOS.profile")
    remove("/etc/skel/.local/share/konsole/DylanOS-Crimson.colorscheme")
    remove("/etc/skel/.config/fastfetch/config.jsonc")
    remove("/usr/share/dylanos/fastfetch/logo.txt")
    # DylanOS Configuration sustituye al lanzador del workspace "Ajustes DylanOS"
    # (dylanos --page settings): la entrada obsoleta no debe volver a aparecer.
    remove("/usr/share/applications/org.dylanos.settings.desktop")
    # "Archivos" siempre es DylanOS Explorer (binario real). La entrada
    # org.dylanos.files.desktop de builds anteriores abría el workspace en su
    # página de archivos en lugar del gestor: es un artefacto obsoleto y no
    # debe volver a aparecer en chroots reutilizados.
    remove("/usr/share/applications/org.dylanos.files.desktop")
    for key, name, icon, category in [
        ("welcome", "Bienvenido a DylanOS", "distributor-logo-dylanos", "Utility"),
        ("notes", "Notas", "accessories-text-editor", "Utility;TextEditor"),
        ("dev", "Desarrollo DylanOS", "applications-development", "Development"),
        ("monitor", "Monitor DylanOS", "utilities-system-monitor", "System;Monitor"),
        ("store", "DylanOS Store", "dylanos-store", "Settings;PackageManager"),
    ]:
        if key == "store":
            write("/usr/share/applications/org.dylanos.store.desktop", f"[Desktop Entry]\nType=Application\nName={name}\nComment=Descubre e instala aplicaciones\nExec=dylanos-store\nStartupWMClass=dylanos-store\nIcon={icon}\nTerminal=false\nCategories={category};\nStartupNotify=true\n")
        else:
            write(f"/usr/share/applications/org.dylanos.{key}.desktop", f"[Desktop Entry]\nType=Application\nName={name}\nExec=dylanos --page {key}\nStartupWMClass=org.dylanos.{key}\nIcon={icon}\nTerminal=false\nCategories={category};\nStartupNotify=true\n")
    # La entrada "Archivos" del menú abre el gestor real, nunca una página del
    # workspace (el fallback anterior usaba "dylanos --page explorer", una
    # página que no existe y moría sin abrir nada). Se copia el .desktop
    # canónico del Explorer: el CMake del build vuelve a instalar el mismo
    # archivo después del staging (fallback idempotente).
    copy("apps/dylanos-explorer/assets/org.dylanos.explorer.desktop",
         "/usr/share/applications/org.dylanos.explorer.desktop")
    write("/usr/bin/dylanos-console",
          "#!/bin/sh\n"
          "exec kitty --class org.dylanos.console --title \"DylanOS Console\" \"$@\"\n",
          0o755)
    write("/usr/bin/neofetch",
          "#!/bin/sh\n"
          "config=\"${XDG_CONFIG_HOME:-${HOME:-/root}/.config}/neofetch/config.conf\"\n"
          "[ -r \"$config\" ] || config=/etc/xdg/neofetch/config.conf\n"
          "exec /usr/bin/neowofetch --config \"$config\" \"$@\"\n",
          0o755)
    write("/usr/share/applications/org.dylanos.console.desktop",
          "[Desktop Entry]\nType=Application\nName=DylanOS Console\n"
          "GenericName=Terminal\nComment=Terminal oficial de DylanOS\n"
          "Exec=dylanos-console\nTryExec=kitty\nIcon=dylanos-console\n"
          "Terminal=false\nCategories=System;TerminalEmulator;\n"
          "StartupNotify=true\nStartupWMClass=org.dylanos.console\n"
          "Keywords=terminal;console;shell;kitty;\n")
    # DylanOS Configuration: única aplicación de configuración visible.
    # Fallback idempotente previo al build; CMake instala la canónica después.
    write("/usr/share/applications/org.dylanos.configuration.desktop",
          "[Desktop Entry]\nType=Application\nName=DylanOS Configuration\nGenericName=Configuración del sistema\n"
          "Comment=Configura DylanOS Crimson y KDE Plasma\nExec=dylanos-configuration\n"
          "StartupWMClass=org.dylanos.configuration\nIcon=dylanos-configuration\n"
          "Terminal=false\nCategories=Settings;\nStartupNotify=true\n")
    # Iconos propios de la app (existen tras compilarla: los genera CMake y el
    # script de preparación de recursos; se instalan solo si están presentes).
    if (ROOT / "apps/dylanos-configuration/assets/dylanos-configuration.png").exists():
        copy("apps/dylanos-configuration/assets/dylanos-configuration.png",
             "/usr/share/icons/hicolor/512x512/apps/dylanos-configuration.png")
    if (ROOT / "apps/dylanos-configuration/assets/dylanos-configuration.svg").exists():
        copy("apps/dylanos-configuration/assets/dylanos-configuration.svg",
             "/usr/share/icons/hicolor/scalable/apps/dylanos-configuration.svg")
    # Una sola aplicación de configuración visible: se ocultan (NoDisplay) las
    # entradas de menú duplicadas SIN tocar binarios ni módulos KCM de KDE, que
    # DylanOS Configuration sigue usando como base funcional (kcmshell/KCM).
    def hide_duplicate(target):
        entry = dest / target.lstrip("/")
        if entry.exists():
            entry.write_text("[Desktop Entry]\nType=Application\nNoDisplay=true\n", encoding="utf-8")
    for duplicate in [
        "/usr/share/applications/systemsettings.desktop",
        "/usr/share/applications/kdesystemsettings.desktop",
        "/usr/share/applications/org.kde.plasma.settings.open.desktop",
        "/usr/share/applications/org.kde.kinfocenter.desktop",
        "/usr/share/applications/org.gnome.Settings.desktop",
        "/usr/share/applications/xfce-settings-manager.desktop",
        "/usr/share/applications/lightdm-settings.desktop",
        "/usr/share/applications/kitty.desktop",
        "/usr/share/applications/kitty-open.desktop",
    ]:
        hide_duplicate(duplicate)
    write("/usr/bin/dylanos-welcome", '''#!/bin/sh
state="${XDG_STATE_HOME:-$HOME/.local/state}/dylanos"
if [ ! -e "$state/welcome-seen" ]; then
    mkdir -p "$state"
    if dylanos --page welcome; then touch "$state/welcome-seen"; fi
fi
''', 0o755)
    write("/etc/sddm.conf.d/10-dylanos.conf", "[Theme]\nCurrent=DylanOS-Crimson\nCursorTheme=breeze_cursors\n\n[General]\nInputMethod=\n\n[Autologin]\nUser=dylan\nSession=plasmax11.desktop\nRelogin=false\n")
    # En el sistema instalado el GRUB no debe mostrar menú: arranca DylanOS
    # directamente. El menú del LIVE lo genera scripts/iso.sh (timeout=10).
    # DylanOS Explorer es el gestor de archivos predeterminado del sistema:
    # cualquier "Abrir carpeta" (navegador, GTK, Qt) lo abre él.
    write("/usr/share/applications/mimeapps.list",
          "[Default Applications]\ninode/directory=org.dylanos.explorer.desktop;\nx-directory/normal=org.dylanos.explorer.desktop;\n")
    write("/etc/default/grub.d/dylanos.cfg", 'GRUB_DISTRIBUTOR="DylanOS"\nGRUB_THEME="/usr/share/grub/themes/dylanos/theme.txt"\nGRUB_CMDLINE_LINUX_DEFAULT="quiet splash"\nGRUB_TIMEOUT=0\nGRUB_TIMEOUT_STYLE=hidden\n')
    write("/etc/sudoers.d/dylan", "dylan ALL=(ALL) NOPASSWD: ALL\n", 0o440)
    passwd_path = dest / "etc/passwd"
    if passwd_path.exists() and "dylan:" not in passwd_path.read_text(encoding="utf-8"):
        with passwd_path.open("a", encoding="utf-8") as f:
            f.write("dylan:x:1000:1000:DylanOS Live:/home/dylan:/bin/bash\n")
    shadow_path = dest / "etc/shadow"
    if shadow_path.exists() and "dylan:" not in shadow_path.read_text(encoding="utf-8"):
        with shadow_path.open("a", encoding="utf-8") as f:
            f.write("dylan::19700:0:99999:7:::\n")
    group_path = dest / "etc/group"
    if group_path.exists():
        grp_content = group_path.read_text(encoding="utf-8")
        if "dylan:" not in grp_content:
            grp_content += "dylan:x:1000:\n"
        for grp in ["sudo", "audio", "video", "render", "netdev", "plugdev", "input", "users"]:
            grp_content = re.sub(rf"(?m)^({grp}:x:\d+:)(.*)$", lambda m: f"{m.group(1)}{m.group(2) + ',' if m.group(2) and not m.group(2).endswith(',') else m.group(2)}dylan" if "dylan" not in m.group(2) else m.group(0), grp_content)
        group_path.write_text(grp_content, encoding="utf-8")
    home_dylan = dest / "home/dylan"
    home_dylan.mkdir(parents=True, exist_ok=True)
    if (dest / "etc/skel").exists():
        shutil.copytree(dest / "etc/skel", home_dylan, dirs_exist_ok=True)
    if os.geteuid() == 0:
        for p in [home_dylan] + list(home_dylan.rglob("*")):
            os.chown(p, 1000, 1000)
    xsessions_dir = dest / "usr/share/xsessions"
    if (xsessions_dir / "plasmax11.desktop").exists() and not (xsessions_dir / "plasma.desktop").exists():
        try:
            (xsessions_dir / "plasma.desktop").symlink_to("plasmax11.desktop")
        except FileExistsError:
            pass
    # Patch live-config's 0085-sddm to use plasmax11.desktop explicitly for
    # Plasma 6 on Trixie.  The default "plasma.desktop" resolves to the Wayland
    # session first, which fails on VMs without GPU acceleration (TCG).
    sddm_hook = dest / "lib/live/config/0085-sddm"
    if sddm_hook.exists():
        hook_text = sddm_hook.read_text(encoding="utf-8")
        hook_text = hook_text.replace(
            'LIVE_SESSION="plasma.desktop"',
            'LIVE_SESSION="plasmax11.desktop"',
        )
        sddm_hook.write_text(hook_text, encoding="utf-8")
    # SDDM override: explicitly conflict with plymouth-quit-wait and quit plymouth
    # so SDDM never hangs behind Plymouth on physical hardware or QEMU.
    write(
        "/etc/systemd/system/sddm.service.d/override.conf",
        "[Unit]\nConflicts=plymouth-quit-wait.service\nAfter=plymouth-start.service\nOnFailure=plymouth-quit.service\n\n[Service]\nExecStartPre=-/usr/bin/plymouth quit\n",
    )
    sddm_target_link = dest / "etc/systemd/system/graphical.target.wants/sddm.service"
    if not sddm_target_link.exists():
        sddm_target_link.parent.mkdir(parents=True, exist_ok=True)
        try:
            sddm_target_link.symlink_to("/lib/systemd/system/sddm.service")
        except FileExistsError:
            pass
    write("/etc/hostname", "dylanos\n")
    write("/etc/hosts", "127.0.0.1 localhost\n127.0.1.1 dylanos\n::1 localhost ip6-localhost ip6-loopback\n")
    version = (version or os.environ.get("DYLANOS_VERSION", "1.0-beta")).strip()
    if not re.fullmatch(r"[0-9]+\.[0-9]+\.[0-9]+(?:[-+][A-Za-z0-9.-]+)?|1\.0-beta", version):
        raise ValueError(f"Versión DylanOS inválida: {version!r}")
    version_label = "1.0 Beta" if version == "1.0-beta" else version
    version_id = "1.0" if version == "1.0-beta" else version.split("+", 1)[0]
    write("/etc/dylanos-release", f"DylanOS {version_label}\nBase: Debian 13 (trixie)\n")
    write("/usr/lib/os-release", f'PRETTY_NAME="DylanOS {version_label}"\nNAME="DylanOS"\nID=dylanos\nID_LIKE=debian\nVERSION_ID="{version_id}"\nVERSION="{version_label} (trixie)"\nVERSION_CODENAME=trixie\nHOME_URL="https://github.com/dylanneymarmontalvo2014-lgtm/DylanOS"\n')
    # DylanOS usa su instalador propio (installer/dylanos-installer);
    # Calamares ya no forma parte de la imagen.
    write("/etc/initramfs-tools/conf.d/dylanos-permissions", "UMASK=0077\n")
    write("/etc/dpkg/origins/dylanos", "Vendor: DylanOS\nVendor-URL: https://github.com/dylanneymarmontalvo2014-lgtm/DylanOS\nParent: Debian\n")
    print(f"Payload DylanOS instalado en {dest}")


if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument("destination")
    parser.add_argument("--installer-dist", type=Path)
    parser.add_argument("--version")
    args = parser.parse_args()
    stage(args.destination, args.installer_dist, args.version)
