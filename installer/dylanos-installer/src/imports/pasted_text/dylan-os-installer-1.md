RECONSTRUCCIÓN DEFINITIVA DEL INSTALADOR DYLANOS

IMPORTANTE:
ESTE NO ES UN PEDIDO PARA MEJORAR EL PROTOTIPO ANTERIOR.

QUIERO QUE RECONSTRUYAS EL PROTOTIPO DESDE CERO.

Las imágenes adjuntas son los DISEÑOS OFICIALES de referencia del
instalador DylanOS.

Analiza TODAS las imágenes antes de comenzar.

El resultado final debe ser una reconstrucción funcional de los
diseños, NO una interpretación libre.

==================================================
OBJETIVO PRINCIPAL
==================================================

Quiero que el resultado sea lo más cercano posible a los bocetos.

OBJETIVO DE FIDELIDAD VISUAL: 100%.

No quiero aproximadamente 90%.
No quiero "inspirado en".
No quiero "similar".

QUIERO RECONSTRUIR LOS BOCETOS.

Si existe una diferencia entre el diseño anterior generado por
Figma Make y los bocetos adjuntos, IGNORA EL DISEÑO ANTERIOR y
PRIORÍZAME LOS BOCETOS.

==================================================
REGLA ABSOLUTA DE ANÁLISIS
==================================================

ANTES de escribir código:

1. Analiza todas las imágenes.
2. Identifica qué pantalla representa cada imagen.
3. Identifica todos los elementos visibles.
4. Identifica la posición relativa de cada elemento.
5. Identifica tamaños y proporciones.
6. Identifica colores.
7. Identifica tipografías y jerarquías.
8. Identifica bordes y radios.
9. Identifica sombras.
10. Identifica transparencias.
11. Identifica iconos.
12. Identifica botones.
13. Identifica estados.
14. Identifica navegación.
15. Identifica elementos repetidos entre pantallas.

NO empieces a programar antes de analizar todas las imágenes.

==================================================
RECONSTRUIR, NO REDISEÑAR
==================================================

NO cambies:

- distribución;
- estructura;
- composición;
- proporciones;
- posición;
- jerarquía;
- colores;
- tamaños;
- espaciado;
- estilo visual;

salvo que sea estrictamente necesario para hacer funcionar una
interacción.

Si un elemento aparece en el boceto, debe aparecer en el prototipo.

Si un elemento NO aparece en el boceto, no lo agregues simplemente
porque "quedaría mejor".

NO simplifiques las pantallas.

NO reemplaces tarjetas por componentes genéricos.

NO reemplaces iconos por emojis.

NO sustituyas elementos visuales importantes.

==================================================
PANTALLAS
==================================================

Reconstruye todas las pantallas proporcionadas en las imágenes.

Incluye también la pantalla de creación de usuario que fue definida
posteriormente.

Flujo:

1. Bienvenido
2. Idioma
3. Teclado
4. Particionado
5. Creación de usuario
6. Resumen
7. Instalando DylanOS
8. Finalizar

Cada pantalla debe corresponder visualmente a su boceto.

==================================================
FUNCIONALIDAD
==================================================

Además de reconstruir visualmente las imágenes, convierte el diseño
en un prototipo funcional.

Debe funcionar:

- navegación;
- Siguiente;
- Atrás;
- Cancelar;
- selección de idioma;
- selección de teclado;
- selección de particionado;
- formularios;
- validación de usuario;
- validación de contraseñas;
- nombre de máquina;
- resumen;
- progreso de instalación;
- estados de instalación;
- finalización.

Las transiciones deben sentirse como una única aplicación.

==================================================
DATOS DINÁMICOS
==================================================

Hay elementos que en el instalador real serán proporcionados por
Linux/Calamares.

NO inventes que Figma Make puede obtener esos datos realmente.

Utiliza datos MOCK durante el prototipo para:

- CPU;
- GPU;
- RAM;
- almacenamiento;
- modelo del equipo;
- discos;
- particiones;
- estado de instalación.

Pero crea una arquitectura que permita reemplazarlos posteriormente
por datos reales.

Ejemplo:

mockSystemInfo

mockDiskInfo

