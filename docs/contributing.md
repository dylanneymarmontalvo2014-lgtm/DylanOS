# Guía de contribución

Gracias por colaborar con DylanOS. Este proyecto mantiene una documentación activa y un estado de desarrollo real del escritorio, por lo que es importante trabajar con el código y la arquitectura actuales, no con referencias históricas.

## Antes de empezar

Lee primero la documentación actual del proyecto:

- [README.md](../README.md)
- [architecture.md](architecture.md)
- [install.md](install.md)

Esto ayuda a detectar si el cambio afecta a branding, workspace, installer, store, explorer o scripts de validación.

## Flujo recomendado

1. Haz un fork del repositorio.
2. Crea una rama exclusiva para el cambio.
3. Mantén el alcance del PR pequeño y claro.
4. Ejecuta la validación mínima del repositorio.
5. Abre el PR con resumen, contexto y pruebas.

```bash
git checkout -b feature/mi-cambio
```

## Estándares del proyecto

- Mantén la estructura del repositorio y el naming actual.
- Prioriza cambios pequeños y bien documentados.
- No subas artefactos del build ni contenido temporal desde `work/` salvo que el proceso claramente lo requiera.
- Si tocas branding o diseño, revisa la paleta Crimson y el estado visual del proyecto.
- Evita referencias obsoletas a Calamares, Dolphin como producto final o Discover si ya se está usando una solución propia.

## Validación mínima

```bash
python3 -m venv .venv
. .venv/bin/activate
python -m pip install -r apps/workspace/requirements-dev.txt
DYLANOS_PYTHON="$PWD/.venv/bin/python" bash scripts/check.sh
```

Si tu cambio afecta archivos de staging, instalación o scripts del sistema, valida también el flujo de `scripts/build.sh` y `scripts/stage.py` antes de enviar el cambio.

## Pull request

Incluye:

- descripción breve del problema o mejora
- archivos tocados
- pruebas ejecutadas
- impacto esperado en usuario final o sistema

## Código de conducta

Se espera un ambiente respetuoso, técnico y colaborativo. Los cambios deben mejorar DylanOS sin introducir ruido ni estados inconsistentes en la documentación.
