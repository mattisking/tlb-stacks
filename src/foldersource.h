#pragma once
#include <QObject>
#include <QUrl>
#include <QVariantList>
#include <QTimer>
#include <QPointer>

class FolderSource : public QObject {
    Q_OBJECT
    Q_PROPERTY(QUrl folder READ folder WRITE setFolder NOTIFY folderChanged)
    Q_PROPERTY(QStringList filters READ filters WRITE setFilters NOTIFY filtersChanged)
    Q_PROPERTY(bool active READ active WRITE setActive NOTIFY activeChanged)
    Q_PROPERTY(QVariantList entries READ entries NOTIFY entriesChanged)
    Q_PROPERTY(bool available READ available NOTIFY stateChanged)
    Q_PROPERTY(bool loading READ loading NOTIFY stateChanged)
    Q_PROPERTY(QString error READ error NOTIFY stateChanged)
public:
    explicit FolderSource(QObject *parent = nullptr);
    QUrl folder() const { return m_folder; }
    QStringList filters() const { return m_filters; }
    bool active() const { return m_active; }
    QVariantList entries() const { return m_entries; }
    bool available() const { return m_available; }
    bool loading() const { return m_loading; }
    QString error() const { return m_error; }
    void setFolder(const QUrl &value);
    void setFilters(const QStringList &value);
    void setActive(bool value);
signals:
    void folderChanged();
    void filtersChanged();
    void activeChanged();
    void entriesChanged();
    void stateChanged();
private:
    void reset();
    void refresh();
    QUrl m_folder;
    QStringList m_filters;
    QVariantList m_entries;
    bool m_active = false, m_available = false, m_loading = false;
    QString m_error;
    QTimer m_timer;
    QPointer<QObject> m_request;
};
