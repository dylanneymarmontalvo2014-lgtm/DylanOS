#pragma once

#include <QFutureWatcher>
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

signals:
    void devicesChanged();
    void homeFoldersChanged();
    void recentFilesChanged();

private:
    void refreshDevices();
    void refreshHomeFolders();
    void refreshRecents();
    static QString projectsDir();

    QVariantList m_favorites;
    QVariantList m_network;
    QVariantList m_devices;
    QVariantList m_homeFolders;
    QVariantList m_recent;
    QFutureWatcher<QVariantList> m_recentWatcher;
    QTimer m_deviceTimer;
};
