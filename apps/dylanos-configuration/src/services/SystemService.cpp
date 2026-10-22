#include "SystemService.h"

#include <QDBusConnection>
#include <QDBusInterface>
#include <QDBusReply>
#include <QDir>
#include <QFile>
#include <QFileInfo>
#include <QFileSystemWatcher>
#include <QProcess>
#include <QRegularExpression>
#include <QStandardPaths>
#include <QStorageInfo>
#include <QSysInfo>
#include <QTimer>
#include <QUrl>

#include <sys/sysinfo.h>
#include <unistd.h>

#include <algorithm>
#include <cmath>

static QString expandPath(const QString &p)
{
    QString out = p;
    if (out.startsWith(QLatin1String("~/")))
        out = QDir::homePath() + out.mid(1);
    return out;
}

static QStringList schemeSearchPaths()
{
    return {QStringLiteral("/usr/share/color-schemes"),
            QDir::homePath() + QStringLiteral("/.local/share/color-schemes")};
}

SystemService::SystemService(QObject *parent)
    : QObject(parent)
{
    m_watcher.addPath(QDir::homePath() + QStringLiteral("/.config/kdeglobals"));
    connect(&m_watcher, &QFileSystemWatcher::fileChanged, this, &SystemService::reloadTheme);
}

bool SystemService::has(const QString &program) const
{
    return !QStandardPaths::findExecutable(program).isEmpty();
}

QString SystemService::exec(const QString &program, const QStringList &args, int timeoutMs) const
{
    m_lastError.clear();
    QProcess process;
    process.start(program, args);
    if (!process.waitForStarted(3000)) {
        m_lastError = QStringLiteral("No se pudo ejecutar %1").arg(program);
        return QString();
    }
    if (!process.waitForFinished(timeoutMs)) {
        m_lastError = QStringLiteral("%1 no respondió").arg(program);
        process.kill();
        return QString();
    }
    const QString out = QString::fromUtf8(process.readAllStandardOutput()).trimmed();
    const QString err = QString::fromUtf8(process.readAllStandardError()).trimmed();
    if (process.exitStatus() != QProcess::NormalExit || process.exitCode() != 0) {
        m_lastError = err.isEmpty() ? out : err;
        if (m_lastError.isEmpty())
            m_lastError = QStringLiteral("%1 terminó con error").arg(program);
        return out;
    }
    if (!err.isEmpty() && out.isEmpty())
        return err;
    return out;
}

void SystemService::launchDetached(const QString &program, const QStringList &args)
{
    if (!has(program)) {
        emit actionFailed(QStringLiteral("%1 no está instalado").arg(program));
        return;
    }
    QProcess::startDetached(program, args);
}

void SystemService::openKcm(const QVariantList &candidates)
{
    const QString shell = kcmShell();
    if (shell.isEmpty()) {
        emit actionFailed(QStringLiteral("No hay kcmshell disponible en este sistema"));
        return;
    }
    for (const QVariant &candidate : candidates) {
        QProcess probe;
        probe.start(shell, QStringList{candidate.toString()});
        if (probe.waitForStarted(2000)) {
            probe.terminate();
            probe.waitForFinished(1000);
            QProcess::startDetached(shell, QStringList{candidate.toString()});
            return;
        }
    }
    emit actionFailed(QStringLiteral("No se encontró el módulo de configuración solicitado"));
}

QString SystemService::kcmShell() const
{
    if (has(QStringLiteral("kcmshell6"))) return QStringLiteral("kcmshell6");
    if (has(QStringLiteral("kcmshell5"))) return QStringLiteral("kcmshell5");
    return QString();
}


/* --------------------------- Sistema ------------------------------ */

