#include "launcher.h"

#include <KIO/ApplicationLauncherJob>
#include <KService>

Launcher::Launcher(QObject *parent)
    : QObject(parent)
{
}

bool Launcher::exists(const QString &desktopId) const
{
    return KService::serviceByDesktopName(desktopId) != nullptr;
}

QString Launcher::name(const QString &desktopId) const
{
    const KService::Ptr service = KService::serviceByDesktopName(desktopId);

    if (!service) {
        return {};
    }

    return service->name();
}

QString Launcher::icon(const QString &desktopId) const
{
    const KService::Ptr service = KService::serviceByDesktopName(desktopId);

    if (!service) {
        return {};
    }

    return service->icon();
}

bool Launcher::launch(const QString &desktopId)
{
    const KService::Ptr service = KService::serviceByDesktopName(desktopId);

    if (!service) {
        return false;
    }

    auto *job = new KIO::ApplicationLauncherJob(service, this);
    job->start();

    return true;
}