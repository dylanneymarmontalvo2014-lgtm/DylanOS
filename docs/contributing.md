# Contribuir a DylanOS

Gracias por ayudar a mejorar DylanOS. El proyecto está en Alpha; los cambios pequeños, verificables y bien documentados son especialmente útiles.

## Antes de empezar

1. Revisa [Estado del proyecto](status.md), [Arquitectura](architecture.md) y los límites de [Pruebas](testing.md).
2. Busca si la propuesta o el error ya se reportó en Issues o Pull Requests.
3. Para errores, incluye versión/commit, pasos para reproducir, resultado esperado y resultado observado. Añade una captura o log cuando ayude, ocultando datos personales.

## Flujo recomendado

```bash
git clone https://github.com/dylanneymarmontalvo2014-lgtm/DylanOS.git
cd DylanOS
git checkout -b docs/describe-el-cambio
```

Trabaja en una rama y mantén cada PR centrado en una responsabilidad. Antes de abrirlo, ejecuta:

```bash
scripts/test.sh
shellcheck --severity=warning install-deps.sh scripts/*.sh
```

Si el cambio afecta paquetes, configuración, branding o construcción de la ISO, explica qué se verificó y qué queda pendiente. La prueba de una ISO requiere `scripts/test-iso.sh`; completar una instalación de Calamares es una prueba aparte.

## Convenciones del repositorio

- Mantén listas APT en `packages/<categoría>/packages.list`; usa nombres de paquete Debian válidos y evita duplicados.
- Coloca defaults de sistema, usuario, Plasma y herramientas en sus directorios responsables bajo `configs/`.
- Evita afirmar soporte, requisitos mínimos o validación que no se haya probado.
- No añadas binarios de ISO, imágenes de disco ni artefactos generados al repositorio.
- Documenta cualquier comportamiento visible y conserva las advertencias propias de una versión Alpha.
- El contenido del proyecto está cubierto por la [GNU GPL v3](../LICENSE).

## Pull Request

Incluye un título claro, resumen del cambio, pruebas ejecutadas y cualquier limitación conocida. Si el PR modifica una workflow o una función de publicación, explica qué evento la activa y qué artefactos produce.
