# DylanOS App Center

Centro de aplicaciones Qt 6/QML que enumera servicios de escritorio registrados con KDE Service (`KService::allServices`). Filtra por nombre/comentario, presenta la lista paginada según el tamaño de ventana y abre una aplicación seleccionada usando `KIO::ApplicationLauncherJob`. Los lanzadores marcados como `NoDisplay` o que no son aplicaciones ejecutables se excluyen.

Se abre desde el menú de aplicaciones como **DylanOS App Center** o ejecutando:

```sh
dylanos-app-center
```

La lista refleja lo instalado y visible en la sesión: el App Center no instala ni actualiza software. Para catálogo, instalar/actualizar paquetes y consultar backends usa **DylanOS Store** (`dylanos-store`), sujeto a que PackageKit/Flatpak y repositorios estén configurados.

La entrada de escritorio está en `dylanos-app-center.desktop`; el ejecutable y la interfaz están en `src/`, `qml/` y `CMakeLists.txt`. Ver también la [guía general](../../docs/guia-de-uso.md), la [arquitectura](../../docs/architecture.md) y el índice de [documentación del repositorio](../../docs/README.md).