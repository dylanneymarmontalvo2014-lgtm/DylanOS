pragma Singleton
import QtQuick

// User-facing texts shared by several screens (installation stages and error catalogue).
QtObject {
    readonly property var stages: ["Preparando instalación", "Descargando", "Verificando paquetes", "Instalando", "Finalizando"]
    function stageOf(p) { return p < 8 ? 0 : p < 55 ? 1 : p < 68 ? 2 : p < 92 ? 3 : 4 }
    function stage(p) { return stages[stageOf(p)] }

    readonly property var errorKinds: ["download", "deps", "space", "repo", "perm"]
    readonly property var errors: ({
        download: { title: "Error de descarga", text: "Se interrumpió la descarga del paquete. Comprueba tu conexión e inténtalo de nuevo.", action: "Reintentar" },
        deps: { title: "Error de dependencias", text: "No se pudieron resolver las dependencias necesarias para este paquete.", action: "Reintentar" },
        space: { title: "Falta de espacio", text: "No hay espacio suficiente en disco. Libera espacio y vuelve a intentarlo.", action: "Reintentar" },
        repo: { title: "Repositorio no disponible", text: "No se pudo contactar con la fuente de software. Prueba de nuevo más tarde.", action: "Reintentar" },
        perm: { title: "Permisos insuficientes", text: "La operación requiere autorización de administrador.", action: "Autorizar y reintentar" }
    })
}
