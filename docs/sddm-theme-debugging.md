# DylanOS Crimson SDDM

## Compatibilidad del greeter

El greeter de SDDM 0.20 usado al investigar previamente el tema estaba enlazado contra Qt 5. Los imports explícitos de QtQuick/QtQuick.Controls 2.15 permiten evitar el error `Library import requires a version` y son compatibles con Qt 6. El tema conserva `QtVersion=6` en `metadata.desktop` para la imagen DylanOS, basada en Qt 6.

## Composición e información mostrada

La composición mantiene los rasgos principales de `previews/DylanOS shell/sddm_preview.png`, idéntica a `previews/pantalla de bloqueo/sddm_preview.png`: fondo y velo oscuro, marca superior, reloj/fecha centrales, tarjetas laterales translúcidas y acceso en la franja inferior. La huella fue sustituida por la identidad del usuario y una entrada de contraseña redondeada, enmascarada y enfocada.

El perfil usa el `userModel` de SDDM (nombre y rol `icon`); si ese rol no apunta a una imagen, intenta `/var/lib/AccountsService/icons/<nombre-de-usuario>`. Si no se puede cargar la foto se muestra la inicial del usuario seleccionado. No se añade una imagen personal al ISO. El selector de sesión usa `sessionModel`, el reloj/fecha vienen de la hora local del greeter y las acciones de energía consultan las capacidades `sddm.canPowerOff`, `canReboot` y `canSuspend` antes de ejecutar la API SDDM.

SDDM no proporciona APIs de clima, agenda/eventos, MPRIS, recordatorios, batería/almacenamiento, estado de red ni métricas del sistema. Se eliminaron las tarjetas y sus componentes que exponían valores de muestra (pronóstico, evento, pista musical, telemetría, tareas y atajos); nunca deben presentarse como datos reales. Su lugar lo ocupan tarjetas veraces de usuario/avatar, sesiones detectadas, fecha local y capacidades de energía. Los iconos estáticos de estado de red/batería también se quitaron porque no reflejaban estado real.

## Pruebas y resultado

Pruebas automatizadas del tema:

```sh
python3 -m unittest scripts.tests.test_sddm_theme -v
```

Esta suite comprueba contrato de identidad y avatar con inicial de respaldo, contraseña/enfoque, login, APIs de energía, paneles reales y ausencia de antiguas muestras. Si `sddm-greeter` existe, también lanza `sddm-greeter --test-mode --theme <copia>` usando Qt offscreen y rechaza el tema embebido de fallback y errores QML/import.

Validación disponible en la sesión de edición (2026-10-22): los tests estáticos pasaron (2/2); el caso con greeter real se omitió porque `sddm-greeter` no estaba instalado. No se ejecutó `scripts/check.sh` ni la batería global completa.

La comprobación de VM debe usar una ISO real:

```sh
bash scripts/test_QEMU.sh
```

En esta sesión no se pudo ejecutar arranque QEMU: faltaba `qemu-system-x86_64`; `bash scripts/test_QEMU.sh --dry-run` se intentó y se detuvo por esa dependencia, por lo que ni siquiera certificó el comando completo. VirtualBox tampoco estaba disponible. No se afirma que la interfaz haya cargado en SDDM ni que la ISO haya arrancado en QEMU/VirtualBox. El smoke test SDDM y el arranque VM deben completarse en el CI/builder o host que disponga de esas herramientas.
