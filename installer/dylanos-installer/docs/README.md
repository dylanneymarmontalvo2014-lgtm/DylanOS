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

GET: `/api/health`, `/api/system-info`, `/api/disks`, `/api/locales`, `/api/keyboards`, `/api/install/status`.

POST: `/api/apply-keyboard`, `/api/validate-user`, `/api/install`, `/api/reboot`, `/api/quit`. El frontend consulta `install/status` durante el progreso. La API escucha solo en localhost; no está concebida como servicio remoto ni como interfaz autenticada para una red.

## Flujo real y protección de disco

El backend obtiene datos de sistema/discos mediante fuentes locales (`/proc`, `lsblk` y herramientas del sistema), enumera discos físicos omitiendo el medio live y responde con progreso de instalación. En modo automático, sobre una ruta de dispositivo existente y con privilegios root, puede escribir una tabla GPT, formatear ESP y raíz ext4, extraer el filesystem, crear la cuenta/locale/teclado y configurar GRUB. Es una operación **destructiva para el disco seleccionado**. Antes de confirmar, verifica dispositivo, tamaño, modo y copia de seguridad; primero prueba en VM con un disco virtual descartable. No uses un disco del host como prueba.

En modo manual, el backend no ofrece un editor de particiones completo: busca una partición ext4 existente y una ESP opcional. Los botones visuales «Nueva partición», «Editar», «Eliminar» y «Revertir» del prototipo de particionado no tienen acciones conectadas. No los trates como funcionales ni elijas el modo manual esperando que apliquen esos cambios.

## Vista previa y límites del frontend

Si el backend no responde, varios componentes React retienen datos locales de demostración como respaldo. El frontend también conserva una secuencia de progreso simulada como fallback cuando la solicitud de instalación falla. Esa animación **no** ejecuta particionado, no copia DylanOS y no prueba que se haya instalado. La interfaz de hardware puede mostrar valores de catálogo si no se reciben datos del backend.

Solo el estado del endpoint real y el log del backend, corriendo con privilegios y disco válido en una VM desechable, sirven para evaluar la instalación. La vista previa QML/HTML o el smoke test de ventana solo demuestra que la interfaz carga. La compilación de frontend no demuestra que una instalación real arranque. Documenta aparte la validación de detección, escritura, reinicio y arranque desde el disco virtual.

## QA

- Frontend: `npm run build` valida compilación de Vite/TypeScript según los scripts instalados.
- Ventana nativa: `dylanos-installer --smoke`; requiere runtime PySide6/Qt WebEngine y sesión gráfica/offscreen apropiada.
- Backend: ejecutar pruebas dirigidas desde `scripts/tests/test_installer_backend.py`; deben usar dispositivos temporales/mocks, nunca el disco de trabajo.
- ISO: seguir [`../../../docs/install.md`](../../../docs/install.md). La instalación real debe ejecutarse en VM con un disco virtual desechable y comprobar el arranque instalado por separado.

## Referencias

- [Guía de uso DylanOS y límites del instalador](../../../docs/guia-de-uso.md)
- [Contrato y pruebas del backend](../../../scripts/tests/test_installer_backend.py)
- [Implementación backend](../backend/server.py) y [ventana nativa](../native/main.py)
