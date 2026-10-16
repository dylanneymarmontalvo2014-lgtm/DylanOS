#include "Formatters.h"

#include <QLocale>
#include <QtMath>

namespace Formatters {

QString fileSize(qint64 bytes)
{
    if (bytes < 0)
        return QStringLiteral("—");
    static const char *units[] = {"B", "KB", "MB", "GB", "TB", "PB"};
    double v = double(bytes);
    int u = 0;
    while (v >= 1000.0 && u < 5) {
        v /= 1000.0;
        ++u;
    }
    if (u == 0)
        return QString::number(bytes) + QStringLiteral(" B");
    return QLocale::c().toString(v, 'f', 1) + QLatin1Char(' ') + QLatin1String(units[u]);
}

QString capacity(qint64 bytes)
{
    if (bytes >= 1000LL * 1000 * 1000 * 1000) {
        const double t = double(bytes) / 1e12;
        const bool whole = qAbs(t - qRound(t)) < 0.05;
        return (whole ? QString::number(qRound(t)) : QLocale::c().toString(t, 'f', 1))
            + QStringLiteral(" TB");
    }
    return QString::number(qRound(double(bytes) / 1e9)) + QStringLiteral(" GB");
}

QString modified(const QDateTime &dt, const QDateTime &now)
{
    if (!dt.isValid())
        return QStringLiteral("—");
    const QDate d = dt.date();
    const QDate today = now.date();
    const QString time = QLocale::c().toString(dt.time(), QStringLiteral("h:mm AP"));
    if (d == today)
        return QStringLiteral("Hoy, ") + time;
    if (d == today.addDays(-1))
        return QStringLiteral("Ayer, ") + time;
    return QLocale::c().toString(d, QStringLiteral("dd/MM/yyyy"));
}

QString itemCount(int n)
{
    return n == 1 ? QStringLiteral("1 elemento") : QStringLiteral("%1 elementos").arg(n);
}

} // namespace Formatters
