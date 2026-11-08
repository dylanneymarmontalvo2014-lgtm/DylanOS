#include "GamingService.h"

#include <QCoreApplication>
#include <QDBusConnection>
#include <QDBusInterface>
#include <QDBusReply>
#include <QDir>
#include <QFile>
#include <QFileInfo>
#include <QJsonArray>
#include <QJsonDocument>
#include <QStandardPaths>
#include <QStorageInfo>
#include <QSysInfo>
#include <QSaveFile>
#include <unistd.h>

namespace {

QString normalizeArch(const QString &arch)
{
    if (arch == QLatin1String("x86_64") || arch == QLatin1String("amd64"))
        return QStringLiteral("x86_64");
    if (arch == QLatin1String("arm64") || arch == QLatin1String("aarch64"))
        return QStringLiteral("aarch64");
    return arch;
}

QString pciVendorName(const QString &id)
{
    const QString hex = id.trimmed().toLower();
    if (hex == QLatin1String("0x1002") || hex == QLatin1String("1002"))
        return QStringLiteral("amd");
    if (hex == QLatin1String("0x10de") || hex == QLatin1String("10de"))
        return QStringLiteral("nvidia");
    if (hex == QLatin1String("0x8086") || hex == QLatin1String("8086"))
        return QStringLiteral("intel");
    return QStringLiteral("unknown");
}

} // namespace

GamingService::GamingService(QObject *parent, bool detectGraphics)
    : QObject(parent)
{
    m_apps = loadApps();
    m_hardware = probeHardware(detectGraphics);
    refreshInstalledFlatpaks();
    const QVariantMap backup = loadBackup();
    m_activeProfile = backup.value(QStringLiteral("activeProfile")).toString();

    connect(&m_process, &QProcess::readyReadStandardOutput, this, [this]() {
        const QString chunk = QString::fromUtf8(m_process.readAllStandardOutput());
        if (!chunk.trimmed().isEmpty())
            setProgress(m_progress, chunk.trimmed().section(QLatin1Char('\n'), -1));
    });
    connect(&m_process, &QProcess::readyReadStandardError, this, [this]() {
        const QString chunk = QString::fromUtf8(m_process.readAllStandardError());
        if (!chunk.trimmed().isEmpty())
            logLine(chunk.trimmed());
    });
    connect(&m_process, qOverload<int, QProcess::ExitStatus>(&QProcess::finished),
            this, [this](int code, QProcess::ExitStatus status) {
        const QString output = QString::fromUtf8(m_process.readAllStandardOutput()
                                                 + m_process.readAllStandardError());
        const bool ok = status == QProcess::NormalExit && code == 0;
        logLine(QStringLiteral("%1 terminó con código %2").arg(m_currentId).arg(code));
        if (!ok)
            setError(output.isEmpty() ? QStringLiteral("La instalación falló.") : output.trimmed());
        m_done += 1;
        const int pct = m_total > 0 ? int((m_done * 100.0) / m_total) : 100;
        setProgress(pct, ok ? QStringLiteral("Completado: %1").arg(m_currentId)
                            : QStringLiteral("Error: %1").arg(m_currentId));
        emit taskDone(m_currentId, ok, output);
        emit catalogChanged();
        startNext();
    });
    connect(&m_process, &QProcess::errorOccurred, this, [this](QProcess::ProcessError error) {
        if (error != QProcess::FailedToStart)
            return;
        const QString message = m_process.errorString();
        setError(message);
        ++m_done;
        const int pct = m_total > 0 ? int((m_done * 100.0) / m_total) : 100;
        setProgress(pct, QStringLiteral("No se pudo iniciar: %1").arg(m_currentId));
        emit taskDone(m_currentId, false, message);
        startNext();
    });
}

QString GamingService::dataRoot() const
{
    const QString env = qEnvironmentVariable("DYLANOS_GAMING_DATA");
    if (!env.isEmpty())
        return env;
    const QString staged = QStringLiteral("/usr/share/dylanos/gaming");
    if (QFile::exists(staged + QLatin1String("/catalog.json")))
        return staged;
    const QDir appDir(QCoreApplication::applicationDirPath());
    const QString source = QDir::cleanPath(appDir.absoluteFilePath(
        QStringLiteral("../../packages/gaming")));
    if (QFile::exists(source + QLatin1String("/catalog.json")))
        return source;
    return staged;
}

QString GamingService::homeDir() const
{
    const QString env = qEnvironmentVariable("HOME");
    return env.isEmpty() ? QDir::homePath() : env;
}

QString GamingService::stateDir() const
{
    const QString env = qEnvironmentVariable("DYLANOS_GAMING_STATE");
    if (!env.isEmpty())
        return env;
    return homeDir() + QStringLiteral("/.local/state/dylanos/gaming");
}

QString GamingService::configDir() const
{
    return homeDir() + QStringLiteral("/.config");
}

QJsonObject GamingService::loadJson(const QString &path) const
{
    QFile file(path);
    if (!file.open(QIODevice::ReadOnly | QIODevice::Text))
        return {};
    const QJsonDocument doc = QJsonDocument::fromJson(file.readAll());
    return doc.object();
}

