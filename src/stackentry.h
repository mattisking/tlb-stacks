#pragma once
#include <QVariantMap>
#include <QUrl>
#include <QFileInfo>
#include <QMimeDatabase>
#include <KService>
#include <KServiceAction>

namespace StackEntry {
// Source-owned capabilities: renderers must not infer actions from an icon/name.
inline QVariantMap make(const QString &id, const QString &name, const QString &icon,
                        const QString &source, const QString &action, const QString &target,
                        bool available, bool children, bool removable)
{
    return {{"id", id}, {"name", name}, {"icon", icon}, {"source", source},
            {"action", action}, {"target", target}, {"available", available},
            {"hasChildren", children}, {"isSeparator", false},
            {"actions", removable ? QStringList{"removeFromStack"} : QStringList{}}};
}
inline QVariantMap applicationData(const QString &id, const QString &source, const QString &overrideIcon,
                                   const KService::Ptr &service)
{
    const QString icon = !overrideIcon.isEmpty() ? overrideIcon
        : service && !service->icon().isEmpty() ? service->icon() : QStringLiteral("application-x-executable");
    auto entry = make(id, service ? service->name() : id, icon, source,
                "launchApplication", id, bool(service), false, source == "applications");
    QString description = service ? service->comment().trimmed() : QString();
    if (description.isEmpty() && service) description = service->genericName().trimmed();
    if (description == entry.value("name").toString()) description.clear();
    entry["description"] = description;
    if (service) {
        for (const auto &action : service->actions()) {
            if (!action.noDisplay() && !action.isSeparator()) {
                auto capabilities = entry.value("actions").toStringList();
                capabilities.append("desktopActions");
                entry["actions"] = capabilities;
                break;
            }
        }
    }
    return entry;
}
inline QVariantMap application(const QString &id, const QString &source, const QString &overrideIcon)
{
    return applicationData(id, source, overrideIcon, KService::serviceByDesktopName(id));
}
inline QVariantMap file(const QUrl &url)
{
    const QFileInfo info(url.toLocalFile());
    const bool directory = info.isDir();
    QString icon;
    if (directory) icon = QStringLiteral("folder");
    else if (info.suffix() == QStringLiteral("desktop")) {
        const KService service(info.absoluteFilePath());
        icon = service.icon();
    }
    if (icon.isEmpty()) icon = QMimeDatabase().mimeTypeForFile(info, QMimeDatabase::MatchExtension).iconName();
    auto entry = make(url.toString(), info.fileName(), icon, "folder",
                directory ? "openChildren" : "openFile", url.toString(),
                url.isLocalFile() && info.exists(), directory, false);
    if (!directory && entry.value("available").toBool()) entry["actions"] = QStringList{"moveToTrash"};
    return entry;
}
}
