#include "taskindex.h"

#include <QFileInfo>
#include <QIcon>
#include <QMetaObject>
#include <QSet>
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

// One top-level row that represents an app's tasks: a group parent or a plain window.
// Launcher-only rows are not tasks. desktopId is normalized; empty when the row has none.
struct TaskRow {
    QModelIndex index;
    QString desktopId;
    QString name;  // "display" role
    QVariant icon; // "decoration" role value
    bool isGroup = false;
    bool active = false;
    bool minimized = false;
};

QList<TaskRow> taskRows(const QAbstractItemModel *model)
{
    QList<TaskRow> rows;
    if (!model)
        return rows;
    const RoleReader reader(model);
    for (int row = 0; row < model->rowCount(); ++row) {
        const QModelIndex index = model->index(row, 0);
        const bool isGroup = reader.flag(index, "IsGroupParent");
        if (!isGroup && !reader.flag(index, "IsWindow"))
            continue;
        QString id = desktopIdFromUrl(reader.value(index, "LauncherUrl").toUrl());
        if (id.isEmpty())
            id = withoutDesktopSuffix(reader.value(index, "AppId").toString());
        rows.append(TaskRow{index, id, reader.value(index, "display").toString(),
                             reader.value(index, "decoration"), isGroup,
                             reader.flag(index, "IsActive"), reader.flag(index, "IsMinimized")});
    }
    return rows;
}

QList<TaskRow> rowsMatching(const QAbstractItemModel *model, const QString &desktopId)
{
    const QString wanted = withoutDesktopSuffix(desktopId);
    QList<TaskRow> matched;
    for (const TaskRow &row : taskRows(model)) {
        if (row.desktopId == wanted)
            matched.append(row);
    }
    return matched;
}

// The tasks model exposes these actions as invokables; calling them by name keeps
// taskmanager headers out of the build.
void invokeTaskAction(QAbstractItemModel *model, const char *action, const QModelIndex &index)
{
    QMetaObject::invokeMethod(model, action, Q_ARG(QModelIndex, index));
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
    const QList<TaskRow> rows = rowsMatching(m_model, desktopId);

    bool active = false, allMinimized = true;
    int count = 0;
    QString iconName;
    for (const TaskRow &row : rows) {
        active = active || row.active;
        allMinimized = allMinimized && row.minimized;
        count += row.isGroup ? qMax(1, m_model->rowCount(row.index)) : 1;
        if (iconName.isEmpty())
            iconName = iconNameOf(row.icon);
    }

    return {{"running", !rows.isEmpty()},
            {"active", active},
            {"minimized", !rows.isEmpty() && allMinimized},
            {"count", count},
            {"iconName", iconName.isEmpty() ? DefaultIconName : iconName}};
}

QVariantList TaskIndex::unclaimedTasks() const
{
    QSet<QString> claimed;
    for (const QString &id : m_desktopIds)
        claimed.insert(withoutDesktopSuffix(id));

    QVariantList tasks;
    for (const TaskRow &row : taskRows(m_model)) {
        if (claimed.contains(row.desktopId))
            continue;
        tasks.append(QVariantMap{{"desktopId", row.desktopId},
                                 {"name", row.name},
                                 {"icon", iconNameOf(row.icon)},
                                 {"active", row.active},
                                 {"minimized", row.minimized},
                                 {"count", row.isGroup ? qMax(1, m_model->rowCount(row.index)) : 1}});
    }
    return tasks;
}

bool TaskIndex::activate(const QString &desktopId)
{
    const QList<TaskRow> rows = rowsMatching(m_model, desktopId);
    if (rows.isEmpty())
        return false; // not running: the caller falls back to launching

    for (const TaskRow &row : rows) {
        if (row.active) { // clicking the focused app minimizes it
            invokeTaskAction(m_model, "requestToggleMinimized", row.index);
            return true;
        }
    }

    const TaskRow *target = &rows.first();
    for (const TaskRow &row : rows) {
        if (!row.minimized) { // restore a visible window, or the first one
            target = &row;
            break;
        }
    }
    invokeTaskAction(m_model, "requestActivate", target->index);
    return true;
}

bool TaskIndex::cycle(const QString &desktopId)
{
    const QList<TaskRow> rows = rowsMatching(m_model, desktopId);
    if (rows.isEmpty())
        return false;

    for (int i = 0; i < rows.size(); ++i) {
        if (rows[i].active) {
            invokeTaskAction(m_model, "requestActivate", rows[(i + 1) % rows.size()].index);
            return true;
        }
    }
    return activate(desktopId); // nothing focused: same as a plain click
}

void TaskIndex::step(const QString &desktopId, int direction)
{
    const QList<TaskRow> rows = rowsMatching(m_model, desktopId);
    if (rows.isEmpty())
        return;

    int target = 0; // nothing focused: start at the first row
    for (int i = 0; i < rows.size(); ++i) {
        if (rows[i].active) {
            const int n = rows.size();
            target = ((i + direction) % n + n) % n; // wraps in both directions
            break;
        }
    }
    invokeTaskAction(m_model, "requestActivate", rows[target].index);
}

bool TaskIndex::newInstance(const QString &desktopId)
{
    const QList<TaskRow> rows = rowsMatching(m_model, desktopId);
    if (rows.isEmpty())
        return false;

    invokeTaskAction(m_model, "requestNewInstance", rows.first().index);
    return true;
}
