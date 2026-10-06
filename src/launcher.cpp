#include "launcher.h"
#include "stackentry.h"
#include "folderpopup.h"
#include <QApplication>
#include <QQuickItem>
#include <QQuickWindow>
#include <QMouseEvent>
#include <QCursor>
#include <QKeyEvent>

#include <KIO/ApplicationLauncherJob>
#include <KServiceAction>
#include <KService>
#include <KSycoca>
#include <KIO/OpenUrlJob>
#include <KIO/CopyJob>
#include <QScopedValueRollback>
#include <QFileInfo>
#include <QMimeDatabase>
#include <QVariantMap>
#include <algorithm>
#include <QJsonDocument>
#include <QJsonObject>
#include <QProcess>
#include <QTimer>
#include <QStandardPaths>

Launcher::Launcher(QObject *parent, bool watchApplications)
    : QObject(parent)
{
    QCoreApplication::instance()->installEventFilter(this);
    connect(this, &Launcher::fileOpenFailed, this, &Launcher::activationFailed);
    if (watchApplications) connect(KSycoca::self(), &KSycoca::databaseChanged, this, &Launcher::applicationsChanged);
}

bool Launcher::exists(const QString &desktopId) const
{
    return KService::serviceByDesktopName(desktopId) != nullptr;
}

QString Launcher::name(const QString &desktopId) const
{
    const KService::Ptr service = KService::serviceByDesktopName(desktopId);

    if (!service) {
        return {};
    }

    return service->name();
}

QString Launcher::icon(const QString &desktopId) const
{
    const KService::Ptr service = KService::serviceByDesktopName(desktopId);

    if (!service) {
        return {};
    }

    return service->icon();
}

QVariantList Launcher::applications() const
{
    QVariantList result;

    const KService::List services = KService::allServices();

    for (const KService::Ptr &service : services) {
        if (!service || service->noDisplay() || !service->showInCurrentDesktop()) {
            continue;
        }

        const QString desktopId = service->desktopEntryName();

        if (desktopId.isEmpty() || service->name().isEmpty()) {
            continue;
        }

        QVariantMap app;
        app["desktopId"] = desktopId;
        app["name"] = service->name();
        app["icon"] = service->icon();
        app["categories"] = service->categories();

        result.append(app);
    }

    std::sort(
        result.begin(),
        result.end(),
        [](const QVariant &left, const QVariant &right) {
            return left.toMap()["name"].toString().localeAwareCompare(
                       right.toMap()["name"].toString()) < 0;
        });

    return result;
}

bool Launcher::launch(const QString &desktopId)
{
    const auto generation = ++m_activationGeneration;
    const KService::Ptr service = KService::serviceByDesktopName(desktopId);

    if (!service) {
        Q_EMIT activationFailed(tr("This application is no longer available."));
        return false;
    }

    auto *job = new KIO::ApplicationLauncherJob(service, this);
    connect(job, &KJob::result, this, [this, job, generation]() {
        if (generation == m_activationGeneration && job->error()) Q_EMIT activationFailed(job->errorString());
    });
    job->start();

    return true;
}

