#ifndef GAMINGSERVICE_H
#define GAMINGSERVICE_H

#include <QJsonObject>
#include <QObject>
#include <QProcess>
#include <QSet>
#include <QVariantList>
#include <QVariantMap>
#include <QVector>

// Gestor real del perfil DylanOS Gaming: catálogo declarativo, detección de
// hardware, instalación vía PackageKit/Flatpak y perfiles reversibles.
class GamingService : public QObject
{
    Q_OBJECT
    Q_PROPERTY(bool busy READ busy NOTIFY busyChanged)
    Q_PROPERTY(int progress READ progress NOTIFY progressChanged)
    Q_PROPERTY(QString progressMessage READ progressMessage NOTIFY progressChanged)
    Q_PROPERTY(QString lastError READ lastError NOTIFY lastErrorChanged)
    Q_PROPERTY(QString activeProfile READ activeProfile NOTIFY profileChanged)

public:
    explicit GamingService(QObject *parent = nullptr, bool detectGraphics = true);

    bool busy() const { return m_busy; }
    int progress() const { return m_progress; }
    QString progressMessage() const { return m_progressMessage; }
    QString lastError() const { return m_lastError; }
    QString activeProfile() const { return m_activeProfile; }

    Q_INVOKABLE QVariantList catalog() const;
    Q_INVOKABLE QVariantList profiles() const;
    Q_INVOKABLE QVariantMap hardware() const;
    Q_INVOKABLE QVariantMap status() const;
    Q_INVOKABLE int approximateSizeMb(const QStringList &ids) const;
    Q_INVOKABLE void refresh();
    Q_INVOKABLE bool installApp(const QString &id);
    Q_INVOKABLE bool uninstallApp(const QString &id);
    Q_INVOKABLE bool updateApp(const QString &id);
    Q_INVOKABLE bool installSelection(const QStringList &ids);
    Q_INVOKABLE bool installRecommended();
    Q_INVOKABLE bool applyProfile(const QString &id);
    Q_INVOKABLE bool restoreProfile();
    Q_INVOKABLE void cancelTask();

signals:
    void busyChanged();
    void progressChanged();
    void lastErrorChanged();
    void profileChanged();
    void catalogChanged();
    void hardwareChanged();
    void taskDone(const QString &tag, bool ok, const QString &output);

private:
    struct AppSpec {
        QString id;
        QString name;
        QString function;
        QString method;
        QStringList packages;
        QString flatpakId;
        QString remote;
        QStringList binaries;
        QStringList arches;
        QStringList gpu;
        QStringList cpuFlags;
        QString unavailableIn;
        QString unavailableReason;
        QString notes;
        int sizeMb = 0;
        int minRamGb = 0;
        bool iso = false;
        bool recommended = false;
        bool needsI386 = false;
        bool requiresVulkan = false;
    };

    QString dataRoot() const;
    QString stateDir() const;
    QString configDir() const;
    QString homeDir() const;
    QJsonObject loadJson(const QString &path) const;
    QVector<AppSpec> loadApps() const;
    AppSpec appById(const QString &id) const;
    QVariantMap appToMap(const AppSpec &app) const;
    bool appInstalled(const AppSpec &app) const;
    void refreshInstalledFlatpaks();
    bool appCompatible(const AppSpec &app, QString *reason) const;
    QVariantMap probeHardware(bool detectGraphics) const;
    QString gpuVendor() const;
    QString run(const QString &program, const QStringList &args, int timeoutMs = 8000) const;
    bool hasProgram(const QString &program) const;
    void setBusy(bool busy);
    void setProgress(int value, const QString &message);
    void setError(const QString &message);
    void logLine(const QString &line) const;
    bool enqueue(const QStringList &ids, bool uninstall, bool update = false);
    void startNext();
    bool startInstall(const AppSpec &app);
    bool startUninstall(const AppSpec &app);
    bool startUpdate(const AppSpec &app);
    QString helperPath() const;
    bool runHelper(const QStringList &args, QString *output) const;
    QVariantMap loadBackup() const;
    bool saveBackup(const QVariantMap &backup) const;
    bool writeText(const QString &path, const QString &text) const;
    QString readText(const QString &path) const;
    void inhibitNotifications(bool enable);
    bool applyPowerProfile(const QString &profile);
    QString currentCpuArch() const;

    QProcess m_process;
    QVector<AppSpec> m_apps;
    QSet<QString> m_installedFlatpaks;
    QVariantMap m_hardware;
    QStringList m_queue;
    bool m_uninstall = false;
    bool m_update = false;
    bool m_busy = false;
    int m_progress = 0;
    int m_total = 0;
    int m_done = 0;
    QString m_progressMessage;
    QString m_lastError;
    QString m_activeProfile;
    QString m_currentId;
    uint m_inhibitCookie = 0;
    bool m_inhibitActive = false;
};

#endif