QVariantMap SystemService::sysInfo() const
{
    QVariantMap info;
    QString pretty, version, base;
    QFile release(QStringLiteral("/usr/lib/os-release"));
    if (release.open(QIODevice::ReadOnly | QIODevice::Text)) {
        while (!release.atEnd()) {
            const QString line = QString::fromUtf8(release.readLine()).trimmed();
            if (line.startsWith(QLatin1String("PRETTY_NAME=")))
                pretty = line.mid(12).remove(QLatin1Char('"'));
            else if (line.startsWith(QLatin1String("VERSION=")))
                version = line.mid(8).remove(QLatin1Char('"'));
            else if (line.startsWith(QLatin1String("ID_LIKE=")))
                base = line.mid(8).remove(QLatin1Char('"'));
        }
    }
    if (QFile::exists(QStringLiteral("/etc/dylanos-release")))
        pretty = QStringLiteral("DylanOS");
    QFile cpufile(QStringLiteral("/proc/cpuinfo"));
    QString cpu;
    if (cpufile.open(QIODevice::ReadOnly | QIODevice::Text)) {
        while (!cpufile.atEnd()) {
            const QString line = QString::fromUtf8(cpufile.readLine());
            // "model name" (x86) y "Hardware" (ARM de 32 bits): el kernel omite
            // "model name" cuando la marca del CPUID está vacía (p. ej. QEMU
            // TCG con -cpu max) y la página quedaba en "—".
            if (line.startsWith(QLatin1String("model name"))
                || line.startsWith(QLatin1String("Hardware"))) {
                const QString model = line.section(QLatin1Char(':'), 1).trimmed();
                if (!model.isEmpty()) {
                    cpu = model;
                    break;
                }
            }
        }
    }
    if (cpu.isEmpty()) {
        const QString lscpu = exec(QStringLiteral("lscpu"), QStringList(), 5000);
        for (const QString &line : lscpu.split(QLatin1Char('\n'))) {
            if (line.startsWith(QLatin1String("Model name:"))) {
                const QString model = line.mid(line.indexOf(QLatin1Char(':')) + 1).trimmed();
                if (!model.isEmpty()) {
                    cpu = model;
                    break;
                }
            }
        }
    }
    if (cpu.isEmpty()) {
        const long cores = sysconf(_SC_NPROCESSORS_ONLN);
        if (cores == 1)
            cpu = QStringLiteral("Procesador de 1 núcleo");
        else if (cores > 1)
            cpu = QStringLiteral("Procesador de %1 núcleos").arg(cores);
    }
    QFile memfile(QStringLiteral("/proc/meminfo"));
    qint64 memKb = 0;
    if (memfile.open(QIODevice::ReadOnly | QIODevice::Text)) {
        const QString first = QString::fromUtf8(memfile.readLine());
        memKb = first.section(QLatin1Char(':'), 1).simplified().split(QLatin1Char(' ')).value(0).toLongLong();
    }
    QString product;
    QFile productFile(QStringLiteral("/sys/devices/virtual/dmi/id/product_name"));
    if (productFile.open(QIODevice::ReadOnly))
        product = QString::fromUtf8(productFile.readAll()).trimmed();

    struct sysinfo si;
    double uptimeHours = 0;
    if (sysinfo(&si) == 0)
        uptimeHours = si.uptime / 3600.0;

    info.insert(QStringLiteral("distro"), pretty.isEmpty() ? QStringLiteral("DylanOS") : pretty);
    info.insert(QStringLiteral("version"), version.isEmpty() ? QStringLiteral("1.0 Beta") : version);
    info.insert(QStringLiteral("base"), base.isEmpty() ? QStringLiteral("debian") : base);
    info.insert(QStringLiteral("kernel"), QSysInfo::kernelVersion());
    info.insert(QStringLiteral("arch"), QSysInfo::currentCpuArchitecture());
    info.insert(QStringLiteral("cpu"), cpu);
    // MemTotal recorta la memoria reservada por el firmware: 8 GB físicos se
    // leen como ~7,6 GiB. La RAM se vende en potencias de dos, así que se
    // redondea al entero más cercano y se ajusta a la potencia de dos más
    // próxima cuando queda a menos del 10 % (7,6→8, 15,4→16, 11,6→12).
    QString memoryGb;
    if (memKb > 0) {
        const double gib = memKb / (1024.0 * 1024.0);
        double shown = std::round(gib);
        for (double size = 2.0; size <= 128.0; size *= 2.0) {
            if (std::abs(gib - size) <= size * 0.10) {
                shown = size;
                break;
            }
        }
        memoryGb = shown < 1.0
                      ? QString::number(gib, 'f', 1) + QStringLiteral(" GB")
                      : QString::number(int(shown)) + QStringLiteral(" GB");
    }
    info.insert(QStringLiteral("memoryGb"), memoryGb);
    info.insert(QStringLiteral("device"), product);
    info.insert(QStringLiteral("hostname"), QSysInfo::machineHostName());
    info.insert(QStringLiteral("uptimeHours"), uptimeHours);
    return info;
}

/* ------------------------ Config y tema --------------------------- */

QString SystemService::configPath(const QString &file) const
{
    if (QDir::isAbsolutePath(file))
        return file;
    return QDir::homePath() + QStringLiteral("/.config/") + file;
}

QString SystemService::readKey(const QString &file, const QString &group, const QString &key) const
{
    QFile f(file);
    if (!f.open(QIODevice::ReadOnly | QIODevice::Text))
        return QString();
    QString current;
    while (!f.atEnd()) {
        const QString line = QString::fromUtf8(f.readLine()).trimmed();
        if (line.startsWith(QLatin1Char('[')) && line.endsWith(QLatin1Char(']')))
            current = line.mid(1, line.length() - 2);
        else if (current == group && line.startsWith(key + QLatin1Char('=')))
            return line.mid(key.length() + 1).trimmed();
    }
    return QString();
}

bool SystemService::writeKey(const QString &file, const QString &group, const QString &key, const QString &value)
{
    const QString tool = has(QStringLiteral("kwriteconfig6")) ? QStringLiteral("kwriteconfig6")
                                                              : QStringLiteral("kwriteconfig5");
    if (!has(tool)) {
        m_lastError = QStringLiteral("kwriteconfig no está disponible");
        return false;
    }
    exec(tool, {QStringLiteral("--file"), file, QStringLiteral("--group"), group,
                QStringLiteral("--key"), key, value});
    return m_lastError.isEmpty();
}

bool SystemService::configBool(const QString &file, const QString &group, const QString &key) const
{
    const QString v = readKey(configPath(file), group, key).toLower();
    return v == QLatin1String("true") || v == QLatin1String("1") || v == QLatin1String("yes");
}

QString SystemService::configString(const QString &file, const QString &group, const QString &key) const
{
    return readKey(configPath(file), group, key);
}

bool SystemService::writeConfig(const QString &file, const QString &group, const QString &key, const QString &value)
{
    return writeKey(configPath(file), group, key, value);
}

