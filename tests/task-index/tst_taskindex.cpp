#include "../../src/taskindex.h"
#include "mocktasksmodel.h"

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

QVariantMap window(const QString &url, bool active = false, bool minimized = false)
{
    return {{"IsWindow", true}, {"IsActive", active}, {"IsMinimized", minimized}, {"LauncherUrl", url}};
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
