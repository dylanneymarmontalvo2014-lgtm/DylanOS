# Hosts compatibles para compilar DylanOS

`init.sh` prepara dependencias y el builder de DylanOS; no cambia la distribución objetivo (Debian 13), la arquitectura ni los artefactos del sistema. La compilación mediante Docker necesita un host Linux `x86_64`/`amd64`, Docker Engine, Compose v2 y un daemon operativo. El servicio del builder requiere modo privilegiado para preparar el `chroot`.

## Matriz

| Host | Método de compilación | Instalación automática de Docker/Compose si falta | Notas |
|---|---|---|---|
| Debian y Ubuntu amd64 | Dependencias nativas `apt` y entorno Python `.venv` | No aplica | Conserva el flujo nativo existente. |
| Arch Linux, Manjaro, EndeavourOS, Garuda y Artix amd64 | Builder Docker | Sí, `pacman` (`docker`, `docker-compose`) | Se ofrece habilitar/iniciar el servicio. |
| Fedora amd64 | Builder Docker | Sí, repositorio oficial Docker para Fedora y `dnf` | No es compatible con Fedora Silverblue/Kinoite en modo nativo; usa Docker Desktop o una configuración de Docker ya preparada si aplica. |
| RHEL, CentOS, Rocky Linux y AlmaLinux amd64 | Builder Docker | Sí, repositorio oficial Docker para CentOS y `dnf` | Versiones y compatibilidad dependen del soporte publicado por Docker. Oracle Linux no se detecta como compatible automáticamente. |
| openSUSE Leap/Tumbleweed y SLES amd64 | Builder Docker | Sí, paquetes `docker` y `docker-compose` de `zypper` | El helper acepta plugin o ejecutable standalone Compose v2; se valida al instalar. |
| Alpine Linux amd64 | Builder Docker | Sí, paquetes `docker` y `docker-cli-compose` de `apk` | El helper acepta plugin o ejecutable standalone Compose v2; se valida al instalar. |
| Otras distribuciones Linux amd64 | Builder Docker | No | Instala Docker Engine y Compose v2 (plugin `docker compose` o standalone `docker-compose`) con la guía oficial de tu distribución antes de ejecutar `init.sh`. |
| macOS y Windows | No ejecutable por `init.sh` | No | Se puede usar Docker Desktop para construir desde un entorno Linux compatible; `init.sh` exige Linux y no está implementado ni validado para macOS/Windows. |
| Linux no amd64 | No compatible | No | `init.sh` rechaza arquitecturas distintas de `x86_64`/`amd64`. |

## Confirmación y permisos

Sin `--yes`, el script explica los cambios y pregunta antes de instalar paquetes, configurar repositorios, habilitar/iniciar el daemon o construir la imagen. Cancela sin cambios si no recibe confirmación. `--yes` omite esa confirmación y debe usarse solo cuando esos cambios hayan sido aprobados explícitamente. No usa `sudo` si ya se ejecuta como root; si se necesita elevación, requiere que exista `sudo`. No instala herramientas en el directorio personal.

Los paquetes/repo pueden variar por versión de la distribución. Si la instalación automática falla, configura Docker Engine y Compose v2 manualmente con fuentes oficiales de tu distribución y vuelve a ejecutar el script. El builder requiere Docker Engine y acepta tanto el plugin `docker compose` como el binario standalone `docker-compose` **v2**. Se consulta la versión de ambas opciones y se rechaza Compose v1; si el plugin reporta v1 pero el standalone reporta v2, se selecciona el standalone. Si el usuario no puede acceder al daemon, el comando se ejecuta con `sudo` solo cuando `sudo docker info` confirma acceso. El builder ejecuta el build y la QA con el mismo modo Compose detectado.

## Archivos modificados y comportamiento

- `init.sh`: conserva dependencias nativas para Debian/Ubuntu; clasifica de forma explícita las familias de host y enruta el resto al builder Docker. Añade instalación del engine/Compose para RHEL-compatible, openSUSE y Alpine además de Arch/Fedora; mantiene confirmación, comprobación de Compose v2 y arranque de servicio con systemd u OpenRC. No instala dependencias en `$HOME`.
- `scripts/build-host.sh`: contiene funciones puras para clasificar `ID`/`ID_LIKE` y marcar las familias donde se admite instalación automatizada.
- `scripts/docker-compose.sh`: detecta plugin/standalone Compose v2, rechaza v1 y elige el modo válido para build y QA.
- `scripts/tests/test_docker_compose.sh`: prueba formatos de versión y fallback con ejecutables falsos; no contacta un daemon real.
- `scripts/test-build-host.sh`: prueba clasificaciones representativas y la tabla de instalaciones permitidas sin tocar el sistema.
- `README.md`: enlaza esta matriz y resume las rutas principales.
- `docs/install.md`: integra los requisitos, comandos, condiciones de consentimiento y límites de la validación con la guía de instalación.

## Detección

La detección usa campos exactos `ID` y `ID_LIKE` de `/etc/os-release`, no coincidencias de subcadenas arbitrarias. La tabla de detección se prueba sin privilegios:

```bash
./scripts/test-build-host.sh
bash -n init.sh scripts/build-host.sh scripts/test-build-host.sh
```


## Integración del builder Docker

`Dockerfile` copia `scripts/build-host.sh` dentro de la imagen antes de ejecutar `init.sh`. El inicializador importa ese módulo para detectar el host y decidir la ruta de dependencias; si falta la copia, la construcción del builder falla con `detect_host_family: command not found`. Esta dependencia entre archivos debe mantenerse al editar la imagen.

En el CI del 23 de octubre de 2026, la construcción Docker falló porque el `Dockerfile` aún no copiaba dicho archivo. La corrección propuesta agrega `COPY scripts/build-host.sh ./scripts/build-host.sh`; queda pendiente confirmar la nueva construcción de la imagen y la QA dentro del contenedor.
