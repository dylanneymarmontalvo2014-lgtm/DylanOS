# DylanOS Configuration

Unica aplicacion de configuracion visible en DylanOS Crimson. Basada en la
arquitectura de KDE System Settings (modulos KCM + kcmshell) con un frontend
Qt6/QML que replica el prototipo previews/DylanOS configuration.

## Arquitectura

- src/main.cpp: CLI (--page, --smoke, --screenshot) y registro del singleton System.
- src/services/SystemService: puente con el sistema real (ver tabla siguiente).
- src/services/LucideProvider: proveedor image://lucide que recolorea los SVG
  Lucide de assets/icons/ en tiempo de ejecucion.
- qml/Theme.qml: tokens visuales alineados con el Crimson oficial #DC143C / #FF4565 / #A50F2E, radios, superficies
  glass, modo oscuro/claro detectado de kdeglobals con QFileSystemWatcher).
- qml/components/: IconTile, Toggle, Slider, Select, Segmented, Tabs,
  Group/Panel/Row, Badge, Dialog, EmptyState, ErrorBanner, Meter, Toast...
  equivalentes 1:1 a src/components/ui.tsx del prototipo.
- qml/pages/: las 16 rutas del prototipo (System, About, Personalization,
  Network, Bluetooth, Apps, Accounts, DateTime, Privacy, Power, Accessibility,
  Updates, Display, Sound, Notifications, Storage).

## Funciones reales vs. delegadas

- Sistema / Acerca de: datos reales (/proc, /sys, os-release, QStorageInfo).
- Personalizacion: tema oscuro/claro, acento y fondo reales; iconos, fuentes,
  look-and-feel y escritorio abren sus KCM nativos.
- Red: Wi-Fi on/off, listado y conexion reales (nmcli); VPN/proxy/DNS abren
  kcm_networkmanagement.
- Bluetooth: encendido, conectar/desconectar y olvidar reales (bluetoothctl).
- Sonido: volumenes, silencio y dispositivos reales (pactl).
- Pantalla: brillo real (DBus powerdevil) y resolucion actual (xrandr);
  escala/orientacion abren kcm_kscreen.
- Energia: perfil (powerprofilesctl) y bateria (/sys) reales.
- Hora e idioma: NTP y zona horaria reales (timedatectl/pkexec).
- Aplicaciones: instaladas reales (XDG) y predeterminadas (xdg-settings/mime).
- Cuentas: usuario real y cierre de sesion (ksmserver); usuarios abre kcm_users.
- Privacidad: bloqueo de pantalla real (kconfig); permisos honestos
  ("Pendiente"); DylanOS no incluye telemetria.
- Notificaciones: modulo nativo kcm_notifications.
- Accesibilidad: abre los KCM nativos; lector de pantalla honesto.
- Actualizaciones: abre DylanOS Store (--mode Update).
- Almacenamiento: disco real, papelera (gio) y apt clean (pkexec).

Las filas marcadas "Pendiente" no simulan exito: muestran su estado real o
abren el modulo nativo que si implementa la funcion.

## Duplicados eliminados

scripts/stage.py oculta con NoDisplay=true (sin borrar binarios ni KCM):
systemsettings.desktop, kdesystemsettings.desktop,
org.kde.plasma.settings.open.desktop, org.kde.kinfocenter.desktop,
org.gnome.Settings.desktop, xfce-settings-manager.desktop y
lightdm-settings.desktop. El dock y el workspace abren dylanos-configuration.

## Recursos

- Logo oficial: branding/logo.png se incrusta en el binario
  (qrc:/assets/logo.png); scripts/build.sh lo copia al arbol fuente.
- Icono de app: assets/dylanos-configuration.svg (maestro) y su variante PNG
  512 en hicolor (generada con rsvg-convert).

## QA

    cmake -S apps/dylanos-configuration -B /tmp/build-config -GNinja
    cmake --build /tmp/build-config
    QT_QPA_PLATFORM=offscreen ./build-config/dylanos-configuration --smoke
    DYLANOS_PYTHON=/tmp/opencode/venv/bin/python bash scripts/check.sh
