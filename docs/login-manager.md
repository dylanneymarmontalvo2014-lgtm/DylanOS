# DylanOS Login Manager

La pantalla de acceso de DylanOS. Es el prototipo adjunto convertido en el
login real: mismo marcado, mismos estilos y mismas medidas, con los datos del
sistema en lugar de los datos de ejemplo. **Sin personalizar, el render es
idéntico píxel a píxel al prototipo** (lo verifica el test de fidelidad).

## Cómo está hecho

SDDM no permite configurar otro binario de greeter, y su greeter QML no puede
inicializar QtWebEngine (el motor aborta con *«must be called from the Qt gui
thread»*). Por eso el HTML no vive dentro del greeter: vive en un **host
propio** que ocupa su lugar.

```
SDDM (daemon, sin modificar)
  └─ /usr/bin/sddm-greeter-qt6      → enlace a dylanos-login-greeter
       └─ /usr/share/dylanos/login-manager/host/dylanos-login-greeter.py
            ├─ tema HTML: /usr/share/sddm/themes/DylanOS-Crimson/web
            ├─ QWebChannel → puente con el sistema
            └─ QLocalSocket → protocolo de SDDM (PAM real)
```

El binario original de SDDM se conserva como
`/usr/bin/sddm-greeter-qt6.sddm-original`; el lanzador lo usa cuando el tema
activo no es DylanOS, así que cambiar el tema a mano sigue funcionando.

## Qué se sustituyó del prototipo

| Prototipo | Ahora | Sin dato |
|---|---|---|
| Reloj y fecha fijos | Hora y fecha reales, cada segundo | — (siempre hay) |
| «DylanOS live», avatar genérico | Usuario real y foto de `~/.face` | silueta del prototipo |
| Pronóstico de ejemplo | open-meteo (abierto, sin clave), caché 30 min | no se pinta |
| «Dream It Possible» | Reproductor MPRIS activo | no se pinta |
| «237 GB libres» | Espacio libre real (`statvfs`) | fila oculta |
| Anillo al 78 % | Batería real de `/sys/class/power_supply` | anillo oculto |
| Contraseña de ejemplo | PAM real a través de SDDM | — |
| Atajos decorativos | Acciones reales (red, energía, preferencias) | — |

Regla que se respeta en todo el tema: **lo que el sistema no puede saber antes
del login no se inventa**. El widget se oculta y el marcado no cambia.

## Variables: cada elemento separado por nombre

La plantilla `web/config/variables.json` (instalada como
`/etc/dylanos/login-manager.json`) separa cada elemento:

```json
{
  "apariencia":  { "fondo_seleccionado": "assets/fondo-seleccionado.png",
                   "color_primario": "#DC143C",
                   "usar_acento_del_sistema": true,
                   "crimson_glass": true },
  "composicion": { "variante": "completa", "posicion_paneles": "clasica",
                   "tamano_reloj": 1.0, "tamano_bloque_acceso": 1.0 },
  "widgets":     { "columna_izquierda": ["clima", "proximo-evento", "reproduccion", "sistema"],
                   "columna_derecha": ["calendario", "recordatorios", "atajos"] },
  "atajos":      { "maximo": 4, "activos": ["tema", "no-molestar", "wifi", "bluetooth"] },
  "clima":       { "latitud": null, "longitud": null, "ciudad": "" },
  "agenda":      { "ics": "" },
  "recordatorios": [ { "texto": "…", "hecho": false } ],
  "reloj_mundial": { "zonas": ["Madrid|Europe/Madrid"] },
  "mensaje":     { "texto": "", "usuario": "" }
}
```

## Variantes

| Variante | Widgets | Composición |
|---|---|---|
| **Completa** (por defecto) | los 7 del prototipo | clásica |
| **Sencilla** | Sistema, Calendario, Atajos | clásica |
| **Mínima** | ninguno | solo centro |

Además de las tres, el usuario puede elegir widgets libremente en
Configuration.

## Catálogo

`apps/dylanos-login-manager/catalog/catalogo.json` declara **12 atajos** y
**18 widgets**, cada uno con su fuente de datos y qué se pinta cuando falta.
Un elemento sin fuente real no se ofrece. Los atajos admiten **4 como máximo**
(la rejilla del prototipo); el límite lo aplica la página de Configuration y el
tema.

## Personalización: DylanOS Configuration → Pantalla de acceso

Todo se cambia desde la aplicación de Configuración, sin terminal:

- **Fondo**: galería del sistema o archivo propio; se copia al catálogo del
  login (`/usr/share/dylanos/login-manager/fondos`) porque el greeter no puede
  leer `/home`.
- **Composición**: posición de paneles (clásica / espejo / solo centro), tamaño
  del reloj y del bloque de acceso (60 %–160 %).
- **Widgets**: elegir cuáles en cada columna, con su fuente declarada y aviso
  de qué pasa cuando falta el dato.