quint64 Launcher::profileOperation(const QString &action, const QVariantMap &request)
{
    const auto id = ++m_profileRequest;
    const auto fail = [this, id](const QString &message) {
        QTimer::singleShot(0, this, [this, id, message] {
            Q_EMIT profileFinished(id, {{"ok", false}, {"error", message}});
        });
    };
    if (profileBusy()) { fail(tr("Another profile operation is in progress.")); return id; }
    const QString python = QStandardPaths::findExecutable(QStringLiteral("python3"));
    const QString helper = QStandardPaths::locate(QStandardPaths::GenericDataLocation,
        QStringLiteral("plasma/plasmoids/com.mattphilmon.tlbstacks/contents/code/profile.py"));
    if (python.isEmpty() || helper.isEmpty()) {
        fail(tr("Profile support requires Python 3 and the updated widget package.")); return id;
    }
    QVariantMap payload = request;
    payload.insert("action", action);
    const auto input = QJsonDocument::fromVariant(payload).toJson(QJsonDocument::Compact);
    if (input.size() > 1024 * 1024) { fail(tr("Profile settings are too large.")); return id; }
    // The process outlives a dismissed editor until it has been reaped. Destruction
    // of the Launcher disconnects UI callbacks and kills without waiting.
    auto *process = new QProcess(QCoreApplication::instance());
    m_profileProcess = process;
    Q_EMIT profileBusyChanged();
    auto *timeout = new QTimer(process);
    timeout->setSingleShot(true);
    connect(timeout, &QTimer::timeout, process, [process] {
        process->setProperty("failure", tr("The profile operation timed out."));
        process->kill();
    });
    connect(process, &QProcess::started, process, [process, input] {
        process->write(input);
        process->closeWriteChannel();
    });
    connect(process, &QProcess::errorOccurred, process, [process](QProcess::ProcessError error) {
        if (error == QProcess::FailedToStart) process->setProperty("failure", tr("Could not start the profile helper."));
    });
    auto done = std::make_shared<bool>(false);
    const auto finish = [this, process, timeout, done, id] {
        if (*done) return;
        *done = true;
        timeout->stop();
        QJsonParseError error;
        const auto document = QJsonDocument::fromJson(process->readAllStandardOutput(), &error);
        QVariantMap result;
        const auto failure = process->property("failure").toString();
        if (!failure.isEmpty() || process->exitStatus() != QProcess::NormalExit ||
            process->exitCode() != 0 || error.error != QJsonParseError::NoError || !document.isObject())
            result = {{"ok", false}, {"error", failure.isEmpty() ? tr("The profile helper failed to return a valid result.") : failure}};
        else result = document.object().toVariantMap();
        m_profileProcess = nullptr;
        Q_EMIT profileBusyChanged();
        Q_EMIT profileFinished(id, result);
    };
    connect(process, &QProcess::finished, this, finish);
    connect(process, &QProcess::errorOccurred, this, [finish](QProcess::ProcessError error) {
        if (error == QProcess::FailedToStart) finish();
    });
    connect(process, &QProcess::finished, process, &QObject::deleteLater);
    connect(process, &QProcess::errorOccurred, process, [process](QProcess::ProcessError error) {
        if (error == QProcess::FailedToStart) process->deleteLater();
    });
    timeout->start(15000);
    process->start(python, {QStringLiteral("-I"), helper});
    return id;
}


bool Launcher::folderAvailable(const QUrl &url) const
{
    const QFileInfo info(url.toLocalFile());
    return url.isLocalFile() && info.isDir() && info.isReadable();
}

QString Launcher::fileIcon(const QUrl &url) const
{
    if (!url.isLocalFile()) return QStringLiteral("unknown");
    const QFileInfo info(url.toLocalFile());
    if (info.isDir()) return QStringLiteral("folder");
    if (info.suffix() == QStringLiteral("desktop")) {
        const KService service(info.absoluteFilePath());
        if (!service.icon().isEmpty()) return service.icon();
    }
    return QMimeDatabase().mimeTypeForFile(info, QMimeDatabase::MatchExtension).iconName();
}

bool Launcher::openFile(const QUrl &url)
{
    const auto generation = ++m_activationGeneration;
    if (!url.isLocalFile()) {
        Q_EMIT fileOpenFailed(tr("This file is no longer available."));
        return false;
    }
    auto *job = new KIO::OpenUrlJob(url, this);
    job->setRunExecutables(true);
    connect(job, &KJob::result, this, [this, job, generation]() {
        if (generation == m_activationGeneration && job->error()) Q_EMIT fileOpenFailed(job->errorString());
    });
    job->start();
    return true;
}


Launcher::~Launcher()
{
    if (m_profileProcess) m_profileProcess->kill();
}

QPoint Launcher::pointerPosition() const
{
    return QCursor::pos();
}

void Launcher::closeFolderMenu()
{
    QScopedValueRollback<bool> closing(m_closingFolderMenu, true);
    if (m_folderPopup) m_folderPopup->close();
}

