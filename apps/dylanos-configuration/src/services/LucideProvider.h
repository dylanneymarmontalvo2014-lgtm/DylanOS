#ifndef LUCIDEPROVIDER_H
#define LUCIDEPROVIDER_H

#include <QQuickImageProvider>

// Proveedor de imágenes "image://lucide/<icono>/<color>/<tamaño>".
// Renderiza los SVG Lucide incrustados (trazo currentColor) con el color
// y el tamaño solicitados, soportando devicePixelRatio para nitidez.
class LucideProvider : public QQuickImageProvider
{
public:
    explicit LucideProvider(QObject *parent = nullptr);
    QImage requestImage(const QString &id, QSize *size, const QSize &requestedSize) override;
};

#endif
