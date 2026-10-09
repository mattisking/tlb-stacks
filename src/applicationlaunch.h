#pragma once
#include <KService>
#include <KDesktopFile>
#include <KConfigGroup>
#include <KShell>

namespace ApplicationLaunch {
// Build a private, in-memory desktop entry. Never edit the installed file.
inline KService::Ptr withArguments(const KService::Ptr &original, const QStringList &arguments)
{
    if (arguments.isEmpty()) return original;
    KDesktopFile source(original->entryPath());
    KDesktopFile copy(QString{});
    source.KConfig::copyTo(QString{}, &copy);
    QString exec = original->exec();
    for (const auto &argument : arguments) {
        // KDE parses desktop field codes before launching. Literal percent signs
        // in user arguments must not become %u, %f, %k, etc.
        exec += QLatin1Char(' ') + KShell::quoteArg(QString(argument).replace("%", "%%"));
    }
    auto group = copy.desktopGroup();
    group.writeEntry("Exec", exec);
    group.writeEntry("DBusActivatable", false);
    copy.markAsClean();
    return KService::Ptr(new KService(&copy, original->entryPath()));
}
}
