#pragma once
#include <QAbstractItemModel>
#include <QObject>
#include <QPointer>
#include <QStringList>
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
Q_SIGNALS:
    void changed();
private:
    void bumpRevision();
    QPointer<QAbstractItemModel> m_model;
    QStringList m_desktopIds;
    int m_revision = 0;
};