QVector<GamingService::AppSpec> GamingService::loadApps() const
{
    QVector<AppSpec> apps;
    const QJsonObject root = loadJson(dataRoot() + QStringLiteral("/catalog.json"));
    const QJsonArray items = root.value(QStringLiteral("apps")).toArray();
    for (const QJsonValue &value : items) {
        const QJsonObject obj = value.toObject();
        AppSpec app;
        app.id = obj.value(QStringLiteral("id")).toString();
        app.name = obj.value(QStringLiteral("name")).toString();
        app.function = obj.value(QStringLiteral("function")).toString();
        app.method = obj.value(QStringLiteral("method")).toString();
        for (const QJsonValue &pkg : obj.value(QStringLiteral("packages")).toArray())
            app.packages.append(pkg.toString());
        app.flatpakId = obj.value(QStringLiteral("flatpak_id")).toString();
        app.remote = obj.value(QStringLiteral("remote")).toString();
        for (const QJsonValue &bin : obj.value(QStringLiteral("binaries")).toArray())
            app.binaries.append(bin.toString());
        for (const QJsonValue &arch : obj.value(QStringLiteral("arches")).toArray())
            app.arches.append(normalizeArch(arch.toString()));
        for (const QJsonValue &gpu : obj.value(QStringLiteral("gpu")).toArray())
            app.gpu.append(gpu.toString());
        for (const QJsonValue &flag : obj.value(QStringLiteral("cpu_flags")).toArray())
            app.cpuFlags.append(flag.toString().toLower());
        app.unavailableIn = obj.value(QStringLiteral("unavailable_in")).toString();
        app.unavailableReason = obj.value(QStringLiteral("unavailable_reason")).toString();
        app.notes = obj.value(QStringLiteral("notes")).toString();
        app.sizeMb = obj.value(QStringLiteral("size_mb")).toInt();
        app.minRamGb = obj.value(QStringLiteral("min_ram_gb")).toInt();
        app.iso = obj.value(QStringLiteral("iso")).toBool();
        app.recommended = obj.value(QStringLiteral("recommended")).toBool();
        app.needsI386 = obj.value(QStringLiteral("needs_i386")).toBool();
        app.requiresVulkan = obj.value(QStringLiteral("requires_vulkan")).toBool();
        if (!app.id.isEmpty())
            apps.append(app);
    }
    return apps;
}

GamingService::AppSpec GamingService::appById(const QString &id) const
{
    for (const AppSpec &app : m_apps) {
        if (app.id == id)
            return app;
    }
    return {};
}

QString GamingService::run(const QString &program, const QStringList &args, int timeoutMs) const
{
    if (!hasProgram(program))
        return {};
    QProcess process;
    process.start(program, args);
    if (!process.waitForFinished(timeoutMs)) {
        process.kill();
        process.waitForFinished(1000);
        return {};
    }
    return QString::fromUtf8(process.readAllStandardOutput() + process.readAllStandardError());
}

bool GamingService::hasProgram(const QString &program) const
{
    return !QStandardPaths::findExecutable(program).isEmpty();
}

QString GamingService::currentCpuArch() const
{
    return normalizeArch(QSysInfo::currentCpuArchitecture());
}

bool GamingService::appInstalled(const AppSpec &app) const
{
    for (const QString &bin : app.binaries) {
        if (hasProgram(bin))
            return true;
    }
    if (app.method == QLatin1String("flatpak") && m_installedFlatpaks.contains(app.flatpakId))
        return true;
    if (app.method == QLatin1String("apt") && !app.packages.isEmpty() && hasProgram(QStringLiteral("dpkg-query"))) {
        for (const QString &pkg : app.packages) {
            const QString status = run(QStringLiteral("dpkg-query"),
                                       {QStringLiteral("-W"), QStringLiteral("-f=${Status}"), pkg}, 3000);
            if (status.contains(QLatin1String("install ok installed")))
                return true;
        }
    }
    return false;
}

void GamingService::refreshInstalledFlatpaks()
{
    m_installedFlatpaks.clear();
    if (!hasProgram(QStringLiteral("flatpak")))
        return;
    QProcess process;
    process.start(QStringLiteral("flatpak"),
                  {QStringLiteral("list"), QStringLiteral("--app"),
                   QStringLiteral("--columns=application")});
    if (!process.waitForFinished(4000)) {
        process.kill();
        process.waitForFinished(1000);
        return;
    }
    if (process.exitCode() != 0)
        return;
    const QString output = QString::fromUtf8(process.readAllStandardOutput());
    for (const QString &id : output.split(QLatin1Char('\n'), Qt::SkipEmptyParts))
        m_installedFlatpaks.insert(id.trimmed());
}

bool GamingService::appCompatible(const AppSpec &app, QString *reason) const
{
    if (!app.unavailableIn.isEmpty()) {
        bool sourceAvailable = !app.binaries.isEmpty() && hasProgram(app.binaries.constFirst());
        if (!sourceAvailable && app.method == QLatin1String("apt") && !app.packages.isEmpty()) {
            const QString policy = run(QStringLiteral("apt-cache"),
                                       {QStringLiteral("policy"), app.packages.constFirst()}, 3000);
            sourceAvailable = policy.contains(QLatin1String("Candidate:"))
                && !policy.contains(QLatin1String("Candidate: (none)"));
        }
        if (!sourceAvailable) {
            if (reason)
                *reason = app.unavailableReason;
            return false;
        }
    }
    if (!app.arches.isEmpty() && !app.arches.contains(currentCpuArch())) {
        if (reason)
            *reason = QStringLiteral("No compatible con la arquitectura %1.").arg(currentCpuArch());
        return false;
    }
    const int ramMb = m_hardware.value(QStringLiteral("ramMb")).toInt();
    if (app.minRamGb > 0 && ramMb > 0 && ramMb < app.minRamGb * 1024) {
        if (reason)
            *reason = QStringLiteral("Se recomiendan al menos %1 GB de RAM.").arg(app.minRamGb);
        return false;
    }
    if (!app.gpu.isEmpty() && !app.gpu.contains(gpuVendor())) {
        if (reason)
            *reason = QStringLiteral("Requiere una GPU compatible: %1.").arg(app.gpu.join(QLatin1Char('/')).toUpper());
        return false;
    }
    if (app.requiresVulkan && !m_hardware.value(QStringLiteral("vulkan")).toBool()) {
        if (reason)
            *reason = QStringLiteral("No se detectó Vulkan, requisito de este emulador.");
        return false;
    }
    const QStringList cpuFlags = m_hardware.value(QStringLiteral("cpuFlags")).toStringList();
    for (const QString &flag : app.cpuFlags) {
        if (!cpuFlags.contains(flag)) {
            if (reason)
                *reason = QStringLiteral("La CPU no informa la instrucción %1 requerida.").arg(flag.toUpper());
            return false;
        }
    }
    return true;
}

