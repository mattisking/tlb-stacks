// TaskIndex coverage: per-app state, unclaimed tasks, and the four actions —
// pinned against BOTH topologies the real grouped TasksModel produces: flat
// standalone rows (one row per window) and grouped apps (a single group-parent
// row with child window rows). request* on a group parent is a no-op upstream,
// so grouped apps must be driven through their CHILD rows; requestNewInstance
// is the exception — upstream passes group parents through.
#include "../../src/taskindex.h"
#include "mocktasksmodel.h"

#include <QDateTime>
#include <QDir>
#include <QIcon>
#include <QImage>
#include <QFile>
#include <QSignalSpy>
#include <QStandardItemModel>
#include <QTemporaryDir>
#include <QtTest>

namespace {
const QString Konsole = QStringLiteral("org.kde.konsole.desktop");
const QString KonsoleUrl = QStringLiteral("file:///usr/share/applications/org.kde.konsole.desktop");
const QString DolphinUrl = QStringLiteral("file:///usr/share/applications/org.kde.dolphin.desktop");

QVariantMap window(const QString &url, bool active = false, bool minimized = false)
{
    return {{"IsWindow", true}, {"IsActive", active}, {"IsMinimized", minimized}, {"LauncherUrl", url}};
}

QVariantMap titledWindow(const QString &url, const QString &title, bool active = false, bool minimized = false)
{
    QVariantMap row = window(url, active, minimized);
    row.insert("display", title);
    return row;
}

// A group parent row wrapping `children` window maps (GroupApplications topology).
QVariantMap groupRow(const QString &url, const QVariantList &children, bool active = false)
{
    return {{"IsGroupParent", true}, {"IsActive", active}, {"LauncherUrl", url}, {"children", children}};
}

// A window carrying "LastActivated" recency (optional in the real model).
QVariantMap recentWindow(const QString &url, qint64 lastActivated, bool minimized = false)
{
    QVariantMap row = window(url, false, minimized);
    row.insert("LastActivated", lastActivated);
    return row;
}

// A window with its per-window identifier: WinIdList holds the platform's id —
// a numeric WId on X11 or a UUID string on Wayland — exactly one entry per
// window row, as the real model reports.
QVariantMap idWindow(const QString &url, const QVariant &id, const QString &title = {},
                     bool active = false, bool minimized = false)
{
    QVariantMap row = window(url, active, minimized);
    row.insert("WinIdList", QVariantList{id});
    if (!title.isEmpty())
        row.insert("display", title);
    return row;
}

// The live Plasma shape: a group parent that ALSO reports IsWindow, with a
// WinIdList carrying its first child's uuid — so it masquerades as that child
// unless IsGroupParent is treated as authoritative.
QVariantMap liveGroupRow(const QString &url, const QVariantList &children, const QVariant &firstChildId)
{
    QVariantMap row = groupRow(url, children);
    row.insert("IsWindow", true);
    row.insert("WinIdList", QVariantList{firstChildId});
    return row;
}

QVariantMap recentWindow(const QString &url, const QDateTime &lastActivated)
{
    QVariantMap row = window(url);
    row.insert("LastActivated", lastActivated);
    return row;
}
}

class TaskIndexTest : public QObject {
    Q_OBJECT
    MockTasksModel model;
    TaskIndex index;
    QTemporaryDir themeRoot;

private slots:
    void initTestCase()
    {
        // A throwaway icon theme so QIcon::fromTheme yields a named icon without a desktop session.
        QVERIFY(themeRoot.isValid());
        QVERIFY(QDir().mkpath(themeRoot.filePath("tst/16x16/apps")));
        QFile themeFile(themeRoot.filePath("tst/index.theme"));
        QVERIFY(themeFile.open(QIODevice::WriteOnly));
        themeFile.write("[Icon Theme]\nName=tst\nDirectories=16x16/apps\n\n"
                        "[16x16/apps]\nSize=16\nType=Fixed\n");
        themeFile.close();
        QImage image(16, 16, QImage::Format_ARGB32);
        image.fill(Qt::red);
        QVERIFY(image.save(themeRoot.filePath("tst/16x16/apps/utilities-terminal.png")));
        QIcon::setThemeSearchPaths({themeRoot.path()});
        QIcon::setThemeName("tst");
    }

    void init()
    {
        model.setRows({});
        model.clearCalls();
        index.setModel(&model);
        index.setDesktopIds({Konsole});
    }

    void emptyModelIsNotRunning()
    {
        const QVariantMap state = index.taskState(Konsole);
        QCOMPARE(state.value("running").toBool(), false);
        QCOMPARE(state.value("active").toBool(), false);
        QCOMPARE(state.value("minimized").toBool(), false);
        QCOMPARE(state.value("count").toInt(), 0);
        QCOMPARE(state.value("iconName").toString(), QStringLiteral("application-x-executable"));
    }

