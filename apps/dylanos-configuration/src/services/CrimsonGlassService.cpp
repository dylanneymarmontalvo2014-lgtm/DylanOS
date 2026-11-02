#include "CrimsonGlassService.h"

#include <QDir>
#include <QFile>
#include <QFileInfo>
#include <QJsonDocument>
#include <QJsonObject>
#include <QRegularExpression>
#include <QSaveFile>
#include <QSettings>
#include <QStandardPaths>

#include <algorithm>

namespace {

const QStringList percentageKeys = {
    QStringLiteral("glassIntensity"), QStringLiteral("transparency"),
    QStringLiteral("blur"), QStringLiteral("reflections"),
    QStringLiteral("shadows"), QStringLiteral("panelTransparency"),
    QStringLiteral("dockTransparency"), QStringLiteral("menuTransparency")
};

const QStringList booleanKeys = {
    QStringLiteral("enabled"), QStringLiteral("globalEffects"),
    QStringLiteral("windowEffects"), QStringLiteral("backgroundBlur"),
    QStringLiteral("animations"), QStringLiteral("additionalEffects"),
    QStringLiteral("lowPower"), QStringLiteral("autoDetect")
};

}

CrimsonGlassService::CrimsonGlassService(QObject *parent)
    : QObject(parent)
{
    loadSettings();
    detectCapabilities();
}

QVariantMap CrimsonGlassService::defaultSettings()
{
    return {
        {QStringLiteral("enabled"), true},
        {QStringLiteral("globalEffects"), true},
        {QStringLiteral("glassIntensity"), 72},
        {QStringLiteral("transparency"), 68},
        {QStringLiteral("blur"), 70},
        {QStringLiteral("reflections"), 64},
        {QStringLiteral("shadows"), 66},
        {QStringLiteral("cornerRadius"), 18},
        {QStringLiteral("accent"), QStringLiteral("#DC143C")},
        {QStringLiteral("mode"), QStringLiteral("automatic")},
        {QStringLiteral("panelTransparency"), 72},
        {QStringLiteral("dockTransparency"), 78},
        {QStringLiteral("menuTransparency"), 70},
        {QStringLiteral("windowEffects"), true},
        {QStringLiteral("backgroundBlur"), true},
        {QStringLiteral("animations"), true},
        {QStringLiteral("animationDuration"), 180},
        {QStringLiteral("additionalEffects"), true},
        {QStringLiteral("lowPower"), false},
        {QStringLiteral("autoDetect"), true}
    };
}

QString CrimsonGlassService::homePath() const
{
    const QByteArray testRoot = qgetenv("DYLANOS_CRIMSON_TEST_ROOT");
    return testRoot.isEmpty() ? QDir::homePath() : QString::fromUtf8(testRoot);
}

QString CrimsonGlassService::configPath(const QString &fileName) const
{
    return homePath() + QStringLiteral("/.config/") + fileName;
}

QString CrimsonGlassService::statePath(const QString &fileName) const
{
    return homePath() + QStringLiteral("/.local/state/dylanos/crimson-glass/") + fileName;
}

void CrimsonGlassService::loadSettings()
{
    m_settings = defaultSettings();
    QSettings config(configPath(QStringLiteral("dylanos/crimson-glass.conf")), QSettings::IniFormat);
    config.beginGroup(QStringLiteral("General"));
    for (auto it = m_settings.cbegin(); it != m_settings.cend(); ++it) {
        if (!config.contains(it.key()))
            continue;
        QVariant normalized;
        if (validate(it.key(), config.value(it.key()), &normalized))
            m_settings.insert(it.key(), normalized);
    }
    config.endGroup();
}

bool CrimsonGlassService::saveSettings()
{
    const QString path = configPath(QStringLiteral("dylanos/crimson-glass.conf"));
    if (!QDir().mkpath(QFileInfo(path).absolutePath()))
        return false;
    QSettings config(path, QSettings::IniFormat);
    config.beginGroup(QStringLiteral("General"));
    for (auto it = m_settings.cbegin(); it != m_settings.cend(); ++it)
        config.setValue(it.key(), it.value());
    config.endGroup();
    config.sync();
    return config.status() == QSettings::NoError;
}