QVariantMap GamingService::appToMap(const AppSpec &app) const
{
    QString reason;
    const bool compatible = appCompatible(app, &reason);
    const bool installed = appInstalled(app);
    const QString vendor = gpuVendor();
    QVariantMap map;
    map.insert(QStringLiteral("id"), app.id);
    map.insert(QStringLiteral("name"), app.name);
    map.insert(QStringLiteral("function"), app.function);
    map.insert(QStringLiteral("method"), app.method);
    map.insert(QStringLiteral("packages"), app.packages);
    map.insert(QStringLiteral("flatpakId"), app.flatpakId);
    map.insert(QStringLiteral("sizeMb"), app.sizeMb);
    map.insert(QStringLiteral("iso"), app.iso);
    map.insert(QStringLiteral("needsI386"), app.needsI386);
    map.insert(QStringLiteral("i386Enabled"), m_hardware.value(QStringLiteral("i386")));
    map.insert(QStringLiteral("requiresVulkan"), app.requiresVulkan);
    map.insert(QStringLiteral("recommended"), app.recommended && compatible);
    map.insert(QStringLiteral("installed"), installed);
    map.insert(QStringLiteral("compatible"), compatible);
    map.insert(QStringLiteral("reason"), reason);
    map.insert(QStringLiteral("notes"), app.notes);
    map.insert(QStringLiteral("unavailable"), !app.unavailableIn.isEmpty() && !compatible && !installed);
    if (!app.gpu.isEmpty() && !app.gpu.contains(vendor)) {
        map.insert(QStringLiteral("gpuHint"),
                   QStringLiteral("Optimizado para GPU %1; este equipo informa %2.")
                       .arg(app.gpu.join(QLatin1Char('/')), vendor));
    }
    QString status = QStringLiteral("disponible");
    if (installed)
        status = QStringLiteral("instalada");
    else if (!app.unavailableIn.isEmpty() && !compatible)
        status = QStringLiteral("no disponible");
    else if (!compatible)
        status = QStringLiteral("incompatible");
    map.insert(QStringLiteral("status"), status);
    return map;
}

QVariantList GamingService::catalog() const
{
    QVariantList list;
    for (const AppSpec &app : m_apps)
        list.append(appToMap(app));
    return list;
}

QVariantList GamingService::profiles() const
{
    static const QStringList ids = {
        QStringLiteral("balanced"), QStringLiteral("performance"),
        QStringLiteral("competitive"), QStringLiteral("streaming"),
        QStringLiteral("emulation")
    };
    QVariantList list;
    for (const QString &id : ids) {
        const QJsonObject obj = loadJson(dataRoot() + QStringLiteral("/profiles/%1.json").arg(id));
        if (obj.isEmpty())
            continue;
        QVariantMap map;
        map.insert(QStringLiteral("id"), obj.value(QStringLiteral("id")).toString());
        map.insert(QStringLiteral("name"), obj.value(QStringLiteral("name")).toString());
        map.insert(QStringLiteral("summary"), obj.value(QStringLiteral("summary")).toString());
        map.insert(QStringLiteral("active"), m_activeProfile == id);
        list.append(map);
    }
    return list;
}

QString GamingService::gpuVendor() const
{
    return m_hardware.value(QStringLiteral("gpuVendor")).toString();
}