    void singleWindowIsRunning()
    {
        model.setRows({window(KonsoleUrl, true)});
        const QVariantMap state = index.taskState(Konsole);
        QCOMPARE(state.value("running").toBool(), true);
        QCOMPARE(state.value("active").toBool(), true);
        QCOMPARE(state.value("minimized").toBool(), false);
        QCOMPARE(state.value("count").toInt(), 1);
    }

    void minimizedWindowReportsMinimized()
    {
        model.setRows({window(KonsoleUrl, false, true)});
        const QVariantMap state = index.taskState(Konsole);
        QCOMPARE(state.value("running").toBool(), true);
        QCOMPARE(state.value("minimized").toBool(), true);
    }

    void iconNameComesFromTheIconRole()
    {
        QVariantMap row = window(KonsoleUrl);
        row.insert("decoration", QIcon::fromTheme("utilities-terminal"));
        model.setRows({row});
        QCOMPARE(index.taskState(Konsole).value("iconName").toString(), QStringLiteral("utilities-terminal"));
    }

    void groupParentCountsItsChildWindowsOnce()
    {
        QVariantMap group{{"IsGroupParent", true}, {"IsActive", true}, {"LauncherUrl", KonsoleUrl},
                          {"children", QVariantList{window(KonsoleUrl, true), window(KonsoleUrl)}}};
        model.setRows({group});
        QVariantMap state = index.taskState(Konsole);
        QCOMPARE(state.value("running").toBool(), true);
        QCOMPARE(state.value("active").toBool(), true);
        QCOMPARE(state.value("count").toInt(), 2);

        group.insert("children", QVariantList{window(KonsoleUrl, true)});
        model.setRows({group});
        QCOMPARE(index.taskState(Konsole).value("count").toInt(), 1);
    }

    void standaloneWindowsEachCountOnce()
    {
        model.setRows({window(KonsoleUrl), window(KonsoleUrl, true), window("file:///usr/share/applications/other.desktop")});
        QCOMPARE(index.taskState(Konsole).value("count").toInt(), 2);
    }

    void launcherUrlFormsAllMatch_data()
    {
        QTest::addColumn<QString>("url");
        QTest::newRow("applications scheme") << "applications:org.kde.konsole.desktop";
        QTest::newRow("file url") << KonsoleUrl;
        QTest::newRow("bare path") << "/usr/share/applications/org.kde.konsole.desktop";
        QTest::newRow("applications without suffix") << "applications:org.kde.konsole";
    }
    void launcherUrlFormsAllMatch()
    {
        QFETCH(QString, url);
        model.setRows({window(url)});
        QCOMPARE(index.taskState(Konsole).value("running").toBool(), true);
        QCOMPARE(index.taskState("org.kde.konsole").value("running").toBool(), true);
        QCOMPARE(index.taskState("org.kde.dolphin.desktop").value("running").toBool(), false);
    }

    void launcherUrlAsQUrlMatches()
    {
        QVariantMap row = window({});
        row.insert("LauncherUrl", QUrl(KonsoleUrl));
        model.setRows({row});
        QCOMPARE(index.taskState(Konsole).value("running").toBool(), true);
    }

    void appIdFallbackWhenUrlIsEmptyOrUnresolvable()
    {
        QVariantMap noUrl = window({});
        noUrl.insert("AppId", Konsole);
        model.setRows({noUrl});
        QCOMPARE(index.taskState(Konsole).value("running").toBool(), true);

        QVariantMap preferred = window("preferred://browser");
        preferred.insert("AppId", "org.kde.konsole");
        model.setRows({preferred});
        QCOMPARE(index.taskState(Konsole).value("running").toBool(), true);

        QVariantMap other = window({});
        other.insert("AppId", "org.kde.dolphin");
        model.setRows({other});
        QCOMPARE(index.taskState(Konsole).value("running").toBool(), false);
    }

    void launcherOnlyRowIsNeverRunning()
    {
        model.setRows({QVariantMap{{"IsLauncher", true}, {"IsWindow", false}, {"LauncherUrl", KonsoleUrl}}});
        const QVariantMap state = index.taskState(Konsole);
        QCOMPARE(state.value("running").toBool(), false);
        QCOMPARE(state.value("count").toInt(), 0);
    }

    void activateWhenIdleReturnsFalse()
    {
        QVERIFY(!index.activate(Konsole));
        model.setRows({window(DolphinUrl)});
        QVERIFY(!index.activate(Konsole));
        QCOMPARE(model.activateCalls(), QVariantList{});
        QCOMPARE(model.toggleMinimizedCalls(), QVariantList{});
    }

