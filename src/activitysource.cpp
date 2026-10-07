#include "activitysource.h"
#include "stackentry.h"
#include <PlasmaActivities/Stats/Query>
#include <PlasmaActivities/Stats/ResultSet>
#include <PlasmaActivities/Stats/Terms>
#include <QFutureWatcher>
#include <QtConcurrentRun>
#include <QSet>
#include <QHash>
#include <KSycoca>


ActivitySource::ActivitySource(QObject *parent) : QObject(parent)
{
    connect(KSycoca::self(), &KSycoca::databaseChanged, this, [this] {
        // Rebuild on the next refresh, not while the user is navigating a menu.
        m_eligibleDirty = true;
    });
    connect(&m_consumer, &KActivities::Consumer::serviceStatusChanged, this, [this] {
        if (m_requested) { ++m_generation; if (!m_loading) start(); }
    });
    connect(&m_consumer, &KActivities::Consumer::currentActivityChanged, this, [this] {
        if (m_requested && m_current) { ++m_generation; if (!m_loading) start(); }
    });
}
void ActivitySource::refresh(bool frequent, int limit, const QStringList &categories, bool currentActivity)
{
    const bool same = m_requested && m_frequent == frequent
        && m_limit == qBound(1, limit, 50) && m_categories == categories && m_current == currentActivity;
    if (same && m_loading) return; // Reopening must not invalidate an identical in-flight query.
    if (!same) setEntries({});
    if (m_categories != categories) m_eligibleDirty = true;
    m_frequent = frequent;
    m_limit = qBound(1, limit, 50);
    m_categories = categories;
    m_current = currentActivity;
    m_requested = true;
    ++m_generation;
    if (!m_loading) start();
}
void ActivitySource::setEntries(const QVariantList &entries)
{
    if (m_entries == entries) return;
    m_entries = entries;
    Q_EMIT entriesChanged();
}
void ActivitySource::start()
{
    m_message.clear();
    if (m_consumer.serviceStatus() != KActivities::Consumer::Running) {
        setEntries({});
        m_message = tr("KDE Activities history is unavailable or still starting.");
        Q_EMIT changed();
        return;
    }
    // Resolve eligibility before querying/ranking so categories do not truncate
    // the top N of all apps into an accidentally short category-specific list.
    if (m_eligibleDirty) {
        m_eligible.clear();
        for (const auto &service : KService::allServices()) {
            if (!service || service->noDisplay() || !service->showInCurrentDesktop()) continue;
            bool matches = m_categories.isEmpty();
            for (const auto &category : m_categories)
                if (service->categories().contains(category)) { matches = true; break; }
            if (!matches) continue;
            const auto entry = StackEntry::applicationData(service->desktopEntryName(), "activity", "", service);
            m_eligible.insert("applications:" + service->storageId(), entry);
            m_eligible.insert("applications:" + service->desktopEntryName() + ".desktop", entry);
        }
        m_eligibleDirty = false;
    }
    const auto eligible = m_eligible;
    if (eligible.isEmpty()) {
        setEntries({});
        m_message = tr("No installed applications match these categories.");
        Q_EMIT changed();
        return;
    }
    using namespace KActivities::Stats;
    using namespace KActivities::Stats::Terms;
    const auto activity = m_current ? Activity(m_consumer.currentActivity()) : Activity::any();
    // At most two resource aliases per eligible desktop ID; fetch enough to deduplicate.
    const auto query = UsedResources | (m_frequent ? HighScoredFirst : RecentlyUsedFirst)
        | Agent::any() | activity | Type::any() | Url(eligible.keys()) | Limit(m_limit * 2);
    const auto generation = m_generation;
    const int limit = m_limit;
    m_loading = true;
    Q_EMIT changed();
    auto *watcher = new QFutureWatcher<QVariantList>(this);
    connect(watcher, &QFutureWatcher<QVariantList>::finished, this, [this, watcher, generation] {
        const auto result = watcher->result();
        watcher->deleteLater();
        m_loading = false;
        if (generation != m_generation) { start(); return; }
        setEntries(result);
        if (m_entries.isEmpty()) m_message = tr("No recorded application usage matches. History may be empty or disabled in KDE Activities settings.");
        Q_EMIT changed();
    });
    watcher->setFuture(QtConcurrent::run([query, eligible, limit] {
        QVariantList entries;
        QSet<QString> seen;
        // The database result lives only in this worker, never across menu opens.
        const ResultSet results(query);
        for (const auto &result : results) {
            const auto entry = eligible.value(result.resource());
            const auto id = entry.value("id").toString();
            if (id.isEmpty() || seen.contains(id)) continue;
            seen.insert(id);
            entries.append(entry);
            if (entries.size() >= limit) break;
        }
        return entries;
    }));
}