QVariantMap GamingService::probeHardware(bool detectGraphics) const
{
    QVariantMap info;
    info.insert(QStringLiteral("arch"), currentCpuArch());
    info.insert(QStringLiteral("cpu"), QString());
    info.insert(QStringLiteral("cores"), int(sysconf(_SC_NPROCESSORS_ONLN)));

    qint64 memKb = 0;
    QFile mem(QStringLiteral("/proc/meminfo"));
    if (mem.open(QIODevice::ReadOnly | QIODevice::Text)) {
        const QString first = QString::fromUtf8(mem.readLine());
        memKb = first.section(QLatin1Char(':'), 1).simplified().split(QLatin1Char(' ')).value(0).toLongLong();
    }
    const int ramGb = memKb > 0 ? int((memKb / (1024.0 * 1024.0)) + 0.5) : 0;
    info.insert(QStringLiteral("ramGb"), ramGb);
    info.insert(QStringLiteral("ramMb"), memKb > 0 ? int(memKb / 1024) : 0);
    info.insert(QStringLiteral("memory"), ramGb > 0 ? QStringLiteral("%1 GB").arg(ramGb) : QStringLiteral("—"));

    QStringList cpuFlags;
    QFile cpuinfo(QStringLiteral("/proc/cpuinfo"));
    if (cpuinfo.open(QIODevice::ReadOnly | QIODevice::Text)) {
        while (!cpuinfo.atEnd()) {
            const QString line = QString::fromUtf8(cpuinfo.readLine());
            if (info.value(QStringLiteral("cpu")).toString().isEmpty()
                && (line.startsWith(QLatin1String("model name")) || line.startsWith(QLatin1String("Hardware")))) {
                const QString model = line.section(QLatin1Char(':'), 1).trimmed();
                if (!model.isEmpty())
                    info.insert(QStringLiteral("cpu"), model);
            }
            if (cpuFlags.isEmpty()
                && (line.startsWith(QLatin1String("flags")) || line.startsWith(QLatin1String("Features"))))
                cpuFlags = line.section(QLatin1Char(':'), 1).simplified().toLower().split(QLatin1Char(' '), Qt::SkipEmptyParts);
            if (!info.value(QStringLiteral("cpu")).toString().isEmpty() && !cpuFlags.isEmpty())
                break;
        }
    }
    if (info.value(QStringLiteral("cpu")).toString().isEmpty()) {
        const QString lscpu = run(QStringLiteral("lscpu"), {}, 3000);
        for (const QString &line : lscpu.split(QLatin1Char('\n'))) {
            if (line.startsWith(QLatin1String("Model name:")) || line.startsWith(QLatin1String("Model:"))) {
                const QString model = line.section(QLatin1Char(':'), 1).trimmed();
                if (!model.isEmpty()) {
                    info.insert(QStringLiteral("cpu"), model);
                    break;
                }
            }
        }
    }
    info.insert(QStringLiteral("cpuFlags"), cpuFlags);

    QString vendor = QStringLiteral("unknown");
    QString renderer;
    QString driver;
    const QDir drm(QStringLiteral("/sys/class/drm"));
    const QStringList cards = drm.entryList({QStringLiteral("card*")}, QDir::Dirs | QDir::NoSymLinks);
    for (const QString &card : cards) {
        if (card.contains(QLatin1Char('-')))
            continue;
        const QString vendorPath = drm.filePath(card + QStringLiteral("/device/vendor"));
        QFile vendorFile(vendorPath);
        if (vendorFile.open(QIODevice::ReadOnly | QIODevice::Text)) {
            vendor = pciVendorName(QString::fromUtf8(vendorFile.readAll()));
            if (vendor != QLatin1String("unknown")) {
                const QString driverLink = QFileInfo(drm.filePath(card + QStringLiteral("/device/driver"))).symLinkTarget();
                driver = QFileInfo(driverLink).fileName();
                QFile nameFile(drm.filePath(card + QStringLiteral("/device/uevent")));
                if (nameFile.open(QIODevice::ReadOnly | QIODevice::Text)) {
                    const QString uevent = QString::fromUtf8(nameFile.readAll());
                    for (const QString &line : uevent.split(QLatin1Char('\n'))) {
                        if (line.startsWith(QLatin1String("DRIVER=")))
                            driver = line.section(QLatin1Char('='), 1);
                    }
                }
                break;
            }
        }
    }
    const QString glx = detectGraphics
        ? run(QStringLiteral("glxinfo"), {QStringLiteral("-B")}, 2500) : QString();
    bool opengl = false;
    for (const QString &line : glx.split(QLatin1Char('\n'))) {
        if (line.startsWith(QLatin1String("OpenGL renderer string:"))) {
            renderer = line.section(QLatin1Char(':'), 1).trimmed();
            opengl = true;
        }
        if (line.contains(QLatin1String("OpenGL version string:")))
            opengl = true;
    }
    const QString vulkan = detectGraphics
        ? run(QStringLiteral("vulkaninfo"), {QStringLiteral("--summary")}, 3000) : QString();
    const bool hasVulkan = vulkan.contains(QLatin1String("GPU")) || vulkan.contains(QLatin1String("deviceName"));
    const bool dxvk = hasVulkan && vendor != QLatin1String("unknown");
    const bool vkd3d = hasVulkan && vendor != QLatin1String("unknown");

    QString acceleration = QStringLiteral("software");
    if (hasVulkan)
        acceleration = QStringLiteral("vulkan");
    else if (opengl)
        acceleration = QStringLiteral("opengl");

    const QStorageInfo storage = QStorageInfo::root();
    const qint64 freeGb = storage.bytesAvailable() / (1024LL * 1024LL * 1024LL);

    QString isoProfile;
    QFile profileFile(QStringLiteral("/etc/dylanos-profile"));
    if (profileFile.open(QIODevice::ReadOnly | QIODevice::Text))
        isoProfile = QString::fromUtf8(profileFile.readAll()).trimmed();

    const bool i386 = run(QStringLiteral("dpkg"), {QStringLiteral("--print-foreign-architectures")}, 3000)
                          .split(QLatin1Char('\n'))
                          .contains(QStringLiteral("i386"));

    QStringList recommendations;
    if (hasVulkan)
        recommendations << QStringLiteral("Vulkan detectado: DXVK/VKD3D pueden usarse con Proton/Wine.");
    else
        recommendations << QStringLiteral("Sin Vulkan: los juegos Direct3D vía Proton pueden no acelerar.");
    if (vendor == QLatin1String("amd"))
        recommendations << QStringLiteral("GPU AMD: CoreCtrl y el perfil Performance son aplicables.");
    else if (vendor == QLatin1String("nvidia"))
        recommendations << QStringLiteral("GPU NVIDIA: no se aplican parámetros AMD; el controlador no se sustituye.");
    else if (vendor == QLatin1String("intel"))
        recommendations << QStringLiteral("GPU Intel: se evitan ajustes exclusivos de AMD o NVIDIA.");
    if (memKb > 0 && memKb < 8 * 1024 * 1024)
        recommendations << QStringLiteral("RAM limitada: ZRAM es opcional; RPCS3 no se recomienda.");
    if (isoProfile == QLatin1String("gaming"))
        recommendations << QStringLiteral("La imagen se construyó con el perfil ISO gaming.");

    info.insert(QStringLiteral("gpuVendor"), vendor);
    info.insert(QStringLiteral("gpu"), renderer.isEmpty()
                    ? (vendor == QLatin1String("unknown") ? QStringLiteral("No detectada") : vendor.toUpper())
                    : renderer);
    info.insert(QStringLiteral("driver"), driver.isEmpty() ? QStringLiteral("—") : driver);
    info.insert(QStringLiteral("vulkan"), hasVulkan);
    info.insert(QStringLiteral("opengl"), opengl);
    info.insert(QStringLiteral("dxvkReady"), dxvk);
    info.insert(QStringLiteral("vkd3dReady"), vkd3d);
    info.insert(QStringLiteral("acceleration"), acceleration);
    info.insert(QStringLiteral("freeGb"), int(freeGb));
    info.insert(QStringLiteral("isoProfile"), isoProfile);
    info.insert(QStringLiteral("i386"), i386);
    info.insert(QStringLiteral("gamescope"), hasProgram(QStringLiteral("gamescope")));
    info.insert(QStringLiteral("gamemode"), hasProgram(QStringLiteral("gamemoderun")));
    info.insert(QStringLiteral("governorAvailable"),
                QFile::exists(QStringLiteral("/sys/devices/system/cpu/cpu0/cpufreq/scaling_governor")));
    info.insert(QStringLiteral("recommendations"), recommendations);
    return info;
}

