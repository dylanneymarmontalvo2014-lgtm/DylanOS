# Roadmap de DylanOS

Este roadmap describe metas, no certificaciones. Consulta [Estado del proyecto](status.md) para separar configuración existente de pruebas completadas.

## 0.1 Alpha — base del sistema

### Ya preparado en el repositorio

- Construcción de una imagen Debian Live amd64 con KDE Plasma.
- Listas de paquetes agrupadas por uso.
- Branding inicial para GRUB, Plymouth, SDDM, GTK y Plasma.
- Configuración inicial de Calamares.
- Bienvenida, diagnóstico local y aplicación manual del wallpaper.
- Pruebas estáticas, CI de paquetes/Docker y smoke test QEMU BIOS/UEFI.
- Automatización para publicar una ISO versionada y checksum SHA-256.

### Pendiente de validación antes de distribuir

- Completar y documentar una instalación de Calamares de extremo a extremo en una VM.
- Verificar la ISO de producción en arranque BIOS/UEFI y probarla en hardware representativo.
- Definir requisitos mínimos y compatibilidad de hardware con evidencia.
- Publicar una versión solo después de revisar los resultados y las notas de la versión.

## 0.5 Beta — metas propuestas

- Mejorar rendimiento y reducir paquetes que no sean necesarios para el uso objetivo.
- Desarrollar aplicaciones propias después de definir sus necesidades y mantenimiento.
- Mejorar estabilidad, accesibilidad y experiencia de actualización.
- Evaluar notificaciones, widgets y una disposición de Plasma/panel propia.
- Ampliar pruebas automatizadas sin presentar tests de arranque como instalación completa.

## 1.0 — metas propuestas

- Definir una política de versiones y actualizaciones mantenible.
- Publicar documentación de usuario, soporte y seguridad con pruebas reproducibles.
- Completar la matriz de compatibilidad y el proceso de releases.
- Decidir qué objetivos del roadmap se mantienen para el primer lanzamiento estable.

Las metas de Beta y 1.0 pueden cambiar; no representan funciones existentes ni fechas comprometidas.
