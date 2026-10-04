# Previews de DylanOS 1.0 Beta

Estas imágenes son el contrato visual previo a la implementación de DylanOS 1.0 Beta.

## Archivos

Cada pantalla tiene dos formatos:

- `.svg`: versión editable y adecuada para revisión en Git.
- `.png`: exportación rasterizada para visualizar rápidamente.

| Archivo | Pantalla |
|---|---|
| `00-indice` | Dirección visual y tokens |
| `01-escritorio-dark` | Escritorio Dark predeterminado |
| `02-escritorio-light` | Escritorio Light |
| `03-control` | Centro de control |
| `04-store` | Centro de aplicaciones |
| `05-files` | Gestor de archivos |
| `06-monitor` | Monitor del sistema |
| `07-dev` | Entorno de desarrollo |
| `08-calamares` | Instalador Calamares configurado |
| `09-sddm` | Pantalla de inicio de sesión |
| `10-grub` | Menú de arranque |
| `11-plymouth` | Splash de arranque |

## Regenerar PNG y SVG

Desde la raíz del repositorio:

```bash
python3 docs/previews/generate_previews.py
for f in docs/previews/*.svg; do
    convert -background none "$f" "${f%.svg}.png"
done
```

Esta iteración busca una similitud visual aproximada del 90 % con macOS Tahoe mediante barra superior, ventanas flotantes, dock inferior e iconos libres de estilo macOS. La esencia DylanOS se limita al logo y al rojo de marca (`#E50914`). La paleta de interfaz es rojo, negro y blanco; se eliminó el azul de la propuesta anterior. Calamares se mantiene visualmente estándar: solo reemplaza el instalador Debian dentro de la ISO. La implementación del sistema no debe comenzar hasta que estas previews sean aprobadas.
