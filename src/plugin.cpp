#include "launcher.h"
#include "activitysource.h"
#include "foldersource.h"
#include "taskindex.h"

#include <QQmlExtensionPlugin>
#include <qqml.h>

class TLBStacksPlugin : public QQmlExtensionPlugin
{
    Q_OBJECT
    Q_PLUGIN_METADATA(IID QQmlExtensionInterface_iid)

public:
    void registerTypes(const char *uri) override
    {
        qmlRegisterType<FolderSource>(uri, 1, 0, "FolderSource");
        qmlRegisterType<ActivitySource>(uri, 1, 0, "ActivitySource");
        qmlRegisterType<Launcher>(uri, 1, 0, "Launcher");
        qmlRegisterType<TaskIndex>(uri, 1, 0, "TaskIndex");
    }
};

#include "plugin.moc"