bool CrimsonGlassService::validate(const QString &key, const QVariant &value, QVariant *normalized) const
{
    if (percentageKeys.contains(key)) {
        bool ok = false;
        const int number = value.toInt(&ok);
        if (!ok || number < 0 || number > 100)
            return false;
        *normalized = number;
        return true;
    }
    if (booleanKeys.contains(key)) {
        if (value.metaType().id() == QMetaType::Bool) {
            *normalized = value.toBool();
            return true;
        }
        const QString text = value.toString().toLower();
        if (text == QLatin1String("true") || text == QLatin1String("1")) {
            *normalized = true;
            return true;
        }
        if (text == QLatin1String("false") || text == QLatin1String("0")) {
            *normalized = false;
            return true;
        }
        return false;
    }
    if (key == QLatin1String("cornerRadius")) {
        bool ok = false;
        const int number = value.toInt(&ok);
        if (!ok || number < 0 || number > 36)
            return false;
        *normalized = number;
        return true;
    }
    if (key == QLatin1String("animationDuration")) {
        bool ok = false;
        const int number = value.toInt(&ok);
        if (!ok || number < 60 || number > 500)
            return false;
        *normalized = number;
        return true;
    }
    if (key == QLatin1String("accent")) {
        const QString color = value.toString().toUpper();
        if (!QRegularExpression(QStringLiteral("^#[0-9A-F]{6}$")).match(color).hasMatch())
            return false;
        *normalized = color;
        return true;
    }
    if (key == QLatin1String("mode")) {
        const QString mode = value.toString().toLower();
        if (!QStringList{QStringLiteral("dark"), QStringLiteral("light"),
                         QStringLiteral("automatic")}.contains(mode))
            return false;
        *normalized = mode;
        return true;
    }
    return false;
}

bool CrimsonGlassService::setOption(const QString &key, const QVariant &value)
{
    QVariant normalized;
    if (!m_settings.contains(key) || !validate(key, value, &normalized)) {
        setLastMessage(QStringLiteral("Valor no válido para %1").arg(key));
        return false;
    }
    if (m_settings.value(key) == normalized)
        return true;
    m_settings.insert(key, normalized);
    if (!saveSettings()) {
        setLastMessage(QStringLiteral("No se pudo guardar la configuración de Crimson Glass"));
        return false;
    }
    updateEffectiveEffects();
    emit settingsChanged();
    return true;
}

void CrimsonGlassService::detectCapabilities()
{
    QString renderer = QString::fromUtf8(qgetenv("DYLANOS_CRIMSON_RENDERER"));
    if (renderer.isEmpty())
        renderer = QString::fromUtf8(qgetenv("QSG_RHI_BACKEND"));
    const QString rendererLower = renderer.toLower();
    const bool software = rendererLower.contains(QStringLiteral("llvmpipe"))
                          || rendererLower.contains(QStringLiteral("softpipe"))
                          || rendererLower == QLatin1String("software");
    QString session = QString::fromUtf8(qgetenv("XDG_SESSION_TYPE")).toLower();
    if (session.isEmpty())
        session = qEnvironmentVariableIsSet("WAYLAND_DISPLAY") ? QStringLiteral("wayland")
                                                                 : QStringLiteral("x11");
    const bool kwin = !QStandardPaths::findExecutable(QStringLiteral("kwin_wayland")).isEmpty()
                      || !QStandardPaths::findExecutable(QStringLiteral("kwin_x11")).isEmpty();
    const bool blur = QFile::exists(QStringLiteral("/usr/share/kwin/builtin-effects/blur.json"))
                      || QFile::exists(QStringLiteral("/usr/share/kwin/builtin-effects/kwin4_effect_blur/metadata.json"));
    const bool animations = QFile::exists(QStringLiteral("/usr/share/kwin/effects/scale/metadata.json"))
                            || QFile::exists(QStringLiteral("/usr/share/kwin/effects/kwin4_effect_scale/metadata.json"));

    m_capabilities = {
        {QStringLiteral("sessionType"), session},
        {QStringLiteral("compositor"), kwin ? QStringLiteral("KWin") : QStringLiteral("No detectado")},
        {QStringLiteral("backend"), renderer.isEmpty() ? QStringLiteral("Se detectará en la sesión") : renderer},
        {QStringLiteral("kwinAvailable"), kwin},
        {QStringLiteral("blurAvailable"), blur && !software},
        {QStringLiteral("animationsAvailable"), animations},
        {QStringLiteral("softwareRendering"), software},
        {QStringLiteral("plasmaThemeAvailable"), QFile::exists(QStringLiteral("/usr/share/plasma/desktoptheme/DylanOS-Crimson-Glass/metadata.json"))},
        {QStringLiteral("reducedMotion"), false}
    };
    updateEffectiveEffects();
    emit capabilitiesChanged();
}

