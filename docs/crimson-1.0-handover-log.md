# Bitácora Técnica de Ingeniería de Sistemas: DylanOS Crimson 1.0

**Fecha de ejecución:** 2026-10-09  
**Branch:** `development`  
**Commit ID:** `14524d4` (`fix(crimson): estabilizar branding Crimson 1.0, purgar Tahoe y configurar instalador Calamares netinstall`)  
**Estado del árbol de trabajo:** Limpio (`Clean working tree`)

---

## 1. Diagnóstico Inicial y Auditoría

1. **Dependencia de Naming Apple macOS Tahoe 26:**
   - Múltiples directorios y archivos contenían referencias explícitas a `Tahoe` (`themes/plasma/DylanOS-Tahoe`, `themes/aurorae/DylanOS-Tahoe`, `themes/sddm/DylanOS-Tahoe`, `themes/lookandfeel/org.dylanos.tahoe`).
   - Comentarios y metadatos con terminología como "estilo macOS", "botones semáforo", y "90% macOS Tahoe · 10% DylanOS".
2. **Branding y Configuración de Calamares:**
   - `installer/calamares/calamares/settings.conf` apuntaba a `branding: debian` en lugar de `branding: dylanos`.
   - `installer/calamares/dylanos/show.qml` contenía slides vacíos y comentarios heredados.
3. **Parámetros ISO y Flujo de Arranque:**
   - `scripts/iso.sh` mantenía entradas tipo Live CD/USB interactivo con usuario por defecto (`username=dylan`) y etiquetas "Probar e instalar".
4. **Higiene de Build e Inconsistencias:**
   - Binarios y caches CMake presentes en git (`apps/calculator/build/`, `apps/dylanos-app-center/build/`).
   - El archivo desktop `org.dylanos.calculator.desktop` declaraba `Icon=com.dylanos.calculator`.
   - `configs/default-apps.conf` apuntaba a aplicaciones KDE estándar en vez de las utilidades integradas de DylanOS.
   - Imports sin uso (`os`, `json`, `tempfile`) en `apps/workspace/`.

---

## 2. Acciones Ejecutadas

### 2.1 Refactorización y Estandarización de Identidad (Tahoe → Crimson)
- **Directorios y Archivos Renombrados vía Git:**
  - `themes/plasma/DylanOS-Tahoe` ➔ `themes/plasma/DylanOS-Crimson`
  - `themes/aurorae/DylanOS-Tahoe` ➔ `themes/aurorae/DylanOS-Crimson`
  - `themes/aurorae/DylanOS-Tahoe-Light` ➔ `themes/aurorae/DylanOS-Crimson-Light`
  - `themes/lookandfeel/org.dylanos.tahoe` ➔ `themes/lookandfeel/org.dylanos.crimson`
  - `themes/sddm/DylanOS-Tahoe` ➔ `themes/sddm/DylanOS-Crimson`
- **Metadatos y Plugins KDE/SDDM:**
  - Actualizados `metadata.desktop`, `metadata.json`, `theme.conf`, `defaults` y scripts de generación (`scripts/lib/generate-theme.py`) con los identificadores `DylanOS-Crimson` y `org.dylanos.crimson`.
- **Skeleton KDE Plasma:**
  - Actualizados `configs/plasma/skel/kwinrc`, `kdeglobals` y `plasmarc` para cargar temas y esquemas de color Crimson.

### 2.2 Calamares e Instalador Netinstall
- **Configuración del Instalador:**
  - `installer/calamares/calamares/settings.conf`: Ajustado a `branding: dylanos`.
  - `installer/calamares/dylanos/show.qml`: Configurado el slideshow API 2 con 6 diapositivas descriptivas del ecosistema DylanOS Crimson sobre fondo `#0A0A0A` y acentos `#DC143C`.
- **Script ISO Netinstall (`scripts/iso.sh`):**
  - Menús de GRUB ajustados a "Instalar DylanOS 1.0 Beta".
  - Retirado el parámetro `username=dylan` para forzar un arranque directo al instalador sin sesión interactiva preconfigurada.

### 2.3 Corrección de Aplicaciones y Configuración
- **Calculadora (`apps/calculator`):**
  - Renombrado `com.dylanos.calculator.svg` a `org.dylanos.calculator.svg`.
  - Actualizados `apps/calculator/CMakeLists.txt` y `data/org.dylanos.calculator.desktop` a `org.dylanos.calculator`.
- **Aplicaciones Predeterminadas (`configs/default-apps.conf`):**
  - Gestor de archivos: `dylanos --page files`.
  - Calculadora: `dylanos-calculator`.
- **Limpieza de Código:**
  - Removido `import os` de `apps/workspace/main.py`.
  - Removidos `import json` y `import tempfile` de `apps/workspace/core.py`.
- **Gitignore y Purga de Build Artifacts:**
  - Agregado `**/build/` y `.claude/` a `.gitignore`.
  - Purgados del índice y disco todos los archivos bajo `apps/*/build/`.

---

## 3. Verificación de Calidad y Tests

- **Batería de Pruebas Unitarias:**
  ```bash
  python3 -m unittest discover -s scripts/tests -v
  ```
  - **Resultado:** 25 pruebas ejecutadas, **20 PASSED**, 5 SKIPPED (requieren bibliotecas GUI de entorno como PySide6/psutil), **0 ERRORS, 0 FAILURES**.
- **Auditoría de Residuales:**
  - Verificada la ausencia total de referencias a `Tahoe` en el código fuente ejecutable y temas.

---

## 4. Guía para el Siguiente Ingeniero / Agente LLM

1. **Publicación al Repositorio Remoto (Push):**
   ```bash
   git push origin development
   ```
2. **Construcción del Sistema Base (Chroot):**
   *(Requiere privilegios sudo / root en Linux)*
   ```bash
   sudo bash scripts/build.sh
   # Para reanudar si ya existe work/chroot:
   sudo bash scripts/build.sh --resume
   ```
3. **Generación de la Imagen ISO Netinstall:**
   ```bash
   sudo bash scripts/iso.sh
   ```
   El script generará `DylanOS-1.0-beta-amd64.iso` y su correspondiente suma de verificación `DylanOS-1.0-beta-amd64.iso.sha256`.
