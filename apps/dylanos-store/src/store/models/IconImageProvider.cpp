#include "IconImageProvider.h"
#include <QColor>
#include <QFile>
#include <QPainter>
#include <QSvgRenderer>

QPixmap IconImageProvider::requestPixmap(const QString &id, QSize *size, const QSize &requestedSize)
{
    const QStringList parts = id.split(QLatin1Char('/'));
    const QString name = parts.value(0);
    QColor color(Qt::white);
    if (parts.size() > 1)
        color = QColor(QLatin1Char('#') + parts[1]);

    QFile f(QStringLiteral(":/data/icons/%1.svg").arg(name));
    if (name.isEmpty() || !f.open(QIODevice::ReadOnly))
        return {};
    QByteArray svg = f.readAll();
    svg.replace("#ffffff", color.name(QColor::HexRgb).toLatin1());

    const QSize px = requestedSize.isValid() ? requestedSize : QSize(24, 24);
    QPixmap pm(px);
    pm.fill(Qt::transparent);
    QPainter p(&pm);
    p.setRenderHint(QPainter::Antialiasing);
    p.setOpacity(color.alphaF());
    QSvgRenderer(svg).render(&p);
    if (size)
        *size = px;
    return pm;
}