    void activateUnfocusedWindowRequestsActivation()
    {
        model.setRows({window(DolphinUrl), window(KonsoleUrl, false, true)});
        QVERIFY(index.activate(Konsole));
        QCOMPARE(model.activateCalls(), QVariantList{1});
        QCOMPARE(model.toggleMinimizedCalls(), QVariantList{});
    }

    void activateFocusedWindowTogglesMinimized()
    {
        model.setRows({window(KonsoleUrl, true)});
        QVERIFY(index.activate(Konsole));
        QCOMPARE(model.toggleMinimizedCalls(), QVariantList{0});
        QCOMPARE(model.activateCalls(), QVariantList{});
    }

    void activateTogglesTheActiveRowAmongMatches()
    {
        model.setRows({window(KonsoleUrl), window(KonsoleUrl, true)});
        QVERIFY(index.activate(Konsole));
        QCOMPARE(model.toggleMinimizedCalls(), QVariantList{1});
        QCOMPARE(model.activateCalls(), QVariantList{});
    }

    void activatePicksTheFirstVisibleWindow()
    {
        model.setRows({window(KonsoleUrl, false, true), window(KonsoleUrl), window(KonsoleUrl, false, true)});
        QVERIFY(index.activate(Konsole));
        QCOMPARE(model.activateCalls(), QVariantList{1});
    }

    void activatePicksTheFirstWindowWhenAllAreMinimized()
    {
        model.setRows({window(KonsoleUrl, false, true), window(KonsoleUrl, false, true)});
        QVERIFY(index.activate(Konsole));
        QCOMPARE(model.activateCalls(), QVariantList{0});
    }

    void activateRoutesRowsWithoutADesktopEntry()
    {
        model.setRows({window({}, false, true), window({})});
        QVERIFY(index.activate(QString()));
        QCOMPARE(model.activateCalls(), QVariantList{1});
        QCOMPARE(model.toggleMinimizedCalls(), QVariantList{});
    }

    void cycleAdvancesToTheRowAfterTheActiveOne()
    {
        model.setRows({window(KonsoleUrl, true), window(KonsoleUrl)});
        QVERIFY(index.cycle(Konsole));
        QCOMPARE(model.activateCalls(), QVariantList{1});
    }

    void cycleWrapsFromTheLastRow()
    {
        model.setRows({window(KonsoleUrl), window(KonsoleUrl, true)});
        QVERIFY(index.cycle(Konsole));
        QCOMPARE(model.activateCalls(), QVariantList{0});
    }

    void cycleWithoutAnActiveWindowBehavesLikeActivate()
    {
        model.setRows({window(KonsoleUrl, false, true), window(KonsoleUrl)});
        QVERIFY(index.cycle(Konsole));
        QCOMPARE(model.activateCalls(), QVariantList{1});
    }

    void cycleWhenIdleReturnsFalse()
    {
        QVERIFY(!index.cycle(Konsole));
        QCOMPARE(model.activateCalls(), QVariantList{});
    }

    void stepMovesForwardFromTheActiveRow()
    {
        model.setRows({window(KonsoleUrl, true), window(KonsoleUrl)});
        index.step(Konsole, 1);
        QCOMPARE(model.activateCalls(), QVariantList{1});
    }

    void stepWrapsForwardPastTheLastRow()
    {
        model.setRows({window(KonsoleUrl), window(KonsoleUrl, true)});
        index.step(Konsole, 1);
        QCOMPARE(model.activateCalls(), QVariantList{0});
    }

    void stepWrapsBackwardBeforeTheFirstRow()
    {
        model.setRows({window(KonsoleUrl, true), window(KonsoleUrl)});
        index.step(Konsole, -1);
        QCOMPARE(model.activateCalls(), QVariantList{1});
    }

    void stepWithoutAnActiveRowStartsAtTheFirstRow()
    {
        model.setRows({window(KonsoleUrl), window(KonsoleUrl)});
        index.step(Konsole, 1);
        QCOMPARE(model.activateCalls(), QVariantList{0});
    }

    void stepWithoutRowsIsANoOp()
    {
        index.step(Konsole, 1);
        QCOMPARE(model.activateCalls(), QVariantList{});
    }

    void newInstanceRequestsOnTheFirstMatchedRow()
    {
        model.setRows({window(DolphinUrl), window(KonsoleUrl), window(KonsoleUrl)});
        QVERIFY(index.newInstance(Konsole));
        QCOMPARE(model.newInstanceCalls(), QVariantList{1});
    }

    void newInstanceWhenIdleReturnsFalse()
    {
        QVERIFY(!index.newInstance(Konsole));
        QCOMPARE(model.newInstanceCalls(), QVariantList{});
    }