QVariantMap GamingService::hardware() const
{
    return m_hardware;
}

QVariantMap GamingService::status() const
{
    QVariantMap map;
    map.insert(QStringLiteral("isoProfile"), m_hardware.value(QStringLiteral("isoProfile")));
    map.insert(QStringLiteral("gpuVendor"), m_hardware.value(QStringLiteral("gpuVendor")));
    map.insert(QStringLiteral("gpu"), m_hardware.value(QStringLiteral("gpu")));
    map.insert(QStringLiteral("gamemode"), m_hardware.value(QStringLiteral("gamemode")));
    map.insert(QStringLiteral("activeProfile"), m_activeProfile);
    map.insert(QStringLiteral("busy"), m_busy);
    map.insert(QStringLiteral("hasBackup"), loadBackup().value(QStringLiteral("captured")).toBool());
    int installed = 0;
    for (const AppSpec &app : m_apps) {
        if (appInstalled(app))
            installed += 1;
    }
    map.insert(QStringLiteral("installedCount"), installed);
    map.insert(QStringLiteral("catalogCount"), m_apps.size());
    return map;
}

int GamingService::approximateSizeMb(const QStringList &ids) const
{
    int total = 0;
    for (const QString &id : ids) {
        const AppSpec app = appById(id);
        if (!app.id.isEmpty())
            total += app.sizeMb;
    }
    return total;
}

void GamingService::refresh()
{
    m_apps = loadApps();
    m_hardware = probeHardware(true);
    refreshInstalledFlatpaks();
    emit catalogChanged();
    emit hardwareChanged();
}

void GamingService::setBusy(bool busy)
{
    if (m_busy == busy)
        return;
    m_busy = busy;
    emit busyChanged();
}

void GamingService::setProgress(int value, const QString &message)
{
    m_progress = qBound(0, value, 100);
    m_progressMessage = message;
    emit progressChanged();
}

void GamingService::setError(const QString &message)
{
    m_lastError = message;
    emit lastErrorChanged();
}

void GamingService::logLine(const QString &line) const
{
    QDir().mkpath(stateDir());
    QFile log(stateDir() + QStringLiteral("/gaming.log"));
    if (!log.open(QIODevice::WriteOnly | QIODevice::Append | QIODevice::Text))
        return;
    log.write(line.toUtf8());
    log.write("\n");
}

QString GamingService::helperPath() const
{
    const QString env = qEnvironmentVariable("DYLANOS_GAMING_HELPER");
    if (!env.isEmpty())
        return env;
    return QStringLiteral("/usr/lib/dylanos/dylanos-gaming-helper");
}

bool GamingService::runHelper(const QStringList &args, QString *output) const
{
    const QString helper = helperPath();
    if (!QFileInfo::exists(helper)) {
        if (output)
            *output = QStringLiteral("El ayudante privilegiado no está instalado.");
        return false;
    }
    QStringList command;
    QString program = helper;
    if (qEnvironmentVariableIntValue("DYLANOS_GAMING_SKIP_PRIVILEGED")) {
        if (output)
            *output = QStringLiteral("Ajuste privilegiado omitido en esta sesión.");
        return true;
    }
    if (hasProgram(QStringLiteral("pkexec")) && qEnvironmentVariable("DYLANOS_GAMING_SYSFS").isEmpty()) {
        program = QStringLiteral("pkexec");
        command << helper;
    }
    command << args;
    QProcess process;
    process.start(program, command);
    if (!process.waitForFinished(20000)) {
        process.kill();
        if (output)
            *output = QStringLiteral("Tiempo de espera agotado.");
        return false;
    }
    const QString text = QString::fromUtf8(process.readAllStandardOutput() + process.readAllStandardError());
    if (output)
        *output = text;
    return process.exitCode() == 0;
}

QVariantMap GamingService::loadBackup() const
{
    const QJsonObject obj = loadJson(stateDir() + QStringLiteral("/backup.json"));
    return obj.toVariantMap();
}

bool GamingService::saveBackup(const QVariantMap &backup) const
{
    QDir().mkpath(stateDir());
    QSaveFile file(stateDir() + QStringLiteral("/backup.json"));
    if (!file.open(QIODevice::WriteOnly | QIODevice::Text))
        return false;
    file.write(QJsonDocument::fromVariant(backup).toJson(QJsonDocument::Indented));
    return file.commit();
}

bool GamingService::writeText(const QString &path, const QString &text) const
{
    QFileInfo info(path);
    QDir().mkpath(info.absolutePath());
    QSaveFile file(path);
    if (!file.open(QIODevice::WriteOnly | QIODevice::Text))
        return false;
    file.write(text.toUtf8());
    if (!text.endsWith(QLatin1Char('\n')))
        file.write("\n");
    return file.commit();
}

QString GamingService::readText(const QString &path) const
{
    QFile file(path);
    if (!file.open(QIODevice::ReadOnly | QIODevice::Text))
        return {};
    return QString::fromUtf8(file.readAll());
}