bool SystemService::isDarkSchemeFile(const QString &path) const
{
    QFile f(path);
    if (!f.open(QIODevice::ReadOnly | QIODevice::Text))
        return true;
    bool inWindow = false;
    const QRegularExpression re(QStringLiteral("(\\d+)\\s*,\\s*(\\d+)\\s*,\\s*(\\d+)"));
    while (!f.atEnd()) {
        const QString line = QString::fromUtf8(f.readLine()).trimmed();
        if (line.startsWith(QLatin1Char('['))) {
            inWindow = (line == QLatin1String("[Colors:Window]"));
            continue;
        }
        if (inWindow && line.startsWith(QLatin1String("BackgroundNormal="))) {
            const auto match = re.match(line);
            if (match.hasMatch()) {
                const int r = match.captured(1).toInt();
                const int g = match.captured(2).toInt();
                const int b = match.captured(3).toInt();
                return (0.299 * r + 0.587 * g + 0.114 * b) < 128.0;
            }
        }
    }
    return true;
}

QString SystemService::currentSchemeFile() const
{
    QString name = readKey(configPath("kdeglobals"), QStringLiteral("General"), QStringLiteral("ColorScheme"));
    if (name.isEmpty())
        name = QStringLiteral("DylanOSDark");
    for (const QString &dir : schemeSearchPaths()) {
        const QString candidate = dir + QLatin1Char('/') + name + QStringLiteral(".colors");
        if (QFile::exists(candidate))
            return candidate;
    }
    for (const QString &dir : schemeSearchPaths()) {
        QDir d(dir);
        const QStringList files = d.entryList(QStringList() << QStringLiteral("*.colors"), QDir::Files);
        for (const QString &f : files) {
            QFile scheme(dir + QLatin1Char('/') + f);
            if (scheme.open(QIODevice::ReadOnly | QIODevice::Text)) {
                const QString content = QString::fromUtf8(scheme.readAll());
                if (content.contains(QStringLiteral("Name=") + name))
                    return dir + QLatin1Char('/') + f;
            }
        }
    }
    return QString();
}

bool SystemService::dark() const
{
    const QString file = currentSchemeFile();
    if (file.isEmpty())
        return true;
    return isDarkSchemeFile(file);
}

void SystemService::reloadTheme()
{
    emit darkChanged();
}

/* -------------------------- Apariencia ---------------------------- */

QVariantList SystemService::colorSchemes()
{
    QVariantList result;
    for (const QString &dir : schemeSearchPaths()) {
        const QDir d(dir);
        const QStringList files = d.entryList(QStringList() << QStringLiteral("*.colors"), QDir::Files);
        for (const QString &f : files) {
            const QString path = dir + QLatin1Char('/') + f;
            QString name = readKey(path, QStringLiteral("KDE"), QStringLiteral("Name"));
            if (name.isEmpty())
                name = f.chopped(QStringLiteral(".colors").length());
            QVariantMap entry;
            entry.insert(QStringLiteral("name"), name);
            entry.insert(QStringLiteral("dark"), isDarkSchemeFile(path));
            entry.insert(QStringLiteral("file"), path);
            result.append(entry);
        }
    }
    return result;
}

bool SystemService::applyColorScheme(const QString &name)
{
    if (!has(QStringLiteral("plasma-apply-colorscheme"))) {
        m_lastError = QStringLiteral("plasma-apply-colorscheme no está disponible");
        emit actionFailed(m_lastError);
        return false;
    }
    exec(QStringLiteral("plasma-apply-colorscheme"), {name}, 20000);
    if (!m_lastError.isEmpty()) {
        emit actionFailed(m_lastError);
        return false;
    }
    emit darkChanged();
    return true;
}

QString SystemService::resolveWallpaperImage(const QString &dir) const
{
    QDir base(dir);
    const QStringList patterns = {QStringLiteral("contents/images/*dark*"),
                                  QStringLiteral("contents/images/*Dark*"),
                                  QStringLiteral("contents/images/1280x720.png"),
                                  QStringLiteral("contents/images/1920x1080.png"),
                                  QStringLiteral("contents/images/*")};
    for (const QString &pattern : patterns) {
        const QStringList matches = base.entryList(QStringList() << pattern.split(QLatin1Char('/')).value(1),
                                                   QDir::Files, QDir::Name);
        const QString sub = pattern.section(QLatin1Char('/'), 0, 1);
        for (const QString &m : matches) {
            const QString candidate = base.filePath(sub + QLatin1Char('/') + m);
            if (QFileInfo(candidate).suffix().toLower() == QStringLiteral("png")
                || QFileInfo(candidate).suffix().toLower() == QStringLiteral("jpg"))
                return candidate;
        }
    }
    return QString();
}

QVariantList SystemService::wallpapers()
{
    QVariantList result;
    QStringList dirs{QStringLiteral("/usr/share/wallpapers"),
                     QDir::homePath() + QStringLiteral("/.local/share/wallpapers")};
    for (const QString &dir : dirs) {
        const QDir d(dir);
        if (!d.exists())
            continue;
        for (const QString &entry : d.entryList(QDir::Dirs | QDir::NoDotAndDotDot, QDir::Name)) {
            const QString path = resolveWallpaperImage(dir + QLatin1Char('/') + entry);
            if (path.isEmpty())
                continue;
            QVariantMap wp;
            wp.insert(QStringLiteral("name"), entry);
            wp.insert(QStringLiteral("path"), path);
            // Los fondos de DylanOS aparecen primero en la galería.
            wp.insert(QStringLiteral("dylanos"), entry.startsWith(QLatin1String("DylanOS")));
            result.append(wp);
        }
    }
    std::stable_sort(result.begin(), result.end(), [](const QVariant &a, const QVariant &b) {
        return a.toMap().value("dylanos").toBool() && !b.toMap().value("dylanos").toBool();
    });
    return result;
}

