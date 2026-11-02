#ifndef CRIMSONGLASSSERVICE_H
#define CRIMSONGLASSSERVICE_H

#include <QObject>
#include <QVariantMap>

class CrimsonGlassService : public QObject
{
    Q_OBJECT
    Q_PROPERTY(QVariantMap settings READ settings NOTIFY settingsChanged)
    Q_PROPERTY(QVariantMap capabilities READ capabilities NOTIFY capabilitiesChanged)
    Q_PROPERTY(QVariantMap effectiveEffects READ effectiveEffects NOTIFY effectiveEffectsChanged)
    Q_PROPERTY(QString lastMessage READ lastMessage NOTIFY lastMessageChanged)

public:
    explicit CrimsonGlassService(QObject *parent = nullptr);

    QVariantMap settings() const { return m_settings; }
    QVariantMap capabilities() const { return m_capabilities; }
    QVariantMap effectiveEffects() const { return m_effectiveEffects; }
    QString lastMessage() const { return m_lastMessage; }

    Q_INVOKABLE bool setOption(const QString &key, const QVariant &value);
    Q_INVOKABLE bool apply();
    Q_INVOKABLE bool restorePrevious();
    Q_INVOKABLE bool resetDefaults();
    Q_INVOKABLE void detectCapabilities();

signals:
    void settingsChanged();
    void capabilitiesChanged();
    void effectiveEffectsChanged();
    void lastMessageChanged();
    void applied(bool ok, const QString &message);

private:
    struct StoredValue {
        bool present = false;
        QString value;
    };

    static QVariantMap defaultSettings();
    bool validate(const QString &key, const QVariant &value, QVariant *normalized) const;
    void loadSettings();
    bool saveSettings();
    void updateEffectiveEffects();
    void setLastMessage(const QString &message);

    QString homePath() const;
    QString configPath(const QString &fileName) const;
    QString statePath(const QString &fileName) const;
    StoredValue readIniValue(const QString &file, const QString &group, const QString &key) const;
    bool writeIniValue(const QString &file, const QString &group, const QString &key,
                       const QString &value, bool remove = false) const;
    bool writeUserPlasmaTheme() const;
    bool ensureBackup();
    bool reloadDesktop() const;

    QVariantMap m_settings;
    QVariantMap m_capabilities;
    QVariantMap m_effectiveEffects;
    QString m_lastMessage;
};

#endif
