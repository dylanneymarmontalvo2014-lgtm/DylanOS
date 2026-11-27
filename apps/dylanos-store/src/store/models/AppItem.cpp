#include "AppItem.h"
#include "../services/PackageBackend.h"

QString AppItem::longDesc() const
{
    if (!m_longDescLoaded) {
        m_longDescLoaded = true;
        if (m_backend)
            m_longDesc = m_backend->resourceLongDescription(m_id);
    }
    return m_longDesc;
}

void AppItem::setLongDesc(const QString &text)
{
    m_longDesc = text;
    m_longDescLoaded = true;
}

void AppItem::setLive(const QString &status, double progress, bool isUpdate, const QString &err, const QString &version)
{
    m_status = status;
    m_progress = progress;
    m_isUpdate = isUpdate;
    m_errorKind = err;
    m_liveVersion = version;
    Q_EMIT stateChanged();
}
