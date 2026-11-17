# DylanOS Widgets — Auditoría y arquitectura (para aprobación)

**Fecha:** 2026-11-16 · **Rama:** `development` · **Estado:** propuesta, sin código implementado
**Alcance:** sistema de widgets de escritorio Crimson Glass, 20 widgets mínimo, layout por defecto
solo en sistema instalado.

Este documento responde al encargo «DylanOS Widgets». No se ha escrito código de producción ni se
ha hecho commit: el encargo exige auditoría y plan aprobados antes de implementar.

---

## 1. Veredicto en una página

| Decisión | Resultado |
|---|---|
| Arquitectura | **Plasmoids nativos** (un paquete por widget) + librería QML común + app de galería propia. **No** se construye un shell/compositor paralelo. |
| Live USB | **0 widgets.** No se toca `layout.js`, que hoy no añade widgets y tiene contrato de test. |
| Instalado, primer login | **3 widgets** (Reloj, Calendario arriba; Clima debajo a doble ancho) creados una sola vez por un servicio de primer arranque vía `evaluateScript`. |
| Stacks de widgets | **No en 1.0**; quedan para Beta (justificado en §7). |
| Los 20 del catálogo | 16 implementables con datos reales sin dependencias nuevas; 3 requieren dependencia nueva; 4 con límite funcional declarado (§6). |
| Riesgo principal | El prompt asume infraestructura que **no existe** en el repositorio (§3). |

---

## 2. Estado real del repositorio (evidencia)

Lo comprobado, no lo supuesto:

- **Hoy no hay ningún widget en el escritorio, por contrato explícito.**
  `scripts/tests/test_desktop.py` afirma `s.widgets.length === 0` para cada pantalla: «el escritorio
  inicial no debe añadir widgets». `themes/lookandfeel/org.dylanos.crimson/contents/layouts/org.kde.plasma.desktop-layout.js`
  solo crea la barra superior, el dock y el fondo. Es un invariante probado, no un descuido.
- **El único artefacto de widgets es histórico y se borra en la imagen.**
  `apps/com.dylanos.dashboard` (Reloj, métricas, calendario, recordatorios, Pomodoro) sigue en el
  repositorio, pero `scripts/stage.py:201` ejecuta
  `remove("/usr/share/plasma/plasmoids/com.dylanos.dashboard")` y el layout no lo instancia.
  `docs/plans/beta-premium-progress.md:10` documenta el ruling: se conserva el código fuente, se
  retira del payload. **Es la base de referencia más valiosa que ya existe**, no un precedente a
  resucitar tal cual.
- **Existe patrón probado de plasmoid propio**: `apps/com.dylanos.dock`, `com.dylanos.activeapp`,
  `com.dylanos.search`, `dylanos-control-center` (metadata.json + contents/ui, staging a
  `/usr/share/plasma/plasmoids/...`, QA de carga real en `scripts/tests/test_plasmoid_runtime.sh`
  con `plasmawindowed` dentro del chroot).
- **Existe patrón probado de scripting de Plasma por DBus**:
  `apps/dylanos-configuration/src/services/CrimsonGlassService.cpp:671-674` obtiene
  `org.kde.plasmashell /PlasmaShell` y llama `evaluateScript`. Ese es el mismo mecanismo que
  necesitamos para crear widgets con geometría exacta.
- **La API de scripting confirma lo necesario** (documentación oficial de KDE, consultada):
  `Containment.addWidget(string name, number x, y, w, h)` y la propiedad escribible
  `Widget.geometry` (QRectF); también `desktops()`, `screenGeometry(n)` y `knownWidgetTypes`.
  Es decir: **se pueden crear widgets en posiciones y tamaños exactos**, requisito del encargo.
