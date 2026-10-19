# DylanOS Crimson SDDM

## Diagnóstico

El greeter de SDDM 0.20 instalado para la prueba está enlazado contra Qt 5. Al
abrir el tema con `sddm-greeter --test-mode --theme`, Qt registraba
`Library import requires a version` al cargar `Main.qml` y luego usaba el tema
embebido de SDDM. La causa eran los imports sin versión de QtQuick,
QtQuick.Controls y QtQuick.Layouts en `Main.qml` y los componentes QML.

`QtVersion=6` en `metadata.desktop` no era el origen: el greeter sí encontraba
y cargaba `Main.qml`; el fallo ocurría después, al resolver los imports QML.

## Corrección y compatibilidad

Los imports del tema declaran las versiones de API compatibles con Qt 5
(QtQuick 2.15 y QtQuick.Controls 2.15). Estas versiones también funcionan con
Qt 6, por lo que el tema se puede probar con ambos greeters sin depender de
imports implícitos.

## Datos y acceso

El fondo configurado (`/usr/share/wallpapers/DylanOS/dylanos-default.png`) es
el mismo que el escritorio DylanOS establece como predeterminado. `stage.py`
instala ese archivo junto con el tema.

El greeter muestra la foto asociada al usuario seleccionado en
`/var/lib/AccountsService/icons/`; si no existe, muestra su inicial. La fecha y
la hora se actualizan desde el reloj local. El campo de contraseña está visible
y enfocado desde el inicio, y conserva el envío mediante `sddm.login`.

Se retiraron el pronóstico, los eventos, la música, recordatorios, atajos y
métricas con valores de muestra. SDDM no proporciona esas fuentes de datos y el
greeter no debe presentarlas como información del sistema.

## Prueba

La regresión se comprueba con el greeter real en modo de prueba:

```sh
python3 -m unittest scripts.tests.test_sddm_theme -v
```

La prueba abre el tema durante unos segundos y falla si SDDM carga su tema
embebido o Qt informa que falta una versión de import. El tema también se
instala en `/usr/share/sddm/themes/DylanOS-Crimson` mediante `scripts/stage.py`.
