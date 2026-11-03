# DylanOS Browser — diseño de ingeniería

Estado: diseño inicial basado en la auditoría de Zen Browser 1.24b y Firefox 159.0,
realizada el 2 de noviembre de 2026.

## 1. Intención

DylanOS Browser será un fork real de Zen Browser, con Gecko como motor, identidad y
canal de mantenimiento propios, integrado como navegador oficial de DylanOS Crimson 1.0.
La meta no es ocultar Zen debajo de un tema: el producto debe conservar las piezas maduras
de Firefox y Zen, limitar las modificaciones profundas a ventajas que puedan mantenerse y
medir cada afirmación de rendimiento.

El navegador debe servir primero a usuarios de DylanOS, desde equipos modestos hasta equipos
modernos. Una versión se considera publicable solo si mantiene compatibilidad web, extensiones,
protecciones de seguridad y un procedimiento reproducible para incorporar una corrección de
Firefox con rapidez.

## 2. Hechos de la auditoría

- El upstream estable elegido es `zen-browser/desktop` 1.24b, commit
  `f75390aa2b797ddc3524ff9ed52ceb32a839f9fa`, construido sobre Firefox 159.0.
- Zen no contiene un checkout completo de Firefox. `@zen-browser/surfer` descarga `engine/`,
  aplica el overlay y los parches de `src/`, y delega la compilación a `mach`.
- El árbol auditado contiene cientos de parches sobre Firefox y más de mil archivos en
  `src/zen/`. Los puntos principales son `surfer.json`, `configs/branding`,
  `configs/common/mozconfig`, `prefs/zen`, `src/zen`, `src/browser` y `src/toolkit`.
- La cadena fija Node 22, Python 3.11 y Rust 1.95.0; una compilación completa requiere
  aproximadamente 30 GB libres, además de C/C++, LLVM/lld, GTK, DBus y bibliotecas multimedia.
- Zen ya aporta espacios, contenedores, pestañas verticales, carpetas/grupos, barra de comandos,
  biblioteca, restauración, migradores, DevTools y compatibilidad con extensiones Firefox.
- `zen.tabs.vertical` conserva una ruta horizontal interna, pero Zen diseña y prueba la interfaz
  alrededor de pestañas verticales. La paridad horizontal necesita cambios coordinados de UI,
  JS, CSS y pruebas.
- `zen.widget.linux.transparency` habilita transparencia del chrome. No garantiza blur de KWin:
  Firefox/Zen usa CSD GTK y no recibe automáticamente la región de desenfoque de Aurorae.
- Zen publica binarios y MAR firmados, pero su AppImage desactiva el actualizador interno.
  DylanOS debe usar APT como autoridad del paquete estable; un canal MAR propio queda fuera del
  primer incremento.

## 3. Límites y obligaciones

- El código upstream se conserva bajo MPL-2.0. Cada binario distribuido indicará dónde obtener
  el código fuente correspondiente; se conservarán avisos, autores y licencia, y los archivos
  MPL modificados seguirán disponibles bajo MPL-2.0.
- DylanOS Browser no usará nombres, logos ni elementos de marca de Mozilla o Zen como identidad
  de producto. La documentación podrá describir de forma factual que deriva de Zen y de la
  tecnología Gecko, con un aviso claro de no afiliación.
- No se añade telemetría propia. Los servicios de red heredados se inventariarán, documentarán y
  probarán; los servicios específicos de Zen que no podamos operar o auditar se desactivarán o
  sustituirán antes de una versión estable.
- No se debilitarán el sandbox, Site Isolation, Safe Browsing, TLS, firmas de extensiones ni otras
  defensas para obtener cifras de rendimiento.
- No se afirmará superioridad de rendimiento sin resultados reproducibles contra una línea base
  equivalente, en el mismo hardware, perfil y conjunto de páginas.

## 4. Arquitectura de repositorios

Se mantendrán dos repositorios con responsabilidades distintas:

1. `DylanOS-Browser`: fork de `zen-browser/desktop`. Tendrá `upstream` apuntando a Zen, rama
   principal `development`, rama de publicación `stable` y etiquetas de versión. Alojará el
   código del navegador, branding, preferencias, pruebas de chrome/Gecko, CI y artefactos fuente.
2. `DylanOS`: distribución. Alojará el empaquetado Debian, instalación en el chroot, asociaciones
   XDG, iconos del sistema, selección como navegador predeterminado y pruebas de ISO/QEMU.

No se copiará un checkout de Gecko dentro de `DylanOS`, ni se convertirá el navegador en una app
Qt WebEngine. El paquete de DylanOS consumirá un artefacto fuente o binario firmado producido por
el repositorio del navegador y fijado por versión y SHA-256.

Cada actualización seguirá esta secuencia: Firefox → Zen upstream → `DylanOS-Browser/development`
→ pruebas y revisión de parches → `DylanOS-Browser/stable` → paquete DylanOS → repositorio APT/ISO.
Las correcciones críticas podrán partir de `stable`, pero nunca omitirán las pruebas mínimas de
seguridad, arranque y navegación.

