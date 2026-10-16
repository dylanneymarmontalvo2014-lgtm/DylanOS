#pragma once

#include <QFutureWatcher>

#include <QUrl>
#include <QObject>
#include <QTimer>
#include <QVariantList>
#include <QtQml/qqmlregistration.h>

// Data for the sidebar (favourites, mounted volumes, network entries) and the
// "Inicio" page (user folders with item counts, recently modified files).
class PlacesService : public QObject
{
    Q_OBJECT
    QML_ELEMENT

    Q_PROPERTY(QVariantList favorites READ favorites CONSTANT)
    Q_PROPERTY(QVariantList network READ network CONSTANT)
    Q_PROPERTY(QVariantList devices READ devices NOTIFY devicesChanged)
    Q_PROPERTY(QVariantList homeFolders READ homeFolders NOTIFY homeFoldersChanged)
    Q_PROPERTY(QVariantList recentFiles READ recentFiles NOTIFY recentFilesChanged)

public:
    explicit PlacesService(QObject *parent = nullptr);
    ~PlacesService() override;

    QVariantList favorites() const { return m_favorites; }
    QVariantList network() const { return m_network; }
    QVariantList devices() const { return m_devices; }
    QVariantList homeFolders() const { return m_homeFolders; }
    QVariantList recentFiles() const { return m_recent; }

    Q_INVOKABLE void refresh();

    // Dispositivos con el motor de Dolphin: detecta unidades extraíbles y
    // las monta bajo demanda (KFilePlacesModel::requestSetup).
    static PlacesService *instance();
    static PlacesService *s_instance;
    bool isUnmountedDevice(const QString &url) const;
    void requestSetup(const QString &url);

signals:
    void devicesChanged();
    void homeFoldersChanged();
    void recentFilesChanged();
    void mounted(const QString &url);

private:
    void refreshDevices();
    void watchSetup(const QString &url);
    void refreshHomeFolders();
    void refreshRecents();
    static QString projectsDir();

    class KFilePlacesModel *m_places = nullptr;
    QString m_pendingSetup;
    bool m_lastSetupFailed = false;
    QVariantList m_favorites;
    QVariantList m_network;
    QVariantList m_devices;
    QVariantList m_homeFolders;
    QVariantList m_recent;
    QFutureWatcher<QVariantList> m_recentWatcher;
    QTimer m_deviceTimer;
};
