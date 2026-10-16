# Herramientas de DylanOS

## `dylanos-info`

DylanOS incluye `dylanos-info`, un comando local para consultar datos básicos del sistema sin privilegios de administrador ni conexión de red.

`dylanos-wallpaper`

Para aplicar manualmente el fondo incluido a la sesión de KDE Plasma, ejecuta `dylanos-wallpaper` desde el escritorio. El comando solo cambia el fondo del usuario actual y no se ejecuta automáticamente al iniciar sesión.

```bash
dylanos-info
```

Muestra el nombre de la instalación, el kernel, la arquitectura y el entorno de escritorio detectado en la sesión. También acepta `--version` y `--help`. No recopila ni envía información.