- **Detección live ya existente y reutilizable**:
  `installer/dylanos-installer/backend/server.py:378-379` define
  `MEDIUM_MOUNTPOINTS = ("/run/live/medium", "/lib/live/mount/medium")` y localiza allí
  `live/filesystem.squashfs`. Además, el instalador purga `live-boot`/`live-config` del sistema
  instalado (`server.py:1146`), así que un sistema en disco **nunca** presenta esa ruta.
- **`sysInfo()` real vive en** `apps/dylanos-configuration/src/services/SystemService.cpp:167`
  (CPU con cadena de fuentes, RAM normalizada a potencia de dos). Ahí está la lógica que el encargo
  atribuye a un inexistente `dylanos-info`.
- **Entorno de este host**: no hay `work/chroot`, ni `plasmashell`, ni `qmllint`, ni `PySide6`.
  Sí hay `node` v24, `python3`, `shellcheck` y `desktop-file-validate`. Esto condiciona la
  verificación (§10).

---

## 3. Divergencias del encargo respecto al repositorio

El megaprompt se escribió sin auditar el árbol. Cuatro supuestos son falsos y uno es un riesgo:

| # | El encargo dice | Realidad verificada | Resolución propuesta |
|---|---|---|---|
| 1 | Reutilizar la detección de `dylanos-info` | **`dylanos-info` no existe** (ni binario, ni referencia en el repo) | Usar `MEDIUM_MOUNTPOINTS` del instalador, que sí existe y es determinista |
| 2 | Reutilizar la telemetría de `dylanos-info` | Igual: no existe | Extraer la lógica de `SystemService::sysInfo()` a la librería común y que Configuration y los widgets la compartan (sin duplicar) |
| 3 | Verificar con `scripts/test.sh` | `scripts/test.sh` valida **estructura de ISO** con `xorriso`, no es la suite | La QA del proyecto es `scripts/check.sh` (§10) |
| 4 | Aplicar la skill `dylanos-qa-engineering` | **No existe** en el catálogo de skills del proyecto | La cobertura QA se toma de `dylanos-workflow` §9 y de `scripts/check.sh` |
| 5 | Los widgets Crimson Glass «con fallback no translúcido» | Ya resuelto a nivel de sistema por Crimson Glass (blur/translucidez con detección de `llvmpipe`/`softpipe`, `docs/crimson-glass.md`) | El widget **no** reimplementa detección de GPU: lee el estado de Crimson Glass y obedece |

Ninguna de estas divergencias bloquea el trabajo, pero cambian el plan: no se puede «reutilizar»
lo que no existe, hay que **crear** la fuente de datos compartida.

---

## 4. Decisión de arquitectura: Plasmoids frente a shell propio

### Opción A — Plasmoids nativos (elegida)

Un paquete `Plasma/Applet` por widget, más un módulo QML común.

**A favor (verificado en el repo):**
- Reutiliza el containment de escritorio de Plasma: arrastrar, soltar, redimensionar, quitar,
  persistencia de geometría y de configuración por instancia (`Plasmoid.configuration` → KConfig).
  Nada de eso hay que escribirlo.
- Coincide con el patrón que el proyecto ya tiene cuatro veces y con su QA
  (`test_plasmoid_runtime.sh` carga el applet de verdad bajo Plasma).
- La scripting API permite crear el layout inicial con geometría exacta (requisito del encargo).
- No duplica compositor ni gestor de ventanas, así que no puede romper KWin, el dock ni la barra.
- Coste de entrada bajo: un widget son ~2 ficheros.

**En contra (honesto):**
- No existe «modo edición» tipo jiggle de macOS: Plasma tiene su propio modo de edición. Se puede
  aproximar con microanimaciones, no replicar.
- El reajuste a la celda de la grilla al redimensionar a mano **no es snapping nativo**: Plasma deja
  geometría libre en el escritorio. Se acota con `minimumWidth/Height` y `Layout.preferred*`
  proporcionales, pero el usuario puede dejar un tamaño intermedio. **Límite declarado.**
