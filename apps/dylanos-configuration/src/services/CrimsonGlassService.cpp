#include "CrimsonGlassService.h"

#include <QDir>
#include <QDBusConnection>
#include <QDBusInterface>
#include <QDBusReply>
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
    const bool rendererOverride = !renderer.isEmpty();
    if (renderer.isEmpty())
        renderer = QString::fromUtf8(qgetenv("QSG_RHI_BACKEND"));
    bool kwinRunning = false;
    if (qgetenv("DYLANOS_CRIMSON_TEST_ROOT").isEmpty()) {
        QDBusInterface kwin(QStringLiteral("org.kde.KWin"), QStringLiteral("/KWin"),
                            QStringLiteral("org.kde.KWin"), QDBusConnection::sessionBus());
        kwinRunning = kwin.isValid();
        if (kwinRunning) {
            const QDBusReply<QString> reply = kwin.call(QStringLiteral("supportInformation"));
            if (reply.isValid()) {
                const QRegularExpression expression(
                    QStringLiteral("OpenGL renderer string:\\s*([^\\n]+)"),
                    QRegularExpression::CaseInsensitiveOption);
                const QRegularExpressionMatch match = expression.match(reply.value());
                if (match.hasMatch() && !rendererOverride)
                    renderer = match.captured(1).trimmed();
            }
        }
    }
    const QString rendererLower = renderer.toLower();
    const bool software = rendererLower.contains(QStringLiteral("llvmpipe"))
                          || rendererLower.contains(QStringLiteral("softpipe"))
                          || rendererLower == QLatin1String("software")
                          || qgetenv("LIBGL_ALWAYS_SOFTWARE") == QByteArrayLiteral("1");
    QString session = QString::fromUtf8(qgetenv("XDG_SESSION_TYPE")).toLower();
    if (session.isEmpty())
        session = qEnvironmentVariableIsSet("WAYLAND_DISPLAY") ? QStringLiteral("wayland")
                                                                 : QStringLiteral("x11");
    const QByteArray testCapabilities = qgetenv("DYLANOS_CRIMSON_TEST_CAPABILITIES");
    const bool forceFull = testCapabilities == QByteArrayLiteral("full");
    const bool forceNone = testCapabilities == QByteArrayLiteral("none");
    const bool kwin = !forceNone && (forceFull || kwinRunning
                      || !QStandardPaths::findExecutable(QStringLiteral("kwin_wayland")).isEmpty()
                      || !QStandardPaths::findExecutable(QStringLiteral("kwin_x11")).isEmpty());
    const bool blur = kwin && (forceFull
                      || QFile::exists(QStringLiteral("/usr/share/kwin/builtin-effects/blur.json"))
                      || QFile::exists(QStringLiteral("/usr/share/kwin/builtin-effects/kwin4_effect_blur/metadata.json")));
    const bool animations = kwin && (forceFull
                            || (QFile::exists(QStringLiteral("/usr/share/kwin/builtin-effects/glide.json"))
                                && QFile::exists(QStringLiteral("/usr/share/kwin/builtin-effects/slidingpopups.json"))));
    QString durationFactor = QString::fromUtf8(qgetenv("KDE_ANIMATION_DURATION_FACTOR"));
    if (durationFactor.isEmpty()) {
        const StoredValue stored = readIniValue(configPath(QStringLiteral("kdeglobals")),
                                                 QStringLiteral("KDE"),
                                                 QStringLiteral("AnimationDurationFactor"));
        if (stored.present)
            durationFactor = stored.value;
    }
    bool factorOk = false;
    const double factor = durationFactor.toDouble(&factorOk);
    const bool reducedMotion = factorOk && factor <= 0.0;

    m_capabilities = {
        {QStringLiteral("sessionType"), session},
        {QStringLiteral("compositor"), kwinRunning ? QStringLiteral("KWin activo")
                                                    : kwin ? QStringLiteral("KWin instalado")
                                                           : QStringLiteral("No detectado")},
        {QStringLiteral("backend"), renderer.isEmpty() ? QStringLiteral("Se detectará en la sesión") : renderer},
        {QStringLiteral("kwinAvailable"), kwin},
        {QStringLiteral("blurAvailable"), blur && !software},
        {QStringLiteral("animationsAvailable"), animations},
        {QStringLiteral("softwareRendering"), software},
        {QStringLiteral("plasmaThemeAvailable"), QFile::exists(QStringLiteral("/usr/share/plasma/desktoptheme/DylanOS-Crimson-Glass/metadata.json"))},
        {QStringLiteral("reducedMotion"), reducedMotion}
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
    const bool kwin = m_capabilities.value(QStringLiteral("kwinAvailable")).toBool();
    const bool animations = active && kwin && !constrained
                            && m_capabilities.value(QStringLiteral("animationsAvailable")).toBool()
                            && !m_capabilities.value(QStringLiteral("reducedMotion")).toBool()
                            && m_settings.value(QStringLiteral("animations")).toBool();
    const int requestedTransparency = m_settings.value(QStringLiteral("transparency")).toInt();
    const int glassIntensity = m_settings.value(QStringLiteral("glassIntensity")).toInt();
    const int requestedOpacity = 100 - qRound(requestedTransparency * 0.45
                                               * glassIntensity / 100.0);
    const int surfaceOpacity = constrained ? std::max(88, requestedOpacity)
                                           : std::max(55, requestedOpacity);
    m_effectiveEffects = {
        {QStringLiteral("enabled"), active},
        {QStringLiteral("blur"), blur},
        {QStringLiteral("contrast"), active && kwin && !constrained
             && m_settings.value(QStringLiteral("additionalEffects")).toBool()},
        {QStringLiteral("animations"), animations},
        {QStringLiteral("windowEffects"), active && kwin
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

bool CrimsonGlassService::writeUserPlasmaTheme() const
{
    const QString root = homePath()
        + QStringLiteral("/.local/share/plasma/desktoptheme/DylanOS-Crimson-Glass");
    const auto writeText = [](const QString &path, const QString &content) {
        if (!QDir().mkpath(QFileInfo(path).absolutePath()))
            return false;
        QSaveFile output(path);
        if (!output.open(QIODevice::WriteOnly | QIODevice::Text))
            return false;
        output.write(content.toUtf8());
        return output.commit();
    };

    const int radius = std::clamp(m_settings.value(QStringLiteral("cornerRadius")).toInt(), 1, 36);
    const int right = 96 - radius;
    const int center = 96 - radius * 2;
    const double intensity = m_settings.value(QStringLiteral("glassIntensity")).toInt() / 100.0;
    const bool constrained = m_effectiveEffects.value(QStringLiteral("lowPowerApplied")).toBool();
    const auto materialOpacity = [intensity, constrained](int transparency) {
        const double requested = 1.0 - transparency / 100.0 * 0.45 * intensity;
        return constrained ? std::max(0.88, requested) : std::max(0.55, requested);
    };
    const double panelOpacity = materialOpacity(
        m_settings.value(QStringLiteral("panelTransparency")).toInt());
    const double menuOpacity = materialOpacity(
        m_settings.value(QStringLiteral("menuTransparency")).toInt());
    const double reflectionOpacity = m_settings.value(QStringLiteral("reflections")).toInt()
                                     / 100.0 * 0.48;
    const double shadowOpacity = m_settings.value(QStringLiteral("shadows")).toInt()
                                 / 100.0 * 0.825;
    const QString accent = m_settings.value(QStringLiteral("accent")).toString();
    const auto decimal = [](double value) { return QString::number(value, 'f', 2); };

    const auto frame = [&](double opacity) {
        QString svg = QStringLiteral(R"SVG(<svg xmlns="http://www.w3.org/2000/svg" width="96" height="96">
<g id="topleft"><path d="M0,{{R}} Q0,0 {{R}},0 L{{R}},{{R}}Z" fill="#120d11" fill-opacity="{{O}}"/></g>
<g id="top"><rect x="{{R}}" y="0" width="{{C}}" height="{{R}}" fill="#120d11" fill-opacity="{{O}}"/><rect x="{{R}}" y="0" width="{{C}}" height="1" fill="#ffffff" fill-opacity="{{REF}}"/><rect x="{{R}}" y="1" width="{{C}}" height="1" fill="{{A}}" fill-opacity="{{REF}}"/></g>
<g id="topright"><path transform="translate({{RIGHT}},0)" d="M0,0 Q{{R}},0 {{R}},{{R}} L0,{{R}}Z" fill="#120d11" fill-opacity="{{O}}"/></g>
<g id="left"><rect x="0" y="{{R}}" width="{{R}}" height="{{C}}" fill="#120d11" fill-opacity="{{O}}"/><rect x="0" y="{{R}}" width="1" height="{{C}}" fill="{{A}}" fill-opacity="{{REF}}"/></g>
<g id="center"><rect x="{{R}}" y="{{R}}" width="{{C}}" height="{{C}}" fill="#120d11" fill-opacity="{{O}}"/></g>
<g id="right"><rect x="{{RIGHT}}" y="{{R}}" width="{{R}}" height="{{C}}" fill="#120d11" fill-opacity="{{O}}"/><rect x="95" y="{{R}}" width="1" height="{{C}}" fill="{{A}}" fill-opacity="{{REF}}"/></g>
<g id="bottomleft"><path transform="translate(0,{{RIGHT}})" d="M0,0 Q0,{{R}} {{R}},{{R}} L{{R}},0Z" fill="#120d11" fill-opacity="{{O}}"/></g>
<g id="bottom"><rect x="{{R}}" y="{{RIGHT}}" width="{{C}}" height="{{R}}" fill="#120d11" fill-opacity="{{O}}"/><rect x="{{R}}" y="95" width="{{C}}" height="1" fill="#000000" fill-opacity="{{SHADOW}}"/></g>
<g id="bottomright"><path transform="translate({{RIGHT}},{{RIGHT}})" d="M0,{{R}} Q{{R}},{{R}} {{R}},0 L0,0Z" fill="#120d11" fill-opacity="{{O}}"/></g>
<rect id="hint-stretch-borders" width="1" height="1" fill="none"/><rect id="hint-apply-color-scheme" width="1" height="1" fill="none"/></svg>
)SVG");
        svg.replace(QStringLiteral("{{RIGHT}}"), QString::number(right));
        svg.replace(QStringLiteral("{{SHADOW}}"), decimal(shadowOpacity));
        svg.replace(QStringLiteral("{{REF}}"), decimal(reflectionOpacity));
        svg.replace(QStringLiteral("{{R}}"), QString::number(radius));
        svg.replace(QStringLiteral("{{C}}"), QString::number(center));
        svg.replace(QStringLiteral("{{O}}"), decimal(opacity));
        svg.replace(QStringLiteral("{{A}}"), accent);
        return svg;
    };

    const QString metadata = QStringLiteral(R"JSON({
  "KPlugin": {
    "Id": "DylanOS-Crimson-Glass",
    "Name": "DylanOS Crimson Glass",
    "Version": "1.0.0",
    "License": "GPL-3.0-or-later"
  },
  "X-Plasma-API": "5.0",
  "X-Plasma-FallbackPackage": "DylanOS-Crimson"
}
)JSON");
    bool ok = writeText(root + QStringLiteral("/metadata.json"), metadata);
    ok = writeText(root + QStringLiteral("/widgets/panel-background.svg"),
                   frame(std::max(0.96, panelOpacity))) && ok;
    ok = writeText(root + QStringLiteral("/translucent/widgets/panel-background.svg"),
                   frame(panelOpacity)) && ok;
    ok = writeText(root + QStringLiteral("/dialogs/background.svg"),
                   frame(std::max(0.96, menuOpacity))) && ok;
    ok = writeText(root + QStringLiteral("/translucent/dialogs/background.svg"),
                   frame(menuOpacity)) && ok;
    return ok;
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
    if (m_settings.value(QStringLiteral("autoDetect")).toBool())
        detectCapabilities();
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
    bool ok = writeUserPlasmaTheme();
    for (const auto &entry : values) {
        ok = writeIniValue(configPath(entry.first.file), entry.first.group,
                           entry.first.key, entry.second) && ok;
    }
    if (!ok) {
        const bool restored = restorePrevious();
        setLastMessage(restored
            ? QStringLiteral("No se pudo aplicar; se recuperó la configuración anterior")
            : QStringLiteral("No se pudo aplicar y la recuperación quedó incompleta"));
        emit applied(false, m_lastMessage);
        return false;
    }
    const bool reloaded = reloadDesktop();
    setLastMessage(reloaded ? QStringLiteral("Crimson Glass aplicado")
                            : QStringLiteral("Perfil guardado; se aplicará al iniciar Plasma"));
    emit applied(true, m_lastMessage);
    return true;
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
    const bool reloaded = ok && reloadDesktop();
    setLastMessage(!ok ? QStringLiteral("No se pudo recuperar la configuración anterior")
                       : reloaded ? QStringLiteral("Configuración anterior recuperada")
                                  : QStringLiteral("Configuración recuperada; se completará al iniciar Plasma"));
    emit applied(ok, m_lastMessage);
    return ok;
}

bool CrimsonGlassService::reloadDesktop() const
{
    if (!qgetenv("DYLANOS_CRIMSON_TEST_ROOT").isEmpty())
        return true;

    QDBusInterface kwin(QStringLiteral("org.kde.KWin"), QStringLiteral("/KWin"),
                        QStringLiteral("org.kde.KWin"), QDBusConnection::sessionBus());
    if (kwin.isValid())
        kwin.asyncCall(QStringLiteral("reconfigure"));

    QDBusInterface effects(QStringLiteral("org.kde.KWin"), QStringLiteral("/Effects"),
                           QStringLiteral("org.kde.kwin.Effects"), QDBusConnection::sessionBus());
    if (effects.isValid()) {
        const QList<QPair<QString, bool>> effectStates = {
            {QStringLiteral("blur"), m_effectiveEffects.value(QStringLiteral("blur")).toBool()},
            {QStringLiteral("contrast"), m_effectiveEffects.value(QStringLiteral("contrast")).toBool()},
            {QStringLiteral("glide"), m_effectiveEffects.value(QStringLiteral("animations")).toBool()},
            {QStringLiteral("slidingpopups"), m_effectiveEffects.value(QStringLiteral("animations")).toBool()},
            {QStringLiteral("translucency"), m_effectiveEffects.value(QStringLiteral("windowEffects")).toBool()}
        };
        for (const auto &effect : effectStates) {
            effects.asyncCall(effect.second ? QStringLiteral("reconfigureEffect")
                                            : QStringLiteral("unloadEffect"),
                              effect.first);
        }
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
        // NUNCA llamar a refreshCurrentShell: en Plasma 6.3.6 sobre X11
        // termina plasmashell en silencio y el relanzado muere igual, así que
        // la sesión se queda sin shell (escritorio negro con solo el splash y
        // el Centro de bienvenida). Reproducido en VM: con el binario que
        // llama refreshCurrentShell plasmashell muere tras el autostart; sin
        // la llamada sobrevive. El shell ya aplica evaluateScript sin refresco.
    }
    return kwin.isValid() || plasma.isValid();
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
