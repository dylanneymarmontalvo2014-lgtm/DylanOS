#include "processcontroller.h"

#include "coreapi.h"

#include <array>

ProcessController::ProcessController(QObject *parent)
    : QObject(parent)
{
}

namespace {
QString readBuffer(const std::array<char, 512> &buffer)
{
    return QString::fromUtf8(buffer.data());
}
}

bool ProcessController::terminateProcess(int pid)
{
    std::array<char, 512> buffer{};
    const int rc = dp_terminate(pid, 0, buffer.data(), buffer.size());
    if (rc == 0) {
        emit notice(QStringLiteral("Proceso finalizado (SIGTERM): %1").arg(pid), true);
        return true;
    }
    emit notice(readBuffer(buffer), false);
    return false;
}

bool ProcessController::forceTerminateProcess(int pid)
{
    std::array<char, 512> buffer{};
    const int rc = dp_terminate(pid, 1, buffer.data(), buffer.size());
    if (rc == 0) {
        emit notice(QStringLiteral("Proceso forzado a finalizar (SIGKILL): %1").arg(pid), true);
        return true;
    }
    emit notice(readBuffer(buffer), false);
    return false;
}

bool ProcessController::setPriority(int pid, int level)
{
    std::array<char, 512> buffer{};
    const int rc = dp_set_priority(pid, level, buffer.data(), buffer.size());
    if (rc == 0) {
        emit notice(QStringLiteral("Prioridad actualizada para el PID %1").arg(pid), true);
        return true;
    }
    emit notice(readBuffer(buffer), false);
    return false;
}

int ProcessController::priorityLevel(int nice) const
{
    return dp_priority_level(nice);
}

bool ProcessController::isAlive(int pid) const
{
    return dp_is_alive(pid) == 1;
}
