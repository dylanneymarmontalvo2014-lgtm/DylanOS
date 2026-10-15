#include "AppItem.h"

void AppItem::setLive(const QString &status, double progress, bool isUpdate, const QString &err, const QString &version)
{
    m_status = status;
    m_progress = progress;
    m_isUpdate = isUpdate;
    m_errorKind = err;
    m_liveVersion = version;
    Q_EMIT stateChanged();
}
