# Herramientas de DylanOS

## `dylanos-info`

Comando local que no requiere privilegios de administrador ni conexión de red.

```bash
dylanos-info
dylanos-info --diagnose
```

Sin opciones muestra el nombre de la instalación, el kernel, la arquitectura y la sesión de escritorio. `--diagnose` añade comprobaciones de solo lectura del modo de arranque, espacio disponible, memoria, NetworkManager y unidades systemd fallidas. No recopila ni envía información.

## `dylanos-welcome`

DylanOS muestra una bienvenida una vez al iniciar una sesión KDE por primera vez. Desde ella puedes abrir los diagnósticos, iniciar el instalador si está disponible o abrir la documentación. También queda accesible desde el menú de aplicaciones.

```bash
dylanos-welcome --force
```

## `dylanos-wallpaper`

Para aplicar manualmente el fondo incluido a la sesión actual de KDE Plasma, ejecuta:

```bash
dylanos-wallpaper
```

Solo cambia el fondo del usuario actual y no se ejecuta automáticamente al iniciar sesión.
