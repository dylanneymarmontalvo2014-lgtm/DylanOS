# Recursos y procedencia

- Fondos `DylanOS-Dark.png` y `DylanOS-Light.png`, esquemas de color, SVG de Plasma
  y Aurorae, QML de Workspace y nuevo login: creados para este repositorio,
  bajo GPL-3.0-or-later. Generador: `scripts/lib/generate-theme.py`.
- Logo de DylanOS: recurso preexistente `branding/logo.png`, conservado.
- Inter, Breeze, cursores, aplicaciones y firmware: paquetes oficiales de Debian;
  sus licencias se incluyen en `/usr/share/doc/<paquete>/copyright` en la imagen.
- VSCodium se obtiene de su repositorio externo con `Signed-By` independiente.
- El tema SDDM anterior, su fuente SFUIText y sus recursos se conservan en el
  repositorio, pero **no se copian a la imagen beta**. El login nuevo usa Inter.
- No se incorporaron fondos, iconos, fuentes ni código extraídos de macOS.

Referencias de implementación:

- [Aurorae](https://develop.kde.org/docs/plasma/aurorae/)
- [Temas y plugins Plasma](https://develop.kde.org/docs/plasma/)
- [API de layout Plasma](https://develop.kde.org/docs/plasma/scripting/api/)
- [Calamares para derivados de Debian](https://packages.debian.org/trixie/calamares-settings-debian)
- [Diseño de macOS Tahoe](https://www.apple.com/newsroom/2025/06/apple-introduces-a-delightful-and-elegant-new-software-design/)

La clave `configs/keys/debian-trixie.asc` se obtuvo de
https://ftp-master.debian.org/keys/archive-key-13.asc. Huella primaria verificada:
`04B54C3CDCA79751B16BC6B5225629DF75B188BD`.
Fuente de la huella: https://ftp-master.debian.org/keys.html.
