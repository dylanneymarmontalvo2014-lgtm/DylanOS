# DylanOS Login Manager

Pantalla de acceso de DylanOS. Es el prototipo `DylanOS Login Manager.html`
convertido en el login real: mismo dibujo, mismos estilos y misma composición,
con datos del sistema en lugar de datos de ejemplo.

## Cómo está hecho

SDDM no permite configurar otro binario de greeter, y su greeter QML no puede
inicializar QtWebEngine (el motor aborta con *«must be called from the Qt gui
thread»*). Por eso el HTML no vive dentro del greeter: vive en un **host
propio** que ocupa su lugar.

```
SDDM (daemon, sin modificar)
  └─ /usr/bin/sddm-greeter-qt6      → lanzador de DylanOS
       └─ /usr/bin/dylanos-login-greeter
            └─ host (PySide6 + QWebEngineView)
                 ├─ tema HTML: themes/sddm/DylanOS-Crimson/web
                 ├─ QWebChannel → puente con el sistema
                 └─ QLocalSocket → protocolo de SDDM (PAM real)
```

El binario original de SDDM se conserva en
`/usr/bin/sddm-greeter-qt6.sddm-original`. El lanzador lo usa cuando el tema
activo no es DylanOS, así que cambiar el tema a mano sigue funcionando.

## Qué se sustituyó del prototipo

| Prototipo | Ahora |
|---|---|
| Reloj y fecha fijos | Hora y fecha reales, actualizadas cada segundo |
| «DylanOS live», avatar genérico | Usuario real y su foto de `~/.face` |
| Pronóstico de ejemplo | Clima real si hay proveedor; si no, el widget no se pinta |
| «Dream It Possible» | Reproductor MPRIS activo; antes del login no hay ninguno |
| «237 GB libres» | Espacio libre real (`statvfs`) |
| Anillo de batería al 78 % | Batería real de `/sys/class/power_supply`; sin batería, no hay anillo |
| Contraseña de ejemplo | Autenticación PAM real a través de SDDM |
| Atajos decorativos | Acciones reales (energía, red, preferencias) |

Regla que se respeta en todo el tema: **lo que el sistema no puede saber antes
del login no se inventa**. El widget se oculta y el marcado no cambia.

### De dónde sale cada widget

| Widget | Fuente | Sin datos |
|---|---|---|
| Clima | open-meteo (abierto, sin clave) con caché de 30 min | no se pinta |
| Próximo evento | `.ics` local indicado en la configuración | no se pinta |
| En reproducción | reproductor MPRIS activo | no se pinta |
| Sistema | `/sys/class/power_supply` y `statvfs` | se oculta la fila sin dato |
| Calendario | reloj del sistema | siempre |
| Recordatorios | lista en `login-manager.json` (máx. 4) | no se pinta |
| Atajos | selección del usuario (máx. 4) | no se pinta |

Todo esto se configura desde **Configuration → Pantalla de acceso → Datos**:
ubicación del clima, ruta del `.ics` y recordatorios. Sin terminal.

## Acento

El prototipo lleva el crimson escrito en los estilos en línea, y un estilo en
línea gana a cualquier hoja: por eso los textos no seguían al acento. Ahora
pasan por cuatro variables CSS con **el mismo valor por defecto**, así que el
dibujo original no cambia (la captura de fidelidad sigue siendo idéntica) pero
el acento elegido tiñe títulos, cifras, iconos activos, el día del calendario y
la casilla de los recordatorios:

```
--dylanos-primario        #dc143c  títulos y cifras
--dylanos-primario-claro  #ff5a66  iconos y estados activos
--dylanos-primario-fuerte #ff3b48  anillo de batería y progreso
--dylanos-primario-control #e11d2a casillas marcadas
```

Al elegir otro acento, las tres últimas se derivan de él (aclarado, saturado),
de modo que todo el login queda coherente con un solo color.

## Variables

`web/config/variables.json` es la plantilla del sistema. Cada elemento del
prototipo está separado por nombre:

