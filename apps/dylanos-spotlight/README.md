# DylanOS Spotlight

Lanzador/buscador de escritorio Python/PySide6. Se abre con el atajo global `Ctrl+Espacio`, con el icono de búsqueda de la barra o desde una terminal:

```sh
dylanos-spotlight
```

Escape cierra la ventana. La interfaz muestra categorías Todo, Apps, Proyectos, Archivos, Web y Calcular. «Web» presenta solo la acción de búsqueda; «Calcular» se limita a expresiones aritméticas sencillas; «Archivos» sigue sin búsqueda real y queda sin resultados. El pie informa solo el número de apps y proyectos. Estado real en `backend.py`:

- indexa entradas `.desktop` visibles en `/usr/share/applications`, `/usr/local/share/applications` y `~/.local/share/applications`;
- busca directorios de proyecto inmediatos bajo `~/Proyectos`, `~/Projects`, `~/DylanOS` y `~/workspace`;
- para una consulta no vacía, codifica el texto como parámetro URL y ofrece abrir DuckDuckGo en el navegador;
- al activar un resultado de carpeta, usa `dylanos-explorer` cuando está instalado, y en su defecto el servicio de escritorio.

## Límites conocidos

Los filtros visibles **Archivos** y **Calcular** no tienen todavía un backend completo: no existe indexado/búsqueda de archivos recientes ni un flujo independiente de calculadora. Una expresión aritmética válida puede añadirse como resultado mientras se escribe, pero no es un motor de cálculo general. El filtro Archivos no implementa búsqueda. No usar las etiquetas como evidencia de funciones que siguen pendientes.

La activación de aplicaciones procesa el campo `Exec` de archivos `.desktop` como argumentos (con comillas y códigos de campo), sin ejecutar un intérprete de shell. Los metacaracteres de shell no se evalúan como comandos; las entradas malformadas se rechazan. Para la arquitectura y el estado integrado, consulta la [guía general](../../docs/guia-de-uso.md) y [`../../docs/architecture.md`](../../docs/architecture.md).