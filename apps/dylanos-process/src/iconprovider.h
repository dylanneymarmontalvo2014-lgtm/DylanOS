// Proveedor de imágenes "image://icon/<nombre>" que resuelve iconos del tema
// activo con Qt (QIcon::fromTheme), respetando la configuración de KDE.
//
// Se usa para los iconos de la interfaz (cabeceras, tarjetas, pestañas), no
// para los de proceso: esos vienen resueltos por el núcleo Rust con la ruta
// real del archivo.

#pragma once

#include <QColor>
#include <QHash>
#include <QImage>
#include <QQuickImageProvider>
#include <QSize>

class IconImageProvider : public QQuickImageProvider
{
public:
    IconImageProvider();

    QImage requestImage(const QString &id, QSize *size, const QSize &requestedSize) override;

private:
    QHash<QString, QImage> m_cache;
};
