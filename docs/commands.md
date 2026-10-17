# Herramientas incluidas

Estas utilidades viven en `configs/system/rootfs/usr/bin/` y se instalan en `/usr/bin` de la imagen. No son servicios de fondo.

## `dylanos-info`

Muestra un resumen local del sistema o realiza comprobaciones de solo lectura:

```bash
dylanos-info
dylanos-info --diagnose
dylanos-info --version
dylanos-info --help
```

Sin opciones imprime el nombre de versión, kernel, arquitectura y sesión de escritorio detectada. `--diagnose` añade modo de arranque, uso del filesystem raíz, memoria, estado de NetworkManager y unidades fallidas de systemd. Si una herramienta o dato no está disponible, el diagnóstico lo indica.

No solicita privilegios de administrador, no necesita conexión de red y no recopila ni envía resultados. Las unidades fallidas solo se consultan con `systemctl`; no se reinician ni modifican.

## `dylanos-welcome`

La entrada de autoinicio de KDE abre la bienvenida una vez por usuario. Desde allí puedes ver diagnósticos, intentar iniciar Calamares si está instalado o abrir la documentación.

```bash
dylanos-welcome                 # abrir manualmente
dylanos-welcome --force         # volver a abrir ignorando el marcador de autoinicio
dylanos-welcome --autostart     # comportamiento de primer inicio usado por KDE
dylanos-welcome --version
dylanos-welcome --help
```

El marcador se guarda bajo `${XDG_STATE_HOME:-$HOME/.local/state}/dylanos/`. Requiere sesión gráfica y `kdialog`; las acciones de abrir documentación e iniciar el instalador también dependen de `xdg-open`, Calamares y `pkexec`, según corresponda. La opción de instalador no implica que Calamares esté disponible en cualquier sesión.

## `dylanos-wallpaper`

Aplica manualmente el fondo incluido a la sesión actual de KDE Plasma:

```bash
dylanos-wallpaper
```

Requiere una sesión KDE activa, un bus D-Bus de sesión y `plasma-apply-wallpaperimage`. Solo cambia el fondo del usuario actual y no se ejecuta automáticamente al iniciar sesión. Usa `dylanos-wallpaper --help` para ver la ayuda.

## Errores de uso

Las utilidades muestran ayuda para opciones no reconocidas. Si falla una acción de escritorio, revisa primero que se ejecute dentro de una sesión KDE y que las dependencias mencionadas estén instaladas.
