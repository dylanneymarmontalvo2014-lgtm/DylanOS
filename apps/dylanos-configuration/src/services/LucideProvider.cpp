#include "LucideProvider.h"

#include <QFile>
#include <QImage>
#include <QPainter>
#include <QStringList>
#include <QSvgRenderer>

LucideProvider::LucideProvider(QObject *parent)
    : QQuickImageProvider(QQuickImageProvider::Image)
{
    Q_UNUSED(parent)
}

QImage LucideProvider::requestImage(const QString &id, QSize *size, const QSize &requestedSize)
{
    // Formato: "<nombre>/<rrggbb>" — el tamaño lo fija requestedSize.
    const QStringList parts = id.split('/');
    const QString name = parts.value(0);
    const QString color = parts.value(1, "ffffff");

    const QString path = QString(":/assets/icons/%1.svg").arg(name);
    QFile file(path);
    if (!file.open(QIODevice::ReadOnly))
        return QImage();

    QString svg = QString::fromUtf8(file.readAll());
    file.close();
    svg.replace("currentColor", QString("#") + color);

    QSvgRenderer renderer(svg.toUtf8());
    if (!renderer.isValid())
        return QImage();

    qreal dpr = 1.0;
    if (requestedSize.width() > 0 && requestedSize.height() > 0) {
        dpr = static_cast<qreal>(requestedSize.width()) / renderer.defaultSize().width();
        dpr = qBound<qreal>(1.0, dpr, 6.0);
    }

    const QSize base = renderer.defaultSize().isEmpty() ? QSize(24, 24) : renderer.defaultSize();
    QImage image(base * dpr, QImage::Format_ARGB32_Premultiplied);
    image.fill(Qt::transparent);
    QPainter painter(&image);
    painter.setRenderHint(QPainter::Antialiasing);
    renderer.render(&painter, QRectF(QPointF(0, 0), QSizeF(base)));
    painter.end();
    image.setDevicePixelRatio(dpr);

    if (size)
        *size = base;
    return image;
}
