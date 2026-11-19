# DylanOS Installer — arquitectura y estado real

El instalador se distribuye como una ventana Qt WebEngine propia que carga el frontend React/Vite (`src/`) servido por el backend HTTP local (`backend/server.py`). No abre un navegador externo. El ejecutable de sesión es `dylanos-installer`; su frontend compilado se copia al staging durante la construcción.

## Iniciar y compilar el frontend

En el ISO, inicia el acceso «Instalar DylanOS» o ejecuta:

```sh
dylanos-installer
dylanos-installer --fullscreen
```

El modo normal abre una ventana redimensionable; `--fullscreen` usa pantalla completa y Escape vuelve a ventana. Para desarrollo del frontend: `npm ci` y `npm run build` dentro de este directorio. El flujo oficial de staging compila el frontend en una copia temporal aislada; no es necesario ni recomendable modificar el `node_modules` del checkout para construir la ISO.

La ventana nativa arranca el backend en `127.0.0.1:8088`. Si ya existe un backend escuchando, puede reutilizarlo. El backend necesita root y acceso a disco para la ruta de instalación real; ejecutado sin root sirve una vista previa sin escribir al disco.

## API local

GET: `/api/health`, `/api/system-info`, `/api/disks`, `/api/locales`, `/api/keyboards`, `/api/partition/filesystems`, `/api/install/status`.

POST: `/api/apply-keyboard`, `/api/validate-user`, `/api/partition/validate`, `/api/install`, `/api/reboot`, `/api/quit`. El frontend consulta `install/status` durante el progreso. La API escucha solo en localhost; no está concebida como servicio remoto ni como interfaz autenticada para una red.

## Flujo real y protección de disco

El backend obtiene datos de sistema/discos mediante fuentes locales (`/proc`, `lsblk` y herramientas del sistema), enumera discos físicos omitiendo el medio live y responde con progreso de instalación. En modo automático, sobre una ruta de dispositivo existente y con privilegios root, puede escribir una tabla GPT, formatear ESP y raíz ext4, extraer el filesystem, crear la cuenta/locale/teclado y configurar GRUB.

En modo manual el instalador ofrece un **editor de particiones real**. La pantalla de particionado mantiene un *plan* (borradores de partición: función, sistema de archivos, tamaño y etiqueta) que no toca el disco mientras se edita. «Nueva partición», «Editar», «Eliminar», «Revertir» y «Plan sugerido» operan sobre ese plan; al pulsar Siguiente el plan se valida contra el servidor (`POST /api/partition/validate`) y, cuando arranca la instalación real, el backend lo revalida y lo aplica con `parted` (tabla GPT nueva) y `mkfs`/`mkswap`. Solo se crean los sistemas de archivos cuyas herramientas existan en el medio: ext4 (`e2fsprogs`), FAT32 (`dosfstools`) y swap (`util-linux`).

Reglas que el servidor impone al plan: exactamente una raíz y como mínimo 12 GB; ESP de 300 MiB o más y obligatoriamente FAT32; `/home` y swap únicos; suma de tamaños que no exceda el disco real. El orden de creación es ESP, raíz, `/home`, swap, datos. Si el plan crea `/home` o swap, se añaden a `/etc/fstab` del sistema instalado; la ESP existente recibe el flag `esp`.

Los comandos que escriben solo se ejecutan dentro de `perform_installation`, nunca mientras se edita. Es una operación **destructiva para el disco seleccionado**: la tabla anterior se descarta. Antes de confirmar, verifica dispositivo, tamaño y copia de seguridad; primero prueba en VM con un disco virtual descartable. No uses un disco del host como prueba.

## Vista previa y límites del frontend

Si el backend no responde, varios componentes React retienen datos locales de demostración como respaldo. El frontend también conserva una secuencia de progreso simulada como fallback cuando la solicitud de instalación falla. Esa animación **no** ejecuta particionado, no copia DylanOS y no prueba que se haya instalado. La interfaz de hardware puede mostrar valores de catálogo si no se reciben datos del backend.

Solo el estado del endpoint real y el log del backend, corriendo con privilegios y disco válido en una VM desechable, sirven para evaluar la instalación. La vista previa QML/HTML o el smoke test de ventana solo demuestra que la interfaz carga. La compilación de frontend no demuestra que una instalación real arranque. Documenta aparte la validación de detección, escritura, reinicio y arranque desde el disco virtual.

## QA

- Frontend: `npm run build` valida compilación de Vite/TypeScript según los scripts instalados.
- Ventana nativa: `dylanos-installer --smoke`; requiere runtime PySide6/Qt WebEngine y sesión gráfica/offscreen apropiada.
- Backend: ejecutar pruebas dirigidas desde `scripts/tests/test_installer_backend.py` y `scripts/tests/test_installer_partitioning.py`; deben usar dispositivos temporales/mocks, nunca el disco de trabajo.
- ISO: seguir [`../../../docs/install.md`](../../../docs/install.md). La instalación real debe ejecutarse en VM con un disco virtual desechable y comprobar el arranque instalado por separado.

## Referencias

- [Guía de uso DylanOS y límites del instalador](../../../docs/guia-de-uso.md)
- [Contrato y pruebas del backend](../../../scripts/tests/test_installer_backend.py)
- [Implementación backend](../backend/server.py) y [ventana nativa](../native/main.py)
