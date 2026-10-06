#pragma once
#include <QObject>
#include <QVariantList>
#include <QStringList>
#include <PlasmaActivities/Consumer>

// Read-only, on-demand snapshot. Never records usage or changes privacy settings.
class ActivitySource : public QObject {
    Q_OBJECT
    Q_PROPERTY(QVariantList entries READ entries NOTIFY changed)
    Q_PROPERTY(bool loading READ loading NOTIFY changed)
    Q_PROPERTY(QString message READ message NOTIFY changed)
public:
    explicit ActivitySource(QObject *parent = nullptr);
    QVariantList entries() const { return m_entries; }
    bool loading() const { return m_loading; }
    QString message() const { return m_message; }
    Q_INVOKABLE void refresh(bool frequent, int limit, const QStringList &categories, bool currentActivity);
Q_SIGNALS:
    void changed();
private:
    void start();
    KActivities::Consumer m_consumer;
    QVariantList m_entries;
    QString m_message;
    QStringList m_categories;
    bool m_frequent = false, m_current = false, m_loading = false, m_requested = false;
    int m_limit = 10;
    quint64 m_generation = 0;
};