```json
{
  "apariencia": { "fondo_seleccionado": "assets/fondo-seleccionado.png",
                  "color_primario": "#dc143c", "crimson_glass": true },
  "composicion": { "posicion_paneles": "clasica", "tamano_reloj": 1.0,
                   "tamano_bloque_acceso": 1.0 },
  "atajos": { "maximo": 4, "activos": ["tema", "no-molestar", "wifi", "bluetooth"] },
  "widgets": { "columna_izquierda": [...], "columna_derecha": [...] }
}
```

La configuración activa vive en `/etc/dylanos/login-manager.json`, que es lo
que lee el greeter.

## Personalización

Todo se cambia desde **DylanOS Configuration → Pantalla de acceso**:

- fondo de pantalla (se copia al sistema para que el greeter pueda leerlo);
- composición: distribución, escala, márgenes;
- tamaños del reloj y del bloque de acceso;
- widgets visibles por columna;
- atajos, **cuatro como máximo** (es la rejilla del prototipo);
- Crimson Glass activado o desactivado, con su intensidad;
- color: el del acento de DylanOS Configuration o uno propio;
- restablecer a los valores del prototipo.

No hace falta terminal ni ninguna herramienta externa.

## Catálogo

`apps/dylanos-login-manager/catalog/catalogo.json` declara los 12 atajos y los
14 widgets con su fuente de datos. Un elemento sin fuente real no se ofrece.

## Datos privilegiados

El greeter corre como el usuario `sddm`. Lo único que necesita privilegios es
encender o apagar la red y publicar la foto de perfil:

- `dylanos-login-helper red|estado|foto`, con lista blanca de acciones: rechaza
  cualquier campo que no sea `wifi`/`bluetooth` y deriva las rutas del nombre de
  usuario validado (nunca de una ruta del llamante);
- política polkit en `/usr/share/polkit-1/actions/org.dylanos.login-helper.policy`,
  con `allow_any=auth_admin`: solo el greeter lo usa sin credenciales, una cuenta
  normal tendría que autenticarse;
- las fotos se copian a `/var/lib/dylanos/login-manager/fotos` (nunca se
  enlaza la carpeta personal del usuario) y el greeter las lee de ahí;
- sin permisos, el helper devuelve un código y lo explica por `stderr`: nunca
  finge haber cambiado nada.

## Protocolo de SDDM

Verificado contra el código de SDDM 0.21 y probado con un daemon simulado:

- greeter → daemon: `Connect`, `Login`, `PowerOff`, `Reboot`, `Suspend`,
  `Hibernate`, `HybridSleep`;
- daemon → greeter: `HostName`, `Capabilities`, `LoginSucceeded`,
  `LoginFailed`, `InformationMessage`;
- `Login` = usuario, contraseña, sesión (`quint32` tipo + `QString` fichero).

Dos detalles que costaron encontrar y quedan documentados en el código:

1. **`quint32` son 4 bytes big-endian.** La API de flujo de Qt 6 escribe 8
   bytes cuando se pide la versión extendida; el daemon usa el flujo por
   defecto. El host escribe los cuatro bytes a mano.
2. **La longitud de un `QString` son bytes UTF-16, no caracteres.** «dylan»
   viaja como `0x0A` (10 bytes). Leerla como caracteres desalinea el mensaje.

## Ver cómo queda

Sin reiniciar ni bloquear la sesión:

```bash
python3 scripts/vista-previa-login.py
```

Elige el modo según lo que haya en el equipo:

| Modo | Cuándo | Qué usa |
|---|---|---|
| `ventana` | hay PySide6 | el propio login, en una ventana (lo más fiel) |
| `navegador` | hay Firefox/Brave… | el tema con tus datos, en el navegador |
| `imagen` | por SSH o para adjuntar | guarda un PNG y termina |

```bash
python3 scripts/vista-previa-login.py --modo imagen --salida /tmp/login.png
python3 scripts/vista-previa-login.py --ajustes /tmp/prueba.json   # probar otra configuración
python3 scripts/vista-previa-login.py --datos                      # ver qué datos se dibujarán
```

