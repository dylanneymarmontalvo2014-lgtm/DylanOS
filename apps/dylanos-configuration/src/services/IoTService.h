#ifndef IOTSERVICE_H
#define IOTSERVICE_H

#include <QObject>
#include <QVariantList>
#include <QVariantMap>

class IoTService : public QObject
{
    Q_OBJECT
    Q_PROPERTY(QString activeProfile READ activeProfile NOTIFY changed)
    Q_PROPERTY(bool enabled READ enabled NOTIFY changed)
public:
    explicit IoTService(QObject *parent = nullptr);
    QString activeProfile() const { return m_profile; }
    bool enabled() const { return m_enabled; }
    Q_INVOKABLE QVariantList catalog() const;
    Q_INVOKABLE QVariantList profiles() const;
    Q_INVOKABLE QVariantList devices() const;
    Q_INVOKABLE QVariantMap status() const;
    Q_INVOKABLE bool setProfile(const QString &id);
    Q_INVOKABLE bool setEnabled(bool enabled);
    Q_INVOKABLE bool restore();
signals:
    void changed();
private:
    QString dataPath(const QString &relative) const;
    QString statePath() const;
    bool save(const QString &profile, bool enabled) const;
    QString m_profile = QStringLiteral("iot-development");
    bool m_enabled = false;
};

#endif