mockInstallationState

==================================================
INSTALACIÓN
==================================================

La instalación debe ser simulada en Figma Make.

NO modificar discos reales.

NO crear usuarios reales.

NO cambiar contraseñas reales.

NO ejecutar comandos del sistema.

NO reiniciar el equipo.

La pantalla debe mostrar un progreso simulado convincente.

Posteriormente conectaremos estas partes con Calamares.

==================================================
ARQUITECTURA
==================================================

Mantén el proyecto organizado.

Separar:

components/
screens/
data/
state/
services/
assets/
styles/
docs/

Cada pantalla debe tener componentes claramente identificables.

Usar nombres como:

WelcomeScreen
LanguageScreen
KeyboardScreen
PartitioningScreen
UserCreationScreen
SummaryScreen
InstallationScreen
FinishScreen

NO utilizar nombres como:

page1
page2
frame123
component1
test
temp

==================================================
DATOS MOCK
==================================================

Todos los datos ficticios deben estar separados del diseño.

Utiliza archivos o módulos como:

mockSystemInfo
mockDiskInfo
mockInstallationProgress

NO colocar datos simulados directamente dentro de componentes
visuales.

==================================================
INTEGRACIÓN FUTURA CON CALAMARES
==================================================

Marcar claramente las partes que posteriormente deberán conectarse
con Calamares/Linux.

Usar comentarios como:

// DYLANOS-MOCK
// DYLANOS-INTEGRATION

Ejemplo:

// DYLANOS-MOCK:
// Hardware mostrado únicamente para el prototipo.

// DYLANOS-INTEGRATION:
// Replace mock hardware data with real system information.

// DYLANOS-INTEGRATION:
// Connect this action to the Calamares partitioning module.

==================================================
RECURSOS VISUALES
==================================================

Utiliza los recursos adjuntos siempre que sea posible.

Si existe un logo en los bocetos, respeta su apariencia.

Si existe un icono específico, no lo sustituyas por un icono
genérico.

Si existe una ilustración o imagen específica, respeta su
composición.

Mantén los assets separados en:

assets/
├── logos/
├── icons/
├── backgrounds/
└── illustrations/

==================================================
RESPONSIVE
==================================================

El diseño debe mantener las proporciones y composición de los
bocetos en diferentes tamaños de ventana.

NO cambiar la estructura visual simplemente porque cambie la
resolución.

Adaptar los elementos conservando la identidad visual.

==================================================
ANIMACIONES
==================================================

Si los bocetos implican estados animados:

- crear transiciones suaves;
- hover;
- pressed;
- focus;
- selección;
- progreso;
- cambios de pantalla.

Las animaciones deben ser discretas y coherentes con DylanOS.

NO agregar animaciones llamativas que no existan en el diseño.

==================================================
VALIDACIÓN VISUAL
==================================================

Antes de considerar TERMINADO el trabajo:

Compara cada pantalla generada contra su imagen de referencia.

Realiza una revisión visual pantalla por pantalla.

Verifica:

□ posición
□ tamaño
□ proporción
□ color
□ tipografía
□ espaciado
□ iconos
□ botones
□ tarjetas
□ sidebar
□ fondos
□ transparencias
□ sombras
□ bordes
□ navegación

Si una pantalla no coincide con su referencia, corrígela.

NO consideres terminado el proyecto hasta que todas las pantallas
sean visualmente equivalentes a sus respectivos bocetos.

==================================================
CRITERIO FINAL
==================================================

El resultado debe cumplir simultáneamente:

100% fidelidad visual objetivo
+
prototipo funcional
+
arquitectura organizada
+
datos MOCK separados
+
puntos de integración con Calamares
+
código mantenible.

LA PRIORIDAD ES:

1. Fidelidad a los bocetos
2. Funcionalidad
3. Arquitectura
4. Integración futura

NO priorices velocidad de implementación sobre fidelidad visual.

Tómate el tiempo necesario para analizar las imágenes.

NO reduzcas el diseño para terminar más rápido.

NO hagas una versión simplificada.

RECONSTRUYE EL INSTALADOR DYLANOS A PARTIR DE LOS BOCETOS.