    void closeRequestsOnTheSingleMatchedWindow()
    {
        model.setRows({window(DolphinUrl), window(KonsoleUrl)});
        QVERIFY(index.close(Konsole));
        QCOMPARE(model.closeCalls(), QVariantList{1});
    }

    void closeRequestsOnEveryStandaloneWindowOfTheApp()
    {
        // Ungrouped windows are separate rows: each one is closed on its own.
        model.setRows({window(DolphinUrl), window(KonsoleUrl), window(KonsoleUrl, false, true)});
        QVERIFY(index.close(Konsole));
        QCOMPARE(model.closeCalls(), (QVariantList{1, 2}));
    }

    void closeWhenIdleReturnsFalseAndInvokesNothing()
    {
        QVERIFY(!index.close(Konsole));
        model.setRows({window(DolphinUrl)});
        QVERIFY(!index.close(Konsole));
        QCOMPARE(model.closeCalls(), QVariantList{});
    }

    // ---- Per-window API (tooltip tiles) ----
    // The real tasks model exposes one identifier per window row through
    // "WinIdList" — a numeric WId on X11, a UUID string on Wayland (there is no
    // separate UUID/WinId role). windows() reports both fields, one per window.

    void windowsListEveryWindowOfTheApp()
    {
        model.setRows({idWindow(DolphinUrl, uint(9)),
                       idWindow(KonsoleUrl, uint(4242), "First", true),
                       idWindow(KonsoleUrl, QStringLiteral("konsole-uuid-2"), "Second", true)});
        const QVariantList windows = index.windows(Konsole);
        QCOMPARE(windows.size(), 2);

        const QVariantMap first = windows.at(0).toMap();
        QCOMPARE(first.value("uuid").toString(), QString());
        QCOMPARE(first.value("winId").toUInt(), uint(4242));
        QCOMPARE(first.value("title").toString(), QStringLiteral("First"));
        QCOMPARE(first.value("active").toBool(), true);
        QCOMPARE(first.value("minimized").toBool(), false);

        const QVariantMap second = windows.at(1).toMap();
        QCOMPARE(second.value("uuid").toString(), QStringLiteral("konsole-uuid-2"));
        QCOMPARE(second.value("winId").toUInt(), uint(0));
        QCOMPARE(second.value("title").toString(), QStringLiteral("Second"));
    }

    void windowsExpandGroupParents()
    {
        const QVariantList children{idWindow(KonsoleUrl, uint(11)),
                                    idWindow(KonsoleUrl, QStringLiteral("u-12"), "B", false, true)};
        model.setRows({window(DolphinUrl), groupRow(KonsoleUrl, children)});
        const QVariantList windows = index.windows(Konsole);
        QCOMPARE(windows.size(), 2);
        QCOMPARE(windows.at(0).toMap().value("winId").toUInt(), uint(11));
        QCOMPARE(windows.at(1).toMap().value("uuid").toString(), QStringLiteral("u-12"));
        QCOMPARE(windows.at(1).toMap().value("title").toString(), QStringLiteral("B"));
        QCOMPARE(windows.at(1).toMap().value("minimized").toBool(), true);
    }

    void windowsAreEmptyWhenTheAppIsIdle()
    {
        QCOMPARE(index.windows(Konsole), QVariantList{});
        model.setRows({idWindow(DolphinUrl, uint(7))});
        QCOMPARE(index.windows(Konsole), QVariantList{});
    }

    void activateWindowTargetsExactlyThatWindow()
    {
        model.setRows({idWindow(KonsoleUrl, uint(111)), idWindow(KonsoleUrl, QStringLiteral("uuid-b")),
                       window(DolphinUrl)});
        QVERIFY(index.activateWindow(QStringLiteral("uuid-b")));
        QCOMPARE(model.activateCalls(), QVariantList{1});
        model.clearCalls();
        QVERIFY(index.activateWindow(QStringLiteral("111"))); // an X11 WId arrives as a string
        QCOMPARE(model.activateCalls(), QVariantList{0});
    }

    void closeWindowTargetsExactlyThatWindow()
    {
        model.setRows({idWindow(KonsoleUrl, uint(111)), idWindow(KonsoleUrl, QStringLiteral("uuid-b"))});
        QVERIFY(index.closeWindow(QStringLiteral("111")));
        QCOMPARE(model.closeCalls(), QVariantList{0});
        model.clearCalls();
        QVERIFY(index.closeWindow(QStringLiteral("uuid-b")));
        QCOMPARE(model.closeCalls(), QVariantList{1});
    }