void Launcher::showFolderMenu(QQuickItem *anchor, const QUrl &folder, const QStringList &filters, int hoverDelay, bool keyboard, bool preview)
{
    if (!anchor || !anchor->window()) return;
    if (!qobject_cast<QApplication *>(QCoreApplication::instance())) {
        Q_EMIT fileOpenFailed(tr("Desktop menus require the Plasma desktop host."));
        return;
    }
    if (m_folderPopup && m_folderPopup->isVisible() && m_folderAnchor == anchor) {
        if (keyboard) {
            m_folderPopup->enterKeyboardMode();
            Q_EMIT folderAnchorHighlightChanged(nullptr);
        }
        return;
    }
    closeFolderMenu();
    QObject::disconnect(m_anchorDestroyed);
    m_folderAnchor = anchor;
    m_enteredFolderPopup = false;
    m_folderPopup = std::make_unique<FolderPopup>(folder, filters,
        [this](const QVariantMap &entry) { activateEntry(entry); }, nullptr, hoverDelay);
    if (preview) m_folderPopup->previewNavigation = [this](int step) {
        Q_EMIT folderNavigateRequested(step);
    };
    m_folderPopup->keyboardEntered = [this] {
        Q_EMIT folderAnchorHighlightChanged(nullptr);
        Q_EMIT folderKeyboardEntered();
    };
    connect(m_folderPopup.get(), &QMenu::aboutToHide, this, [this]() {
        Q_EMIT folderAnchorHighlightChanged(nullptr);
        // Wayland can dismiss the native popup without delivering an outside
        // mouse press. Follow its dismissal unless our parent handoff closed it.
        if (!m_closingFolderMenu) {
            QMetaObject::invokeMethod(this, [this] {
                if (!m_folderPopup || !m_folderPopup->isVisible())
                    Q_EMIT folderDismissRequested();
            }, Qt::QueuedConnection);
        }
    });
    m_anchorDestroyed = connect(anchor, &QObject::destroyed, this, &Launcher::closeFolderMenu);
    // Match the successful standalone probe: attach the native popup to the
    // Quick window, then ask Qt to place it beside the row and constrain it.
    m_folderPopup->winId();
    m_folderPopup->windowHandle()->setTransientParent(anchor->window());
    // A native popup takes the mouse grab before the pointer leaves its row.
    // Keep the visual cue until pointer motion actually enters the native menu.
    if (keyboard) m_folderPopup->enterKeyboardMode();
    Q_EMIT folderAnchorHighlightChanged(keyboard ? nullptr : anchor);
    m_folderPopup->popup(anchor->mapToGlobal(QPointF(anchor->width(), 0)).toPoint());
    if (!m_folderPopup->isVisible()) Q_EMIT folderAnchorHighlightChanged(nullptr);
}


void Launcher::closeApplicationContextMenu()
{
    if (m_applicationContextMenu) m_applicationContextMenu->close();
}

void Launcher::showApplicationContextMenu(QQuickItem *anchor, const QString &desktopId, bool removable, bool desktopActions)
{
    if (!anchor || !anchor->window() || desktopId.isEmpty() ||
        !qobject_cast<QApplication *>(QCoreApplication::instance())) return;
    closeApplicationContextMenu();
    QObject::disconnect(m_contextAnchorDestroyed);
    m_applicationContextMenu = std::make_unique<QMenu>();
    const auto service = desktopActions ? KService::serviceByDesktopName(desktopId) : KService::Ptr();
    if (service) {
        for (const auto &serviceAction : service->actions()) {
            if (serviceAction.noDisplay() || serviceAction.isSeparator()) continue;
            auto *action = m_applicationContextMenu->addAction(QIcon::fromTheme(serviceAction.icon()),
                QString(serviceAction.text()).replace('&', QStringLiteral("&&")));
            connect(action, &QAction::triggered, this, [this, serviceAction] {
                const auto generation = ++m_activationGeneration;
                auto *job = new KIO::ApplicationLauncherJob(serviceAction, this);
                connect(job, &KJob::result, this, [this, job, generation] {
                    if (generation == m_activationGeneration && job->error())
                        Q_EMIT activationFailed(job->errorString());
                });
                job->start();
            });
        }
    }
    if (removable) {
        if (!m_applicationContextMenu->isEmpty()) m_applicationContextMenu->addSeparator();
        auto *remove = m_applicationContextMenu->addAction(tr("Remove from this stack"));
        connect(remove, &QAction::triggered, this, [this, desktopId]() {
            // Defer the model change until the native action has finished dispatching.
            QMetaObject::invokeMethod(this, [this, desktopId]() {
                Q_EMIT removeApplicationRequested(desktopId);
            }, Qt::QueuedConnection);
        });
    }
    if (m_applicationContextMenu->isEmpty()) return;
    m_contextAnchorDestroyed = connect(anchor, &QObject::destroyed,
                                      this, &Launcher::closeApplicationContextMenu);
    m_applicationContextMenu->winId();
    m_applicationContextMenu->windowHandle()->setTransientParent(anchor->window());
    m_applicationContextMenu->popup(anchor->mapToGlobal(QPointF(anchor->width(), 0)).toPoint());
}


