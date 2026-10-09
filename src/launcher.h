#pragma once

#include <QObject>
#include <QString>
#include <QVariantList>
#include <QVariantMap>
#include <QUrl>
#include <QPoint>
#include <QPointer>
#include <memory>

class QQuickItem;
class FolderPopup;
class QMenu;
class QProcess;

class Launcher : public QObject
{
    Q_OBJECT
    Q_PROPERTY(bool profileBusy READ profileBusy NOTIFY profileBusyChanged)

public:
    explicit Launcher(QObject *parent = nullptr, bool watchApplications = true);

    ~Launcher() override;
    Q_INVOKABLE void showFolderMenu(QQuickItem *anchor, const QUrl &folder, const QStringList &filters, int hoverDelay, bool keyboard = false, bool preview = false);
    Q_INVOKABLE void closeFolderMenu();
    Q_INVOKABLE QPoint pointerPosition() const;

    Q_INVOKABLE void showApplicationContextMenu(QQuickItem *anchor, const QString &desktopId, bool removable = true, bool desktopActions = true, const QString &applicationId = {});
    Q_INVOKABLE void closeApplicationContextMenu();

    Q_INVOKABLE QVariantList applicationEntries(const QStringList &ids, const QVariantMap &icons, const QString &source, const QVariantMap &customLaunchers = {}) const;
    Q_INVOKABLE QVariantMap folderEntry(const QUrl &url) const;
    Q_INVOKABLE bool activateEntry(const QVariantMap &entry);
    Q_INVOKABLE void showEntryContextMenu(QQuickItem *anchor, const QVariantMap &entry);

    Q_INVOKABLE bool exists(const QString &desktopId) const;
    Q_INVOKABLE QString name(const QString &desktopId) const;
    Q_INVOKABLE QString icon(const QString &desktopId) const;
    Q_INVOKABLE bool themeIconAvailable(const QString &name) const;
    Q_INVOKABLE bool launch(const QString &desktopId, const QStringList &arguments = {});

    Q_INVOKABLE QVariantList applications() const;
    Q_INVOKABLE bool folderAvailable(const QUrl &url) const;
    Q_INVOKABLE QString fileIcon(const QUrl &url) const;
    Q_INVOKABLE bool openFile(const QUrl &url);

Q_SIGNALS:
    void applicationsChanged();
    void profileBusyChanged();
    void profileFinished(quint64 requestId, const QVariantMap &result);
    void folderDismissRequested();
    void folderNavigateRequested(int step);
    void folderKeyboardEntered();
    void folderFocusRequested(QQuickItem *anchor);
    void folderAnchorHighlightChanged(QQuickItem *anchor);
    void activationFailed(const QString &message);
    void removeApplicationRequested(const QString &desktopId);
    void fileOpenFailed(const QString &message);

public:
    Q_INVOKABLE quint64 profileOperation(const QString &action, const QVariantMap &request);
    bool profileBusy() const { return !m_profileProcess.isNull(); }
    Q_INVOKABLE void invalidateActivations() { ++m_activationGeneration; }
protected:
    bool eventFilter(QObject *watched, QEvent *event) override;
private:
    QPointer<QProcess> m_profileProcess;
    quint64 m_profileRequest = 0;
    quint64 m_activationGeneration = 0;
    bool m_enteredFolderPopup = false;
    bool m_closingFolderMenu = false;
    std::unique_ptr<QMenu> m_applicationContextMenu;
    QMetaObject::Connection m_contextAnchorDestroyed;
    std::unique_ptr<FolderPopup> m_folderPopup;
    QPointer<QQuickItem> m_folderAnchor;
    QMetaObject::Connection m_anchorDestroyed;
};