    void windowActionsFindGroupedChildRows()
    {
        // The group sits at top-level 1 with three children, and the target is
        // child 2: a row index that can never be the group-parent row, so the
        // recorded call proves the CHILD row was driven, not the parent.
        const QVariantList children{idWindow(KonsoleUrl, uint(11)), idWindow(KonsoleUrl, QStringLiteral("u-12")),
                                    idWindow(KonsoleUrl, QStringLiteral("u-13"))};
        model.setRows({window(DolphinUrl), groupRow(KonsoleUrl, children)});
        QVERIFY(index.activateWindow(QStringLiteral("u-13")));
        QCOMPARE(model.activateCalls(), QVariantList{2});
        QVERIFY(index.closeWindow(QStringLiteral("11")));
        QCOMPARE(model.closeCalls(), QVariantList{0});
    }

    void windowActionsWithoutAMatchReturnFalse()
    {
        model.setRows({idWindow(KonsoleUrl, uint(111))});
        QVERIFY(!index.activateWindow(QStringLiteral("nope")));
        QVERIFY(!index.closeWindow(QStringLiteral("nope")));
        QVERIFY(!index.activateWindow(QString()));
        QVERIFY(!index.closeWindow(QString()));
        QCOMPARE(model.activateCalls(), QVariantList{});
        QCOMPARE(model.closeCalls(), QVariantList{});
    }

    void windowsAcceptAWindowUuidAsAByteArray()
    {
        // Some Wayland backends surface the window UUID as a QByteArray; it must
        // still be usable as a window id, since a silently empty id turns every
        // tile click into a no-op.
        model.setRows({idWindow(KonsoleUrl, QByteArray("konsole-byte-uuid"), "Byte")});
        const QVariantList windows = index.windows(Konsole);
        QCOMPARE(windows.size(), 1);
        QCOMPARE(windows.at(0).toMap().value("uuid").toString(), QStringLiteral("konsole-byte-uuid"));
        QCOMPARE(windows.at(0).toMap().value("winId").toUInt(), uint(0));
        QVERIFY(index.activateWindow(QStringLiteral("konsole-byte-uuid")));
        QCOMPARE(model.activateCalls(), QVariantList{0});
        QVERIFY(index.closeWindow(QStringLiteral("konsole-byte-uuid")));
        QCOMPARE(model.closeCalls(), QVariantList{0});
    }

    void liveGroupParentNeverMasqueradesAsItsFirstChild()
    {
        // The live Plasma 6.7 shape (from a real desktop trace): the group parent
        // reports BOTH IsWindow and IsGroupParent, and its WinIdList.first() is its
        // first child's uuid — so IsWindow-first logic makes the parent look like a
        // window and hides its children. Dolphin sits at top-level 0 so the konsole
        // group is top-level 1: a driven CHILD records its own row under the parent
        // (0 or 1), while a wrongly driven PARENT would record 1 and, for the first
        // child's uuid, would win the match outright.
        const QVariantList children{idWindow(KonsoleUrl, QStringLiteral("{9c56c428}"), "Left"),
                                    idWindow(KonsoleUrl, QStringLiteral("{25accca1}"), "Right")};
        model.setRows({window(DolphinUrl),
                       liveGroupRow(KonsoleUrl, children, QStringLiteral("{9c56c428}"))});

        // Tiles: exactly the two children, in order, never the parent.
        const QVariantList windows = index.windows(Konsole);
        QCOMPARE(windows.size(), 2);
        QCOMPARE(windows.at(0).toMap().value("uuid").toString(), QStringLiteral("{9c56c428}"));
        QCOMPARE(windows.at(0).toMap().value("title").toString(), QStringLiteral("Left"));
        QCOMPARE(windows.at(1).toMap().value("uuid").toString(), QStringLiteral("{25accca1}"));
        QCOMPARE(windows.at(1).toMap().value("title").toString(), QStringLiteral("Right"));

        // Left-click the first tile: the CHILD row (0), never the group parent (1),
        // whose requestActivate is an upstream no-op.
        QVERIFY(index.activateWindow(QStringLiteral("{9c56c428}")));
        QCOMPARE(model.activateCalls(), QVariantList{0});
        model.clearCalls();
        // The second child's own uuid can only ever match that child.
        QVERIFY(index.activateWindow(QStringLiteral("{25accca1}")));
        QCOMPARE(model.activateCalls(), QVariantList{1});
        model.clearCalls();
        // Middle-click / ✕: exactly that child, never every child through the parent.
        QVERIFY(index.closeWindow(QStringLiteral("{9c56c428}")));
        QCOMPARE(model.closeCalls(), QVariantList{0});
        model.clearCalls();
        QVERIFY(index.closeWindow(QStringLiteral("{25accca1}")));
        QCOMPARE(model.closeCalls(), QVariantList{1});
        QCOMPARE(model.activateCalls(), QVariantList{});
    }

    // ---- Grouped topology (one group-parent row with child window rows) ----
    // Every grouped test puts a dolphin row at top-level 0 so the konsole
    // group sits at top-level 1: recorded child rows (0..2) then can never be
    // confused with the group-parent row the pre-fix code would have driven.

