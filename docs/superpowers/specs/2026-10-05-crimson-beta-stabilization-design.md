# Diseño de estabilización de DylanOS Crimson 1.0 Beta

**Fecha:** 2026-10-05  
**Rama objetivo:** `development`  
**Base:** Debian 13 (trixie), KDE Plasma 6 y Qt 6

## Objetivo

Estabilizar los fallos técnicos confirmados durante la auditoría de la beta sin
rediseñar DylanOS, cambiar su arquitectura, modificar `main` ni tocar el
contenido de `installer/calamares/`. La identidad visual Crimson existente se
conserva; los cambios de color se limitarán a acentos que actualmente
representan el color principal.

## Límites no negociables

- No modificar archivos bajo `installer/calamares/`.
- No usar `git reset --hard`, `git clean -fd`, force push ni operaciones sobre
  discos o particiones reales.
- Trabajar exclusivamente en `development`.
- No sustituir el gestor funcional de archivos de Workspace por el prototipo
  antiguo de `apps/archivos/qml`.
- No afirmar `PASS` cuando una dependencia impida ejecutar una prueba.

## Cambios de diseño

### 1. App Center

`AppModel` seguirá siendo la fuente de servicios KDE, pero su contrato de
lanzamiento dejará de aceptar índices internos. `itemsForPage()` expondrá
`desktopId` como identificador estable y QML llamará a
`launchApp(desktopId)`. La implementación buscará el servicio por
`storageId()` y rechazará identificadores vacíos o inexistentes sin iniciar un
servicio incorrecto.

Se eliminarán las reglas de instalación CMake duplicadas. El archivo `.desktop`
usará `Exec=dylanos-app-center`, de forma que Debian, CMake y los entornos de
staging resuelvan el binario mediante `PATH` sin depender de `/usr/local/bin`.

### 2. Staging y branding

`stage.py` usará el recurso de branding que realmente existe en el repositorio
para el icono general y para Calamares, sin editar el instalador. Se mantendrá
la protección contra destinos peligrosos y se añadirán comprobaciones de
staging para detectar referencias a archivos ausentes antes de construir la
imagen.

### 3. Archivos

`apps/archivos/main.py` permanecerá como launcher compatible que ejecuta
Workspace con `--page files`. Se eliminará solamente el bloque QML independiente
que queda después del `return`, porque nunca se ejecuta. El prototipo QML se
conservará como fuente histórica no productiva y su README lo identificará
explícitamente como prototipo con datos simulados no conectado al disco.

La implementación de producción continuará usando `apps/workspace`, que lista
el sistema de archivos real, ejecuta operaciones mediante Qt/Python y no
presenta capacidades ficticias.

### 4. Sintaxis y paleta

Se corregirá la propiedad QML `selectionColor` del tema SDDM para que use un
literal de color válido. Los acentos principales equivalentes se centralizarán
en `#DC143C` o en tokens existentes; no se cambiarán colores que expresen
estados, tipos de archivo o etiquetas con significado independiente.

Los identificadores técnicos Tahoe de Plasma, Aurorae, SDDM y Look-and-Feel no
se renombrarán masivamente porque forman parte de rutas, metadatos y
configuración KDE. La documentación explicará que pertenecen a la base visual
heredada de la edición Crimson.

### 5. Artefactos y validación

`.gitignore` cubrirá artefactos CMake, Qt, Debian y Python que no sean fuentes.
Los artefactos existentes en el árbol de trabajo se eliminarán de forma
selectiva sin tocar código fuente ni archivos rastreados legítimos.

La validación cubrirá, según las dependencias disponibles:

- sintaxis de Shell y ShellCheck;
- pruebas unitarias Python y `compileall`;
- staging repetible y seguro;
- validación de todos los `.desktop`;
- configuración y compilación limpia de Calculator y App Center;
- inspección de instalación, ejecutable, icono y QML del App Center;
- smoke tests QML disponibles en modo offscreen;
- validación de la estructura ISO si existe una ISO construida.

Cada resultado final se clasificará como `PASS`, `FAIL`, `NOT RUN` o `WARNING`
con la razón correspondiente.

## Secuencia de implementación

1. Corregir App Center y añadir sus verificaciones de contrato.
2. Corregir staging/branding y actualizar sus pruebas.
3. Limpiar el launcher de Archivos y documentar el prototipo.
4. Corregir QML y acentos Crimson equivalentes.
5. Reforzar `.gitignore` y retirar artefactos generados.
6. Ejecutar validaciones por capas, corregir regresiones y repetirlas.
7. Crear commits lógicos con la atribución requerida.
8. Verificar el diff final, ausencia de cambios en Calamares, estado limpio y
   sincronización antes de hacer push a `origin/development`.

## Criterio de finalización

La beta solo se considerará lista cuando no existan fallos conocidos sin
justificación, las pruebas ejecutables pasen, las no ejecutadas estén
identificadas con su causa, el staging se genere correctamente, App Center sea
instalable y ejecutable, y el push a `origin/development` se complete sin
force push ni modificar `main` o `installer/calamares/`.
