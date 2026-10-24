# DylanOS Control Center — plasmoid `com.dylanos.controlcenter`

Widget Plasma 6 que abre el panel de notificaciones y controles del escritorio. Versión del applet: 0.3.0.

## Funciones conectadas

- **Notificaciones**: modelo de notificaciones real de Plasma, contador del total visible (no es un contador garantizado de no leídas) y cierre de entradas. «Borrar todo» cierra las notificaciones actualmente expuestas por el modelo.
- **No molestar**: usa `NotificationManager.Settings`; la acción del usuario inhibe notificaciones durante ocho horas. Si una aplicación posee la inhibición, el widget lo indica y no la anula.
- **Wi-Fi**: lee y cambia estado mediante `nmcli`; SSID puede no estar disponible si NetworkManager no gestiona la interfaz.
- **Bluetooth**: usa el adaptador BluezQt que Plasma presenta como utilizable.
- **Brillo**: consulta PowerDevil por D-Bus; depende de hardware/driver compatibles.
- **Volumen/silencio**: consulta y controla el sink de salida con `pactl`; necesita PulseAudio o PipeWire Pulse.
- **Micrófono**: muestra nivel de la fuente predeterminada, permite ajustar su volumen y alternar silencio con `pactl`; depende de una fuente de entrada disponible en PulseAudio/PipeWire Pulse. Si no existe, el control queda deshabilitado y se muestra «Micrófono no detectado».
- **Tema**: selecciona los esquemas propios `DylanOSDark`/`DylanOSLight`, conservando la identidad Crimson.
- **Reproducción**: `playerctl`/MPRIS si hay reproductor activo. `playerctl` se instala en el perfil base; el widget no incluye reproductor.
- **Accesos secundarios**: KDE Connect, pantalla y perfiles de energía abren sus módulos KCM de KDE; no simulan AirDrop ni alteran directamente todas sus opciones.

El sondeo está escalonado: audio/brillo cada 5 segundos; Wi-Fi y estado de tema/reproductor cada 15 segundos. Si una herramienta o API no está disponible, ciertos controles quedan desactivados o muestran «No detectado».

## QA y limitaciones

El contrato de estado se cubre parcialmente con `scripts/tests/test_shell_contract.py`; staging verifica el payload. Las pruebas estáticas no confirman que BluezQt, NotificationManager, D-Bus, audio o hardware funcionen en cada equipo. La carga del panel debe verificarse en una sesión real de Plasma 6.

Ver el [Dashboard](../com.dylanos.dashboard/README.md), la [guía general](../../docs/guia-de-uso.md) y el [documento de shell](../../docs/dylanos-shell.md).

## Acabado visual

En 0.3.0, las superficies exteriores del Centro de Control y Notificaciones
tienen una transparencia discreta y un borde claro suave. Las tarjetas internas
conservan contraste para que los controles y las alertas sigan siendo fáciles
de leer. El blur detrás de los plasmoids lo proporciona KWin/Plasma cuando el
compositor y `BlurBehindEffect` están disponibles; la transparencia por sí
sola no garantiza desenfoque.