    void activateUnfocusedGroupedAppActivatesAChild()
    {
        const QVariantList children{window(KonsoleUrl, false, true), window(KonsoleUrl, false, true),
                                    window(KonsoleUrl)};
        model.setRows({window(DolphinUrl), groupRow(KonsoleUrl, children)});
        QVERIFY(index.activate(Konsole));
        QCOMPARE(model.activateCalls(), QVariantList{2}); // first visible child
        QCOMPARE(model.toggleMinimizedCalls(), QVariantList{});
    }

    void activateFocusedGroupedAppTogglesTheActiveChild()
    {
        // The group parent carries IsActive too (the real model mirrors the
        // focused child); the toggle must land on the ACTIVE CHILD.
        const QVariantList children{window(KonsoleUrl, true), window(KonsoleUrl), window(KonsoleUrl)};
        model.setRows({window(DolphinUrl), groupRow(KonsoleUrl, children, true)});
        QVERIFY(index.activate(Konsole));
        QCOMPARE(model.toggleMinimizedCalls(), QVariantList{0});
        QCOMPARE(model.activateCalls(), QVariantList{});
    }

    void activatePicksTheMostRecentlyActivatedVisibleWindow()
    {
        // "LastActivated" recency (when the model exposes it) beats window
        // order; a minimized window is never the pick.
        QVariantList children{recentWindow(KonsoleUrl, 300), recentWindow(KonsoleUrl, 100),
                              recentWindow(KonsoleUrl, 200)};
        model.setRows({window(DolphinUrl), groupRow(KonsoleUrl, children)});
        QVERIFY(index.activate(Konsole));
        QCOMPARE(model.activateCalls(), QVariantList{0});

        children = QVariantList{recentWindow(KonsoleUrl, 200), recentWindow(KonsoleUrl, 999, true),
                                 recentWindow(KonsoleUrl, 300)};
        model.setRows({window(DolphinUrl), groupRow(KonsoleUrl, children)});
        model.clearCalls();
        QVERIFY(index.activate(Konsole));
        QCOMPARE(model.activateCalls(), QVariantList{2});

        // QDateTime recency reads the same way as numeric recency.
        children = QVariantList{recentWindow(KonsoleUrl, 500), recentWindow(KonsoleUrl, 100),
                                recentWindow(KonsoleUrl, QDateTime(QDate(2026, 1, 1), QTime(0, 0)))};
        model.setRows({window(DolphinUrl), groupRow(KonsoleUrl, children)});
        model.clearCalls();
        QVERIFY(index.activate(Konsole));
        QCOMPARE(model.activateCalls(), QVariantList{2});
    }

    void cycleAdvancesToTheGroupedChildAfterTheActiveOne()
    {
        const QVariantList children{window(KonsoleUrl), window(KonsoleUrl, true), window(KonsoleUrl)};
        model.setRows({window(DolphinUrl), groupRow(KonsoleUrl, children, true)});
        QVERIFY(index.cycle(Konsole));
        QCOMPARE(model.activateCalls(), QVariantList{2});
    }

    void cycleWrapsFromTheLastGroupedChild()
    {
        const QVariantList children{window(KonsoleUrl), window(KonsoleUrl), window(KonsoleUrl, true)};
        model.setRows({window(DolphinUrl), groupRow(KonsoleUrl, children, true)});
        QVERIFY(index.cycle(Konsole));
        QCOMPARE(model.activateCalls(), QVariantList{0});
    }

    void cycleOnAGroupedAppWithoutAnActiveChildBehavesLikeActivate()
    {
        const QVariantList children{window(KonsoleUrl, false, true), window(KonsoleUrl, false, true),
                                    window(KonsoleUrl)};
        model.setRows({window(DolphinUrl), groupRow(KonsoleUrl, children)});
        QVERIFY(index.cycle(Konsole));
        QCOMPARE(model.activateCalls(), QVariantList{2}); // first visible child, like activate
    }

    void stepMovesForwardFromTheActiveGroupedChild()
    {
        const QVariantList children{window(KonsoleUrl), window(KonsoleUrl, true), window(KonsoleUrl)};
        model.setRows({window(DolphinUrl), groupRow(KonsoleUrl, children, true)});
        index.step(Konsole, 1);
        QCOMPARE(model.activateCalls(), QVariantList{2});
    }

    void stepWrapsBothWaysAcrossGroupedChildren()
    {
        QVariantList children{window(KonsoleUrl, true), window(KonsoleUrl), window(KonsoleUrl)};
        model.setRows({window(DolphinUrl), groupRow(KonsoleUrl, children, true)});
        index.step(Konsole, -1);
        QCOMPARE(model.activateCalls(), QVariantList{2});

        children = QVariantList{window(KonsoleUrl), window(KonsoleUrl), window(KonsoleUrl, true)};
        model.setRows({window(DolphinUrl), groupRow(KonsoleUrl, children, true)});
        model.clearCalls();
        index.step(Konsole, 1);
        QCOMPARE(model.activateCalls(), QVariantList{0});
    }

