# Contribuir a DylanOS

Gracias por dedicar tiempo a mejorar DylanOS. Este proyecto sigue un modelo de contribución centrado en pequeños cambios, revisión de arquitectura y validación real del comportamiento del sistema.

## Requisitos previos

Antes de abrir un cambio, revisa al menos:

- [README.md](README.md)
- [docs/architecture.md](docs/architecture.md)
- [docs/install.md](docs/install.md)

Esto ayuda a mantener el proyecto alineado con el estado real del código, especialmente en temas de branding, instalador, explorador y store.

## Flujo recomendado

1. Haz un fork del repositorio.
2. Crea una rama específica para tu cambio.
3. Mantén los cambios enfocados y documentados.
4. Ejecuta la validación mínima antes de enviar el PR.
5. Abre el Pull Request con contexto técnico y pruebas verificadas.

```bash
git checkout -b feature/tu-cambio
```

## Estándares

- Evita cambios de alcance amplio sin necesidad.
- Mantén la estructura del proyecto y los nombres actuales de componentes.
- No comites artefactos de build ni contenido temporal generados en `work/` salvo que el proceso lo requiera explícitamente.
- Si modifies la experiencia visual, añade contexto en la documentación y verifica la identidad Crimson.
- Comprueba que tus cambios no introducen referencias obsoletas a Dolphin, Calamares o Discover si el proyecto ya usa soluciones propias.

## Validación local

Para validar la base del proyecto en un entorno Python del repositorio:

```bash
python3 -m venv .venv
. .venv/bin/activate
python -m pip install -r apps/workspace/requirements-dev.txt
DYLANOS_PYTHON="$PWD/.venv/bin/python" bash scripts/check.sh
```

Si tu cambio afecta a scripts o paquetes del ISO, usa también la validación del flujo de staging y del build definido en `scripts/`.

## Pull requests

Incluye en tu PR:

- resumen del problema o mejora
- archivos tocados
- pruebas ejecutadas
- impacto esperado en escritorio, branding o sistema

## Código de conducta

Se espera un entorno respetuoso, técnico y colaborativo. El foco es mejorar DylanOS sin generar ruido ni cambios no relacionados.
