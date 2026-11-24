#ifndef LOGINMANAGERSERVICE_H
#define LOGINMANAGERSERVICE_H

#include <QObject>
#include <QVariantList>
#include <QPair>
#include <QVariantMap>

/**
 * Configuración del DylanOS Login Manager (la pantalla de acceso).
 *
 * Lee y escribe /etc/dylanos/login-manager.json (con `pkexec` si hace falta
 * elevación), copia el fondo elegido a una ruta legible por el greeter y
 * mantiene el catálogo de widgets y atajos. Todos los valores que expone son
 * los que el login va a usar de verdad: la vista previa se genera pidiendo una
 * captura al propio greeter, no con un dibujo aparte.
 */
class LoginManagerService : public QObject
{
    Q_OBJECT
    Q_PROPERTY(QVariantMap settings READ settings NOTIFY settingsChanged)
    Q_PROPERTY(QVariantList widgets READ widgets NOTIFY catalogoChanged)
    Q_PROPERTY(QVariantList shortcuts READ shortcuts NOTIFY catalogoChanged)
    Q_PROPERTY(QVariantList variants READ variants NOTIFY catalogoChanged)
    Q_PROPERTY(int maximumShortcuts READ maximumShortcuts CONSTANT)
    Q_PROPERTY(QString settingsPath READ settingsPath CONSTANT)
    Q_PROPERTY(QString backgroundPath READ backgroundPath NOTIFY settingsChanged)

public:
    explicit LoginManagerService(QObject *parent = nullptr);

    QVariantMap settings() const { return m_settings; }
    QVariantList widgets() const { return m_widgets; }
    QVariantList shortcuts() const { return m_shortcuts; }
    QVariantList variants() const { return m_variants; }
    int maximumShortcuts() const;
    QString settingsPath() const;
    QString backgroundPath() const;

    /** Cambia un valor y lo guarda. `ruta` es una clave con puntos:
     *  "apariencia.crimson_glass", "composicion.posicion_paneles"… */
    Q_INVOKABLE bool setValue(const QString &ruta, const QVariant &valor);
    /** Elige el fondo: copia el archivo al catálogo del login y lo activa. */
    Q_INVOKABLE bool setBackground(const QString &origen);
    /** Widgets elegidos: los pone en la columna que declara el catálogo. */
    Q_INVOKABLE bool setWidgetEnabled(const QString &id, bool activo);
    /** Atajos elegidos. Devuelve false si ya hay cuatro (el límite real). */
    Q_INVOKABLE bool setShortcutEnabled(const QString &id, bool activo);
    /** Aplica una variante completa (completa / sencilla / minima). */
    Q_INVOKABLE bool applyVariant(const QString &nombre);
    /** Restablece el login al estado del prototipo. */
    Q_INVOKABLE bool resetToPrototype();
    /** Genera una captura del login real con la configuración actual. */
    Q_INVOKABLE bool capturePreview(const QString &destino);
    /** Relee el archivo (por si lo cambió otro proceso). */
    Q_INVOKABLE void reload();

signals:
    void settingsChanged();
    void catalogoChanged();
    void previewReady(const QString &ruta);
    void actionFailed(const QString &message);
    void actionDone(const QString &message);

private:
    bool loadSettings();
    bool saveSettings();
    QVariantMap defaultSettings() const;
    void loadCatalogo();

    QVariantMap m_settings;
    QVariantList m_widgets;
    QVariantList m_shortcuts;
    QVariantList m_variants;
};

#endif // LOGINMANAGERSERVICE_H