bool SystemService::applyWallpaper(const QString &path)
{
    if (!has(QStringLiteral("plasma-apply-wallpaperimage"))) {
        m_lastError = QStringLiteral("plasma-apply-wallpaperimage no está disponible");
        emit actionFailed(m_lastError);
        return false;
    }
    exec(QStringLiteral("plasma-apply-wallpaperimage"), {path}, 30000);
    if (!m_lastError.isEmpty()) {
        emit actionFailed(m_lastError);
        return false;
    }
    return true;
}

void SystemService::applyCursor(const QString &theme)
{
    if (has(QStringLiteral("plasma-apply-cursortheme")))
        exec(QStringLiteral("plasma-apply-cursortheme"), {theme}, 20000);
}

QString SystemService::accent() const
{
    return readKey(configPath(QStringLiteral("kdeglobals")), QStringLiteral("General"), QStringLiteral("AccentColor"));
}

void SystemService::setAccent(const QString &hex)
{
    if (!writeKey(QStringLiteral("kdeglobals"), QStringLiteral("General"), QStringLiteral("AccentColor"), hex)) {
        emit actionFailed(m_lastError);
        return;
    }
    emit accentChanged();
}

/* ------------------------- Brillo --------------------------------- */

static QString backlightDevice()
{
    QDir dir(QStringLiteral("/sys/class/backlight"));
    const QStringList devices = dir.entryList(QDir::Dirs | QDir::NoDotAndDotDot);
    return devices.isEmpty() ? QString() : dir.filePath(devices.first());
}

bool SystemService::brightnessAvailable() const
{
    return !backlightDevice().isEmpty();
}

int SystemService::maxBrightness() const
{
    const QString dev = backlightDevice();
    if (dev.isEmpty())
        return 0;
    QFile f(dev + QStringLiteral("/max_brightness"));
    if (!f.open(QIODevice::ReadOnly))
        return 0;
    return QString::fromUtf8(f.readAll()).trimmed().toInt();
}

int SystemService::brightness() const
{
    const QString dev = backlightDevice();
    if (dev.isEmpty())
        return 0;
    QFile f(dev + QStringLiteral("/actual_brightness"));
    if (!f.open(QIODevice::ReadOnly))
        return 0;
    return QString::fromUtf8(f.readAll()).trimmed().toInt();
}

void SystemService::setBrightness(int value)
{
    // Vía nativa: powerdevil (el mismo agente que usa el applet de energía).
    QDBusInterface powerdevil(QStringLiteral("org.kde.Solid.PowerManagement"),
                              QStringLiteral("/org/kde/Solid/PowerManagement"),
                              QStringLiteral("org.kde.Solid.PowerManagement.Actions.BrightnessControl"),
                              QDBusConnection::sessionBus());
    if (powerdevil.isValid()) {
        QDBusReply<void> reply = powerdevil.call(QStringLiteral("setBrightness"), value);
        if (reply.isValid()) {
            emit brightnessChanged();
            return;
        }
    }
    emit actionFailed(QStringLiteral("No se pudo ajustar el brillo en este sistema"));
}

/* -------------------------- Sonido -------------------------------- */

static int parseVolumePercent(const QString &pactlOutput)
{
    const QRegularExpression re(QStringLiteral("(\\d+)%"));
    const auto match = re.match(pactlOutput);
    return match.hasMatch() ? match.captured(1).toInt() : 0;
}

static QVariantList pactlDevices(const QString &kind)
{
    QVariantList result;
    QProcess process;
    process.start(QStringLiteral("pactl"), {QStringLiteral("list"), QStringLiteral("short"), kind});
    if (!process.waitForFinished(4000))
        return result;
    const QStringList lines = QString::fromUtf8(process.readAllStandardOutput())
                                  .split(QLatin1Char('\n'), Qt::SkipEmptyParts);
    for (const QString &line : lines) {
        const QStringList fields = line.split(QLatin1Char('\t'));
        if (fields.size() < 2)
            continue;
        QVariantMap dev;
        dev.insert(QStringLiteral("name"), fields.value(1));
        dev.insert(QStringLiteral("description"), fields.value(fields.size() - 1, fields.value(1)));
        result.append(dev);
    }
    return result;
}

QVariantMap SystemService::audio()
{
    QVariantMap audio;
    if (!has(QStringLiteral("pactl"))) {
        audio.insert(QStringLiteral("available"), false);
        return audio;
    }
    audio.insert(QStringLiteral("available"), true);
    audio.insert(QStringLiteral("sinks"), pactlDevices(QStringLiteral("sinks")));
    audio.insert(QStringLiteral("sources"), pactlDevices(QStringLiteral("sources")));
    audio.insert(QStringLiteral("defaultSink"), exec(QStringLiteral("pactl"), {QStringLiteral("get-default-sink")}));
    audio.insert(QStringLiteral("defaultSource"), exec(QStringLiteral("pactl"), {QStringLiteral("get-default-source")}));
    audio.insert(QStringLiteral("volume"), parseVolumePercent(exec(QStringLiteral("pactl"), {QStringLiteral("get-sink-volume"), QStringLiteral("@DEFAULT_SINK@")})));
    audio.insert(QStringLiteral("micVolume"), parseVolumePercent(exec(QStringLiteral("pactl"), {QStringLiteral("get-source-volume"), QStringLiteral("@DEFAULT_SOURCE@")})));
    audio.insert(QStringLiteral("muted"), exec(QStringLiteral("pactl"), {QStringLiteral("get-sink-mute"), QStringLiteral("@DEFAULT_SINK@")}).contains(QLatin1String("yes"), Qt::CaseInsensitive));
    audio.insert(QStringLiteral("micMuted"), exec(QStringLiteral("pactl"), {QStringLiteral("get-source-mute"), QStringLiteral("@DEFAULT_SOURCE@")}).contains(QLatin1String("yes"), Qt::CaseInsensitive));
    return audio;
}