- Los «stacks» y la galería con previews en vivo hay que construirlos aparte (§7, §8).

### Opción B — Capa propia de widgets (rechazada)

Un proceso propio que dibuje widgets sobre el escritorio.

**A favor:** control total del acabado (jiggle real, snapping perfecto, stacks, galería integrada).

**En contra (decisivo):** obliga a reimplementar arrastre, redimensionado, orden Z, persistencia,
multi-pantalla, DPI y accesibilidad; entra en conflicto con el modo de edición de Plasma; añade un
proceso residente —justo lo que `docs/crimson-glass.md` evita explícitamente— y duplica una
capacidad que el sistema ya tiene. Contradice la regla de arquitectura «no construir dos
implementaciones del mismo capability».

### Veredicto

**Opción A**, con dos piezas propias: `libdylanos-widgets` (contrato visual y de tamaños) y
`dylanos-widgets` (galería, app QML de DylanOS que crea widgets vía scripting API). Se desvía del
encargo solo en lo ya señalado: no se duplica el contenedor.

---

## 5. Live USB frente a instalado: el punto crítico

El requisito es duro: **live = 0 widgets; instalado, primer login = exactamente 3**. La ISO es la
misma en ambos casos (el squashfs se copia a disco), así que un marcador en `/usr/share` **no puede
distinguirlos**. Se evaluaron tres mecanismos:

| Mecanismo | Por qué se descarta / se elige |
|---|---|
| Marcar el layout en `layout.js` | Falla el requisito: `layout.js` corre también en live (perfil nuevo) y metería 3 widgets en el USB. Además rompería el contrato de `test_desktop.py`. **Descartado.** |
| Archivo marcador en `/usr/share` | Idéntico en live e instalado: no distingue. **Descartado.** |
| **Servicio de primer arranque de sesión** | Detecta live por la ruta del medio (`/run/live/medium`, `/lib/live/mount/medium`) —la misma que usa el instalador— y solo actúa si **no** es live. Marca por usuario en `~/.local/state/dylanos/widgets/`. **Elegido.** |

**Flujo exacto:**

1. Al iniciar sesión, un autostart `org.dylanos.widgets.desktop` (patrón del ya existente
   `org.dylanos.crimson-glass.desktop`, con `X-KDE-autostart-after=panel`) ejecuta
   `dylanos-configuration --apply-widget-layout --headless`.
2. El binario comprueba, en este orden: (a) ¿existe el medio live? → salir sin hacer nada;
   (b) ¿existe la marca de layout aplicado para este usuario? → salir; (c) ¿el escritorio ya tiene
   widgets de estos tipos? → salir (idempotencia).
3. Si procede, construye un script y lo envía por `evaluateScript` a `org.kde.plasmashell`,
   reutilizando el patrón de `CrimsonGlassService.cpp`. Geometría calculada desde
   `screenGeometry(0)`:

   ```
   celda  = clamp(round(alto_pantalla / 6), 120, 190)   // lado de un widget "normal"
   margen = celda / 3
   Reloj      → (margen,              margen, celda,     celda)
   Calendario → (margen*2 + celda,    margen, celda,     celda)
   Clima      → (margen,              margen*2 + celda, celda*2, celda)
   ```
   El Clima queda **exactamente** a `2 × celda` de ancho y `1 × celda` de alto, alineado con el
   borde izquierdo del Reloj y justo debajo de la fila. Cumple «doble de ancho, no de alto».
4. Escribe la marca. No vuelve a ejecutarse para ese usuario: si luego borra un widget, se queda
   borrado.

**Por qué el flag vive en `dylanos-configuration`:** ese binario ya existe, ya habla QDBus, ya tiene
un flag `--headless` equivalente (`--apply-crimson-glass`) y ya está sujeto al test que prohíbe
`refreshCurrentShell` (`scripts/tests/test_session_startup.py`). Añadir un segundo binario al
arranque sería peso sin beneficio.

