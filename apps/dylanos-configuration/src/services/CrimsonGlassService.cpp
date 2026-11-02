#include "CrimsonGlassService.h"

#include <QDir>
#include <QDBusConnection>
#include <QDBusInterface>
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

struct ConfigTarget {
    QString file;
    QString group;
    QString key;
};

const QList<ConfigTarget> managedTargets = {
    {QStringLiteral("kwinrc"), QStringLiteral("Plugins"), QStringLiteral("blurEnabled")},
    {QStringLiteral("kwinrc"), QStringLiteral("Plugins"), QStringLiteral("contrastEnabled")},
    {QStringLiteral("kwinrc"), QStringLiteral("Plugins"), QStringLiteral("glideEnabled")},
    {QStringLiteral("kwinrc"), QStringLiteral("Plugins"), QStringLiteral("slidingpopupsEnabled")},
    {QStringLiteral("kwinrc"), QStringLiteral("Plugins"), QStringLiteral("translucencyEnabled")},
    {QStringLiteral("kwinrc"), QStringLiteral("Effect-blur"), QStringLiteral("BlurStrength")},
    {QStringLiteral("kwinrc"), QStringLiteral("Effect-blur"), QStringLiteral("NoiseStrength")},
    {QStringLiteral("kwinrc"), QStringLiteral("Effect-translucency"), QStringLiteral("MoveResize")},
    {QStringLiteral("kwinrc"), QStringLiteral("Effect-translucency"), QStringLiteral("Dialogs")},
    {QStringLiteral("kwinrc"), QStringLiteral("Effect-translucency"), QStringLiteral("Inactive")},
    {QStringLiteral("kwinrc"), QStringLiteral("Effect-translucency"), QStringLiteral("Menus")},
    {QStringLiteral("kwinrc"), QStringLiteral("Effect-translucency"), QStringLiteral("IndividualMenuConfig")},
    {QStringLiteral("kwinrc"), QStringLiteral("Effect-translucency"), QStringLiteral("DropdownMenus")},
    {QStringLiteral("kwinrc"), QStringLiteral("Effect-translucency"), QStringLiteral("PopupMenus")},
    {QStringLiteral("kwinrc"), QStringLiteral("Effect-translucency"), QStringLiteral("TornOffMenus")},
    {QStringLiteral("kwinrc"), QStringLiteral("Effect-glide"), QStringLiteral("Duration")},
    {QStringLiteral("kwinrc"), QStringLiteral("Effect-slidingpopups"), QStringLiteral("SlideInTime")},
    {QStringLiteral("kwinrc"), QStringLiteral("Effect-slidingpopups"), QStringLiteral("SlideOutTime")},
    {QStringLiteral("kwinrc"), QStringLiteral("org.kde.kdecoration2"), QStringLiteral("theme")},
    {QStringLiteral("plasmarc"), QStringLiteral("Theme"), QStringLiteral("name")},
    {QStringLiteral("kdeglobals"), QStringLiteral("General"), QStringLiteral("AccentColor")},
    {QStringLiteral("kdeglobals"), QStringLiteral("General"), QStringLiteral("ColorScheme")},
    {QStringLiteral("gtk-3.0/settings.ini"), QStringLiteral("Settings"), QStringLiteral("gtk-theme-name")},
    {QStringLiteral("gtk-3.0/settings.ini"), QStringLiteral("Settings"), QStringLiteral("gtk-application-prefer-dark-theme")},
    {QStringLiteral("gtk-4.0/settings.ini"), QStringLiteral("Settings"), QStringLiteral("gtk-theme-name")},
    {QStringLiteral("gtk-4.0/settings.ini"), QStringLiteral("Settings"), QStringLiteral("gtk-application-prefer-dark-theme")}
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
    QJsonObject root;
    for (const ConfigTarget &target : managedTargets) {
        const StoredValue stored = readIniValue(configPath(target.file), target.group, target.key);
        QJsonObject entry;
        entry.insert(QStringLiteral("file"), target.file);
        entry.insert(QStringLiteral("group"), target.group);
        entry.insert(QStringLiteral("key"), target.key);
        entry.insert(QStringLiteral("present"), stored.present);
        entry.insert(QStringLiteral("value"), stored.value);
        root.insert(target.file + QLatin1Char('|') + target.group + QLatin1Char('|') + target.key, entry);
    }

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
    if (!m_settings.value(QStringLiteral("enabled")).toBool()) {
        if (!QFile::exists(statePath(QStringLiteral("backup.json")))) {
            setLastMessage(QStringLiteral("Crimson Glass está desactivado"));
            emit applied(true, m_lastMessage);
            return true;
        }
        return restorePrevious();
    }
    if (!ensureBackup()) {
        setLastMessage(QStringLiteral("No se pudo crear el respaldo de Crimson Glass"));
        emit applied(false, m_lastMessage);
        return false;
    }
    const bool blur = m_effectiveEffects.value(QStringLiteral("blur")).toBool();
    const bool contrast = m_effectiveEffects.value(QStringLiteral("contrast")).toBool();
    const bool animations = m_effectiveEffects.value(QStringLiteral("animations")).toBool()
                            && !m_effectiveEffects.value(QStringLiteral("lowPowerApplied")).toBool();
    const bool translucency = m_effectiveEffects.value(QStringLiteral("windowEffects")).toBool();
    const int blurStrength = 1 + qRound(m_settings.value(QStringLiteral("blur")).toInt() * 14.0 / 100.0);
    const int noiseStrength = qRound(m_settings.value(QStringLiteral("reflections")).toInt() * 10.0 / 100.0);
    const int transparency = m_settings.value(QStringLiteral("transparency")).toInt();
    const int menuTransparency = m_settings.value(QStringLiteral("menuTransparency")).toInt();
    const int moveResize = std::clamp(100 - qRound(transparency * 0.10), 90, 100);
    const int dialogs = std::clamp(100 - qRound(transparency * 0.08), 90, 100);
    const int inactive = std::clamp(100 - qRound(transparency * 0.06), 92, 100);
    const int menus = std::clamp(100 - qRound(menuTransparency * 0.10), 90, 100);
    const int duration = animations ? m_settings.value(QStringLiteral("animationDuration")).toInt() : 0;
    const QString mode = m_settings.value(QStringLiteral("mode")).toString();
    QString colorScheme;
    if (mode == QLatin1String("light"))
        colorScheme = QStringLiteral("DylanOSLight");
    else if (mode == QLatin1String("dark"))
        colorScheme = QStringLiteral("DylanOSDark");
    else {
        const StoredValue current = readIniValue(configPath(QStringLiteral("kdeglobals")),
                                                  QStringLiteral("General"),
                                                  QStringLiteral("ColorScheme"));
        colorScheme = current.present ? current.value : QStringLiteral("DylanOSDark");
    }
    const bool darkMode = colorScheme != QLatin1String("DylanOSLight");

    const QList<QPair<ConfigTarget, QString>> values = {
        {managedTargets[0], blur ? QStringLiteral("true") : QStringLiteral("false")},
        {managedTargets[1], contrast ? QStringLiteral("true") : QStringLiteral("false")},
        {managedTargets[2], animations ? QStringLiteral("true") : QStringLiteral("false")},
        {managedTargets[3], animations ? QStringLiteral("true") : QStringLiteral("false")},
        {managedTargets[4], translucency ? QStringLiteral("true") : QStringLiteral("false")},
        {managedTargets[5], QString::number(blurStrength)},
        {managedTargets[6], QString::number(noiseStrength)},
        {managedTargets[7], QString::number(moveResize)},
        {managedTargets[8], QString::number(dialogs)},
        {managedTargets[9], QString::number(inactive)},
        {managedTargets[10], QString::number(menus)},
        {managedTargets[11], QStringLiteral("true")},
        {managedTargets[12], QString::number(menus)},
        {managedTargets[13], QString::number(menus)},
        {managedTargets[14], QString::number(menus)},
        {managedTargets[15], QString::number(duration)},
        {managedTargets[16], QString::number(duration)},
        {managedTargets[17], QString::number(duration)},
        {managedTargets[18], QStringLiteral("__aurorae__svg__DylanOS-Crimson-Glass")},
        {managedTargets[19], QStringLiteral("DylanOS-Crimson-Glass")},
        {managedTargets[20], m_settings.value(QStringLiteral("accent")).toString()},
        {managedTargets[21], colorScheme},
        {managedTargets[22], darkMode ? QStringLiteral("DylanOS-Crimson") : QStringLiteral("DylanOS-Crimson-Light")},
        {managedTargets[23], darkMode ? QStringLiteral("1") : QStringLiteral("0")},
        {managedTargets[24], darkMode ? QStringLiteral("DylanOS-Crimson") : QStringLiteral("DylanOS-Crimson-Light")},
        {managedTargets[25], darkMode ? QStringLiteral("1") : QStringLiteral("0")}
    };
    bool ok = true;
    for (const auto &entry : values) {
        ok = writeIniValue(configPath(entry.first.file), entry.first.group,
                           entry.first.key, entry.second) && ok;
    }
    if (ok)
        reloadDesktop();
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
    bool ok = !root.isEmpty();
    for (auto it = root.constBegin(); it != root.constEnd(); ++it) {
        const QJsonObject entry = it.value().toObject();
        const bool present = entry.value(QStringLiteral("present")).toBool();
        ok = writeIniValue(configPath(entry.value(QStringLiteral("file")).toString()),
                           entry.value(QStringLiteral("group")).toString(),
                           entry.value(QStringLiteral("key")).toString(),
                           entry.value(QStringLiteral("value")).toString(), !present) && ok;
    }
    if (ok)
        QFile::remove(backup.fileName());
    if (ok)
        reloadDesktop();
    setLastMessage(ok ? QStringLiteral("Configuración anterior recuperada")
                      : QStringLiteral("No se pudo recuperar la configuración anterior"));
    emit applied(ok, m_lastMessage);
    return ok;
}