bool SystemService::setSinkVolume(int percent)
{
    exec(QStringLiteral("pactl"), {QStringLiteral("set-sink-volume"), QStringLiteral("@DEFAULT_SINK@"),
                                   QStringLiteral("%1%").arg(percent)});
    return m_lastError.isEmpty();
}

bool SystemService::setMicVolume(int percent)
{
    exec(QStringLiteral("pactl"), {QStringLiteral("set-source-volume"), QStringLiteral("@DEFAULT_SOURCE@"),
                                   QStringLiteral("%1%").arg(percent)});
    return m_lastError.isEmpty();
}

bool SystemService::setSinkMute(bool mute)
{
    exec(QStringLiteral("pactl"), {QStringLiteral("set-sink-mute"), QStringLiteral("@DEFAULT_SINK@"),
                                   mute ? QStringLiteral("1") : QStringLiteral("0")});
    return m_lastError.isEmpty();
}

bool SystemService::setMicMute(bool mute)
{
    exec(QStringLiteral("pactl"), {QStringLiteral("set-source-mute"), QStringLiteral("@DEFAULT_SOURCE@"),
                                   mute ? QStringLiteral("1") : QStringLiteral("0")});
    return m_lastError.isEmpty();
}

bool SystemService::setDefaultSink(const QString &name)
{
    exec(QStringLiteral("pactl"), {QStringLiteral("set-default-sink"), name});
    return m_lastError.isEmpty();
}

bool SystemService::setDefaultSource(const QString &name)
{
    exec(QStringLiteral("pactl"), {QStringLiteral("set-default-source"), name});
    return m_lastError.isEmpty();
}

/* --------------------------- Red ---------------------------------- */

QVariantMap SystemService::network()
{
    QVariantMap net;
    if (!has(QStringLiteral("nmcli"))) {
        net.insert(QStringLiteral("available"), false);
        // Claves siempre presentes: la página enlaza visible: wifiEnabled && …
        // y un undefined rompería el binding bool (QA offscreen lo detectó).
        net.insert(QStringLiteral("wifiEnabled"), false);
        net.insert(QStringLiteral("networks"), QVariantList());
        return net;
    }
    net.insert(QStringLiteral("available"), true);
    net.insert(QStringLiteral("wifiEnabled"),
               exec(QStringLiteral("nmcli"), {QStringLiteral("radio"), QStringLiteral("wifi")}).contains(QLatin1String("enabled")));
    QVariantList wifiList;
    const QString list = exec(QStringLiteral("nmcli"),
                              {QStringLiteral("-g"), QStringLiteral("IN-USE,SSID,SIGNAL,SECURITY"),
                               QStringLiteral("device"), QStringLiteral("wifi"), QStringLiteral("list")});
    QString connectedSsid;
    for (const QString &line : list.split(QLatin1Char('\n'), Qt::SkipEmptyParts)) {
        const QStringList f = line.split(QLatin1Char(':'));
        if (f.size() < 4)
            continue;
        QVariantMap ap;
        ap.insert(QStringLiteral("active"), !f.value(0).isEmpty());
        ap.insert(QStringLiteral("ssid"), f.value(1));
        ap.insert(QStringLiteral("signal"), f.value(2).toInt());
        ap.insert(QStringLiteral("secure"), !f.value(3).isEmpty());
        wifiList.append(ap);
        if (!f.value(0).isEmpty())
            connectedSsid = f.value(1);
    }
    net.insert(QStringLiteral("networks"), wifiList);
    net.insert(QStringLiteral("connectedSsid"), connectedSsid);
    const QString devices = exec(QStringLiteral("nmcli"),
                                 {QStringLiteral("-g"), QStringLiteral("TYPE,STATE"),
                                  QStringLiteral("device"), QStringLiteral("status")});
    bool ethernetUp = false;
    for (const QString &line : devices.split(QLatin1Char('\n'), Qt::SkipEmptyParts)) {
        const QStringList f = line.split(QLatin1Char(':'));
        if (f.value(0) == QLatin1String("ethernet") && f.value(1) == QLatin1String("connected"))
            ethernetUp = true;
    }
    net.insert(QStringLiteral("ethernet"), ethernetUp);
    return net;
}

bool SystemService::setWifi(bool enabled)
{
    exec(QStringLiteral("nmcli"), {QStringLiteral("radio"), QStringLiteral("wifi"),
                                   enabled ? QStringLiteral("on") : QStringLiteral("off")});
    if (!m_lastError.isEmpty()) {
        emit actionFailed(m_lastError);
        return false;
    }
    return true;
}

void SystemService::connectWifi(const QString &ssid, const QString &password)
{
    QStringList args{QStringLiteral("device"), QStringLiteral("wifi"), QStringLiteral("connect"), ssid};
    if (!password.isEmpty())
        args << QStringLiteral("password") << password;
    QProcess *process = new QProcess(this);
    process->start(QStringLiteral("nmcli"), args);
    connect(process, &QProcess::finished, this, [this, process, ssid](int code, QProcess::ExitStatus) {
        const QString out = QString::fromUtf8(process->readAllStandardOutput());
        const QString err = QString::fromUtf8(process->readAllStandardError());
        process->deleteLater();
        emit taskDone(QStringLiteral("wifi:%1").arg(ssid), code == 0,
                      code == 0 ? out : (err.isEmpty() ? out : err));
    });
}