**Consecuencia para el test existente:** `test_desktop.py` sigue pasando **intacto**, porque
`layout.js` no cambia. No se debilita ningún test: el comportamiento nuevo se prueba con tests
nuevos (§10).

---

## 6. Catálogo de 20 widgets con viabilidad real

`Tamaños`: `S` 1×1 · `W` 2×1 · `T` 1×2 · `L` 2×2 · `XL` 4×2 (según §5, en celdas).

| # | Widget | Tamaños | Fuente de datos real | Red | Estado |
|---|---|---|---|---|---|
| 1 | Reloj | S, L | Reloj del sistema (`Qt.formatTime`), zona local | no | Implementable |
| 2 | Calendario | S, L | Fecha del sistema; vista mensual calculada | no | Implementable |
| 3 | Clima | W (def.), S, L | DataSource `org.kde.plasma.weather` (plasma5support) | **sí** | **Con límite**: sin proveedor configurado muestra «Configura tu ubicación», nunca cifras inventadas |
| 4 | Batería | S | UPower por DBus (`org.freedesktop.UPower`) | no | Implementable |
| 5 | CPU / RAM | S, W | `/proc/stat`, `/proc/meminfo` (lógica de `SystemService::sysInfo`) | no | Implementable |
| 6 | Red / Wi-Fi | S | NetworkManager por DBus | no | Implementable |
| 7 | Notas rápidas | S, W, L | `Plasmoid.configuration` (nota persistida) | no | Implementable |
| 8 | Reproductor | W | MPRIS DBus; `playerctl` ya está en el perfil base | no | Implementable |
| 9 | Calculadora | S | Evaluador acotado en QML/JS (patrón del de Spotlight) | no | Implementable |
| 10 | Accesos directos | S, W | `.desktop` reales del sistema vía `KService`/`applicationExists` | no | Implementable |
| 11 | Fotos | W, L | Carpeta local del usuario | no | **Requiere dependencia**: `qml6-module-qt-labs-folderlistmodel` no está en `packages/default` |
| 12 | Captura rápida | S | `spectacle` (ya en el perfil) + última captura en `~/Imágenes` | no | Implementable |
| 13 | Portapapeles | S, W | Historial requiere `klipper`/`cliphist`; **no está en la imagen** | no | **Con límite**: sin backend, solo el contenido actual (QML `Clipboard`), sin historial |
| 14 | Tareas / To-Do | S, W, L | `Plasmoid.configuration` (JSON de tareas) | no | Implementable |
| 15 | Reloj mundial | W | `Qt.formatTime` con zonas de `zoneinfo` | no | Implementable |
| 16 | Pomodoro | S | Temporizador local (reutilizar `PomodoroClock.js` del dashboard) | no | Implementable |
| 17 | Espacio en disco | S | `QStorageInfo` / `df -B1` por partición | no | Implementable |
| 18 | Actualizaciones | S, W | PackageKit (ya usado por la Store); alternativa `apt-get -s upgrade` | no | Implementable |
| 19 | DylanOS Info | S, L | `sysInfo()` compartido: os-release, CPU, RAM, kernel | no | Implementable |
| 20 | Próximo evento | S, W | **No hay calendario de sistema**: Akonadi/KOrganizer no están en la imagen | no | **Con límite**: leer un `.ics` local que el usuario seleccione, o declarar vacío explícito |

**Balance honesto:** 16 de 20 con datos reales y sin dependencias nuevas; 1 requiere un paquete QML
(Fotos); 3 tienen límite funcional declarado (Clima sin proveedor, Portapapeles sin historial,
Próximo evento sin calendario de sistema). Ninguno mostrará datos simulados: si la fuente falta, el
widget muestra estado explícito, conforme a la regla del proyecto.

**Roadmap no implementado (declarado):** RSS/Noticias (requiere red y lector de feeds), Citas
(requiere calendario), Contador de notificaciones (DataSource de notificaciones).

