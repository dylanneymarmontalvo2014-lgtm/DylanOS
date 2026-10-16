#pragma once

#include <QDateTime>
#include <QString>

namespace Formatters {

// Decimal (SI) units, one decimal: "12.4 MB".
QString fileSize(qint64 bytes);
// Disk capacity without decimals: "512 GB", "1 TB".
QString capacity(qint64 bytes);
// "Hoy, 8:45 AM" / "Ayer, 11:30 PM" / "03/08/2025".
QString modified(const QDateTime &dt, const QDateTime &now = QDateTime::currentDateTime());
// "1 elemento" / "24 elementos".
QString itemCount(int n);

} // namespace Formatters
