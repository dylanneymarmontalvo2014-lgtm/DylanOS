<p align="center">
  <img src="docs/assets/dylanos-readme-banner.svg" alt="DylanOS — abierto, moderno, tuyo" width="100%">
</p>

<p align="center"><strong>Una distribución GNU/Linux de escritorio, en desarrollo abierto.</strong></p>
<p align="center">Debian Stable · amd64 · KDE Plasma · SDDM · Calamares</p>
<p align="center"><a href="docs/status.md">Estado del proyecto</a> · <a href="docs/architecture.md">Arquitectura</a> · <a href="docs/build.md">Construir</a> · <a href="docs/install.md">Instalar</a> · <a href="docs/contributing.md">Contribuir</a></p>

> [!WARNING]
> **DylanOS está en fase Alpha.** La configuración del instalador existe, pero todavía no se ha documentado una instalación completa de Calamares como validada. Usa el proyecto para pruebas y haz copias de seguridad; no lo trates como un sistema listo para equipos o datos críticos. Una ISO solo existe cuando se publica en [Releases](https://github.com/dylanneymarmontalvo2014-lgtm/DylanOS/releases).

## El proyecto

DylanOS busca ofrecer un escritorio Linux moderno y personalizable, con identidad visual propia y componentes conocidos del ecosistema Debian y KDE. El lema visual del proyecto es **Abierto · Moderno · Tuyo**.

### Qué incluye hoy

- Base de construcción **Debian Stable para amd64**, con Debian Live.
- Escritorio **KDE Plasma**, gestor de sesión **SDDM** y temas Breeze con ajustes de DylanOS.
- Identidad visual aplicada a recursos de GRUB, Plymouth, GTK y Plasma.
- Configuración de Calamares y una bienvenida gráfica con accesos al diagnóstico, documentación e instalador.
- `dylanos-info --diagnose`, comprobaciones locales de solo lectura; `dylanos-wallpaper`, aplicación manual del fondo de pantalla.
- Pruebas estáticas, resolución simulada de paquetes y construcción de la imagen Docker; `scripts/test-iso.sh` permite probar manualmente el arranque BIOS/UEFI con QEMU.

Consulta el [estado y los límites conocidos](docs/status.md). Que exista una configuración o una prueba automática no significa que la instalación completa o el soporte de hardware estén certificados.

## Identidad visual

La interfaz combina azul noche, superficies azul marino, cian y violeta. La paleta se deriva de los esquemas y recursos gráficos que el proyecto mantiene en el repositorio.

<p align="center">
  <img src="docs/assets/palette.svg" alt="Paleta de colores de DylanOS: azul noche, azul marino, selección, cian, violeta y blanco frío" width="100%">
</p>

Los colores y dónde se aplican están descritos en [Identidad visual y escritorio](docs/desktop.md). El fondo se puede aplicar manualmente con `dylanos-wallpaper`; el repositorio todavía no define una disposición propia del panel o dock de Plasma.

## Construcción rápida

En Debian o Ubuntu, instala las dependencias y genera una imagen desde la raíz del repositorio:

```bash
sudo ./install-deps.sh
sudo scripts/build.sh
```

O usa el constructor en Docker:

```bash
docker build --tag dylanos-builder .
docker run --rm --privileged --volume "$PWD:/workspace" --workdir /workspace dylanos-builder
```

La construcción requiere Internet, privilegios de root y, en Docker, `--privileged` para las operaciones de Debian Live. El resultado queda bajo `build/live-build/`. Para validar una ISO o publicar una versión, sigue la [guía de construcción y pruebas](docs/build.md).

> [!NOTE]
> Las listas `default`, `development`, `gaming` e `iot` se incorporan todas en cada construcción actual; todavía no son perfiles opcionales para elegir durante la instalación.

## Documentación

| Guía | Contenido |
|---|---|
| [Estado del proyecto](docs/status.md) | Qué está implementado, qué está limitado y qué falta validar |
| [Arquitectura](docs/architecture.md) | Componentes, carpetas y flujo de construcción |
| [Identidad visual y escritorio](docs/desktop.md) | Paleta, temas, recursos y configuración de Plasma |
| [Construcción y publicación](docs/build.md) | Dependencias, ISO, QEMU, Releases y limitaciones |
| [Instalación](docs/install.md) | Descarga, verificación y precauciones para probar |
| [Pruebas](docs/testing.md) | Qué cubre cada test y qué no cubre |
| [Herramientas](docs/commands.md) | `dylanos-info`, `dylanos-welcome` y `dylanos-wallpaper` |
| [Roadmap](docs/roadmap.md) | Metas por etapa de desarrollo |
| [Contribuir](docs/contributing.md) | Flujo de trabajo y validaciones para cambios |

## Mapa del repositorio

- `branding/`: logo, icono, fondos y pantalla de inicio.
- `configs/`: identidad del sistema, valores iniciales de Bash/Zsh/Plasma y herramientas propias.
- `packages/`: listas de paquetes incluidas por el constructor.
- `themes/`: ajustes de GRUB, GTK, Plasma y SDDM.
- `installer/calamares/`: configuración y marca del instalador.
- `scripts/`, `Dockerfile` e `install-deps.sh`: construcción y comprobaciones.
- `.github/workflows/`: validación rápida, build manual de artefacto y publicación de ISO al crear una etiqueta de versión.
- `docs/`: documentación del proyecto y recursos del README.

## Licencia

DylanOS se distribuye bajo la **GNU General Public License v3.0**. Consulta [`LICENSE`](LICENSE).
