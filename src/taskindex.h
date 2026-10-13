#pragma once
#include <QAbstractItemModel>
#include <QObject>
#include <QPointer>
#include <QStringList>
#include <QVariantList>
#include <QVariantMap>

// Queries accept desktop-file IDs or opaque taskKey values from unclaimedTasks.
// Matches desktop-file IDs against a tasks model (Plasma's TasksModel at runtime).
// Reads roles by name only, so it needs no taskmanager headers and works with any model.
class TaskIndex : public QObject {
    Q_OBJECT
    Q_PROPERTY(QAbstractItemModel *model READ model WRITE setModel NOTIFY changed)
    Q_PROPERTY(QStringList desktopIds READ desktopIds WRITE setDesktopIds NOTIFY changed)
    Q_PROPERTY(int revision READ revision NOTIFY changed)
public:
    explicit TaskIndex(QObject *parent = nullptr);
    QAbstractItemModel *model() const { return m_model; }
    QStringList desktopIds() const { return m_desktopIds; }
    int revision() const { return m_revision; }
    void setModel(QAbstractItemModel *model);
    void setDesktopIds(const QStringList &desktopIds);
    // {running, active, minimized, count, iconName}; walks the model on every call.
    Q_INVOKABLE QVariantMap taskState(const QString &desktopId) const;
    // {desktopId, taskKey, name, icon, active, minimized, count} per unclaimed group/window row,
    // in model order; walks the model on every call.
    Q_INVOKABLE QVariantList unclaimedTasks() const;
    // Toggle-minimize the focused window, else activate the most recently
    // activated visible one (the first when all are minimized); group-parent
    // rows drive their child windows — request* on a group parent is a no-op
    // upstream. False when nothing matches, so the caller falls back to
    // launching.
    Q_INVOKABLE bool activate(const QString &desktopId);
    // Activate the window after the focused one (wrapping); otherwise like
    // activate().
    Q_INVOKABLE bool cycle(const QString &desktopId);
    // Activate the window `direction` steps from the focused one (wrapping);
    // the first one when nothing is focused.
    Q_INVOKABLE void step(const QString &desktopId, int direction);
    // Request a new window of the app (group-parent rows pass through
    // upstream, unlike the other actions); false when nothing matches.
    Q_INVOKABLE bool newInstance(const QString &desktopId);
    // Politely close every window of the app. Unlike the activate family, the
    // matched row itself is the target: upstream's
    // TaskGroupingProxyModel::requestClose expands a group parent to its child
    // windows, so grouped apps are driven through the parent row and ungrouped
    // windows each get their own call. False when nothing matches.
    Q_INVOKABLE bool close(const QString &desktopId);
    // Per-window rows for the app, in model order, expanding group parents to
    // their child windows: {uuid, winId, title, minimized, active}, where the
    // platform fills exactly one of uuid (Wayland) / winId (X11).
    Q_INVOKABLE QVariantList windows(const QString &desktopId) const;
    // Activate / politely close exactly the window `id` names — a Wayland UUID
    // string or an X11 WId as a decimal string. False when no window matches.
    Q_INVOKABLE bool activateWindow(const QString &id);
    Q_INVOKABLE bool closeWindow(const QString &id);
Q_SIGNALS:
    void changed();
private:
    void bumpRevision();
    QPointer<QAbstractItemModel> m_model;
    QStringList m_desktopIds;
    int m_revision = 0;
};