    void newInstanceOnAGroupedRowKeepsTheGroupParent()
    {
        // Upstream passes group parents through requestNewInstance (unlike the
        // other request* actions), so the group row stays the target.
        const QVariantList children{window(KonsoleUrl), window(KonsoleUrl)};
        model.setRows({window(DolphinUrl), groupRow(KonsoleUrl, children)});
        QVERIFY(index.newInstance(Konsole));
        QCOMPARE(model.newInstanceCalls(), QVariantList{1}); // the group-parent row
    }

    void closeOnAGroupParentTargetsTheParentRow()
    {
        // Unlike activate, close does NOT walk the children: upstream's
        // TaskGroupingProxyModel::requestClose expands the group parent itself,
        // so driving the parent row closes every child window (parent semantics).
        const QVariantList children{window(KonsoleUrl), window(KonsoleUrl), window(KonsoleUrl)};
        model.setRows({window(DolphinUrl), groupRow(KonsoleUrl, children)});
        QVERIFY(index.close(Konsole));
        QCOMPARE(model.closeCalls(), QVariantList{1}); // the group-parent row, not its children
    }

    void groupedAndStandaloneRowsOperateAcrossAllWindows()
    {
        // Defensive topology the grouped model never produces: a group parent
        // AND a standalone window with the same desktop ID. Every matched row
        // contributes its windows — the group expands to children, the
        // standalone row rides along — so no window is unreachable.
        QVariantList children{window(KonsoleUrl, true), window(KonsoleUrl), window(KonsoleUrl)};
        model.setRows({groupRow(KonsoleUrl, children, true), window(DolphinUrl), window(KonsoleUrl)});
        QVERIFY(index.cycle(Konsole));
        QCOMPARE(model.activateCalls(), QVariantList{1}); // cycles within the children

        children = QVariantList{window(KonsoleUrl), window(KonsoleUrl), window(KonsoleUrl)};
        model.setRows({groupRow(KonsoleUrl, children), window(DolphinUrl), window(KonsoleUrl, true)});
        model.clearCalls();
        index.step(Konsole, -1);
        QCOMPARE(model.activateCalls(), QVariantList{2}); // the standalone window is a step target too
    }

    void unclaimedTasksListRowsMissingFromDesktopIds()
    {
        QVariantMap dolphin = titledWindow(DolphinUrl, "Dolphin", true);
        dolphin.insert("decoration", QIcon::fromTheme("utilities-terminal"));
        model.setRows({window(KonsoleUrl, true), dolphin,
                       titledWindow("file:///usr/share/applications/org.kde.kate.desktop", "Kate", false, true)});
        const QVariantList tasks = index.unclaimedTasks();
        QCOMPARE(tasks.size(), 2);

        const QVariantMap first = tasks.at(0).toMap();
        QCOMPARE(first.value("desktopId").toString(), QStringLiteral("org.kde.dolphin"));
        QCOMPARE(first.value("name").toString(), QStringLiteral("Dolphin"));
        QCOMPARE(first.value("icon").toString(), QStringLiteral("utilities-terminal"));
        QCOMPARE(first.value("active").toBool(), true);
        QCOMPARE(first.value("minimized").toBool(), false);
        QCOMPARE(first.value("count").toInt(), 1);

        const QVariantMap second = tasks.at(1).toMap();
        QCOMPARE(second.value("desktopId").toString(), QStringLiteral("org.kde.kate"));
        QCOMPARE(second.value("minimized").toBool(), true);
    }

    void unclaimedTasksEmptyWhenAllClaimed()
    {
        // desktopIds stores the .desktop-suffixed form; the row's URL carries none.
        model.setRows({window(QStringLiteral("applications:org.kde.konsole"))});
        QCOMPARE(index.unclaimedTasks(), QVariantList{});

        // The stripped form claims the suffixed URL too.
        index.setDesktopIds({QStringLiteral("org.kde.konsole")});
        model.setRows({window(KonsoleUrl)});
        QCOMPARE(index.unclaimedTasks(), QVariantList{});
    }