QString SystemService::activeConnectionInfo()
{
    const QString show = exec(QStringLiteral("nmcli"),
                              {QStringLiteral("-g"), QStringLiteral("IP4.GATEWAY,IP4.ADDRESS"),
                               QStringLiteral("device"), QStringLiteral("show")});
    return show.trimmed();
}

/* ------------------------- Bluetooth ------------------------------ */

QVariantMap SystemService::bluetooth()
{
    QVariantMap bt;
    if (!has(QStringLiteral("bluetoothctl"))) {
        bt.insert(QStringLiteral("available"), false);
        // Las claves que consume la UI deben existir siempre: sin esto los
        // bindings `visible: state.powered` reciben undefined en equipos sin
        // bluetooth y QML emite "Unable to assign [undefined] to bool".
        bt.insert(QStringLiteral("powered"), false);
        bt.insert(QStringLiteral("devices"), QVariantList());
        return bt;
    }
    bt.insert(QStringLiteral("available"), true);
    const QString show = exec(QStringLiteral("bluetoothctl"), {QStringLiteral("show")});
    bt.insert(QStringLiteral("powered"), show.contains(QLatin1String("Powered: yes")));
    bt.insert(QStringLiteral("name"), QSysInfo::machineHostName());
    QVariantList devices;
    const QString list = exec(QStringLiteral("bluetoothctl"), {QStringLiteral("devices"), QStringLiteral("Paired")});
    for (const QString &line : list.split(QLatin1Char('\n'), Qt::SkipEmptyParts)) {
        if (!line.startsWith(QLatin1String("Device ")))
            continue;
        const QStringList f = line.split(QLatin1Char(' '));
        if (f.size() < 3)
            continue;
        const QString mac = f.value(1);
        const QString info = exec(QStringLiteral("bluetoothctl"), {QStringLiteral("info"), mac});
        QVariantMap dev;
        dev.insert(QStringLiteral("mac"), mac);
        dev.insert(QStringLiteral("name"), line.section(QLatin1Char(' '), 2));
        dev.insert(QStringLiteral("connected"), info.contains(QLatin1String("Connected: yes")));
        devices.append(dev);
    }
    bt.insert(QStringLiteral("devices"), devices);
    return bt;
}

bool SystemService::setBluetooth(bool enabled)
{
    exec(QStringLiteral("bluetoothctl"), {QStringLiteral("power"),
                                          enabled ? QStringLiteral("on") : QStringLiteral("off")});
    if (!m_lastError.isEmpty()) {
        emit actionFailed(m_lastError);
        return false;
    }
    return true;
}

static void bluetoothAsync(QObject *service, const QString &mac, const QString &command, const QString &tag)
{
    QProcess *process = new QProcess(service);
    process->start(QStringLiteral("bluetoothctl"), QStringList{command, mac});
    QObject::connect(process, &QProcess::finished, service,
                     [service, process, tag](int code, QProcess::ExitStatus) {
                         const QString out = QString::fromUtf8(process->readAllStandardOutput());
                         const QString err = QString::fromUtf8(process->readAllStandardError());
                         process->deleteLater();
                         QMetaObject::invokeMethod(service, "taskDone", Qt::DirectConnection,
                                                   Q_ARG(QString, tag), Q_ARG(bool, code == 0),
                                                   Q_ARG(QString, code == 0 ? out : (err.isEmpty() ? out : err)));
                     });
}

void SystemService::btConnect(const QString &mac)
{
    bluetoothAsync(this, mac, QStringLiteral("connect"), QStringLiteral("bt:%1").arg(mac));
}

void SystemService::btDisconnect(const QString &mac)
{
    bluetoothAsync(this, mac, QStringLiteral("disconnect"), QStringLiteral("bt:%1").arg(mac));
}

bool SystemService::btRemove(const QString &mac)
{
    exec(QStringLiteral("bluetoothctl"), {QStringLiteral("remove"), mac});
    return m_lastError.isEmpty();
}

/* -------------------------- Energía ------------------------------- */

QVariantMap SystemService::power()
{
    QVariantMap power;
    if (has(QStringLiteral("powerprofilesctl"))) {
        const QString profile = exec(QStringLiteral("powerprofilesctl"), {QStringLiteral("get")});
        power.insert(QStringLiteral("available"), true);
        power.insert(QStringLiteral("profile"), profile.trimmed());
    } else {
        power.insert(QStringLiteral("available"), false);
    }
    QDir batteryDir(QStringLiteral("/sys/class/power_supply"));
    QVariantMap battery;
    battery.insert(QStringLiteral("present"), false);
    for (const QString &entry : batteryDir.entryList(QDir::Dirs | QDir::NoDotAndDotDot)) {
        if (!entry.startsWith(QLatin1String("BAT")))
            continue;
        QFile capacity(batteryDir.filePath(entry + QStringLiteral("/capacity")));
        QFile status(batteryDir.filePath(entry + QStringLiteral("/status")));
        if (!capacity.open(QIODevice::ReadOnly))
            continue;
        battery.insert(QStringLiteral("present"), true);
        battery.insert(QStringLiteral("percent"), QString::fromUtf8(capacity.readAll()).trimmed().toInt());
        battery.insert(QStringLiteral("charging"),
                       status.open(QIODevice::ReadOnly)
                           && QString::fromUtf8(status.readAll()).trimmed() == QLatin1String("Charging"));
        break;
    }
    power.insert(QStringLiteral("battery"), battery);
    return power;
}

