#include "launcher.h"
#include "foldersource.h"

#include <QQmlExtensionPlugin>
#include <qqml.h>

class TrueLaunchBarPlugin : public QQmlExtensionPlugin
{
    Q_OBJECT
    Q_PLUGIN_METADATA(IID QQmlExtensionInterface_iid)

public:
    void registerTypes(const char *uri) override
    {
        qmlRegisterType<FolderSource>(uri, 1, 0, "FolderSource");
        qmlRegisterType<Launcher>(uri, 1, 0, "Launcher");
    }
};

#include "plugin.moc"