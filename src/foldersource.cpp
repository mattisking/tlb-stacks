#include "foldersource.h"
#include "folderreader.h"

FolderSource::FolderSource(QObject *parent) : QObject(parent)
{
    m_timer.setInterval(1000);
    connect(&m_timer, &QTimer::timeout, this, &FolderSource::refresh);
}
void FolderSource::setFolder(const QUrl &value)
{
    if (m_folder == value) return;
    m_folder = value; emit folderChanged(); reset();
}
void FolderSource::setFilters(const QStringList &value)
{
    if (m_filters == value) return;
    m_filters = value; emit filtersChanged(); reset();
}
void FolderSource::setActive(bool value)
{
    if (m_active == value) return;
    m_active = value; emit activeChanged();
    if (value) { m_timer.start(); refresh(); }
    else { m_timer.stop(); delete m_request; m_loading = false; emit stateChanged(); }
}
void FolderSource::reset()
{
    delete m_request;
    if (!m_entries.isEmpty()) { m_entries.clear(); emit entriesChanged(); }
    m_available = false; m_loading = false; m_error.clear(); emit stateChanged();
    refresh();
}
void FolderSource::refresh()
{
    if (!m_active || m_request) return;
    auto *token = new QObject(this);
    m_request = token;
    m_loading = true; emit stateChanged();
    requestFolder(token, m_folder, m_filters, [this, token](const FolderListing &result) {
        m_request = nullptr;
        token->deleteLater();
        m_loading = false; m_available = result.available; m_error = result.error;
        if (m_entries != result.entries) { m_entries = result.entries; emit entriesChanged(); }
        emit stateChanged();
    });
}