void GamingService::inhibitNotifications(bool enable)
{
    QDBusInterface iface(QStringLiteral("org.freedesktop.Notifications"),
                         QStringLiteral("/org/freedesktop/Notifications"),
                         QStringLiteral("org.freedesktop.Notifications"),
                         QDBusConnection::sessionBus());
    if (!iface.isValid())
        return;
    if (enable && !m_inhibitActive) {
        const QDBusReply<uint> reply = iface.call(QStringLiteral("Inhibit"),
                                                  QStringLiteral("DylanOS Gaming"),
                                                  QStringLiteral("Sesión de juego"),
                                                  QVariantMap());
        if (reply.isValid()) {
            m_inhibitCookie = reply.value();
            m_inhibitActive = true;
        }
        return;
    }
    if (!enable && m_inhibitActive) {
        iface.call(QStringLiteral("UnInhibit"), m_inhibitCookie);
        m_inhibitActive = false;
        m_inhibitCookie = 0;
    }
}

bool GamingService::applyPowerProfile(const QString &profile)
{
    if (profile.isEmpty() || !hasProgram(QStringLiteral("powerprofilesctl")))
        return true;
    const QStringList allowed = {QStringLiteral("power-saver"), QStringLiteral("balanced"),
                                 QStringLiteral("performance")};
    if (!allowed.contains(profile))
        return false;
    QProcess process;
    process.start(QStringLiteral("powerprofilesctl"), {QStringLiteral("set"), profile});
    return process.waitForFinished(5000) && process.exitCode() == 0;
}

bool GamingService::enqueue(const QStringList &ids, bool uninstall, bool update)
{
    if (m_busy) {
        setError(QStringLiteral("Ya hay una operación en curso."));
        return false;
    }
    QStringList pending;
    for (const QString &id : ids) {
        const AppSpec app = appById(id);
        if (app.id.isEmpty()) {
            setError(QStringLiteral("Aplicación desconocida: %1").arg(id));
            return false;
        }
        QString reason;
        if (!uninstall && !update && !appCompatible(app, &reason)) {
            setError(QStringLiteral("%1: %2").arg(app.name, reason));
            continue;
        }
        if (update && !appInstalled(app)) {
            setError(QStringLiteral("%1 no está instalada.").arg(app.name));
            return false;
        }
        if (!app.remote.isEmpty() && app.remote != QLatin1String("flathub")) {
            setError(QStringLiteral("Solo se permite el remoto Flathub."));
            return false;
        }
        pending.append(id);
    }
    if (pending.isEmpty()) {
        setError(QStringLiteral("No hay aplicaciones compatibles para instalar."));
        return false;
    }
    m_queue = pending;
    m_uninstall = uninstall;
    m_update = update;
    m_total = pending.size();
    m_done = 0;
    m_lastError.clear();
    emit lastErrorChanged();
    setBusy(true);
    setProgress(1, uninstall ? QStringLiteral("Desinstalando…") : QStringLiteral("Instalando…"));
    startNext();
    return true;
}

void GamingService::startNext()
{
    if (m_queue.isEmpty()) {
        setBusy(false);
        setProgress(100, QStringLiteral("Operación terminada"));
        m_apps = loadApps();
        refreshInstalledFlatpaks();
        emit catalogChanged();
        return;
    }
    m_currentId = m_queue.takeFirst();
    const AppSpec app = appById(m_currentId);
    const bool ok = m_uninstall ? startUninstall(app)
                                : m_update ? startUpdate(app) : startInstall(app);
    if (!ok) {
        ++m_done;
        const int pct = m_total > 0 ? int((m_done * 100.0) / m_total) : 100;
        setProgress(pct, QStringLiteral("Error: %1").arg(m_currentId));
        emit taskDone(m_currentId, false, m_lastError);
        startNext();
    }
}

bool GamingService::startInstall(const AppSpec &app)
{
    logLine(QStringLiteral("Instalar %1 (%2)").arg(app.id, app.method));
    if (app.method == QLatin1String("apt")) {
        if (app.needsI386 && !m_hardware.value(QStringLiteral("i386")).toBool()) {
            QString helperOut;
            if (!runHelper({QStringLiteral("enable-i386")}, &helperOut)) {
                setError(QStringLiteral("No se pudo habilitar la arquitectura i386 requerida: %1")
                             .arg(helperOut.trimmed()));
                emit taskDone(app.id, false, m_lastError);
                return false;
            }
            m_hardware.insert(QStringLiteral("i386"), true);
            emit hardwareChanged();
        }
        if (!hasProgram(QStringLiteral("pkcon"))) {
            setError(QStringLiteral("Falta pkcon (packagekit-tools)."));
            return false;
        }
        QStringList args = {QStringLiteral("--noninteractive"), QStringLiteral("install")};
        args.append(app.packages);
        m_process.start(QStringLiteral("pkcon"), args);
        return true;
    }
    if (app.method == QLatin1String("flatpak")) {
        if (!hasProgram(QStringLiteral("flatpak"))) {
            setError(QStringLiteral("Falta flatpak."));
            return false;
        }
        QProcess addRemote;
        addRemote.start(QStringLiteral("flatpak"), {
            QStringLiteral("remote-add"), QStringLiteral("--if-not-exists"),
            QStringLiteral("--user"), QStringLiteral("flathub"),
            QStringLiteral("https://dl.flathub.org/repo/flathub.flatpakrepo")
        });
        if (!addRemote.waitForFinished(30000) || addRemote.exitCode() != 0) {
            setError(QStringLiteral("No se pudo preparar el remoto oficial de Flathub: %1")
                         .arg(QString::fromUtf8(addRemote.readAllStandardError()).trimmed()));
            return false;
        }
        m_process.start(QStringLiteral("flatpak"),
                        {QStringLiteral("install"), QStringLiteral("-y"), QStringLiteral("--user"),
                         QStringLiteral("flathub"), app.flatpakId});
        return true;
    }
    setError(QStringLiteral("Método de instalación no soportado."));
    return false;
}