bool Launcher::eventFilter(QObject *watched, QEvent *event)
{
    // Only the first native level returns to the QML root. Deeper levels keep
    // QMenu's existing Left behavior, and Escape follows normal dismissal.
    if (event->type() == QEvent::KeyPress && m_folderPopup &&
        watched == m_folderPopup.get() && m_folderPopup->isVisible() &&
        static_cast<QKeyEvent *>(event)->key() == Qt::Key_Left) {
        const auto anchor = m_folderAnchor;
        closeFolderMenu();
        if (anchor && anchor->window()) {
            anchor->window()->requestActivate();
            anchor->forceActiveFocus(Qt::BacktabFocusReason);
            Q_EMIT folderFocusRequested(anchor);
        }
        return true;
    }
    // A QWidget popup grabs pointer input even over its transient QQuickWindow.
    // Watch that input before dispatch and release the whole native branch when
    // the pointer returns to the root. Do not synthesize clicks or activation.
    if ((event->type() == QEvent::MouseMove || event->type() == QEvent::MouseButtonPress) && m_folderPopup &&
        m_folderPopup->isVisible() && m_folderAnchor && m_folderAnchor->window()) {
        const QPoint point = static_cast<QMouseEvent *>(event)->globalPosition().toPoint();
        bool overNative = m_folderPopup->frameGeometry().contains(point);
        const auto children = m_folderPopup->findChildren<QMenu *>();
        for (auto *child : children) {
            if (child->isVisible() && child->frameGeometry().contains(point)) overNative = true;
        }
        if (overNative) {
            if (!m_enteredFolderPopup) Q_EMIT folderAnchorHighlightChanged(nullptr);
            m_enteredFolderPopup = true;
        } else {
            auto *window = m_folderAnchor->window();
            const QRect rootRect(window->mapToGlobal(QPoint(0, 0)), window->size());
            const QRectF anchorRect(m_folderAnchor->mapToGlobal(QPointF(0, 0)),
                                    QSizeF(m_folderAnchor->width(), m_folderAnchor->height()));
            if (event->type() == QEvent::MouseButtonPress && !rootRect.contains(point)) {
                // The native popup consumes the outside press, so Plasma never
                // receives it. Dismiss both layers without replaying that click.
                closeFolderMenu();
                Q_EMIT folderDismissRequested();
                return true;
            }
            // Ignore initial movement within the launching row, allowing the user
            // to cross into the submenu. After entering it, returning anywhere
            // on the root (including that row) dismisses the native branch.
            if (rootRect.contains(point) &&
                (m_enteredFolderPopup || !anchorRect.contains(point))) {
                closeFolderMenu();
            }
        }
    }
    return QObject::eventFilter(watched, event);
}

QVariantList Launcher::applicationEntries(const QStringList &ids, const QVariantMap &icons, const QString &source) const
{
    QVariantList entries;
    if (source != "applications" && source != "categories") return entries;
    for (const auto &id : ids) entries.append(StackEntry::application(id, source, icons.value(id).toString()));
    return entries;
}

QVariantMap Launcher::folderEntry(const QUrl &url) const
{
    return StackEntry::file(url);
}

bool Launcher::activateEntry(const QVariantMap &entry)
{
    const auto action = entry.value("action").toString();
    const auto source = entry.value("source").toString();
    if (action == "launchApplication" && (source == "applications" || source == "categories" || source == "activity"))
        return launch(entry.value("target").toString());
    if (action == "openFile" && source == "folder") return openFile(QUrl(entry.value("target").toString()));
    if (action == "moveToTrash" && source == "folder" &&
        entry.value("actions").toStringList().contains("moveToTrash")) {
        const QUrl url(entry.value("target").toString());
        if (!url.isLocalFile() || url.toLocalFile().isEmpty()) return false;
        auto *job = KIO::trash(QList<QUrl>{url});
        connect(job, &KJob::result, this, [this, job] {
            if (job->error()) Q_EMIT fileOpenFailed(job->errorString());
        });
        return true;
    }
    // Child enumeration belongs to the source; the renderer supplies the anchor.
    return false;
}

void Launcher::showEntryContextMenu(QQuickItem *anchor, const QVariantMap &entry)
{
    if (entry.value("source").toString() == "folder" &&
        entry.value("actions").toStringList().contains("moveToTrash")) {
        if (!anchor || !anchor->window() ||
            !qobject_cast<QApplication *>(QCoreApplication::instance())) return;
        closeApplicationContextMenu();
        QObject::disconnect(m_contextAnchorDestroyed);
        m_applicationContextMenu = std::make_unique<QMenu>();
        auto *trash = m_applicationContextMenu->addAction(tr("Move to Trash"));
        connect(trash, &QAction::triggered, this, [this, entry] {
            auto operation = entry;
            operation["action"] = "moveToTrash";
            activateEntry(operation);
        });
        m_contextAnchorDestroyed = connect(anchor, &QObject::destroyed,
                                          this, &Launcher::closeApplicationContextMenu);
        m_applicationContextMenu->winId();
        m_applicationContextMenu->windowHandle()->setTransientParent(anchor->window());
        m_applicationContextMenu->popup(anchor->mapToGlobal(QPointF(anchor->width(), 0)).toPoint());
        return;
    }
    const auto source = entry.value("source").toString();
    if (source == "applications" || source == "categories" || source == "activity")
        showApplicationContextMenu(anchor, entry.value("id").toString(),
            source == "applications" && entry.value("actions").toStringList().contains("removeFromStack"),
            entry.value("actions").toStringList().contains("desktopActions"));
}