---

## 7. Stacks de widgets: ruling

**No van en 1.0.** Motivo técnico: un stack implica que varios widgets comparten un mismo
rectángulo con cambio de capa y arrastre entre ellos. Con la Opción A cada widget es una instancia
independiente que Plasma posiciona, así que el stack exigiría un contenedor propio —precisamente la
Opción B que se ha descartado— o un efecto de KWin. Se pospone a Beta con esta condición: si se
implementa, será dentro de un contenedor y no reescribiendo los 20 widgets.

---

## 8. `libdylanos-widgets`: contrato

Módulo QML compartido, **sin código C++ nuevo** en la primera fase:

```
apps/dylanos-widgets-lib/
├── qmldir
└── WidgetTheme.qml     // singleton: tokens de color, radios, espaciado, tipografía, materiales
    WidgetSize.qml      // singleton: clases S/W/T/L/XL → geometría en px a partir de una celda
    WidgetCard.qml      // componente: superficie Crimson Glass (fondo, borde, especular, sombra)
    WidgetHeader.qml    // título + acción opcional
```

**Reglas del contrato (no negociables):**

- Colores **solo** desde tokens: `#DC143C`, `#0A0A0A`, `#FFFFFF`, `#1A1A1A`, `#B3B3B3` y los
  gradientes oficiales. Prohibido cualquier valor hex fuera de `WidgetTheme`. Es la no conformidad
  que ya detectó `docs/auditoria-diseno-tahoe-crimson.md` (deriva cromática a `#e11d2e`/`#ff4d5a`).
- Alpha en formato Qt `#AARRGGBB`, **nunca** `#RRGGBBAA` (lección documentada en `docs/architecture.md`).
- Espaciado en múltiplos de 4; radios desde tokens; sin radios inventados.
- Material: el widget consume el estado de Crimson Glass. No reimplementa detección de GPU ni
  activa blur por su cuenta.
- Cada widget declara `readonly property var supportedSizes` y su tamaño por defecto.
- Persistencia: `Plasmoid.configuration` por instancia. Nada de escribir en `/etc/skel` ni en
  ubicaciones compartidas.
- Datos: señales/DBus cuando existan (UPower, NM, MPRIS); temporizador mínimo de 5 s y **detenido**
  cuando el widget no es visible. Sin polling agresivo.

---

## 9. Galería y modo edición

`dylanos-widgets`: app QML frameless de DylanOS (mismo patrón que Configuration/Explorer:
semáforos a la izquierda, `startSystemMove()`, `setDesktopFileName("org.dylanos.widgets")`).

- Catálogo de los 20, agrupado por categoría (Tiempo, Sistema, Productividad, Medios, Red),
  con buscador y **preview en vivo** (instancia real del widget, no captura).
- Botón «Añadir al escritorio»: llama al script de `addWidget(type, x, y, w, h)` con la celda del
  §5 y busca hueco libre.
- Selector de tamaño por widget, limitado a `supportedSizes`.
- «Modo edición»: delega en el modo de edición de Plasma (arrastrar/redimensionar/quitar) y ofrece
  un botón que lo activa. No se reimplementa la interacción.
- Ajustes de material por widget y globales (blur, opacidad, variante oscura/carmesí/clara) con
  interruptor de **modo rendimiento** que sube opacidad y desactiva blur.

---

## 10. Plan por fases y verificación