## 5. Identidad y experiencia

- Nombre: `DylanOS Browser`.
- Binario Linux: `dylanos-browser`.
- ID de escritorio: `org.dylanos.browser.desktop`.
- Nombre de aplicación/base Gecko: `DylanOSBrowser` donde se requiera un identificador sin espacios.
- Perfil separado del de Firefox y Zen; nunca se comparte un perfil en ejecución entre productos.
- La marca predeterminada del navegador usa el acento de producto solicitado `#E50914`, negro
  `#0A0A0A`, superficie `#141414` y blanco `#FFFFFF`. Al activar “Seguir DylanOS”, el navegador
  toma el acento real del sistema (actualmente `#DC143C`) sin cambiar la marca global del SO.
- Oscuro es el valor inicial; claro y sistema son opciones persistentes. Contraste alto y
  `prefers-reduced-motion` prevalecen sobre animaciones y transparencias.

La interfaz parte del chrome de Zen y lo modifica por tokens propios. No se reemplazarán piezas
maduras de Firefox (barra URL, permisos, contraseñas, descargas, historial, marcadores, DevTools)
por imitaciones.

## 6. Funciones y fronteras

### Conservar y adaptar

- Gecko, arquitectura multiproceso, WebRender, sandbox, ETP, permisos, cookies, contraseñas,
  Safe Browsing, DevTools, migradores y extensiones Firefox.
- Espacios, carpetas/grupos, biblioteca, restauración, pestañas verticales, Glance y barra de
  comandos de Zen.
- Quick Search se construye como una presentación DylanOS del proveedor de URL/barra de comandos
  existente. Añade acciones internas y una combinación configurable sin crear un segundo índice.

### Desarrollar

- Tokens Crimson y componentes de chrome diferenciados, sin reutilizar activos de marca Zen.
- Página de preferencias DylanOS con estas categorías: Apariencia; Crimson Glass; Pestañas y
  espacios de trabajo; Privacidad y seguridad; Rendimiento; Descargas; Buscadores; Atajos de
  teclado; Integración con DylanOS; Accesibilidad; y Acerca de DylanOS Browser. Reutiliza los
  controles maduros de Firefox/Zen y añade, como mínimo, tema/acento, orientación, perfil visual,
  suspensión de pestañas, transparencia/fallback opaco, atajo de Quick Search, integración con el
  sistema y restauración de valores. Las preferencias nuevas son validadas, persistentes y tienen
  migraciones versionadas.
- Perfil de rendimiento visual: `Completo`, `Equilibrado` y `Ligero`. El modo Ligero elimina blur,
  transparencias y animaciones no esenciales, pero no funciones de seguridad.
- Integración del tema con DylanOS mediante preferencias y lectura de configuración al iniciar o
  recibir un cambio explícito; no se añade un daemon residente.
- Contrato de empaquetado y asociaciones XDG para HTTP, HTTPS y HTML.

### Prototipar antes de prometer

- Pestañas horizontales con paridad de espacios, fijadas, carpetas, arrastre, split view y sesión.
- Blur real bajo KDE Plasma 6 en X11 y Wayland. La alternativa siempre disponible es una superficie
  opaca equivalente; transparencia sin contraste suficiente se considera fallo.
- Aislamiento fuerte entre espacios. La primera versión estable ofrece dos conceptos explícitos:
  un espacio normal usa un contenedor y advierte que historial/extensiones siguen compartidos; un
  “perfil aislado” abre otra ventana y proceso con directorio de perfil distinto. El selector de
  espacios puede lanzar ese perfil, pero no mezcla sus pestañas, historial, marcadores, búsqueda ni
  estado de sesión con la ventana normal. Nunca se presenta un contenedor como aislamiento total.

## 7. Crimson Glass

Crimson Glass tendrá una máquina de decisión simple:

1. Si el usuario lo desactiva, usar superficies opacas.
2. Si está activo el perfil Ligero, usar superficies opacas.
3. Si falta aceleración o el backend no demuestra blur correcto, usar superficies opacas con el
   mismo contraste, bordes y jerarquía.
4. Solo habilitar transparencia/blur cuando una prueba de capacidad y una prueba visual en el
   backend concreto pasen.

DylanOS Configuration es la única autoridad que configura Crimson Glass para todo el sistema. La
categoría Crimson Glass del navegador muestra el estado efectivo y abre directamente esa ruta de
Configuration para cambiarla; no escribe la configuración global. El navegador sí puede forzar su
fallback opaco desde Rendimiento/Accesibilidad cuando falta aceleración, se pide reducir movimiento
o se activa el perfil Ligero. Así se evita un segundo configurador y se conserva una salida segura.

## 8. Privacidad y seguridad

- Mantener las protecciones upstream y documentar cualquier desviación de sus valores.
- Inventariar conexiones de primer arranque, búsqueda, Safe Browsing, actualizaciones, Sync,
  Mods/Boosts, compartir espacios y live folders.
- Desactivar por defecto servicios específicos de Zen que apunten a infraestructura ajena hasta
  disponer de política, operación y revisión propias. No se sustituirán por servicios improvisados.
