# Optimización de apps Qt y personalización del instalador

Cambios aplicados en `development`:

- El App Center mantiene índices de resultados filtrados y los reutiliza en la
  paginación; reconstruye la caché solo al cambiar la búsqueda o actualizar el
  catálogo, evitando volver a filtrar y copiar la colección en cada consulta.
- El instalador usa la paleta carmesí de DylanOS de forma consistente, recurre
  a fuentes locales sin llamadas a Google Fonts, adapta la barra lateral en
  pantallas compactas y respeta la preferencia de movimiento reducido.
- Qt WebEngine deja de permitir que el frontend local acceda a recursos remotos.
  Se conservan la ventana nativa, los controles, las pantallas y el contrato de
  instalación del backend.

Validación: se añadieron pruebas de regresión del caché Qt y del contrato visual,
la disponibilidad offline y el wrapper nativo. La compilación de Qt y del
frontend Vite debe confirmarse con CI; una prueba estática no la sustituye.