bool GamingService::startUninstall(const AppSpec &app)
{
    logLine(QStringLiteral("Desinstalar %1").arg(app.id));
    if (app.method == QLatin1String("apt")) {
        if (!hasProgram(QStringLiteral("pkcon"))) {
            setError(QStringLiteral("Falta pkcon (packagekit-tools)."));
            return false;
        }
        QStringList args = {QStringLiteral("--noninteractive"), QStringLiteral("remove")};
        args.append(app.packages);
        m_process.start(QStringLiteral("pkcon"), args);
        return true;
    }
    if (app.method == QLatin1String("flatpak")) {
        m_process.start(QStringLiteral("flatpak"),
                        {QStringLiteral("uninstall"), QStringLiteral("-y"), QStringLiteral("--user"),
                         app.flatpakId});
        return true;
    }
    return false;
}

bool GamingService::startUpdate(const AppSpec &app)
{
    logLine(QStringLiteral("Actualizar %1").arg(app.id));
    if (app.method == QLatin1String("apt")) {
        if (!hasProgram(QStringLiteral("pkcon"))) {
            setError(QStringLiteral("Falta pkcon (packagekit-tools)."));
            return false;
        }
        QStringList args = {QStringLiteral("--noninteractive"), QStringLiteral("update")};
        args.append(app.packages);
        m_process.start(QStringLiteral("pkcon"), args);
        return true;
    }
    if (app.method == QLatin1String("flatpak")) {
        if (!hasProgram(QStringLiteral("flatpak"))) {
            setError(QStringLiteral("Falta flatpak."));
            return false;
        }
        m_process.start(QStringLiteral("flatpak"),
                        {QStringLiteral("update"), QStringLiteral("-y"), QStringLiteral("--user"),
                         app.flatpakId});
        return true;
    }
    setError(QStringLiteral("Método de actualización no soportado."));
    return false;
}

bool GamingService::installApp(const QString &id)
{
    return enqueue({id}, false);
}

bool GamingService::uninstallApp(const QString &id)
{
    return enqueue({id}, true);
}

bool GamingService::updateApp(const QString &id)
{
    return enqueue({id}, false, true);
}

bool GamingService::installSelection(const QStringList &ids)
{
    return enqueue(ids, false);
}

bool GamingService::installRecommended()
{
    QStringList ids;
    for (const AppSpec &app : m_apps) {
        QString reason;
        if (app.recommended && appCompatible(app, &reason) && !appInstalled(app))
            ids.append(app.id);
    }
    return enqueue(ids, false);
}

void GamingService::cancelTask()
{
    if (m_process.state() != QProcess::NotRunning)
        m_process.kill();
    m_queue.clear();
    setBusy(false);
    setProgress(0, QStringLiteral("Cancelado"));
}

bool GamingService::applyProfile(const QString &id)
{
    static const QStringList allowedProfiles = {
        QStringLiteral("balanced"), QStringLiteral("performance"),
        QStringLiteral("competitive"), QStringLiteral("streaming"),
        QStringLiteral("emulation")
    };
    if (!allowedProfiles.contains(id)) {
        setError(QStringLiteral("Perfil desconocido."));
        return false;
    }
    const QJsonObject obj = loadJson(dataRoot() + QStringLiteral("/profiles/%1.json").arg(id));
    if (obj.isEmpty()) {
        setError(QStringLiteral("Perfil desconocido."));
        return false;
    }

    QVariantMap backup = loadBackup();
    if (!backup.value(QStringLiteral("captured")).toBool()) {
        const QString envPath = configDir() + QStringLiteral("/environment.d/90-dylanos-gaming.conf");
        const QString mangoPath = configDir() + QStringLiteral("/MangoHud/MangoHud.conf");
        const QString obsPath = configDir() + QStringLiteral("/obs-studio/basic/profiles/DylanOSStreaming/basic.ini");
        backup.insert(QStringLiteral("captured"), true);
        backup.insert(QStringLiteral("envExisted"), QFile::exists(envPath));
        backup.insert(QStringLiteral("env"), readText(envPath));
        backup.insert(QStringLiteral("mangoExisted"), QFile::exists(mangoPath));
        backup.insert(QStringLiteral("mango"), readText(mangoPath));
        backup.insert(QStringLiteral("obsExisted"), QFile::exists(obsPath));
        backup.insert(QStringLiteral("obs"), readText(obsPath));
        if (hasProgram(QStringLiteral("powerprofilesctl"))) {
            const QString current = run(QStringLiteral("powerprofilesctl"), {QStringLiteral("get")}, 4000).trimmed();
            backup.insert(QStringLiteral("power"), current);
        }
        QVariantMap governors;
        const QDir cpus(QStringLiteral("/sys/devices/system/cpu"));
        const QStringList entries = cpus.entryList({QStringLiteral("cpu[0-9]*")}, QDir::Dirs);
        for (const QString &cpu : entries) {
            const QString path = cpus.filePath(cpu + QStringLiteral("/cpufreq/scaling_governor"));
            if (QFile::exists(path))
                governors.insert(path, readText(path).trimmed());
        }
        backup.insert(QStringLiteral("governors"), governors);
        if (!saveBackup(backup)) {
            setError(QStringLiteral("No se pudo guardar el respaldo de Gaming."));
            return false;
        }
    }

    QString env;
    const QJsonObject envObj = obj.value(QStringLiteral("env")).toObject();
    for (const QString &key : envObj.keys()) {
        const QString value = envObj.value(key).toString();
        if (!value.isEmpty())
            env += key + QLatin1Char('=') + value + QLatin1Char('\n');
    }
    const QString vendor = gpuVendor();
    const QJsonObject gpuEnv = obj.value(QStringLiteral("gpu_env")).toObject().value(vendor).toObject();
    for (const QString &key : gpuEnv.keys()) {
        const QString value = gpuEnv.value(key).toString();
        if (!value.isEmpty())
            env += key + QLatin1Char('=') + value + QLatin1Char('\n');
    }
    env += QStringLiteral("# DylanOS Gaming perfil %1\n").arg(id);
    if (!writeText(configDir() + QStringLiteral("/environment.d/90-dylanos-gaming.conf"), env)) {
        setError(QStringLiteral("No se pudo escribir environment.d."));
        return false;
    }

    const QString preset = obj.value(QStringLiteral("mangohud_preset")).toString();
    const QString mangoSrc = dataRoot() + QStringLiteral("/overlay/mangohud/%1.conf").arg(preset);
    if (QFile::exists(mangoSrc)) {
        if (!writeText(configDir() + QStringLiteral("/MangoHud/MangoHud.conf"), readText(mangoSrc))) {
            setError(QStringLiteral("No se pudo escribir MangoHud.conf."));
            return false;
        }
    }

    if (id == QLatin1String("streaming")) {
        const QString obsSrc = dataRoot() + QStringLiteral("/overlay/obs/basic.ini");
        const QString obsDest = configDir() + QStringLiteral("/obs-studio/basic/profiles/DylanOSStreaming/basic.ini");
        if (QFile::exists(obsSrc) && !QFile::exists(obsDest))
            writeText(obsDest, readText(obsSrc));
    }

    if (!applyPowerProfile(obj.value(QStringLiteral("power_profile")).toString())) {
        setError(QStringLiteral("No se pudo cambiar el perfil de energía. Revisa power-profiles-daemon."));
        return false;
    }
    inhibitNotifications(obj.value(QStringLiteral("notifications_inhibit")).toBool());

    QString governor = obj.value(QStringLiteral("governor")).toString();
    if (governor.isEmpty()) {
        const QVariantMap originals = backup.value(QStringLiteral("governors")).toMap();
        QStringList originalValues;
        for (auto it = originals.cbegin(); it != originals.cend(); ++it) {
            if (readText(it.key()).trimmed() != it.value().toString())
                originalValues << it.key() + QLatin1Char('=') + it.value().toString();
        }
        QString helperOut;
        if (!originalValues.isEmpty()
            && !runHelper({QStringLiteral("restore-governor"), originalValues.join(QLatin1Char(';'))}, &helperOut))
            logLine(QStringLiteral("No se pudo devolver el governor al valor original: %1").arg(helperOut));
    }
    if (!governor.isEmpty() && m_hardware.value(QStringLiteral("governorAvailable")).toBool()) {
        const QString current = readText(QStringLiteral("/sys/devices/system/cpu/cpu0/cpufreq/scaling_governor")).trimmed();
        if (current != governor) {
            QString helperOut;
            if (!runHelper({QStringLiteral("set-governor"), governor}, &helperOut))
                logLine(QStringLiteral("Governor no aplicado: %1").arg(helperOut));
        }
    }

    backup.insert(QStringLiteral("activeProfile"), id);
    if (!saveBackup(backup)) {
        setError(QStringLiteral("No se pudo guardar el estado activo del perfil."));
        return false;
    }
    m_activeProfile = id;
    logLine(QStringLiteral("Perfil aplicado: %1").arg(id));
    emit profileChanged();
    return true;
}