void CrimsonGlassService::updateEffectiveEffects()
{
    const bool active = m_settings.value(QStringLiteral("enabled")).toBool()
                        && m_settings.value(QStringLiteral("globalEffects")).toBool();
    const bool constrained = m_settings.value(QStringLiteral("lowPower")).toBool()
                             || m_capabilities.value(QStringLiteral("softwareRendering")).toBool();
    const bool blur = active && !constrained
                      && m_settings.value(QStringLiteral("backgroundBlur")).toBool()
                      && m_capabilities.value(QStringLiteral("blurAvailable")).toBool();
    const bool animations = active && !m_capabilities.value(QStringLiteral("reducedMotion")).toBool()
                            && m_settings.value(QStringLiteral("animations")).toBool();
    const int requestedTransparency = m_settings.value(QStringLiteral("transparency")).toInt();
    const int surfaceOpacity = constrained ? std::max(88, 100 - requestedTransparency / 5)
                                           : std::max(32, 100 - requestedTransparency);
    m_effectiveEffects = {
        {QStringLiteral("enabled"), active},
        {QStringLiteral("blur"), blur},
        {QStringLiteral("contrast"), active && !constrained
             && m_settings.value(QStringLiteral("additionalEffects")).toBool()},
        {QStringLiteral("animations"), animations},
        {QStringLiteral("windowEffects"), active
             && m_settings.value(QStringLiteral("windowEffects")).toBool()},
        {QStringLiteral("lowPowerApplied"), constrained},
        {QStringLiteral("surfaceOpacity"), surfaceOpacity}
    };
    emit effectiveEffectsChanged();
}

CrimsonGlassService::StoredValue CrimsonGlassService::readIniValue(
    const QString &file, const QString &group, const QString &key) const
{
    QFile input(file);
    if (!input.open(QIODevice::ReadOnly | QIODevice::Text))
        return {};
    QString currentGroup;
    while (!input.atEnd()) {
        const QString line = QString::fromUtf8(input.readLine()).trimmed();
        if (line.startsWith(QLatin1Char('[')) && line.endsWith(QLatin1Char(']'))) {
            currentGroup = line.mid(1, line.size() - 2);
        } else if (currentGroup == group && line.startsWith(key + QLatin1Char('='))) {
            return {true, line.mid(key.size() + 1)};
        }
    }
    return {};
}

bool CrimsonGlassService::writeIniValue(const QString &file, const QString &group,
                                        const QString &key, const QString &value,
                                        bool remove) const
{
    QStringList lines;
    QFile input(file);
    if (input.open(QIODevice::ReadOnly | QIODevice::Text)) {
        const QString text = QString::fromUtf8(input.readAll());
        lines = text.split(QLatin1Char('\n'));
        if (!lines.isEmpty() && lines.last().isEmpty())
            lines.removeLast();
    }

    const QString header = QLatin1Char('[') + group + QLatin1Char(']');
    int groupLine = -1;
    int nextGroupLine = lines.size();
    int keyLine = -1;
    for (int i = 0; i < lines.size(); ++i) {
        const QString trimmed = lines.at(i).trimmed();
        if (trimmed == header) {
            groupLine = i;
            nextGroupLine = lines.size();
            continue;
        }
        if (groupLine >= 0 && i > groupLine && trimmed.startsWith(QLatin1Char('['))) {
            nextGroupLine = i;
            break;
        }
        if (groupLine >= 0 && i > groupLine && trimmed.startsWith(key + QLatin1Char('=')))
            keyLine = i;
    }

    if (remove) {
        if (keyLine >= 0)
            lines.removeAt(keyLine);
    } else if (keyLine >= 0) {
        lines[keyLine] = key + QLatin1Char('=') + value;
    } else if (groupLine >= 0) {
        lines.insert(nextGroupLine, key + QLatin1Char('=') + value);
    } else {
        if (!lines.isEmpty() && !lines.last().isEmpty())
            lines.append(QString());
        lines.append(header);
        lines.append(key + QLatin1Char('=') + value);
    }

    if (!QDir().mkpath(QFileInfo(file).absolutePath()))
        return false;
    QSaveFile output(file);
    if (!output.open(QIODevice::WriteOnly | QIODevice::Text))
        return false;
    output.write((lines.join(QLatin1Char('\n')) + QLatin1Char('\n')).toUtf8());
    return output.commit();
}

