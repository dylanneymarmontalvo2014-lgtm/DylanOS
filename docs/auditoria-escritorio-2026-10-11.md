# Auditoría y módulos de la renovación visual

## Estado inicial

- El tema global se empaqueta en `plasma/lookandfeel`, pero la ruta de KPackage es `plasma/look-and-feel`: impide descubrir el tema. Se corrige el destino y su prueba.
- El layout inicial instala una sola barra superior con tareas. `dylanos-default.png` existe, pero `stage.py` solo copia los fondos generados Dark/Light y el layout selecciona Dark.
- GTK 3/4 ya tiene una base Crimson; hay propiedades CSS de navegador incompatibles con GTK y falta integración completa de estados y variante clara.
- Workspace combina siete herramientas en una ventana. Cada lanzador abre esa misma navegación. Monitor actualiza procesos incluso cuando se usa otra herramienta.
- App Center tiene cuadrícula fija de 850 px, poca navegación con teclado y no indica búsquedas vacías. Calculadora usa botones que no aceptan foco.
- No existe splash de sesión propio. El splash de Plasma y Plymouth son capas distintas.
- El build usa `installer/calamares/beta`, no el branding alternativo `dylanos`. Ese branding usa claves de color incorrectas y no incluye stylesheet.
- El ZIP de Figma es una aplicación React de demostración: discos, hardware y progreso simulados. Las llamadas `Calamares.*` de sus notas no constituyen una API instalada.
- Hay cambios previos del usuario en ISO/QEMU/test_ui y eliminación de installer_preview.py; se conservan.

## Módulos y decisiones

| Módulo | Archivos | Corrección |
| --- | --- | --- |
| Payload | scripts/stage.py, configs/plasma | Copiar fondo original, valores por defecto y recursos resueltos |
| Escritorio | themes/lookandfeel, themes/plasma, themes/aurorae | Barra superior + dock nativo, vidrio con fallback opaco, splash independiente |
| GTK | themes/gtk, configs/plasma/skel | GTK 3 y 4, variantes y estados reales; no sustituir apps existentes |
| Apps | apps/workspace, calculator, dylanos-app-center | Ventanas independientes, monitor y desarrollo enfocados, controles accesibles |
| Instalación | installer/calamares/beta | Adaptar composición, banner y paleta del ZIP al Calamares nativo; datos y operaciones de sus módulos |

La ISO existente no incorpora cambios del árbol de fuentes hasta reconstruirla. El layout inicial se aplica a perfiles nuevos; no se borran paneles de usuarios existentes.

## Hallazgos corregidos durante la validación

- App Center compilaba, pero `loadFromModule()` no encontraba Main porque el
  recurso estaba fuera del prefijo de importación. Se fija el prefijo y se carga
  su URL QRC explícita. El proveedor conserva un icono visible cuando falta uno.
- GTK 3 rechazaba `filter: brightness()` y GTK 4 rechazaba `:horizontal` aplicado
  al slider. Ambos motores cargan ahora las variantes clara y oscura sin errores.
- Calculadora mantenía la entrada de teclado en un elemento hermano de los
  botones: al darles foco se perdían las teclas. Ahora usa atajos de ventana.
- El logo de Ajustes apuntaba a un directorio inexistente del payload. Ahora
  utiliza un recurso empaquetado en la propia aplicación.
- Los colores producidos por el generador volvían al acento anterior. Se alinea
  el generador con Crimson para que regenerar los SVG no revierta la identidad.

## Alcance de la adaptación

Se usan las APIs de [layout de Plasma](https://develop.kde.org/docs/plasma/scripting/api/)
y el [branding de Calamares 3.3.14](https://github.com/calamares/calamares/blob/v3.3.14/src/branding/default/branding.desc).
La barra lateral lee ViewManager; los módulos nativos conservan las validaciones,
particionado, contraseñas y trabajos de instalación. El panel de hardware ficticio
del ZIP no se muestra como si fueran datos reales. Los pasos centrales mantienen
sus controles Qt: la adaptación visual no es una ejecución del frontend React.

GTK 3 y GTK 4 tienen tema propio, incluidos foco, hover, selección y controles de
ventana. Las apps que imponen libadwaita o sus propios temas y las apps Flatpak
que no tienen acceso al tema pueden conservar parte de su apariencia. No se fuerza
un CSS global dentro de esas aplicaciones. El vidrio del escritorio depende del
compositor de KWin; los SVG opacos cubren los equipos sin composición.

Las implementaciones experimentales de dock/control-center con datos mock no
se activan: el dock usa icontasks y la barra superior usa el área de estado nativa.
Los menús globales aparecen en aplicaciones que exportan un menú compatible.

## Comprobaciones

- Validación Bash/ShellCheck, entradas desktop, staging repetido y payload.
- Pruebas de datos y QML: notas persistentes, operaciones de archivos, plantillas,
  ciclo de vida separado de Monitor/Desarrollo, historial, teclado de Calculadora,
  búsqueda y paginación de App Center, layout de dos paneles y CSS con GTK 3/4 reales.
- Compilación de App Center y Calculadora con Qt 6.8.2/KF6 de Debian 13 en el chroot.
- Ejecución de ambos binarios; detección del tema con plasma-apply-lookandfeel;
  carga real de KSplash y Calamares 3.3.14 con configuración de QA sin trabajos de disco.
- Capturas de las siete vistas, Calculadora y splash en `artifacts/renewal/`.

La carga de Calamares en QA usa welcome/locale/keyboard/users/summary; no ejecuta
particionado ni instalación. Las advertencias de locale1 del chroot corresponden
a que ese entorno de prueba no ejecuta el bus del sistema.