- APT será el canal estable de actualización en DylanOS. El navegador no reemplazará silenciosamente
  archivos del paquete. Los artefactos se verificarán con SHA-256 y firma del repositorio.
- SLA objetivo: evaluar una actualización de seguridad de Firefox/Zen el mismo día y publicar una
  compilación corregida dentro de 72 horas cuando no exista un bloqueo documentado. Una incidencia
  crítica puede exigir un hotfix más rápido.
- Si Mozilla publica una corrección crítica antes que Zen, DylanOS Browser no espera al siguiente
  release de Zen: crea un hotfix desde `stable`, actualiza directamente la base Firefox mediante
  Surfer o porta el parche oficial mínimo, resuelve el overlay DylanOS/Zen y ejecuta la puerta de
  seguridad. Si el parche no es portable con seguridad, se desactiva temporalmente la superficie
  vulnerable cuando sea viable y se publica el bloqueo con su mitigación; la demora no se considera
  aceptable solo porque Zen todavía no haya publicado.
- Publicar `SECURITY.md`, procedimiento privado de reporte, SBOM/lista de dependencias y procedencia
  de cada artefacto.

## 9. Rendimiento verificable

La optimización empieza con una línea base, no con preferencias arbitrarias. En hardware y entorno
fijados se medirán al menos:

- tiempo hasta primera ventana y hasta página interactiva, arranque frío y caliente;
- RSS/PSS del árbol de procesos con 1, 10, 30 y 50 pestañas, activas y descargadas;
- CPU y despertares durante cinco minutos en reposo;
- tiempo de apertura, cambio y cierre de pestaña, búsqueda URL y cambio de espacio;
- frames perdidos al desplazar la barra lateral y al usar Crimson Glass;
- tamaño instalado y tiempo de restauración de sesión.

Se conservarán PGO/LTO y las optimizaciones del motor. No se publicará una variante AVX2: Zen ya la
retiró por no demostrar una ventaja fiable frente a PGO/LTO. Las optimizaciones propias se limitarán
primero al chrome: inicialización diferida, observadores con ciclo de vida explícito, animaciones de
`transform`/`opacity`, ausencia de timers de sondeo y carga bajo demanda de paneles.

Cada cambio de rendimiento incluye escenario, comando, datos crudos, mediana y dispersión. Una
regresión de seguridad o funcionalidad invalida la mejora.

## 10. Integración con DylanOS

El estado final sustituirá `firefox-esr` en el paquete base, `mimeapps.list`, dock y workspace por
`org.dylanos.browser.desktop`/`dylanos-browser`. La retirada se hará en dos pasos:

1. Instalar y probar DylanOS Browser junto a Firefox ESR en el chroot y en una VM limpia.
2. Cuando abrir HTTP/HTTPS, ventana privada, descargas, selectores y extensiones funcione, retirar
   Firefox ESR del perfil predeterminado y purgar restos de chroots reutilizados.

El `.desktop` canónico incluirá `%U`, categorías `Network;WebBrowser;`, acciones Nueva ventana y
Nueva ventana privada, tipos MIME admitidos y `StartupWMClass` coherente. `xdg-settings` y
`xdg-mime` respetarán decisiones de usuarios existentes; los valores por defecto solo se aplican a
usuarios nuevos y a la imagen del sistema.

## 11. Entregas por fases

1. **Base mantenible:** fork local/remoto, remotos, pin 1.24b, licencia, branding mínimo,
   metadatos propios, script de auditoría de referencias upstream y CI de licencia/lint.
2. **Binario funcional:** bootstrap, compilación Linux genérica, pruebas upstream y paquete de prueba.
3. **Identidad y ajustes:** tokens Crimson, iconos propios, páginas de preferencias y fallback opaco.
4. **Funciones DylanOS:** Quick Search, integración de tema, perfiles visuales y aislamiento honesto.
5. **Rendimiento:** harness reproducible, línea base, perfiles, optimizaciones y límites de regresión.
6. **Distribución:** paquete Debian, APT, defaults XDG, dock/workspace y migración desde Firefox ESR.
7. **Calidad de lanzamiento:** VM limpia, actualización, desinstalación, extensiones, privacidad,
   accesibilidad, compatibilidad y documentación de pendientes.

Cada fase termina con software o infraestructura ejecutable y pruebas; ninguna fase se declara
completa por producir solo documentación.

## 12. Decisiones del diseño

- Se elige un fork dedicado y un paquete de distribución separado, porque tienen cadencias y
  superficies de riesgo distintas.
- Se parte de Zen estable, no de `dev`, para que la primera línea base sea reproducible.
- Se reutilizan funciones de Zen/Firefox antes de crear equivalentes DylanOS.
- Se usa APT como actualizador estable inicial y se aplaza MAR propio.
- Se conserva Firefox ESR temporalmente solo durante la validación de integración; el producto final
  vuelve a una sola aplicación por función.
- El blur integral y la paridad horizontal son prototipos con criterios de salida, no promesas ya
  cumplidas.
