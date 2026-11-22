# Recursos y procedencia

- Fondos `DylanOS-Dark.png` y `DylanOS-Light.png`, esquemas de color, SVG de Plasma
  y Aurorae, QML de Workspace y nuevo login: creados para este repositorio,
  bajo GPL-3.0-or-later. Generador: `scripts/lib/generate-theme.py`.
- Logo de DylanOS: recurso preexistente `branding/logo.png`, conservado.
- Inter, Breeze, cursores, aplicaciones y firmware: paquetes oficiales de Debian;
  sus licencias se incluyen en `/usr/share/doc/<paquete>/copyright` en la imagen.
- Visual Studio Code se obtiene del repositorio apt oficial de Microsoft
  (`packages.microsoft.com/repos/vscode`) con `Signed-By` independiente. El
  binario distribuido se rige por la licencia de Microsoft (el código fuente
  "Code - OSS" es MIT y no se redistribuye aquí). VSCodium fue retirado.
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

- Banner y mapa del instalador: recursos aportados por el usuario en
  `DylanOS instalador calamares.zip`; procedencia y hash en
  `installer/calamares/beta/PROTOTYPE.md`. La adaptación no incorpora React ni
  bibliotecas web del ZIP.
- Fondo predeterminado: recurso preexistente `branding/wallpapers/dylanos-default.png`,
  copiado sin regenerarlo ni alterarlo.
- **Login manager HTML** (`themes/sddm/DylanOS-Crimson/web/`): el prototipo lo
  aportó el usuario; el tema se genera con `scripts/lib/extract-login-prototype.py`
  y `scripts/lib/enlazar-datos-login.py` (GPL-3.0-or-later). Incluye:
  - React 18.3.1 y ReactDOM 18.3.1 (UMD, producción): licencia MIT, cabecera
    `@license React` conservada intacta en cada fichero de `web/vendor/`.
  - `dc-runtime` (runtime del prototipo): generado a partir del paquete
    original, se distribuye tal cual.
  - Inter (subconjunto latino, `web/fonts/inter-latin.woff2`): SIL Open Font
    License 1.1, la misma que el paquete `fonts-inter` de Debian.
  - Fondos y logo: recursos preexistentes del repositorio, sin modificar.
