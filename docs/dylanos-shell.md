# DylanOS Shell

The first-run Plasma desktop layout adds the DylanOS dashboard to each desktop using Plasma's positioned `Containment.addWidget` scripting API. It provides a live clock, a navigable month calendar, and local memory, CPU-usage, filesystem-capacity, and uptime readings from `/proc` and `df`; it intentionally has no fabricated weather, events, reminders, or remote-service data. Like the rest of the initial layout, this applies to new profiles and does not replace an existing user's panels or desktop widgets.

The Control Center's Do Not Disturb toggle now uses Plasma's public `NotificationManager.Settings` API. A user-initiated toggle inhibits notifications for eight hours and can be cleared from the same control. An application-owned inhibition is shown as such and is not overridden. The notification list continues to display the real Plasma notification model, including while Do Not Disturb is active. The compact badge shows the number of current notifications, not an unread count. The secondary action opens KDE Connect by its proper name, not the unrelated AirDrop brand.

Konsole retains the DylanOS Crimson profile and current-session-directory behavior; its scrollback history is increased to 50,000 lines. No wallpaper configuration or image is changed by these shell enhancements. Fastfetch remains unchanged pending approval of its separate logo preview.


## Seguimiento de la identidad visual y la optimización

- **Dashboard (actualización 2026-10-23):** se amplió el panel a 500 × 360 para alojar las métricas añadidas y se agregaron lecturas reales de uso de CPU desde las diferencias de contadores de `/proc/stat` y espacio usado/total del filesystem raíz mediante `df -B1`. CPU, memoria y disco usan barras carmesí; si una fuente no está disponible, se muestra un estado explícito, no un valor inventado. Se conserva el calendario, reloj y uptime.
- **Optimización de la ISO (actualización 2026-10-23):** `scripts/build.sh` instala paquetes explícitos con `--no-install-recommends` y, después de retirar Dolphin, sus plugins, KCalc y dependencias de compilación, ejecuta `apt-get autoremove --purge`. APT decide qué dependencias automáticas ya no necesita. No se eliminan apps que estén en la lista base; tampoco se cambian el fondo ni los paquetes funcionales explícitos.
- **Motivo/alcance:** evitar software recomendado no pedido y dependencias huérfanas, además de acercar el panel de estado a la referencia visual sin inventar datos. Esto puede reducir el tamaño de futuras imágenes; no se afirma un ahorro de bytes hasta construir y medir una ISO nueva.
- **Verificación requerida:** `bash scripts/tests/test_packages.sh`, `python3 -m unittest scripts.tests.test_shell_contract`, `make check`, `make build`, `make iso` y `make test-iso`. Una build automatizada no demuestra el arranque del escritorio; para eso se requiere `make qemu-test` y revisar el render real.
- **Archivos afectados:** `apps/com.dylanos.dashboard/contents/ui/main.qml` (métricas), `scripts/build.sh` (instalación/purga), `scripts/tests/test_packages.sh` y `scripts/tests/test_shell_contract.py` (regresiones) y este documento.
