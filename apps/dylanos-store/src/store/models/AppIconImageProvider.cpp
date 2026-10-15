#include "AppIconImageProvider.h"
#include <QFile>
#include <QIcon>
#include <QPainter>
#include <QSvgRenderer>
#include <QUrl>

AppIconImageProvider::AppIconImageProvider(const std::function<QVariant(const QString &)> &iconLookup)
    : QQuickImageProvider(QQuickImageProvider::Pixmap)
    , m_iconLookup(iconLookup)
{
}

static QPixmap lucidePixmap(const QString &name, const QSize &px)
{
    QFile f(QStringLiteral(":/data/icons/%1.svg").arg(name));
    if (!f.open(QIODevice::ReadOnly))
        f.setFileName(QStringLiteral(":/data/icons/Box.svg"));
    if (!f.open(QIODevice::ReadOnly))
        return {};
    QByteArray svg = f.readAll();
    svg.replace("#ffffff", QColor(0xb3, 0xb3, 0xb3).name(QColor::HexRgb).toLatin1());
    QPixmap pm(px);
    pm.fill(Qt::transparent);
    QPainter p(&pm);
    p.setRenderHint(QPainter::Antialiasing);
    QSvgRenderer(svg).render(&p);
    return pm;
}

QPixmap AppIconImageProvider::requestPixmap(const QString &id, QSize *size, const QSize &requestedSize)
{
    const QString appId = id.section(QLatin1Char('/'), 0, 0);
    const QSize px = requestedSize.isValid() ? requestedSize : QSize(128, 128);

    QPixmap out;
    const QVariant v = m_iconLookup ? m_iconLookup(appId) : QVariant();
    if (v.isValid() && !v.isNull()) {
        if (v.canConvert<QIcon>()) {
            const QIcon icon = v.value<QIcon>();
            if (!icon.isNull())
                out = icon.pixmap(px);
        } else if (v.canConvert<QUrl>()) {
            const QUrl url = v.toUrl();
            if (url.isLocalFile())
                out = QPixmap(url.toLocalFile());
        } else {
            const QString s = v.toString();
            if (!s.isEmpty()) {
                const QIcon themed = QIcon::fromTheme(s);
                if (!themed.isNull()) {
                    out = themed.pixmap(px);
                } else {
                    const QUrl url = QUrl(s);
                    if (url.isLocalFile() && QFile::exists(url.toLocalFile()))
                        out = QPixmap(url.toLocalFile());
                }
            }
        }
    }
    if (out.isNull())
        out = lucidePixmap(QStringLiteral("PackageOpen"), px);
    if (size)
        *size = out.size();
    return out;
}
