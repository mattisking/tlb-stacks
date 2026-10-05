#pragma once
#include <QObject>
#include <QUrl>
#include <QVariantList>
#include <functional>

struct FolderListing {
    bool available = false;
    QString error;
    QVariantList entries;
};
// GUI-thread service. Results and callbacks arrive on the GUI thread; all I/O
// runs on a bounded private pool. Identical in-flight requests are shared.
void requestFolder(QObject *context, const QUrl &folder, const QStringList &filters,
                   std::function<void(const FolderListing &)> completed);
