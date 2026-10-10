# Auditoría de Diseño: Shell de Sistema DylanOS Crimson
## Evaluación de Estilo macOS Tahoe 26, Fidelidad de Branding y Eliminación de Elementos Ficticios

**Fecha:** 2026-10-09  
**Objetivo Auditado:** Componentes del Shell de Sistema (`apps/dylanos-control-center`, `apps/com.dylanos.dock`, integración con `themes/aurorae` y `themes/gtk`).  
**Estado:** Auditoría Técnica y Propuesta de Estandarización Visual.  
**Paleta de Referencia Oficial:** [branding/colors/dylanos.conf](file:///home/dylan/DylanOS/branding/colors/dylanos.conf) · [branding/README.md](file:///home/dylan/DylanOS/branding/README.md)  
**Activo de Identidad Oficial:** [branding/logo.png](file:///home/dylan/DylanOS/branding/logo.png) (PNG RGBA 108×114, staging 512×512 hicolor).

---

## 1. Resumen Ejecutivo

La presente auditoría evalúa la conformidad estilística, ergonómica y cromática del **Shell de Sistema de DylanOS** frente al referente de experiencia de usuario de **macOS Tahoe 26**, exigiendo la aplicación rigurosa de los colores oficiales del branding y la eliminación total de cualquier elemento ficticio, mockups huérfanos o suplantaciones del logotipo de la marca.

### Veredicto Global
| Criterio | Calificación | Diagnóstico |
|---|:---:|---|
| **Alineación Estética macOS Tahoe 26** | **8.5 / 10** | Excelente trabajo en la morfología (bordes squircle 16–22px, sliders tipo píldora, controles semáforo a la izquierda y microinteracciones fluidas). Requiere refinar la consistencia de desenfoque y capas de elevación translúcidas. |
| **Fidelidad al Branding Oficial** | **6.0 / 10** | **Discrepancia detectada.** Se encontraron colores no autorizados heredados (`#e11d2e`, `#ff4d5a`, `#1a1414`, `#2a1618`) en lugar de los tokens oficiales de DylanOS (`#DC143C`, `#0A0A0A`, `#1A1A1A`). |
| **Autenticidad y Cero Ficción** | **5.5 / 10** | **Crítico.** Presencia de referencias ficticias heredadas de Apple (`airdrop` en `MockData.qml`) y omisión del logotipo real `branding/logo.png` en módulos donde se utilizaron caracteres de texto de sustitución como `"D"`. |

---

## 2. Benchmark de Diseño: macOS Tahoe 26

El lenguaje visual de macOS Tahoe 26 se distingue por cuatro pilares fundamentales de diseño de interfaz de usuario:

```
        ┌────────────────────────────────────────────────────────┐
        │                 macOS Tahoe 26 Design                  │
        ├──────────────────────────┬─────────────────────────────┤
        │  Morfología y Materiales │  Translucidez y Vidrio      │
        │  • Radios Squircle 16-22px│  • Opacidad 55% - 75%       │
        │  • Borde especular 1px   │  • Desenfoque KWin Blur     │
        ├──────────────────────────┼─────────────────────────────┤
        │  Ergonomía de Control    │  Jerarquía y Tipografía     │
        │  • Píldoras de volumen   │  • Fuente Inter (Semibold)  │
        │  • Botones semáforo izq. │  • Cuadrícula de 8/12/16px  │
        └──────────────────────────┴─────────────────────────────┘
```

1. **Vidrio Frosted y Superficies Flotantes:**
   - Paneles desacoplados del borde de la pantalla que flotan con un margen perimetral.
   - Fondo translúcido con desenfoque Gaussiano profundo (*frosted glass*), delimitado por un trazo de contorno sutil (1px) con opacidad del 8% al 12% blanco para simular reflexión de luz física en los bordes.
2. **Geometría Orgánica (Continuous Squircles):**
   - Radios de curvatura de 22px en contenedores principales y 14–16px en tarjetas secundarias.
   - Botones de acción y selectores de herramientas tipo píldora (`radius: height / 2`).
3. **Controles Semáforo (Traffic Lights):**
   - Disposición estricta a la izquierda en ventanas: Cerrar (`#FF5F57`), Minimizar (`#FEBC2E`), Maximizar (`#28C840`), con glifos interactivos que únicamente se revelan en estado *hover*.
4. **Agrupación Modular e Interacción Háptica:**
   - Módulos 2×2 para conectividad rápida (Wi-Fi, Bluetooth).
   - Sliders táctiles anchos con indicación de estado integrada en la cápsula.

---

## 3. Auditoría Detallada por Componentes

### 3.1. Centro de Control (`apps/dylanos-control-center`)

El Centro de Control ([apps/dylanos-control-center/contents/ui/ControlCenterPanel.qml](file:///home/dylan/DylanOS/apps/dylanos-control-center/contents/ui/ControlCenterPanel.qml)) constituye el corazón visual estilo Tahoe del sistema operativo.

#### Hallazgos y No Conformidades:
1. **Deriva Cromática (Colores No Autorizados):**
   - **Líneas 61, 106, 150, 188, 250, 289, 345:** Usa el valor `#e11d2e` (un rojo genérico con matices anaranjados) y acentos `#ff4d5a`.
     - *Estándar Oficial:* El único rojo corporativo es **DylanOS Crimson (`#DC143C`)**.
   - **Líneas 12, 61, 106, 247, 286, 310, 336:** Superficies con valores `#0d0d0f`, `#1a1414`, `#2a2a2a` y bordes `#2a1618`.
     - *Estándar Oficial:* **DylanOS Black (`#0A0A0A`)** para fondos base, **DylanOS Gray (`#1A1A1A`)** para tarjetas/superficies elevadas, y un borde neutro `#FFFFFF` al 8% de opacidad o `#2E2E33`.
   - **Líneas 95, 139, 177, 215:** Texto de estado utiliza `#ffd7da` y `#9a9a9a`.
     - *Estándar Oficial:* **DylanOS Light Gray (`#B3B3B3`)** para texto secundario y **DylanOS White (`#FFFFFF`)** para texto primario.

2. **Detección de Elementos Ficticios en [MockData.qml](file:///home/dylan/DylanOS/apps/dylanos-control-center/contents/ui/MockData.qml):**
   - **Línea 15:** `{ id: "airdrop", icon: "emblem-shared", label: "Compartir" }`.
     - *Violación:* "AirDrop" es una marca y protocolo ficticio en el ecosistema Linux. Debe sustituirse por el servicio nativo real del sistema: **KDE Connect** (`kdeconnect`) o Compartir en Red Local.
   - **Líneas 16–17:** Botones estáticos sin asignación a la API de KDE/D-Bus (`project` y `powersave`). Deben enlazarse al backend de KScreen y UPower / PowerDevil.

3. **Sliders de Brillo y Volumen:**
   - La implementación actual usa tracks delgados de 6px con una manija circular (estilo Android clásico). En macOS Tahoe 26, el slider es una cápsula gruesa e integrada con el icono incrustado en el propio riel.

---

### 3.2. Dock Flotante (`apps/com.dylanos.dock`)

El Dock ([apps/com.dylanos.dock/contents/ui/main.qml](file:///home/dylan/DylanOS/apps/com.dylanos.dock/contents/ui/main.qml)) presenta una ejecución muy cercana a la visión de Tahoe:

#### Aspectos Positivos:
- **Radio y Translucidez:** `radius: 22`, fondo `#0A0A0A` con opacidad `0.55` y borde blanco al `0.08` de opacidad ([main.qml#L57-L70](file:///home/dylan/DylanOS/apps/com.dylanos.dock/contents/ui/main.qml#L57-L70)).
- **Acento:** Ya consume `Plasmoid.configuration.accentColor` (`#DC143C`).
- **Microinteracción:** Escala cúbica suave en hover (de 48px base a 72px hover) y punto indicador circular de ejecución activa en la parte inferior ([DockItemDelegate.qml#L44-L57](file:///home/dylan/DylanOS/apps/com.dylanos.dock/contents/ui/DockItemDelegate.qml#L44-L57)).
- **Menú Contextual:** Estilo cápsula glass con `radius: 22`, fondo `Qt.rgba(10/255, 10/255, 10/255, 0.55)` y selección en Crimson `#DC143C`.

#### No Conformidades y Residuales:
- **Lanzadores por Defecto Ficticios o Genéricos ([main.qml#L37-L44](file:///home/dylan/DylanOS/apps/com.dylanos.dock/contents/ui/main.qml#L37-L44)):**
  - Contiene: `applications:org.kde.dolphin.desktop`, `applications:systemsettings.desktop`, y `applications:com.dylanos.appcenter.desktop` con un comentario `// TODO: confirmar id real del App Center`.
  - En DylanOS el gestor de archivos oficial integrado y la tienda deben referenciar los archivos desktop verificados del sistema (`org.dylanos.archivos.desktop` / `dylanos-app-center.desktop`).

---

### 3.3. Integración de Ventanas y Sistema (Aurorae & GTK)

Tanto el tema Aurorae ([themes/aurorae/DylanOS-Crimson/DylanOS-Crimsonrc](file:///home/dylan/DylanOS/themes/aurorae/DylanOS-Crimson/DylanOS-Crimsonrc)) como el tema GTK ([themes/gtk/DylanOS-Crimson/gtk-3.0/gtk.css](file:///home/dylan/DylanOS/themes/gtk/DylanOS-Crimson/gtk-3.0/gtk.css)):
- Cumplen a la perfección con la colocación de controles a la izquierda (`close,minimize,maximize:menu`).
- Emplean la paleta semáforo de Tahoe: `#FF5F57` (cerrar), `#FEBC2E` (minimizar), `#28C840` (maximizar).
- Emplean `#0A0A0A` y acento `#DC143C`.
- Poseen esquinas redondeadas en decoraciones de ventana con sombras volumétricas profundas (`box-shadow: 0 18px 44px alpha(#000000, 0.55)`).

---

### 3.4. Detección de Suplantación de Logotipo en Aplicaciones de la Distro

En la inspección transversal de la distro se identificó un problema severo de identidad en [apps/workspace/qml/Main.qml#L67-L70](file:///home/dylan/DylanOS/apps/workspace/qml/Main.qml#L67-L70):

```qml
// Código actual no conforme en Workspace:
Rectangle {
    width: 37; height: 37; radius: 12; color: "#e3485b"
    Text { anchors.centerIn: parent; text: "D"; color: "white"; font.pixelSize: 25; font.weight: Font.DemiBold }
}
```

> [!CAUTION]
> **No utilizar logotipos improvisados ni ficticios.**
> El logotipo oficial y único de DylanOS es el activo real ubicado en [branding/logo.png](file:///home/dylan/DylanOS/branding/logo.png). Cualquier vista de bienvenida, barra lateral o cabecera debe renderizar directamente dicho asset mediante componentes `Image { source: "..." }` y no inventar cajas de colores con la letra "D".

---

## 4. Matriz de Corrección de Color: Tokens Reales vs. Desviaciones

| Elemento UI | Valor Encontrado (No Conforme) | Token Oficial DylanOS | Valor HEX Oficial | Estado |
|---|---|---|---|:---:|
| **Fondo Principal** | `#0d0d0f`, `#14151b`, `#1c1c1e` | `DYLANOS_BLACK` | `#0A0A0A` | ❌ Requiere corrección |
| **Superficie de Tarjeta** | `#1a1414`, `#1f1f21`, `#2a2d38` | `DYLANOS_GRAY` | `#1A1A1A` | ❌ Requiere corrección |
| **Acento Primario** | `#e11d2e`, `#e3485b`, `#b8433f` | `DYLANOS_RED` | `#DC143C` | ❌ Requiere corrección |
| **Texto Primario** | `#f5f5f5`, `#f1f1f6` | `DYLANOS_WHITE` | `#FFFFFF` | ⚠️ Normalizar |
| **Texto Secundario** | `#9a9a9a`, `#ffd7da`, `#6e6e70` | `DYLANOS_LIGHT_GRAY` | `#B3B3B3` | ❌ Requiere corrección |
| **Bordes de Tarjeta** | `#2a1618`, `#383b49` | `Borde Translúcido` | `rgba(255,255,255,0.08)` | ❌ Requiere corrección |
| **Sombra Proyectada** | `#e11d2e` al 50% | `Sombra de Elevación` | `rgba(0,0,0,0.55)` | ⚠️ Ajustar brillo |

---

## 5. Especificación y Propuesta de Refactorización QML

A continuación se detalla la reimplementación del bloque central de tarjetas y controles para [apps/dylanos-control-center/contents/ui/ControlCenterPanel.qml](file:///home/dylan/DylanOS/apps/dylanos-control-center/contents/ui/ControlCenterPanel.qml), aplicando el 100% de la estética Tahoe 26 combinada con los tokens de DylanOS Crimson:

### 5.1. Bloque de Tokens Estilísticos de Marca

```qml
// Definición canónica de tokens DylanOS Crimson
readonly property color cBlack:      "#0A0A0A"
readonly property color cGray:       "#1A1A1A"
readonly property color cCrimson:    "#DC143C"
readonly property color cWhite:      "#FFFFFF"
readonly property color cLightGray:  "#B3B3B3"
readonly property color cCardBorder: Qt.rgba(1, 1, 1, 0.08)
```

### 5.2. Tarjeta de Activación Tahoe (Wi-Fi / Bluetooth)

```qml
// Módulo de alternancia rápida estilo Tahoe 26
Rectangle {
    Layout.fillWidth: true
    Layout.preferredHeight: 88
    radius: 18
    color: SystemStatus.wifiPowered ? cCrimson : cGray
    border.color: SystemStatus.wifiPowered ? Qt.lighter(cCrimson, 1.2) : cCardBorder
    border.width: 1

    Behavior on color { ColorAnimation { duration: 160; easing.type: Easing.OutCubic } }

    MouseArea {
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        enabled: SystemStatus.wifiAvailable
        onClicked: SystemStatus.toggleWifi()
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 14
        spacing: 4

        Kirigami.Icon {
            source: "network-wireless"
            isMask: true
            color: SystemStatus.wifiPowered ? cWhite : cLightGray
            Layout.preferredWidth: 22
            Layout.preferredHeight: 22
        }

        Item { Layout.fillHeight: true }

        QQC2.Label {
            text: "Wi-Fi"
            color: cWhite
            font.pixelSize: 13
            font.bold: true
        }

        QQC2.Label {
            text: !SystemStatus.wifiAvailable ? "No detectado"
                  : SystemStatus.wifiPowered ? (SystemStatus.wifiSsid || "Conectado")
                  : "Desactivado"
            color: SystemStatus.wifiPowered ? Qt.rgba(1, 1, 1, 0.85) : cLightGray
            font.pixelSize: 11
        }
    }
}
```

### 5.3. Slider de Volumen / Brillo estilo Cápsula Tahoe 26

En lugar de un riel esquelético de 6px, se especifica la cápsula interactiva de 42px de alto con icono embebido:

```qml
// Slider tipo cápsula interactiva Tahoe 26
QQC2.Slider {
    id: volumeSlider
    Layout.fillWidth: true
    Layout.preferredHeight: 44
    from: 0; to: 1
    value: SystemStatus.volumeValue
    onMoved: SystemStatus.setVolume(value)

    background: Rectangle {
        anchors.fill: parent
        radius: 22
        color: cGray
        border.color: cCardBorder
        border.width: 1
        clip: true

        // Nivel de llenado activo
        Rectangle {
            width: volumeSlider.visualPosition * parent.width
            height: parent.height
            radius: 22
            color: cCrimson
        }

        // Icono integrado dentro de la cápsula
        Kirigami.Icon {
            anchors.left: parent.left
            anchors.leftMargin: 14
            anchors.verticalCenter: parent.verticalCenter
            source: "audio-volume-high"
            isMask: true
            color: cWhite
            width: 18; height: 18
        }
    }

    handle: Item { width: 0; height: 0 } // Manija invisible, la cápsula completa es interactiva
}
```

### 5.4. Sustitución de Accesos Ficticios en [MockData.qml](file:///home/dylan/DylanOS/apps/dylanos-control-center/contents/ui/MockData.qml)

```qml
// Reemplazo real y nativo de Linux / KDE:
QtObject {
    readonly property var secondaryActions: [
        { id: "kdeconnect", icon: "kdeconnect", label: "KDE Connect" },
        { id: "displays",   icon: "preferences-desktop-display", label: "Pantallas" },
        { id: "powersave",  icon: "battery-profile-powersave", label: "Batería" }
    ]
}
```

### 5.5. Uso Obligatorio del Logotipo Real de DylanOS

Dondequiera que se requiera la identidad corporativa, debe cargarse el archivo real:

```qml
Image {
    source: "file:///usr/share/branding/dylanos/logo.png" // En entorno instalado
    // O relativo en árbol de desarrollo: "file://" + brandingDir + "/logo.png"
    Layout.preferredWidth: 36
    Layout.preferredHeight: 36
    fillMode: Image.PreserveAspectFit
    smooth: true
    mipmap: true
}
```

---

## 6. Lista de Verificación y Plan de Acción

- [x] **Acción 1:** Actualizar [apps/dylanos-control-center/contents/ui/ControlCenterPanel.qml](file:///home/dylan/DylanOS/apps/dylanos-control-center/contents/ui/ControlCenterPanel.qml) y [NotificationsPanel.qml](file:///home/dylan/DylanOS/apps/dylanos-control-center/contents/ui/NotificationsPanel.qml) con los tokens `#DC143C`, `#0A0A0A`, `#1A1A1A`, `#FFFFFF` y `#B3B3B3` *(EJECUTADO)*.
- [x] **Acción 2:** Purgar el identificador `"airdrop"` de [apps/dylanos-control-center/contents/ui/MockData.qml](file:///home/dylan/DylanOS/apps/dylanos-control-center/contents/ui/MockData.qml) y sustituirlo por el ID real `"kdeconnect"` *(EJECUTADO)*.
- [x] **Acción 3:** Reemplazar el icono artesanal de texto `"D"` en [apps/workspace/qml/Main.qml](file:///home/dylan/DylanOS/apps/workspace/qml/Main.qml) y [SettingsPage.qml](file:///home/dylan/DylanOS/apps/workspace/qml/SettingsPage.qml) por la imagen real de [branding/logo.png](file:///home/dylan/DylanOS/branding/logo.png) *(EJECUTADO)*.
- [x] **Acción 4:** Ajustar la lista de aplicaciones por defecto en [apps/com.dylanos.dock/contents/ui/main.qml](file:///home/dylan/DylanOS/apps/com.dylanos.dock/contents/ui/main.qml) para enlazar los archivos `.desktop` propios de DylanOS (`dylanos-app-center.desktop`, `org.dylanos.calculator.desktop`) *(EJECUTADO)*.
- [x] **Acción 5:** Ejecutar la suite de pruebas unitarias (`python3 -m unittest discover -s scripts/tests -v`), extendiendo `test_theme.py` para asegurar que ningún color legado (`#e11d2e`, `#e3485b`, `#E50914`, `#e11d2a`) subsista en QML *(EJECUTADO · 25/25 PASSED / SKIPPED ENTORNO GUI)*.

