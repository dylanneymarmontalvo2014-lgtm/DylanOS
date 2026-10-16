#pragma once
#include <QObject>
#include <QStringList>
#include <QtQml/qqmlregistration.h>

// One catalog entry as seen by QML. Static fields come from the catalog (demo JSON today,
// AppStream tomorrow); live fields (status, progress...) are fed by the PackageBackend.
class AppItem : public QObject
{
    Q_OBJECT
    QML_ELEMENT
    QML_UNCREATABLE("Provided by the Store singleton")

    Q_PROPERTY(QString appId MEMBER m_id CONSTANT)
    Q_PROPERTY(QString name MEMBER m_name CONSTANT)
    Q_PROPERTY(QString glyph MEMBER m_glyph CONSTANT)
    Q_PROPERTY(QString color MEMBER m_color CONSTANT)
    Q_PROPERTY(QString category MEMBER m_category CONSTANT)
    Q_PROPERTY(QString categoryLabel MEMBER m_categoryLabel CONSTANT)
    Q_PROPERTY(QString shortDesc MEMBER m_short CONSTANT)
    Q_PROPERTY(QString longDesc MEMBER m_long CONSTANT)
    Q_PROPERTY(QString developer MEMBER m_dev CONSTANT)
    Q_PROPERTY(QString license MEMBER m_license CONSTANT)
    Q_PROPERTY(QString version MEMBER m_version CONSTANT)
    Q_PROPERTY(QString newVersion MEMBER m_newVersion CONSTANT)
    Q_PROPERTY(QString size MEMBER m_size CONSTANT)
    Q_PROPERTY(QString date MEMBER m_date CONSTANT)
    Q_PROPERTY(QString installedOn READ installedOn NOTIFY stateChanged)
    Q_PROPERTY(QString initial MEMBER m_initial CONSTANT)
    Q_PROPERTY(QStringList tags MEMBER m_tags CONSTANT)
    Q_PROPERTY(QStringList changes MEMBER m_changes CONSTANT)
    Q_PROPERTY(bool statusUnknown MEMBER m_unknown CONSTANT)

    Q_PROPERTY(bool hasIcon READ hasIcon NOTIFY iconChanged)
    Q_PROPERTY(int iconVersion READ iconVersion NOTIFY iconChanged)

    Q_PROPERTY(QString status READ status NOTIFY stateChanged)
    Q_PROPERTY(double progress READ progress NOTIFY stateChanged)
    Q_PROPERTY(bool isUpdate READ isUpdate NOTIFY stateChanged)
    Q_PROPERTY(QString errorKind READ errorKind NOTIFY stateChanged)
    Q_PROPERTY(QString currentVersion READ currentVersion NOTIFY stateChanged)

public:
    using QObject::QObject;

    // static
    QString m_id, m_name, m_glyph, m_color, m_category, m_categoryLabel, m_short, m_long, m_dev, m_license;
    QString m_version, m_newVersion, m_size, m_date, m_installedOn, m_initial, m_failsOnce;
    QString m_packageName, m_backendName;
    QStringList m_tags, m_changes;
    bool m_unknown = false;
    bool m_hasIcon = false;
    int m_iconVersion = 0;

    QString installedOn() const { return m_installedOn; }
    void setInstalledOn(const QString &date)
    {
        m_installedOn = date;
        Q_EMIT stateChanged();
    }
    bool hasIcon() const { return m_hasIcon; }
    int iconVersion() const { return m_iconVersion; }
    void setHasIcon(bool b)
    {
        if (m_hasIcon == b)
            return;
        m_hasIcon = b;
        Q_EMIT iconChanged();
    }
    void bumpIconVersion()
    {
        ++m_iconVersion;
        Q_EMIT iconChanged();
    }

    QString status() const { return m_status; }
    double progress() const { return m_progress; }
    bool isUpdate() const { return m_isUpdate; }
    QString errorKind() const { return m_errorKind; }
    QString currentVersion() const { return m_liveVersion.isEmpty() ? m_version : m_liveVersion; }

    void setLive(const QString &status, double progress, bool isUpdate, const QString &err, const QString &version);

Q_SIGNALS:
    void stateChanged();
    void iconChanged();

private:
    QString m_status = QStringLiteral("none"), m_errorKind, m_liveVersion;
    double m_progress = 0;
    bool m_isUpdate = false;
};