bool SystemService::setPowerProfile(const QString &profile)
{
    if (!has(QStringLiteral("powerprofilesctl"))) {
        emit actionFailed(QStringLiteral("power-profiles-daemon no está disponible"));
        return false;
    }
    exec(QStringLiteral("powerprofilesctl"), {QStringLiteral("set"), profile});
    if (!m_lastError.isEmpty()) {
        emit actionFailed(m_lastError);
        return false;
    }
    return true;
}

/* ----------------------- Almacenamiento --------------------------- */

QVariantMap SystemService::storage() const
{
    QStorageInfo root(QStringLiteral("/"));
    QVariantMap storage;
    storage.insert(QStringLiteral("totalGb"), static_cast<int>(root.bytesTotal() / (1024 * 1024 * 1024)));
    storage.insert(QStringLiteral("freeGb"), static_cast<int>(root.bytesFree() / (1024 * 1024 * 1024)));
    storage.insert(QStringLiteral("usedGb"), static_cast<int>((root.bytesTotal() - root.bytesFree()) / (1024 * 1024 * 1024)));
    storage.insert(QStringLiteral("device"), root.device());
    storage.insert(QStringLiteral("filesystem"), root.fileSystemType());
    return storage;
}

bool SystemService::emptyTrash()
{
    if (has(QStringLiteral("gio"))) {
        exec(QStringLiteral("gio"), {QStringLiteral("trash"), QStringLiteral("--empty")});
        return m_lastError.isEmpty();
    }
    m_lastError = QStringLiteral("No hay una herramienta para vaciar la papelera");
    return false;
}

/* --------------------- Aplicaciones ------------------------------- */

static QVariantMap parseDesktopFile(const QString &path)
{
    QVariantMap app;
    QFile f(path);
    if (!f.open(QIODevice::ReadOnly | QIODevice::Text))
        return app;
    QString name, comment, categories, icon, execLine;
    bool noDisplay = false, hidden = false, isApplication = false;
    while (!f.atEnd()) {
        const QString line = QString::fromUtf8(f.readLine()).trimmed();
        if (line.startsWith(QLatin1Char('[')) && line != QLatin1String("[Desktop Entry]"))
            break;
        if (line.startsWith(QLatin1String("Name=")))
            name = line.mid(5);
        else if (line.startsWith(QLatin1String("Comment=")))
            comment = line.mid(8);
        else if (line.startsWith(QLatin1String("Categories=")))
            categories = line.mid(11);
        else if (line.startsWith(QLatin1String("Icon=")))
            icon = line.mid(5);
        else if (line.startsWith(QLatin1String("Exec=")))
            execLine = line.mid(5);
        else if (line == QLatin1String("NoDisplay=true"))
            noDisplay = true;
        else if (line == QLatin1String("Hidden=true"))
            hidden = true;
        else if (line == QLatin1String("Type=Application"))
            isApplication = true;
    }
    if (!isApplication || noDisplay || hidden || execLine.isEmpty())
        return QVariantMap();
    app.insert(QStringLiteral("name"), name.isEmpty() ? QFileInfo(path).completeBaseName() : name);
    app.insert(QStringLiteral("desc"), comment);
    app.insert(QStringLiteral("categories"), categories);
    app.insert(QStringLiteral("icon"), icon);
    app.insert(QStringLiteral("desktop"), QFileInfo(path).fileName());
    return app;
}

QVariantList SystemService::installedApps() const
{
    QVariantList apps;
    QDir dir(QStringLiteral("/usr/share/applications"));
    for (const QString &f : dir.entryList(QStringList() << QStringLiteral("*.desktop"), QDir::Files, QDir::Name)) {
        QVariantMap app = parseDesktopFile(dir.filePath(f));
        if (!app.isEmpty())
            apps.append(app);
    }
    return apps;
}

static QString kindToMime(const QString &kind)
{
    if (kind == QLatin1String("browser")) return QStringLiteral("x-scheme-handler/http");
    if (kind == QLatin1String("fileManager")) return QStringLiteral("inode/directory");
    if (kind == QLatin1String("mail")) return QStringLiteral("x-scheme-handler/mailto");
    if (kind == QLatin1String("media")) return QStringLiteral("video/mp4");
    return QString();
}

static QStringList kindToCategories(const QString &kind)
{
    if (kind == QLatin1String("browser")) return {QStringLiteral("WebBrowser")};
    if (kind == QLatin1String("fileManager")) return {QStringLiteral("FileManager")};
    if (kind == QLatin1String("mail")) return {QStringLiteral("Email")};
    if (kind == QLatin1String("media")) return {QStringLiteral("Player"), QStringLiteral("AudioVideo")};
    return {};
}

QString SystemService::defaultApp(const QString &kind) const
{
    if (kind == QLatin1String("browser") && has(QStringLiteral("xdg-settings")))
        return exec(QStringLiteral("xdg-settings"), {QStringLiteral("get"), QStringLiteral("default-web-browser")});
    const QString mime = kindToMime(kind);
    if (mime.isEmpty() || !has(QStringLiteral("xdg-mime")))
        return QString();
    return exec(QStringLiteral("xdg-mime"), {QStringLiteral("query"), QStringLiteral("default"), mime});
}