| Fase | Contenido | Verificación exigida |
|---|---|---|
| **F0** | `libdylanos-widgets` + tokens + `WidgetCard` | Revisión de tokens: cero hex fuera del singleton; carga QML en chroot |
| **F1** | Detección live (§5) + `--apply-widget-layout` + autostart + Reloj, Calendario, Clima | Test Python de la detección (live/instalado/marca/idempotencia); test del script de geometría con `node` (mismo harness que `test_desktop.py`); carga real de los 3 applets en chroot |
| **F2** | Galería `dylanos-widgets` + creación vía scripting API | Test de contrato del catálogo (20 entradas, campos obligatorios); carga QML offscreen; staging del `.desktop` e icono |
| **F3** | Widgets 4–20 | Un test de contrato por widget (fuente declarada, sin datos ficticios); carga en `plasmawindowed` |
| **F4** | Material configurable + modo rendimiento | Test de que el modo rendimiento sube opacidad y apaga blur; revisión de que ningún widget ignore el token |
| **F5** | `docs/widgets.md`, CHANGELOG, `docs/architecture.md`, `docs/roadmap.md`, AGENTS.md | `scripts/check.sh` completo |

**Qué se puede verificar en este host (sin chroot ni Qt):** tests Python de detección e
idempotencia; ejecución del script de geometría con `node` (el harness de `test_desktop.py` ya
emula `addWidget(type,x,y,w,h)` y `screenGeometry`); `shellcheck`; `desktop-file-validate`; el
staging completo con `scripts/stage.py` a un root temporal.

**Qué NO se puede verificar aquí y requiere chroot:** carga QML real de los applets
(`test_plasmoid_runtime.sh`), `evaluateScript` contra un `plasmashell` vivo, y el render gráfico.
No se declarará «terminado» nada de eso sin ejecutarlo en el chroot; si no hay chroot disponible,
se entregará como «implementado y probado en estático» con esa etiqueta explícita.

**Criterios de aceptación** (los del encargo, con la corrección de §3): 0 widgets en live; 3 widgets
exactos en instalado con la geometría de §5; 20 widgets catalogados con contrato; galería y
redimensionado operativos; Crimson Glass consistente y con modo rendimiento; sin regresión en
`scripts/check.sh`; documentación y CHANGELOG actualizados.

---

## 11. Riesgos

| Riesgo | Impacto | Mitigación |
|---|---|---|
| `evaluateScript` llega antes de que `plasmashell` esté listo | Sin widgets al primer login | `X-KDE-autostart-after=panel` + reintento acotado; no se marca como aplicado hasta confirmar |
| El usuario borra los 3 widgets y no quiere que vuelvan | Molestia | Marca por usuario; nunca se re-aplica |
| Clima sin proveedor | Widget vacío percibido como fallo | Estado explícito con acción a configuración; jamás datos inventados |
| Redimensionado libre no encaja en la grilla | Layout descuadrado | `minimumWidth/Height` proporcionales + declararlo como límite |
| Añadir `folderlistmodel` engorda la ISO | Peso | Es un módulo pequeño; se mide en el manifest |
| 20 widgets elevan el coste de mantenimiento | Deuda | Librería común obligatoria; ningún widget con estilos propios |
| Colores hardcodeados (deriva ya vista) | Inconsistencia visual | Token único + revisión explícita en F0 y F4 |

---

## 12. Decisiones que necesito del responsable

1. ~~**Alcance de la primera entrega**~~ — **Resuelto:** se aprobó F0–F2 y después F3; los 20
   widgets están implementados (ver `docs/widgets.md`).
2. ~~**Fotos y Portapapeles**~~ — **Resuelto:** se aprobó añadir dependencias. Fotos usa
   `qml6-module-qt-labs-folderlistmodel` y el Portapapeles lee con `xclip`. El *historial* sigue
   fuera: `klipper` no existe como paquete en trixie y `cliphist` es solo Wayland; el widget lo
   declara en lugar de simularlo.
3. **Próximo evento**: ¿se acepta leer un `.ics` local elegido por el usuario en lugar de un
   calendario de sistema que la imagen no tiene?
4. ~~**Clima**~~ y ~~**Próximo evento**~~ — **Resuelto:** el Clima se mantiene con estado
   «Configura tu ubicación» y el Próximo evento lee un `.ics` local.