    void unclaimedTasksCountAGroupRowByItsWindows()
    {
        QVariantMap group{{"IsGroupParent", true}, {"IsActive", true}, {"LauncherUrl", DolphinUrl},
                          {"display", "Dolphin"},
                          {"children", QVariantList{window(DolphinUrl), window(DolphinUrl)}}};
        model.setRows({group});
        const QVariantList tasks = index.unclaimedTasks();
        QCOMPARE(tasks.size(), 1);
        const QVariantMap task = tasks.at(0).toMap();
        QCOMPARE(task.value("desktopId").toString(), QStringLiteral("org.kde.dolphin"));
        QCOMPARE(task.value("active").toBool(), true);
        QCOMPARE(task.value("count").toInt(), 2);
        QCOMPARE(task.value("icon").toString(), QStringLiteral("application-x-executable"));
    }

    void unclaimedTasksIncludeRowsWithoutADesktopEntry()
    {
        model.setRows({window(KonsoleUrl, true),
                       QVariantMap{{"IsWindow", true}, {"IsMinimized", true}, {"display", "Mystery"}},
                       titledWindow(DolphinUrl, "Dolphin")});
        const QVariantList tasks = index.unclaimedTasks();
        QCOMPARE(tasks.size(), 2);

        const QVariantMap first = tasks.at(0).toMap();
        QCOMPARE(first.value("desktopId").toString(), QString());
        QCOMPARE(first.value("name").toString(), QStringLiteral("Mystery"));
        QCOMPARE(first.value("icon").toString(), QStringLiteral("application-x-executable"));
        QCOMPARE(first.value("active").toBool(), false);
        QCOMPARE(first.value("minimized").toBool(), true);
        QCOMPARE(first.value("count").toInt(), 1);

        QCOMPARE(tasks.at(1).toMap().value("desktopId").toString(), QStringLiteral("org.kde.dolphin"));
    }

    void unclaimedTasksSkipLauncherRows()
    {
        model.setRows({QVariantMap{{"IsLauncher", true}, {"LauncherUrl", DolphinUrl}},
                       titledWindow(DolphinUrl, "Dolphin")});
        const QVariantList tasks = index.unclaimedTasks();
        QCOMPARE(tasks.size(), 1);
        QCOMPARE(tasks.at(0).toMap().value("desktopId").toString(), QStringLiteral("org.kde.dolphin"));
    }

    void revisionBumpsOnEveryModelChange()
    {
        QSignalSpy spy(&index, &TaskIndex::changed);
        int revision = index.revision();

        model.appendRow(window(KonsoleUrl));
        QVERIFY(index.revision() > revision);
        QCOMPARE(index.taskState(Konsole).value("count").toInt(), 1);
        revision = index.revision();

        model.updateRow(0, {{"IsActive", true}});
        QVERIFY(index.revision() > revision);
        QCOMPARE(index.taskState(Konsole).value("active").toBool(), true);
        revision = index.revision();

        model.removeRowAt(0);
        QVERIFY(index.revision() > revision);
        QCOMPARE(index.taskState(Konsole).value("running").toBool(), false);
        revision = index.revision();

        model.setRows({window(KonsoleUrl)});
        QVERIFY(index.revision() > revision);
        QCOMPARE(index.taskState(Konsole).value("count").toInt(), 1);
        QVERIFY(spy.count() >= 4);
    }

    void swappingModelOrDesktopIdsBumpsRevision()
    {
        model.setRows({window(KonsoleUrl)});
        QCOMPARE(index.taskState(Konsole).value("running").toBool(), true);

        int revision = index.revision();
        MockTasksModel other;
        index.setModel(&other);
        QVERIFY(index.revision() > revision);
        QCOMPARE(index.taskState(Konsole).value("running").toBool(), false);

        revision = index.revision();
        model.setRows({window(KonsoleUrl)});
        QCOMPARE(index.revision(), revision);

        other.setRows({window(KonsoleUrl)});
        QVERIFY(index.revision() > revision);
        QCOMPARE(index.taskState(Konsole).value("running").toBool(), true);

        revision = index.revision();
        index.setDesktopIds({"org.kde.dolphin.desktop"});
        QVERIFY(index.revision() > revision);
        QCOMPARE(index.desktopIds(), QStringList{"org.kde.dolphin.desktop"});

        revision = index.revision();
        index.setDesktopIds({"org.kde.dolphin.desktop"});
        QCOMPARE(index.revision(), revision);
        index.setModel(&model);
    }

    void nullModelIsTolerated()
    {
        index.setModel(nullptr);
        QCOMPARE(index.taskState(Konsole).value("running").toBool(), false);
        QCOMPARE(index.unclaimedTasks(), QVariantList{});
        QVERIFY(!index.activate(Konsole));
    }

    void missingRolesAreTolerated()
    {
        QStandardItemModel bare;
        bare.appendRow(new QStandardItem("x"));
        index.setModel(&bare);
        QCOMPARE(index.taskState(Konsole).value("running").toBool(), false);
        index.setModel(&model);
    }
};

QTEST_MAIN(TaskIndexTest)
#include "tst_taskindex.moc"
