#ifndef LOGINMANAGERSERVICE_H
#define LOGINMANAGERSERVICE_H

#include <QDateTime>
#include <QObject>
#include <QVariantList>
#include <QVariantMap>

class QTimer;

/**
 * Configuración del DylanOS Login Manager.
 *
 * Todo lo que el usuario puede cambiar del login pasa por aquí: fondo,
 * composición, tamaños, atajos (4 como máximo), widgets, Crimson Glass y
 * colores. El resultado se escribe en `/etc/dylanos/login-manager.json`, que
 * es exactamente lo que lee el greeter al arrancar.
 */
class LoginManagerService : public QObject
{
    Q_OBJECT
    Q_PROPERTY(QVariantMap settings READ settings NOTIFY settingsChanged)
    Q_PROPERTY(QVariantMap effective READ effective NOTIFY settingsChanged)
    Q_PROPERTY(bool available READ available NOTIFY settingsChanged)
    Q_PROPERTY(QString previewImage READ previewImage NOTIFY previewChanged)
    Q_PROPERTY(QString previewUrl READ previewUrl NOTIFY previewChanged)
public:
    explicit LoginManagerService(QObject *parent = nullptr);

    QVariantMap settings() const;
    QVariantMap effective() const;
    bool available() const;
    QString previewImage() const;
    QString previewUrl() const;

    Q_INVOKABLE QVariantList shortcutCatalog() const;
    Q_INVOKABLE QVariantList widgetCatalog() const;
    Q_INVOKABLE QVariantList wallpapers() const;
    Q_INVOKABLE QString fontFile() const;
    Q_INVOKABLE QString previewTarget() const;

    Q_INVOKABLE bool setOption(const QString &seccion, const QString &clave,
                               const QVariant &valor);
    Q_INVOKABLE bool setShortcuts(const QStringList &activos);
    Q_INVOKABLE bool setWidgets(const QStringList &izquierda, const QStringList &derecha);
    Q_INVOKABLE bool setRecordatorios(const QVariantList &lista);
    Q_INVOKABLE bool setWallpaper(const QString &ruta);
    Q_INVOKABLE bool refreshPreview(const QVariantMap &configuracion);
    Q_INVOKABLE bool reset();
    Q_INVOKABLE bool applyAccentColor();

signals:
    void settingsChanged();
    void previewChanged();
    void error(const QString &mensaje);

private:
    QVariantMap leerConfiguracion() const;
    bool escribirConfiguracion(const QVariantMap &configuracion);
    QVariantList leerLista(const QString &clave) const;

    QVariantMap m_config;
    QString m_previsualizacion;
    QTimer *m_vigilancia = nullptr;
    QDateTime m_ultimaLectura;
};

#endif