bool GamingService::restoreProfile()
{
    const QVariantMap backup = loadBackup();
    if (!backup.value(QStringLiteral("captured")).toBool()) {
        setError(QStringLiteral("No hay un respaldo que restaurar."));
        return false;
    }
    const QString envPath = configDir() + QStringLiteral("/environment.d/90-dylanos-gaming.conf");
    const QString mangoPath = configDir() + QStringLiteral("/MangoHud/MangoHud.conf");
    const QString obsPath = configDir() + QStringLiteral("/obs-studio/basic/profiles/DylanOSStreaming/basic.ini");
    bool restored = true;
    if (backup.value(QStringLiteral("envExisted")).toBool())
        restored = writeText(envPath, backup.value(QStringLiteral("env")).toString()) && restored;
    else
        restored = (QFile::remove(envPath) || !QFile::exists(envPath)) && restored;
    if (backup.value(QStringLiteral("mangoExisted")).toBool())
        restored = writeText(mangoPath, backup.value(QStringLiteral("mango")).toString()) && restored;
    else
        restored = (QFile::remove(mangoPath) || !QFile::exists(mangoPath)) && restored;
    if (backup.value(QStringLiteral("obsExisted")).toBool())
        restored = writeText(obsPath, backup.value(QStringLiteral("obs")).toString()) && restored;
    else {
        restored = (QFile::remove(obsPath) || !QFile::exists(obsPath)) && restored;
        QDir().rmdir(QFileInfo(obsPath).absolutePath());
    }

    const QString power = backup.value(QStringLiteral("power")).toString();
    if (!power.isEmpty())
        restored = applyPowerProfile(power) && restored;

    const QVariantMap governors = backup.value(QStringLiteral("governors")).toMap();
    if (!governors.isEmpty()) {
        QStringList originals;
        for (auto it = governors.cbegin(); it != governors.cend(); ++it) {
            if (readText(it.key()).trimmed() != it.value().toString())
                originals << it.key() + QLatin1Char('=') + it.value().toString();
        }
        if (!originals.isEmpty()) {
            QString helperOut;
            restored = runHelper({QStringLiteral("restore-governor"), originals.join(QLatin1Char(';'))}, &helperOut)
                       && restored;
            if (!helperOut.isEmpty())
                logLine(QStringLiteral("Restauración del governor: %1").arg(helperOut.trimmed()));
        }
    }
    if (!restored) {
        setError(QStringLiteral("No se pudieron restaurar todos los ajustes. El respaldo se conserva para reintentar."));
        return false;
    }
    inhibitNotifications(false);

    QVariantMap cleared;
    if (!saveBackup(cleared)) {
        setError(QStringLiteral("Se restauraron los ajustes, pero no se pudo limpiar el respaldo."));
        return false;
    }
    m_activeProfile.clear();
    logLine(QStringLiteral("Perfil restaurado al estado anterior."));
    emit profileChanged();
    return true;
}
