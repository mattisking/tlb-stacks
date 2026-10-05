#include "folderreader.h"
#include "stackentry.h"
#include <QCoreApplication>
#include <QDir>
#include <QFutureWatcher>
#include <QJsonArray>
#include <QJsonDocument>
#include <QPointer>
#include <QThreadPool>
#include <QTimer>
#include <QtConcurrentRun>
#include <atomic>
#include <memory>

namespace {
struct Listener {
    QPointer<QObject> context;
    std::function<void(const FolderListing &)> complete;
};
struct Request {
    QList<Listener> listeners;
    std::atomic_bool cancelled{false};
};
class Reader : public QObject {
public:
    explicit Reader(QObject *parent) : QObject(parent) { pool.setMaxThreadCount(2); }
    QThreadPool pool;
    QHash<QString, std::shared_ptr<Request>> pending;
};
FolderListing scan(const QUrl &url, const QStringList &filters, const std::shared_ptr<Request> &request)
{
    FolderListing result;
    if (request->cancelled) return result;
    const QFileInfo info(url.toLocalFile());
    if (!url.isLocalFile() || !info.isDir() || !info.isReadable()) return result;
    result.available = true;
    const auto files = QDir(info.absoluteFilePath()).entryInfoList(
        filters.isEmpty() ? QStringList{"*"} : filters,
        QDir::Files | QDir::AllDirs | QDir::NoDotAndDotDot,
        QDir::DirsFirst | QDir::Name | QDir::IgnoreCase);
    for (const auto &file : files) {
        if (request->cancelled) return {};
        result.entries.append(StackEntry::file(QUrl::fromLocalFile(file.absoluteFilePath())));
    }
    return result;
}
}
void requestFolder(QObject *context, const QUrl &folder, const QStringList &filters,
                   std::function<void(const FolderListing &)> completed)
{
    static QPointer<Reader> reader;
    if (!reader) reader = new Reader(QCoreApplication::instance());
    const auto key = folder.toString() + '\n' + QString::fromUtf8(
        QJsonDocument(QJsonArray::fromStringList(filters)).toJson(QJsonDocument::Compact));
    auto request = reader->pending.value(key);
    if (!request) {
        // Bound queued work as well as running work. A later open/poll retries.
        if (reader->pending.size() >= 8) {
            QTimer::singleShot(0, context, [completed] {
                completed({false, QObject::tr("Folder loading is busy. Please try again."), {}});
            });
            return;
        }
        request = std::make_shared<Request>();
        reader->pending.insert(key, request);
        auto *watcher = new QFutureWatcher<FolderListing>(reader);
        QObject::connect(watcher, &QFutureWatcher<FolderListing>::finished, reader,
                         [service = reader, watcher, key, request] {
            const auto result = watcher->result();
            service->pending.remove(key);
            watcher->deleteLater();
            for (const auto &listener : request->listeners)
                if (listener.context) listener.complete(result);
        });
        watcher->setFuture(QtConcurrent::run(&reader->pool, scan, folder, filters, request));
    }
    if (request->cancelled) {
        QPointer<QObject> guard(context);
        request->listeners.append({context, [guard, folder, filters, completed](const FolderListing &) {
            if (guard) requestFolder(guard, folder, filters, completed);
        }});
        return;
    }
    request->listeners.append({context, std::move(completed)});
    std::weak_ptr<Request> weak = request;
    QObject::connect(context, &QObject::destroyed, reader, [weak] {
        if (auto work = weak.lock()) {
            bool live = false;
            for (const auto &listener : work->listeners) if (listener.context) live = true;
            if (!live) work->cancelled = true;
        }
    });
}
