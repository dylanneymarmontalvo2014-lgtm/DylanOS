#pragma once

#include <QFileSystemWatcher>
#include <QObject>
#include <QQuickPaintedItem>
#include <QString>
#include <QtQml/qqmlregistration.h>

// DylanIcon: icono de tema (XDG) resuelto dinámicamente con QIcon::fromTheme.
// Sustituye a la iconografía stroke embebida para archivos, carpetas, lugares
// y unidades: el dibujo lo aporta el icon theme activo del sistema
// (kdeglobals [Icons] Theme), igual que el resto de apps de DylanOS.

class DylanIconTheme : public QObject
{
    Q_OBJECT
    Q_PROPERTY(QString theme READ themeName NOTIFY themeChanged)

public:
    static DylanIconTheme *instance();

    QString themeName() const { return m_themeName; }
    Q_INVOKABLE bool hasThemeIcon(const QString &name) const;

public slots:
    void refresh();

signals:
    void themeChanged();

private:
    explicit DylanIconTheme();

    QFileSystemWatcher m_watcher;
    QString m_themeName;
};

class DylanIcon : public QQuickPaintedItem
{
    Q_OBJECT
    QML_ELEMENT
    Q_PROPERTY(QString name READ name WRITE setName NOTIFY nameChanged)
    Q_PROPERTY(QString fallback READ fallback WRITE setFallback NOTIFY fallbackChanged)

public:
    explicit DylanIcon(QQuickItem *parent = nullptr);

    void paint(QPainter *painter) override;

    QString name() const { return m_name; }
    void setName(const QString &name);
    QString fallback() const { return m_fallback; }
    void setFallback(const QString &fallback);

signals:
    void nameChanged();
    void fallbackChanged();

private:
    QString m_name;
    QString m_fallback;
};
