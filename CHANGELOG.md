# Changelog

Cambios importantes del proyecto, inspirados en el formato Keep a Changelog y versionado semántico.

## [Unreleased]

### Añadido

- README visual con banner y paleta derivada de los temas de DylanOS.
- Guías de estado, identidad visual y escritorio, y alcance de pruebas.

### Cambiado

- Se amplía la documentación de arquitectura, instalación, construcción, herramientas, contribución y roadmap para distinguir configuración de validación real.
- Se separa el build manual de artefactos del workflow que publica Releases etiquetadas, evitando dos publicadores para el mismo tag.
- Se retira de la CI por PR el smoke test QEMU que reconstruía la ISO completa; `scripts/test-iso.sh` sigue disponible para pruebas manuales.

## [0.1.0-alpha] - En desarrollo

### Añadido

- Creación del repositorio oficial y estructura inicial.
- Branding, configuración del sistema y listas de paquetes.
- Constructor de ISO, pruebas automatizadas y documentación base.
