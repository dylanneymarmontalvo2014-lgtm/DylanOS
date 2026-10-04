# Arquitectura

DylanOS 1.0 Beta usa Debian 13 trixie amd64, Plasma 6, SDDM y Calamares.

## Componentes

- `apps/workspace/core.py`: operaciones de archivos, SQLite y plantillas; sin Qt.
- `apps/workspace/backend.py`: puente Qt, trabajos en segundo plano, métricas
  reales con psutil y ejecución de aplicaciones con argumentos separados.
- `apps/workspace/qml`: siete vistas con componentes visuales compartidos.
- `apps/calculator` y `apps/dylanos-app-center`: aplicaciones C++/QML compiladas
  dentro del chroot usando la versión de Qt/KF de la distribución de destino.
- `themes`: Plasma, Aurorae Dark/Light, tema global, SDDM, GRUB y Plymouth.
- `configs/plasma/skel`: valores iniciales para nuevos usuarios, sin sobrescribir
  la configuración de usuarios existentes.
- `scripts/stage.py`: instala únicamente el payload de DylanOS en un directorio
  explícito. Se puede ejecutar sin root para validar el contenido de la imagen.
- `scripts/build.sh`: debootstrap firmado, repositorios, paquetes, staging,
  compilación, initramfs y manifiesto. Usa un namespace de montajes privado.
- `scripts/iso.sh`: squashfs conservando `/boot`, kernel/initrd de igual versión,
  GRUB BIOS/UEFI, checksum y entradas live normal/gráficos seguros.

## Datos y permisos

Notas guarda en `$XDG_DATA_HOME/DylanOS/Workspace/notes.sqlite3` (normalmente
`~/.local/share/DylanOS/Workspace/notes.sqlite3`). SQLite hace atómicos los guardados.
Los ajustes de las apps usan QSettings. La bienvenida aparece una vez por usuario.

El explorador nunca reemplaza deliberadamente un archivo existente al copiar o
renombrar. La papelera usa `QFile.moveToTrash`, no borrado permanente. Una carpeta
se abre en aplicaciones mediante URLs locales; los comandos no pasan por un shell.
La creación de proyectos no instala dependencias ni ejecuta código de plantillas.

Discover/PackageKit y los módulos de KDE gestionan las operaciones privilegiadas.
No se guardan contraseñas, tokens ni una cuenta instalada con clave predeterminada.
El usuario `dylan` pertenece a la sesión live creada por live-config.

## Integración y límites

Se usa la configuración de Calamares distribuida por Debian, con sus jobs de particionado, usuarios y arranque. Se cambian el branding y la
fuente squashfs. Se omiten los jobs de APT del medio live-build y de instalación
de GRUB: la imagen ya incluye ambos destinos de GRUB y cryptsetup-initramfs,
y conserva los repositorios configurados para permitir la instalación offline. El instalador sigue
siendo responsable de particionar, crear el usuario y configurar el arranque.

El dock experimental y el antiguo centro de control permanecen en el repositorio,
pero la imagen usa el panel superior y los controles nativos de Plasma.
La biblioteca gráfica propia usa superficies tintadas; no promete el motor
Liquid Glass de Apple. El desenfoque del escritorio depende de KWin y del equipo.

El esquema claro cambia los colores y la decoración de ventanas. El fondo se
puede elegir desde Plasma; no se sobreescribe la elección personal del usuario.
