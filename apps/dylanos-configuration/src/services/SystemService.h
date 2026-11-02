#ifndef SYSTEMSERVICE_H
#define SYSTEMSERVICE_H

#include <QFileSystemWatcher>
#include <QObject>
#include <QVariantList>
#include <QVariantMap>

// Puente entre la interfaz QML de DylanOS Configuration y el sistema real:
// utilidades de KDE Plasma (plasma-apply-*, kcmshell), NetworkManager,
// PulseAudio (pactl), bluetoothctl, powerprofilesctl, timedatectl y datos
// de hardware leídos de /proc y /sys.
class SystemService : public QObject
{
    Q_OBJECT
    Q_PROPERTY(bool dark READ dark NOTIFY darkChanged)
    Q_PROPERTY(QString accent READ accent WRITE setAccent NOTIFY accentChanged)
    Q_PROPERTY(int brightness READ brightness WRITE setBrightness NOTIFY brightnessChanged)
    Q_PROPERTY(int maxBrightness READ maxBrightness CONSTANT)
    Q_PROPERTY(bool brightnessAvailable READ brightnessAvailable CONSTANT)

public:
    explicit SystemService(QObject *parent = nullptr);

    bool dark() const;
    QString accent() const;
    void setAccent(const QString &hex);
    int brightness() const;
    void setBrightness(int value);
    int maxBrightness() const;
    bool brightnessAvailable() const;

    Q_INVOKABLE bool has(const QString &program) const;
    Q_INVOKABLE QString exec(const QString &program, const QStringList &args, int timeoutMs = 10000) const;
    Q_INVOKABLE QString lastError() const { return m_lastError; }
    Q_INVOKABLE void launchDetached(const QString &program, const QStringList &args);

    // Módulos KCM nativos (arquitectura de KDE System Settings).
    Q_INVOKABLE void openKcm(const QVariantList &candidates);

    // Información del sistema (página Sistema / Acerca de).
    Q_INVOKABLE QVariantMap sysInfo() const;

    // Apariencia: esquemas de color, acento, fondos.
    Q_INVOKABLE QVariantList colorSchemes();
    Q_INVOKABLE bool applyColorScheme(const QString &name);
    Q_INVOKABLE QVariantList wallpapers();
    Q_INVOKABLE bool applyWallpaper(const QString &path);
    Q_INVOKABLE void applyCursor(const QString &theme);

    // Sonido real vía pactl.
    Q_INVOKABLE QVariantMap audio();
    Q_INVOKABLE bool setSinkVolume(int percent);
    Q_INVOKABLE bool setMicVolume(int percent);
    Q_INVOKABLE bool setSinkMute(bool mute);
    Q_INVOKABLE bool setMicMute(bool mute);
    Q_INVOKABLE bool setDefaultSink(const QString &name);
    Q_INVOKABLE bool setDefaultSource(const QString &name);

    // Red real vía nmcli.
    Q_INVOKABLE QVariantMap network();
    Q_INVOKABLE bool setWifi(bool enabled);
    Q_INVOKABLE void connectWifi(const QString &ssid, const QString &password);
    Q_INVOKABLE QString activeConnectionInfo();

    // Bluetooth real vía bluetoothctl.
    Q_INVOKABLE QVariantMap bluetooth();
    Q_INVOKABLE bool setBluetooth(bool enabled);
    Q_INVOKABLE void btConnect(const QString &mac);
    Q_INVOKABLE void btDisconnect(const QString &mac);
    Q_INVOKABLE bool btRemove(const QString &mac);

    // Energía real vía powerprofilesctl + batería en /sys.
    Q_INVOKABLE QVariantMap power();
    Q_INVOKABLE bool setPowerProfile(const QString &profile);

    // Almacenamiento real.
    Q_INVOKABLE QVariantMap storage() const;
    Q_INVOKABLE bool emptyTrash();

    // Aplicaciones instaladas y predeterminadas reales.
    Q_INVOKABLE QVariantList installedApps() const;
    Q_INVOKABLE QString defaultApp(const QString &kind) const;
    Q_INVOKABLE QVariantList defaultAppCandidates(const QString &kind) const;
    Q_INVOKABLE bool setDefaultApp(const QString &kind, const QString &desktopFile);

    // Fecha/hora e idioma.
    Q_INVOKABLE QVariantMap dateTime();
    Q_INVOKABLE bool setNtp(bool enabled);
    Q_INVOKABLE bool setTimezone(const QString &tz);

    // Cuenta de usuario real.
    Q_INVOKABLE QVariantMap userInfo() const;

    // Preferencias del escritorio aplicables sin KCM.
    Q_INVOKABLE bool setSingleClick(bool single);
    Q_INVOKABLE bool singleClick() const;
    Q_INVOKABLE bool setRestoreSession(bool enabled);
    Q_INVOKABLE bool restoreSession() const;

    Q_INVOKABLE bool configBool(const QString &file, const QString &group, const QString &key) const;
    Q_INVOKABLE QString configString(const QString &file, const QString &group, const QString &key) const;
    Q_INVOKABLE bool writeConfig(const QString &file, const QString &group, const QString &key, const QString &value);

signals:
    void darkChanged();
    void accentChanged();
    void brightnessChanged();
    void actionFailed(const QString &message);
    void taskDone(const QString &tag, bool ok, const QString &output);

private slots:
    void reloadTheme();

private:
    QString kcmShell() const;
    QString configPath(const QString &file) const;
    QString currentSchemeFile() const;
    bool writeKey(const QString &file, const QString &group, const QString &key, const QString &value);
    QString readKey(const QString &file, const QString &group, const QString &key) const;
    bool isDarkSchemeFile(const QString &path) const;
    QString resolveWallpaperImage(const QString &dir) const;


    QFileSystemWatcher m_watcher;
    mutable QString m_lastError;
};

#endif
