#pragma once
#include <QAbstractItemModel>
#include <QObject>
#include <QPointer>
#include <QStringList>
#include <QVariantList>
#include <QVariantMap>

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
    // {desktopId, name, icon, active, minimized, count} per unclaimed group/window row,
    // in model order; walks the model on every call.
    Q_INVOKABLE QVariantList unclaimedTasks() const;
    // Toggle-minimize the focused row, else activate the first visible window (the
    // first one when all are minimized); false when nothing matches, so the caller
    // falls back to launching.
    Q_INVOKABLE bool activate(const QString &desktopId);
    // Activate the row after the focused one (wrapping); otherwise like activate().
    Q_INVOKABLE bool cycle(const QString &desktopId);
    // Activate the row `direction` steps from the focused one (wrapping); the first
    // row when nothing is focused.
    Q_INVOKABLE void step(const QString &desktopId, int direction);
    // Request a new window of the app; false when nothing matches.
    Q_INVOKABLE bool newInstance(const QString &desktopId);
Q_SIGNALS:
    void changed();
private:
    void bumpRevision();
    QPointer<QAbstractItemModel> m_model;
    QStringList m_desktopIds;
    int m_revision = 0;
};