QVariantList SystemService::defaultAppCandidates(const QString &kind) const
{
    QVariantList result;
    const QStringList wanted = kindToCategories(kind);
    QDir dir(QStringLiteral("/usr/share/applications"));
    for (const QString &f : dir.entryList(QStringList() << QStringLiteral("*.desktop"), QDir::Files, QDir::Name)) {
        const QVariantMap app = parseDesktopFile(dir.filePath(f));
        if (app.isEmpty())
            continue;
        const QStringList cats = app.value("categories").toString().split(QLatin1Char(';'));
        for (const QString &wantedCat : wanted) {
            if (cats.contains(wantedCat)) {
                QVariantMap entry;
                entry.insert(QStringLiteral("name"), app.value("name"));
                entry.insert(QStringLiteral("desktop"), app.value("desktop"));
                result.append(entry);
                break;
            }
        }
    }
    return result;
}

bool SystemService::setDefaultApp(const QString &kind, const QString &desktopFile)
{
    if (kind == QLatin1String("browser") && has(QStringLiteral("xdg-settings"))) {
        exec(QStringLiteral("xdg-settings"), {QStringLiteral("set"), QStringLiteral("default-web-browser"), desktopFile});
        return m_lastError.isEmpty();
    }
    const QString mime = kindToMime(kind);
    if (mime.isEmpty() || !has(QStringLiteral("xdg-mime"))) {
        m_lastError = QStringLiteral("xdg-mime no está disponible");
        return false;
    }
    exec(QStringLiteral("xdg-mime"), {QStringLiteral("default"), desktopFile, mime});
    return m_lastError.isEmpty();
}

/* ------------------------ Fecha y hora ---------------------------- */

QVariantMap SystemService::dateTime()
{
    QVariantMap dt;
    if (has(QStringLiteral("timedatectl"))) {
        const QString show = exec(QStringLiteral("timedatectl"), {QStringLiteral("show"),
                                                                  QStringLiteral("-p"), QStringLiteral("Timezone"),
                                                                  QStringLiteral("-p"), QStringLiteral("NTP")});
        for (const QString &line : show.split(QLatin1Char('\n'), Qt::SkipEmptyParts)) {
            if (line.startsWith(QLatin1String("Timezone=")))
                dt.insert(QStringLiteral("timezone"), line.mid(9));
            else if (line.startsWith(QLatin1String("NTP=")))
                dt.insert(QStringLiteral("ntp"), line.mid(4) == QLatin1String("yes"));
        }
        dt.insert(QStringLiteral("available"), true);
    } else {
        dt.insert(QStringLiteral("available"), false);
    }
    return dt;
}

bool SystemService::setNtp(bool enabled)
{
    exec(QStringLiteral("pkexec"), {QStringLiteral("timedatectl"), QStringLiteral("set-ntp"),
                                    enabled ? QStringLiteral("true") : QStringLiteral("false")}, 60000);
    if (!m_lastError.isEmpty()) {
        emit actionFailed(QStringLiteral("No se pudo cambiar la hora automática: ") + m_lastError);
        return false;
    }
    return true;
}

bool SystemService::setTimezone(const QString &tz)
{
    exec(QStringLiteral("pkexec"), {QStringLiteral("timedatectl"), QStringLiteral("set-timezone"), tz}, 60000);
    if (!m_lastError.isEmpty()) {
        emit actionFailed(QStringLiteral("No se pudo cambiar la zona horaria: ") + m_lastError);
        return false;
    }
    return true;
}

/* -------------------------- Usuario ------------------------------- */

QVariantMap SystemService::userInfo() const
{
    QVariantMap user;
    const QString name = qEnvironmentVariable("USER").isEmpty()
                             ? QString::fromLocal8Bit(getlogin())
                             : qEnvironmentVariable("USER");
    user.insert(QStringLiteral("name"), name);
    QString fullName;
    QFile passwd(QStringLiteral("/etc/passwd"));
    if (passwd.open(QIODevice::ReadOnly | QIODevice::Text)) {
        while (!passwd.atEnd()) {
            const QString line = QString::fromUtf8(passwd.readLine()).trimmed();
            const QStringList f = line.split(QLatin1Char(':'));
            if (f.value(0) == name) {
                fullName = f.value(4).section(QLatin1Char(','), 0, 0);
                break;
            }
        }
    }
    user.insert(QStringLiteral("fullName"), fullName.isEmpty() ? name : fullName);
    user.insert(QStringLiteral("home"), QDir::homePath());
    return user;
}

/* --------------------- Escritorio (kdeglobals) -------------------- */

bool SystemService::setSingleClick(bool single)
{
    return writeKey(QStringLiteral("kdeglobals"), QStringLiteral("KDE"), QStringLiteral("SingleClick"),
                    single ? QStringLiteral("false") : QStringLiteral("true"));
}

bool SystemService::singleClick() const
{
    // KDE: SingleClick=true significa "un clic abre". En el prototipo el
    // interruptor es "Doble clic para abrir", así que invertimos el valor.
    return readKey(configPath(QStringLiteral("kdeglobals")), QStringLiteral("KDE"),
                   QStringLiteral("SingleClick")) != QLatin1String("true");
}

bool SystemService::setRestoreSession(bool enabled)
{
    return writeKey(QStringLiteral("ksmserverrc"), QStringLiteral("General"),
                    QStringLiteral("loginMode"),
                    enabled ? QStringLiteral("restorePreviousLogout") : QStringLiteral("default"));
}

bool SystemService::restoreSession() const
{
    return readKey(configPath(QStringLiteral("ksmserverrc")), QStringLiteral("General"),
                   QStringLiteral("loginMode")) == QLatin1String("restorePreviousLogout");
}









