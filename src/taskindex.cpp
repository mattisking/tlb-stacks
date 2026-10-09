#include "taskindex.h"

#include <QFileInfo>
#include <QIcon>
#include <QUrl>

namespace {
const QString DesktopSuffix = QStringLiteral(".desktop");
const QString DefaultIconName = QStringLiteral("application-x-executable");

QString withoutDesktopSuffix(QString id)
{
    if (id.endsWith(DesktopSuffix))
        id.chop(DesktopSuffix.size());
    return id;
}

// Accepts applications:<id>, file:// URLs and bare paths; empty when nothing usable remains.
QString desktopIdFromUrl(const QUrl &url)
{
    if (!url.isValid() || url.isEmpty())
        return {};
    return withoutDesktopSuffix(QFileInfo(url.path()).fileName());
}

struct RoleReader {
    const QAbstractItemModel *model;
    QHash<QByteArray, int> roles;

    explicit RoleReader(const QAbstractItemModel *m) : model(m)
    {
        const auto names = m->roleNames();
        for (auto it = names.cbegin(); it != names.cend(); ++it)
            roles.insert(it.value(), it.key());
    }
    QVariant value(const QModelIndex &index, const char *name) const
    {
        const auto role = roles.constFind(name);
        return role == roles.cend() ? QVariant() : model->data(index, role.value());
    }
    bool flag(const QModelIndex &index, const char *name) const { return value(index, name).toBool(); }
};

QString iconNameOf(const QVariant &icon)
{
    const QString name = icon.canConvert<QIcon>() ? icon.value<QIcon>().name() : icon.toString();
    return name.isEmpty() ? DefaultIconName : name;
}
}

TaskIndex::TaskIndex(QObject *parent) : QObject(parent) {}

void TaskIndex::setModel(QAbstractItemModel *model)
{
    if (m_model == model)
        return;
    if (m_model)
        m_model->disconnect(this);
    m_model = model;
    if (model) {
        connect(model, &QAbstractItemModel::rowsInserted, this, &TaskIndex::bumpRevision);
        connect(model, &QAbstractItemModel::rowsRemoved, this, &TaskIndex::bumpRevision);
        connect(model, &QAbstractItemModel::dataChanged, this, &TaskIndex::bumpRevision);
        connect(model, &QAbstractItemModel::modelReset, this, &TaskIndex::bumpRevision);
        connect(model, &QAbstractItemModel::layoutChanged, this, &TaskIndex::bumpRevision);
        connect(model, &QObject::destroyed, this, &TaskIndex::bumpRevision);
    }
    bumpRevision();
}

void TaskIndex::setDesktopIds(const QStringList &desktopIds)
{
    if (m_desktopIds == desktopIds)
        return;
    m_desktopIds = desktopIds;
    bumpRevision();
}

void TaskIndex::bumpRevision()
{
    ++m_revision;
    emit changed();
}

QVariantMap TaskIndex::taskState(const QString &desktopId) const
{
    bool running = false, active = false, allMinimized = true;
    int count = 0;
    QString iconName;

    if (m_model) {
        const RoleReader reader(m_model);
        const QString wanted = withoutDesktopSuffix(desktopId);
        for (int row = 0; row < m_model->rowCount(); ++row) {
            const QModelIndex index = m_model->index(row, 0);
            const bool isGroup = reader.flag(index, "IsGroupParent");
            if (!isGroup && !reader.flag(index, "isWindow"))
                continue;
            QString id = desktopIdFromUrl(reader.value(index, "LauncherUrl").toUrl());
            if (id.isEmpty())
                id = withoutDesktopSuffix(reader.value(index, "AppId").toString());
            if (id != wanted)
                continue;

            running = true;
            active = active || reader.flag(index, "isActive");
            allMinimized = allMinimized && reader.flag(index, "isMinimized");
            count += isGroup ? qMax(1, m_model->rowCount(index)) : 1;
            if (iconName.isEmpty())
                iconName = iconNameOf(reader.value(index, "icon"));
        }
    }

    return {{"running", running},
            {"active", active},
            {"minimized", running && allMinimized},
            {"count", count},
            {"iconName", iconName.isEmpty() ? DefaultIconName : iconName}};
}