- **Atajos**: elegir entre los 12, máximo 4; la página avisa cuando se intenta
  añadir un quinto.
- **Crimson Glass**: activar o desactivar el vidrio de las tarjetas.
- **Color**: heredar el acento del sistema (`kdeglobals → AccentColor`) o uno
  propio entre los propuestos.
- **Vista previa**: captura del greeter real (`--preview --screenshot`), no un
  dibujo aparte.
- **Restablecer al prototipo**: vuelve a los valores del diseño.

## El acento

El prototipo lleva el carmesí escrito en los estilos en línea, y un estilo en
línea gana a cualquier hoja. Por eso el acento pasa por dos variables CSS con
el **mismo valor por defecto**:

```
--dylanos-primario       #DC143C      títulos, cifras, iconos activos
--dylanos-primario-rgb   220,20,60    los rgba(...,α) del prototipo
```

Al elegir otro color se actualizan ambas y todo el login queda coherente con
un solo color, sin cambiar el dibujo por defecto.

## Datos privilegiados

El greeter corre como `sddm`. Lo único que necesita privilegios es tocar la
red y publicar la foto de perfil:

- `dylanos-login-helper red|estado|foto|sesiones`, con lista blanca de
  acciones; rechaza cualquier campo que no sea `wifi`/`bluetooth` y deriva las
  rutas del nombre de usuario validado (nunca de una ruta del llamante);
- política polkit en `/usr/share/polkit-1/actions/org.dylanos.login-helper.policy`,
  con `allow_any=auth_admin`: solo el greeter lo usa sin credenciales;
- las fotos se copian a `/var/lib/dylanos/login-manager/fotos` (nunca se
  enlaza la carpeta personal del usuario).

## Protocolo de SDDM

Verificado contra SDDM 0.21 y probado con daemon simulado:

- greeter → daemon: `Connect`, `Login`, `PowerOff`, `Reboot`, `Suspend`,
  `Hibernate`, `HybridSleep`;
- daemon → greeter: `HostName`, `Capabilities`, `LoginSucceeded`,
  `LoginFailed`, `InformationMessage`;
- `Login` = usuario, contraseña, sesión (`quint32` tipo + `QString` fichero).

Dos detalles que costaron encontrar y quedan en el código:

1. **`quint32` son 4 bytes big-endian.** La API de flujo de Qt 6 escribe 8
   bytes con la versión extendida; el daemon usa el flujo por defecto. El host
   escribe los cuatro bytes a mano.
2. **La longitud de un `QString` son bytes UTF-16, no caracteres.** «dylan»
   viaja como `0x0A` (10 bytes).

Y un tercero, del lado del puente:

3. **Los slots de QWebChannel con valor de retorno son asíncronos.** Sin
   callback, `estado()` devuelve `undefined`. Por eso el estado inicial viaja
   como JSON literal dentro del puente y el canal solo se usa para acciones y
   refrescar con callback.

## Fidelidad y QA

La prueba principal: **el tema con los datos del prototipo produce el mismo
dibujo píxel a píxel que el prototipo** (diff 0 contra
`artifacts/login-manager-qa/prototipo.png`).

```bash
# Los 25 tests (incluye capturas PNG si hay Chromium/Playwright)
QT_QPA_PLATFORM=offscreen python3 -m unittest scripts.tests.test_login_manager -v

# Captura del tema con un perfil concreto
python3 scripts/lib/capturar-login.py --perfil perfil.json --salida /tmp/login.png
python3 scripts/lib/capturar-login.py --variante sencilla --salida /tmp/sencilla.png

# Comparar dos capturas (falla si hay píxeles distintos)
python3 scripts/lib/comparar-capturas.py a.png b.png

# Captura con el host real (QtWebEngine), como en el arranque
DYLANOS_LOGIN_AJUSTES=variables.json python3 apps/dylanos-login-manager/host/ \
    dylanos-login-greeter.py --preview --theme themes/sddm/DylanOS-Crimson/web \
    --size 1440x960 --screenshot /tmp/host.png

# Regenerar el tema desde el prototipo (verifica el HTML resultante)
python3 scripts/lib/generar-tema-login.py --check
```

Artefactos en `artifacts/login-manager-qa/`: el prototipo de referencia, el
tema con sus datos y las tres variantes.

## Límites declarados

- **Clima, agenda y reproducción**: sin ubicación, sin `.ics` y sin
  reproductor, esos widgets no aparecen. No hay datos falsos.
- **KWin no compone antes del login**: el Crimson Glass del login es el
  desenfoque real del navegador (`backdrop-filter`), no el del compositor. El
  interruptor y la persistencia son reales.
- **Wi-Fi/Bluetooth** requieren el helper instalado; sin él, el atajo no cambia
  nada y no finge haberlo hecho.
- **La prueba final del daemon real** necesita QEMU: aquí se valida el
  protocolo contra el host real y las capturas. Queda por comprobar en
  hardware el arranque con el daemon de SDDM autenticando por PAM.