bool CrimsonGlassService::ensureBackup()
{
    const QString backupFile = statePath(QStringLiteral("backup.json"));
    if (QFile::exists(backupFile))
        return true;
    const StoredValue blur = readIniValue(configPath(QStringLiteral("kwinrc")),
                                          QStringLiteral("Plugins"),
                                          QStringLiteral("blurEnabled"));
    QJsonObject entry;
    entry.insert(QStringLiteral("file"), QStringLiteral("kwinrc"));
    entry.insert(QStringLiteral("group"), QStringLiteral("Plugins"));
    entry.insert(QStringLiteral("key"), QStringLiteral("blurEnabled"));
    entry.insert(QStringLiteral("present"), blur.present);
    entry.insert(QStringLiteral("value"), blur.value);
    QJsonObject root;
    root.insert(QStringLiteral("kwinrc|Plugins|blurEnabled"), entry);

    if (!QDir().mkpath(QFileInfo(backupFile).absolutePath()))
        return false;
    QSaveFile output(backupFile);
    if (!output.open(QIODevice::WriteOnly | QIODevice::Text))
        return false;
    output.write(QJsonDocument(root).toJson(QJsonDocument::Indented));
    return output.commit();
}

bool CrimsonGlassService::apply()
{
    if (!ensureBackup()) {
        setLastMessage(QStringLiteral("No se pudo crear el respaldo de Crimson Glass"));
        emit applied(false, m_lastMessage);
        return false;
    }
    const bool blur = m_effectiveEffects.value(QStringLiteral("blur")).toBool();
    const bool ok = writeIniValue(configPath(QStringLiteral("kwinrc")),
                                  QStringLiteral("Plugins"),
                                  QStringLiteral("blurEnabled"),
                                  blur ? QStringLiteral("true") : QStringLiteral("false"));
    setLastMessage(ok ? QStringLiteral("Crimson Glass aplicado")
                      : QStringLiteral("No se pudo actualizar KWin"));
    emit applied(ok, m_lastMessage);
    return ok;
}

bool CrimsonGlassService::restorePrevious()
{
    QFile backup(statePath(QStringLiteral("backup.json")));
    if (!backup.open(QIODevice::ReadOnly | QIODevice::Text)) {
        setLastMessage(QStringLiteral("No hay una configuración anterior guardada"));
        return false;
    }
    const QJsonObject root = QJsonDocument::fromJson(backup.readAll()).object();
    const QJsonObject entry = root.value(QStringLiteral("kwinrc|Plugins|blurEnabled")).toObject();
    if (entry.isEmpty())
        return false;
    const bool present = entry.value(QStringLiteral("present")).toBool();
    const bool ok = writeIniValue(configPath(entry.value(QStringLiteral("file")).toString()),
                                  entry.value(QStringLiteral("group")).toString(),
                                  entry.value(QStringLiteral("key")).toString(),
                                  entry.value(QStringLiteral("value")).toString(), !present);
    if (ok)
        QFile::remove(backup.fileName());
    setLastMessage(ok ? QStringLiteral("Configuración anterior recuperada")
                      : QStringLiteral("No se pudo recuperar la configuración anterior"));
    emit applied(ok, m_lastMessage);
    return ok;
}

bool CrimsonGlassService::resetDefaults()
{
    m_settings = defaultSettings();
    const bool ok = saveSettings();
    updateEffectiveEffects();
    emit settingsChanged();
    setLastMessage(ok ? QStringLiteral("Valores predeterminados restaurados")
                      : QStringLiteral("No se pudieron restaurar los valores predeterminados"));
    return ok;
}

void CrimsonGlassService::setLastMessage(const QString &message)
{
    if (m_lastMessage == message)
        return;
    m_lastMessage = message;
    emit lastMessageChanged();
}