void CrimsonGlassService::reloadDesktop() const
{
    if (!qgetenv("DYLANOS_CRIMSON_TEST_ROOT").isEmpty())
        return;

    QDBusInterface kwin(QStringLiteral("org.kde.KWin"), QStringLiteral("/KWin"),
                        QStringLiteral("org.kde.KWin"), QDBusConnection::sessionBus());
    if (kwin.isValid())
        kwin.asyncCall(QStringLiteral("reconfigure"));

    QDBusInterface effects(QStringLiteral("org.kde.KWin"), QStringLiteral("/Effects"),
                           QStringLiteral("org.kde.kwin.Effects"), QDBusConnection::sessionBus());
    if (effects.isValid()) {
        for (const QString &effect : {QStringLiteral("blur"), QStringLiteral("contrast"),
                                      QStringLiteral("glide"), QStringLiteral("slidingpopups"),
                                      QStringLiteral("translucency")})
            effects.asyncCall(QStringLiteral("reconfigureEffect"), effect);
    }

    const auto opacityMode = [](int value) {
        return value >= 55 ? QStringLiteral("translucent")
                           : value >= 25 ? QStringLiteral("adaptive") : QStringLiteral("opaque");
    };
    const QString panelMode = opacityMode(m_settings.value(QStringLiteral("panelTransparency")).toInt());
    const QString dockMode = opacityMode(m_settings.value(QStringLiteral("dockTransparency")).toInt());
    const QString script = QStringLiteral(
        "var ps=panels(); for (var i=0;i<ps.length;i++){"
        "var p=ps[i]; if(p.location==='top') p.opacity='%1';"
        "else if(p.location==='bottom') p.opacity='%2';}").arg(panelMode, dockMode);
    QDBusInterface plasma(QStringLiteral("org.kde.plasmashell"), QStringLiteral("/PlasmaShell"),
                          QStringLiteral("org.kde.PlasmaShell"), QDBusConnection::sessionBus());
    if (plasma.isValid()) {
        plasma.asyncCall(QStringLiteral("evaluateScript"), script);
        plasma.asyncCall(QStringLiteral("refreshCurrentShell"));
    }
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