La vista previa usa el mismo módulo de datos que el login
(`apps/dylanos-login-manager/host/datos_sistema.py`), así que no puede mostrar
algo distinto de lo que aparecerá al arrancar.

## QA

Test Greeter, los dos greeters:

```bash
# Tema QML clásico (Main.qml): sin errores de QML y con captura
bash scripts/test-greeter-qml.sh

# Host HTML del login: protocolo de SDDM real contra un daemon simulado
bash scripts/test-greeter-host.sh
```

Ambos se ejecutan en el chroot (Qt 6.8 + PySide6) y dejan las capturas en
`artifacts/sddm-qa/`:

- `greeter-qml.png`: el tema QML con el reloj, la fecha y el bloqueo reales;
- `host.png`: el login HTML con datos del sistema.

El test del host comprueba lo que de verdad importa del protocolo: capacidades
recibidas, login válido aceptado, login inválido rechazado, acción de energía
entregada y ausencia de errores de JavaScript. Sale con código 1 si algo falla.

QA completa del proyecto (sustituye el Python si hace falta uno con PySide6):

```bash
DYLANOS_PYTHON=/tmp/opencode/venv/bin/python bash scripts/check.sh
```

- `scripts/tests/test_login_manager.py`: fidelidad del prototipo, variables,
  protocolo contra daemon simulado y datos reales.
- `artifacts/login-manager-qa/`: captura del prototipo, captura del tema
  enlazado y `fidelidad.json` (mismo SHA-256: **0 píxeles de diferencia**), más
  una captura con personalización aplicada (atajos nuevos, reloj de 24 h al
  135 %, acceso al 120 %, Crimson Glass apagado y acento turquesa).
- `artifacts/login-manager-qa/captura/`: utilidades para regenerar capturas
  (`capturar.js` y `capturar-fidelidad.js`) y los perfiles de datos usados en
  la comparación.

Regenerar las capturas (requiere Node y Playwright):

```bash
cd artifacts/login-manager-qa/captura
node capturar.js <tema>/index.html /tmp/custom.png 1440 960 ./perfil-personalizado.js
node capturar-fidelidad.js /tmp/fidelidad.png
```

Regenerar el tema desde el paquete original:

```bash
python3 scripts/lib/extract-login-prototype.py "DylanOS Login Manager.html"
python3 scripts/lib/enlazar-datos-login.py
```

Ver el resultado de una configuración concreta sin tocar la del sistema:

```bash
DYLANOS_LOGIN_AJUSTES=/tmp/prueba.json dylanos-login-greeter --preview \
    --theme /usr/share/sddm/themes/DylanOS-Crimson --size 1440x960 \
    --screenshot /tmp/vista.png
```

## Límites declarados

- **Clima, agenda y reproducción**: sin proveedor, sin `.ics` y sin
  reproductor respectivamente, esos widgets no aparecen. No hay datos falsos.
- **KWin no compone antes del login**: el «Crimson Glass» del login es el
  desenfoque real del navegador (`backdrop-filter`), no el efecto del
  compositor. El interruptor y la persistencia son reales.
- **Wi-Fi/Bluetooth** requieren el helper instalado; sin él, el atajo no
  cambia nada y no finge haberlo hecho.
- **La prueba final del daemon real** necesita QEMU: aquí se valida el
  protocolo contra un servidor simulado y la captura del host real.

## Qué falta por probar en hardware

El Test Greeter valida el protocolo y el dibujo, pero no sustituye a un
arranque real. Queda por comprobar en QEMU:

1. que el daemon de SDDM acepte al host como su greeter y el login inicie
   sesión de verdad con PAM;
2. que apagar, reiniciar y suspender funcionen desde el login;
3. que el helper de red cambie Wi-Fi y Bluetooth con polkit;
4. el comportamiento en una pantalla real (el test usa `offscreen`).

Los dos primeros son los que más riesgo tienen: son los únicos que dependen
del daemon, que aquí no se puede levantar.
