#include "../../src/folderpopup.h"
#include "../../src/stackentry.h"
#include "../../src/foldersource.h"
#include "../../src/folderreader.h"
#include "../../src/launcher.h"
#include <QQuickWindow>
#include <QQuickItem>
#include <QMouseEvent>
#include <QStandardPaths>
#include <QtTest>
#include <QTemporaryDir>
#include <QFile>
#include <QDir>
#include <QStyle>
#include <QQmlEngine>
#include <QQmlComponent>
#include <QQmlExpression>
#include <QJsonDocument>
#include <QJsonArray>

class FolderPopupTest : public QObject {
    Q_OBJECT
private slots:
    void initTestCase() { qRegisterMetaType<QQuickItem *>("QQuickItem*"); }
    void customLauncherPassesLiteralArguments() {
        QTemporaryDir dir;
        const QString output = dir.filePath("result");
        const QString script = dir.filePath("test executable");
        QFile executable(script);
        QVERIFY(executable.open(QIODevice::WriteOnly));
        executable.write("#!/usr/bin/python3\nimport sys,json\nwith open(sys.argv[1], 'w') as f: json.dump(sys.argv[2:], f)\n");
        executable.close();
        QVERIFY(executable.setPermissions(QFile::ReadOwner | QFile::WriteOwner | QFile::ExeOwner));
        Launcher launcher;
        const QString id = "tlbstacks-command:1";
        const QStringList args{output, "two words", "", "$HOME", ";echo nope", "a\"b"};
        const QVariantMap custom{{id, QVariantMap{{"name", "Custom"}, {"executable", script}, {"arguments", args}}}};
        const auto entries = launcher.applicationEntries({id}, {}, "applications", custom);
        QCOMPARE(entries.size(), 1);
        const auto entry = entries.first().toMap();
        QCOMPARE(entry.value("name").toString(), QString("Custom"));
        QVERIFY(entry.value("actions").toStringList().contains("removeFromStack"));
        QVERIFY(launcher.activateEntry(entry));
        QTRY_VERIFY(QFileInfo::exists(output));
        QFile result(output); QVERIFY(result.open(QIODevice::ReadOnly));
        const auto actual = QJsonDocument::fromJson(result.readAll()).array().toVariantList();
        QCOMPARE(actual, QVariant(args.mid(1)).toList());
        auto missing = entry;
        missing["target"] = dir.filePath("missing");
        QSignalSpy error(&launcher, &Launcher::activationFailed);
        QVERIFY(!launcher.activateEntry(missing));
        QCOMPARE(error.count(), 1);
    }
    void asyncRootRefreshAndFilterChange() {
        QTemporaryDir dir;
        QFile file(dir.filePath("one.txt"));
        QVERIFY(file.open(QIODevice::WriteOnly)); file.close();
        FolderSource source;
        source.setFolder(QUrl::fromLocalFile(dir.path()));
        source.setFilters({"*.txt"});
        source.setActive(true);
        QTRY_COMPARE(source.entries().size(), 1);
        QVERIFY(source.available());
        QFile second(dir.filePath("two.txt"));
        QVERIFY(second.open(QIODevice::WriteOnly)); second.close();
        QTRY_COMPARE(source.entries().size(), 2);
        source.setFilters({"*.pdf"});
        QTRY_VERIFY(!source.loading());
        QCOMPARE(source.entries().size(), 0);
        source.setActive(false);
        QVERIFY(!source.loading());
    }
    void sharedReadAndAbandonment() {
        QTemporaryDir dir;
        QFile file(dir.filePath("one.txt"));
        QVERIFY(file.open(QIODevice::WriteOnly)); file.close();
        auto *abandoned = new QObject;
        bool unwanted = false, received = false;
        requestFolder(abandoned, QUrl::fromLocalFile(dir.path()), {},
                      [&](const FolderListing &) { unwanted = true; });
        delete abandoned;
        QObject survivor;
        requestFolder(&survivor, QUrl::fromLocalFile(dir.path()), {},
                      [&](const FolderListing &result) { received = result.available && result.entries.size() == 1; });
        QTRY_VERIFY(received);
        QVERIFY(!unwanted);
    }
    void folderQueueIsBounded() {
        QTemporaryDir dir;
        QObject context;
        int completed = 0, busy = 0;
        for (int i = 0; i < 20; ++i) {
            const auto name = QString::number(i);
            QVERIFY(QDir(dir.path()).mkpath(name));
            requestFolder(&context, QUrl::fromLocalFile(dir.filePath(name)), {},
                          [&](const FolderListing &result) {
                ++completed;
                if (!result.error.isEmpty()) ++busy;
            });
        }
        QTRY_COMPARE(completed, 20);
        QVERIFY(busy >= 12); // at most eight unique requests admitted before dispatch
    }
    void launcherPointerHandoffAndHighlight() {
        QTemporaryDir dir;
        QQuickWindow window;
        window.setGeometry(20, 20, 300, 300);
        window.show();
        QQuickItem anchor(window.contentItem());
        anchor.setSize(QSizeF(100, 40));
        Launcher launcher(nullptr, false); // isolate GUI bridge from system catalog
        QSignalSpy highlights(&launcher, &Launcher::folderAnchorHighlightChanged);
        launcher.showFolderMenu(&anchor, QUrl::fromLocalFile(dir.path()), {}, 0);
        QMenu *menu = nullptr;
        for (auto *widget : QApplication::topLevelWidgets())
            if (auto *candidate = qobject_cast<QMenu *>(widget); candidate && candidate->isVisible()) menu = candidate;
        QVERIFY(menu);
        QTRY_COMPARE(menu->actions().first()->text(), QString("No files match these patterns"));
        menu->move(500, 20);
        QCOMPARE(highlights.count(), 1);
        QCOMPARE(qvariant_cast<QQuickItem *>(highlights.first().first()), &anchor);
        QObject receiver;
        auto move = [&](QPoint global) {
            QMouseEvent event(QEvent::MouseMove, QPointF(0, 0), QPointF(global),
                              Qt::NoButton, Qt::NoButton, Qt::NoModifier);
            QCoreApplication::sendEvent(&receiver, &event);
        };
        move(anchor.mapToGlobal(QPointF(10, 10)).toPoint());
        QVERIFY(menu->isVisible());
        QCOMPARE(highlights.count(), 1); // opening alone preserves the highlight
        move(menu->frameGeometry().center());
        QCOMPARE(highlights.count(), 2);
        QVERIFY(highlights.last().first().value<QQuickItem *>() == nullptr);
        move(window.mapToGlobal(QPoint(10, 100)));
        QVERIFY(!menu->isVisible());
        QVERIFY(highlights.last().first().value<QQuickItem *>() == nullptr);
    }
    void outsidePressDismissesWholeStack() {
        QTemporaryDir dir;
        QQuickWindow window;
        window.setGeometry(20, 20, 300, 300); window.show();
        QQuickItem anchor(window.contentItem()); anchor.setSize(QSizeF(100, 40));
        Launcher launcher(nullptr, false);
        QSignalSpy dismissed(&launcher, &Launcher::folderDismissRequested);
        launcher.showFolderMenu(&anchor, QUrl::fromLocalFile(dir.path()), {}, 0);
        QMenu *menu = nullptr;
        for (auto *widget : QApplication::topLevelWidgets())
            if (auto *candidate = qobject_cast<QMenu *>(widget); candidate && candidate->isVisible()) menu = candidate;
        QVERIFY(menu);
        QTRY_COMPARE(menu->actions().first()->text(), QString("No files match these patterns"));
        menu->move(400, 20);
        auto *child = new QMenu(menu);
        child->addAction("Nested file");
        child->popup(QPoint(600, 20));
        QObject receiver;
        auto press = [&](QPoint global) {
            QMouseEvent event(QEvent::MouseButtonPress, QPointF(0, 0), QPointF(global),
                              Qt::LeftButton, Qt::LeftButton, Qt::NoModifier);
            QCoreApplication::sendEvent(&receiver, &event);
        };
        press(anchor.mapToGlobal(QPointF(10, 10)).toPoint());
        QCOMPARE(dismissed.count(), 0);
        press(child->frameGeometry().center());
        QCOMPARE(dismissed.count(), 0);
        press(menu->frameGeometry().center());
        QCOMPARE(dismissed.count(), 0);
        press(QPoint(-100, -100));
        QCOMPARE(dismissed.count(), 1);
        QVERIFY(!menu->isVisible());
        press(QPoint(-100, -100));
        QCOMPARE(dismissed.count(), 1);
    }
    void nativeDismissalWithoutMousePress() {
        QTemporaryDir dir;
        QQuickWindow window; window.setGeometry(20, 20, 300, 300); window.show();
        QQuickItem anchor(window.contentItem()); anchor.setSize(QSizeF(100, 40));
        Launcher launcher(nullptr, false);
        QSignalSpy dismissed(&launcher, &Launcher::folderDismissRequested);
        auto open = [&]() -> QMenu * {
            launcher.showFolderMenu(&anchor, QUrl::fromLocalFile(dir.path()), {}, 0);
            for (auto *widget : QApplication::topLevelWidgets())
                if (auto *menu = qobject_cast<QMenu *>(widget); menu && menu->isVisible()) return menu;
            return nullptr;
        };
        QVERIFY(open());
        launcher.closeFolderMenu(); // pointer return / programmatic close
        QCoreApplication::processEvents();
        QCOMPARE(dismissed.count(), 0);
        auto *menu = open(); QVERIFY(menu);
        menu->close(); // compositor/native dismissal, no QMouseEvent
        QTRY_COMPARE(dismissed.count(), 1);
    }
    void rightClickOffersTrashWithoutLaunching() {
        QTemporaryDir dir;
        QFile file(dir.filePath("example.txt"));
        QVERIFY(file.open(QIODevice::WriteOnly)); file.close();
        QVariantList operations;
        FolderPopup menu(QUrl::fromLocalFile(dir.path()), {},
                         [&](const QVariantMap &entry) { operations.append(entry); });
        menu.popup(QPoint(20, 20));
        QTRY_COMPARE(menu.actions().first()->text(), QString("example.txt"));
        QTest::mouseClick(&menu, Qt::RightButton, Qt::NoModifier,
                          menu.actionGeometry(menu.actions().first()).center());
        QCOMPARE(operations.size(), 0);
        QMenu *context = nullptr;
        for (auto *child : menu.findChildren<QMenu *>()) if (child->isVisible()) context = child;
        QVERIFY(context);
        QCOMPARE(context->actions().size(), 1);
        QCOMPARE(context->actions().first()->text(), QString("Move to Trash"));
        context->actions().first()->trigger();
        QCOMPARE(operations.size(), 1);
        QCOMPARE(operations.first().toMap().value("action").toString(), QString("moveToTrash"));
        QCOMPARE(operations.first().toMap().value("target").toString(), QUrl::fromLocalFile(file.fileName()).toString());
        QVERIFY(file.exists()); // test callback records intent; never trashes user files
    }
    void leftReturnsFocusWithoutDismissingRoot() {
        QTemporaryDir dir;
        QQuickWindow window; window.setGeometry(20, 20, 300, 300); window.show();
        QQuickItem anchor(window.contentItem()); anchor.setSize(QSizeF(100, 40));
        Launcher launcher(nullptr, false);
        QSignalSpy dismissed(&launcher, &Launcher::folderDismissRequested);
        QSignalSpy returned(&launcher, &Launcher::folderFocusRequested);
        launcher.showFolderMenu(&anchor, QUrl::fromLocalFile(dir.path()), {}, 0);
        QMenu *menu = nullptr;
        for (auto *widget : QApplication::topLevelWidgets())
            if (auto *candidate = qobject_cast<QMenu *>(widget); candidate && candidate->isVisible()) menu = candidate;
        QVERIFY(menu);
        QTest::keyClick(menu, Qt::Key_Left);
        QCOMPARE(returned.count(), 1);
        QCOMPARE(returned.first().first().value<QQuickItem *>(), &anchor);
        QVERIFY(!menu->isVisible());
        QCoreApplication::processEvents();
        QCOMPARE(dismissed.count(), 0);
        QCOMPARE(window.activeFocusItem(), &anchor);
        launcher.showFolderMenu(&anchor, QUrl::fromLocalFile(dir.path()), {}, 0);
        for (auto *widget : QApplication::topLevelWidgets())
            if (auto *candidate = qobject_cast<QMenu *>(widget); candidate && candidate->isVisible()) menu = candidate;
        QTest::keyClick(menu, Qt::Key_Escape);
        QTRY_COMPARE(dismissed.count(), 1);
    }
    void keyboardSelectionSurvivesAsyncNestedLoading() {
        QTemporaryDir dir;
        QVERIFY(QDir(dir.path()).mkpath("child/grandchild"));
        QFile file(dir.filePath("child/grandchild/test.txt"));
        QVERIFY(file.open(QIODevice::WriteOnly)); file.close();
        FolderPopup menu(QUrl::fromLocalFile(dir.path()), {}, [](const QVariantMap &) {});
        menu.enterKeyboardMode();
        menu.popup(QPoint(20, 20));
        QTRY_VERIFY(menu.activeAction());
        QCOMPARE(menu.activeAction()->text(), QString("child"));
        auto *child = menu.activeAction()->menu(); QVERIFY(child);
        QTest::keyClick(&menu, Qt::Key_Right);
        QTRY_VERIFY(child->isVisible());
        QTRY_VERIFY(child->activeAction());
        QCOMPARE(child->activeAction()->text(), QString("grandchild"));
        auto *grandchild = child->activeAction()->menu(); QVERIFY(grandchild);
        QTest::keyClick(child, Qt::Key_Right);
        QTRY_VERIFY(grandchild->isVisible());
        QTRY_VERIFY(grandchild->activeAction());
        QCOMPARE(grandchild->activeAction()->text(), QString("test.txt"));
        menu.close();
    }
    void previewsKeepKeyboardInParentUntilRight() {
        QTemporaryDir dir;
        QVERIFY(QDir(dir.path()).mkpath("child/grandchild"));
        QFile file(dir.filePath("child/grandchild/test.txt"));
        QVERIFY(file.open(QIODevice::WriteOnly)); file.close();
        int navigation = 0, entered = 0;
        FolderPopup menu(QUrl::fromLocalFile(dir.path()), {}, [](const QVariantMap &) {});
        menu.previewNavigation = [&](int step) { navigation += step; };
        menu.keyboardEntered = [&] { ++entered; };
        menu.popup(QPoint(20, 20));
        QTRY_COMPARE(menu.actions().first()->text(), QString("child"));
        QTest::keyClick(&menu, Qt::Key_Down);
        QCOMPARE(navigation, 1);
        QCOMPARE(entered, 0);
        QVERIFY(!menu.activeAction());
        QTest::keyClick(&menu, Qt::Key_Right);
        QCOMPARE(entered, 1);
        QCOMPARE(menu.activeAction(), menu.actions().first());
        auto *child = menu.activeAction()->menu(); QVERIFY(child);
        // Model a submenu already opened by the parent selection's delay.
        child->popup(QPoint(300, 20));
        QTRY_COMPARE(child->actions().first()->text(), QString("grandchild"));
        QVERIFY(!child->activeAction());
        QTest::keyClick(child, Qt::Key_Right);
        QCOMPARE(child->activeAction(), child->actions().first());
        auto *grandchild = child->activeAction()->menu(); QVERIFY(grandchild);
        grandchild->popup(QPoint(500, 20));
        QTRY_COMPARE(grandchild->actions().first()->text(), QString("test.txt"));
        QTest::keyClick(grandchild, Qt::Key_Right);
        QCOMPARE(grandchild->activeAction(), grandchild->actions().first());
        QTest::keyClick(grandchild, Qt::Key_Left);
        QVERIFY(!grandchild->isVisible());
        QCOMPARE(child->activeAction(), grandchild->menuAction());
        QTest::keyClick(child, Qt::Key_Left);
        QVERIFY(!child->isVisible());
        QCOMPARE(menu.activeAction(), child->menuAction());
        menu.close();
    }
    void rightEntersHoverOpenedFolder() {
        QTemporaryDir dir;
        QFile file(dir.filePath("test.txt"));
        QVERIFY(file.open(QIODevice::WriteOnly)); file.close();
        QQuickWindow window; window.setGeometry(20, 20, 300, 300); window.show();
        QQuickItem anchor(window.contentItem()); anchor.setSize(QSizeF(100, 40));
        Launcher launcher(nullptr, false);
        QSignalSpy entered(&launcher, &Launcher::folderKeyboardEntered);
        QSignalSpy returned(&launcher, &Launcher::folderFocusRequested);
        QSignalSpy dismissed(&launcher, &Launcher::folderDismissRequested);
        // Default arguments match a mouse-hover opening, not keyboard preview.
        launcher.showFolderMenu(&anchor, QUrl::fromLocalFile(dir.path()), {}, 0);
        QMenu *menu = nullptr;
        for (auto *widget : QApplication::topLevelWidgets())
            if (auto *candidate = qobject_cast<QMenu *>(widget); candidate && candidate->isVisible()) menu = candidate;
        QVERIFY(menu);
        QTRY_COMPARE(menu->actions().first()->text(), QString("test.txt"));
        QVERIFY(!menu->activeAction());
        QTest::keyClick(menu, Qt::Key_Right);
        QCOMPARE(entered.count(), 1);
        QCOMPARE(menu->activeAction(), menu->actions().first());
        QTest::keyClick(menu, Qt::Key_Left);
        QCOMPARE(returned.count(), 1);
        QCOMPARE(returned.first().first().value<QQuickItem *>(), &anchor);
        QCoreApplication::processEvents();
        QCOMPARE(dismissed.count(), 0);
        QVERIFY(!menu->isVisible());
    }
    void selectedRemovalCapability() {
        Launcher launcher(nullptr, false);
        QQuickWindow window;
        window.setGeometry(20, 20, 300, 300); window.show();
        QQuickItem anchor(window.contentItem()); anchor.setSize(QSizeF(100, 40));
        QSignalSpy removed(&launcher, &Launcher::removeApplicationRequested);
        const auto category = StackEntry::applicationData("example", "categories", "", {});
        launcher.showEntryContextMenu(&anchor, category);
        QCOMPARE(removed.count(), 0);
        const auto selected = StackEntry::applicationData("example", "applications", "", {});
        launcher.showEntryContextMenu(&anchor, selected);
        QMenu *menu = nullptr;
        for (auto *widget : QApplication::topLevelWidgets())
            if (auto *candidate = qobject_cast<QMenu *>(widget); candidate && candidate->isVisible()) menu = candidate;
        QVERIFY(menu);
        menu->actions().first()->trigger();
        QTRY_COMPARE(removed.count(), 1);
        QCOMPARE(removed.first().first().toString(), QString("example"));
        launcher.closeApplicationContextMenu();
    }
    void profileDoesNotBlockAndRejectsOverlap() {
        QTemporaryDir dir;
        const auto previous = qgetenv("XDG_DATA_HOME");
        qputenv("XDG_DATA_HOME", dir.path().toUtf8());
        const QString relative = "plasma/plasmoids/com.mattphilmon.tlbstacks/contents/code";
        QVERIFY(QDir(dir.path()).mkpath(relative));
        QFile helper(dir.filePath(relative + "/profile.py"));
        QVERIFY(helper.open(QIODevice::WriteOnly));
        helper.write("import time,json,sys\njson.load(sys.stdin)\ntime.sleep(0.25)\nprint(json.dumps({'ok':True,'icon':'test'}))\n");
        helper.close();
        Launcher launcher(nullptr, false);
        QSignalSpy results(&launcher, &Launcher::profileFinished);
        bool ticked = false;
        QTimer::singleShot(20, &launcher, [&] { ticked = true; });
        const auto request = launcher.profileOperation("manageIcon", {{"icon", "test"}});
        QVERIFY(launcher.profileBusy());
        QCOMPARE(results.count(), 0);
        launcher.profileOperation("manageIcon", {{"icon", "other"}});
        QTRY_VERIFY(ticked);
        QTRY_COMPARE(results.count(), 2);
        QVERIFY(!launcher.profileBusy());
        bool success = false, rejected = false;
        for (const auto &result : results) {
            if (result.first().toULongLong() == request) success = result.at(1).toMap().value("ok").toBool();
            else rejected = !result.at(1).toMap().value("ok").toBool();
        }
        QVERIFY(success); QVERIFY(rejected);
        if (previous.isNull()) qunsetenv("XDG_DATA_HOME"); else qputenv("XDG_DATA_HOME", previous);
    }
    void entryCapabilitiesAndIdentity() {
        const QString id = "tlb-test-intentionally-missing-application";
        const auto selected = StackEntry::applicationData(id, "applications", "custom-icon", {});
        const auto category = StackEntry::applicationData(id, "categories", "custom-icon", {});
        QCOMPARE(selected.value("id").toString(), category.value("id").toString());
        QCOMPARE(selected.value("icon").toString(), QString("custom-icon"));
        QVERIFY(!selected.value("available").toBool());
        QVERIFY(!selected.value("isSeparator").toBool());
        QVERIFY(selected.value("actions").toStringList().contains("removeFromStack"));
        QVERIFY(category.value("actions").toStringList().isEmpty());
        QTemporaryDir dir;
        QFile file(dir.filePath("document.txt"));
        QVERIFY(file.open(QIODevice::WriteOnly));
        file.close();
        const auto folder = StackEntry::file(QUrl::fromLocalFile(dir.path()));
        const auto document = StackEntry::file(QUrl::fromLocalFile(file.fileName()));
        QVERIFY(folder.value("hasChildren").toBool());
        QCOMPARE(folder.value("action").toString(), QString("openChildren"));
        QVERIFY(!document.value("hasChildren").toBool());
        QCOMPARE(document.value("action").toString(), QString("openFile"));
        QCOMPARE(document.value("actions").toStringList(), QStringList{"moveToTrash"});
        QCOMPARE(document.value("name").toString(), QString("document.txt"));
    }
    void delayReachesNestedMenus() {
        QTemporaryDir dir;
        QVERIFY(QDir(dir.path()).mkpath("child/grandchild"));
        const int original = QApplication::style()->styleHint(QStyle::SH_Menu_SubMenuPopupDelay);
        for (int delay : {0, 75, 250, 2000}) {
            FolderPopup menu(QUrl::fromLocalFile(dir.path()), {}, [](const QVariantMap &) {}, nullptr, delay);
            QCOMPARE(menu.style()->styleHint(QStyle::SH_Menu_SubMenuPopupDelay), delay);
            menu.popup(QPoint(20, 20));
            QTRY_VERIFY(menu.actions().first()->menu());
            auto *child = menu.actions().first()->menu();
            QVERIFY(child);
            QCOMPARE(child->style()->styleHint(QStyle::SH_Menu_SubMenuPopupDelay), delay);
            child->popup(QPoint(200, 20));
            QTRY_VERIFY(child->actions().first()->menu());
            auto *grandchild = child->actions().first()->menu();
            QVERIFY(grandchild);
            QCOMPARE(grandchild->style()->styleHint(QStyle::SH_Menu_SubMenuPopupDelay), delay);
            grandchild->close();
            child->close();
            menu.close();
        }
        QCOMPARE(QApplication::style()->styleHint(QStyle::SH_Menu_SubMenuPopupDelay), original);
    }
    void filteringReopenAndLifecycle() {
        QTemporaryDir dir;
        QVERIFY(dir.isValid());
        QVERIFY(QDir(dir.path()).mkpath("child/grandchild"));
        for (const auto &name : {"one.txt", "ignored.md", ".hidden.txt", "child/two.txt"}) {
            QFile file(dir.filePath(name));
            QVERIFY(file.open(QIODevice::WriteOnly));
        }
        QUrl opened;
        FolderPopup menu(QUrl::fromLocalFile(dir.path()), {"*.txt"},
                         [&](const QVariantMap &entry) { opened = QUrl(entry.value("target").toString()); });
        menu.popup(QPoint(20, 20));
        QTRY_VERIFY(menu.isVisible());
        QTRY_COMPARE(menu.actions().size(), 2);
        auto *child = menu.actions().first()->menu();
        QVERIFY(child);
        QVERIFY(child->actions().isEmpty()); // no recursive filesystem walk
        child->popup(QPoint(200, 20));
        QTRY_VERIFY(child->isVisible());
        QTRY_COMPARE(child->actions().size(), 2);
        child->actions().last()->trigger();
        QCOMPARE(opened, QUrl::fromLocalFile(dir.filePath("child/two.txt")));
        QFile added(dir.filePath("child/added.txt"));
        QVERIFY(added.open(QIODevice::WriteOnly));
        added.close();
        QTest::qWait(100);
        QCOMPARE(child->actions().size(), 2); // stable snapshot while open
        child->close();
        child->popup(QPoint(200, 20));
        QTRY_COMPARE(child->actions().size(), 3); // refreshed on reopening
        child->close();
        QPointer<QMenu> oldChild = child;
        menu.close();
        QVERIFY(QFile::remove(dir.filePath("one.txt")));
        menu.popup(QPoint(20, 20));
        QTRY_VERIFY(menu.isVisible());
        QVERIFY(oldChild.isNull());
        QTRY_VERIFY(menu.actions().first()->menu());
        QCOMPARE(menu.actions().size(), 1);
        menu.close();
        for (int i = 0; i < 30; ++i) {
            menu.popup(QPoint(20, 20));
            QTRY_VERIFY(menu.actions().first()->menu());
        QCOMPARE(menu.actions().size(), 1);
            menu.close();
        }
    }
    void rootAndChildListingAgree() {
        QTemporaryDir dir;
        QVERIFY(QDir(dir.path()).mkpath("zFolder"));
        QVERIFY(QDir(dir.path()).mkpath("AFolder"));
        QVERIFY(QDir(dir.path()).mkpath(".hiddenFolder"));
        for (const auto &name : {"Z.TXT", "a.txt", "b.md", "ignored.png", ".hidden.txt"}) {
            QFile file(dir.filePath(name));
            QVERIFY(file.open(QIODevice::WriteOnly));
        }
        QQmlEngine engine;
        QQmlComponent component(&engine);
        component.setData(R"(
            import QtQuick
            import Qt.labs.folderlistmodel
            FolderListModel {
                nameFilters: ["*.txt", "*.md"]
                showFiles: true; showDirs: true; showDirsFirst: true
                showDotAndDotDot: false; showHidden: false
                caseSensitive: false
                sortField: FolderListModel.Name; sortCaseSensitive: false
                property string listing: {
                    let names = []
                    for (let i = 0; i < count; ++i) names.push(get(i, "fileName"))
                    return names.join("|")
                }
            }
        )", QUrl());
        QScopedPointer<QObject> model(component.create());
        QVERIFY2(model, qPrintable(component.errorString()));
        model->setProperty("folder", QUrl::fromLocalFile(dir.path()));
        QTRY_COMPARE(model->property("count").toInt(), 5);
        FolderPopup menu(QUrl::fromLocalFile(dir.path()), {"*.txt", "*.md"}, [](const QVariantMap &) {});
        menu.popup(QPoint(20, 20));
        QTRY_COMPARE(menu.actions().size(), 5);
        QStringList names;
        for (auto *action : menu.actions()) names.append(action->toolTip());
        QCOMPARE(names.join('|'), model->property("listing").toString());
        FolderSource rootSource;
        rootSource.setFolder(QUrl::fromLocalFile(dir.path()));
        rootSource.setFilters({"*.txt", "*.md"});
        rootSource.setActive(true);
        QTRY_COMPARE(rootSource.entries().size(), 5);
        QStringList sourceNames;
        for (const auto &entry : rootSource.entries()) sourceNames.append(entry.toMap().value("name").toString());
        QCOMPARE(names, sourceNames);
        menu.close();
    }
    void closeDuringLoad() {
        QTemporaryDir dir;
        for (int i = 0; i < 20; ++i) {
            auto *menu = new FolderPopup(QUrl::fromLocalFile(dir.path()), {}, [](const QVariantMap &) {});
            menu->popup(QPoint(20, 20));
            QCOMPARE(menu->actions().first()->text(), QString("Loading…"));
            menu->close();
            delete menu; // worker must not access destroyed widgets
        }
        QTest::qWait(100);
    }
    void unavailableAndEmpty() {
        QTemporaryDir dir;
        FolderPopup empty(QUrl::fromLocalFile(dir.path()), {"*.txt"}, [](const QVariantMap &) {});
        empty.popup(QPoint(20, 20));
        QTRY_COMPARE(empty.actions().first()->text(), QString("No files match these patterns"));
        QCOMPARE(empty.actions().size(), 1);
        QVERIFY(!empty.actions().first()->isEnabled());
        empty.close();
        FolderPopup missing(QUrl::fromLocalFile(dir.filePath("missing")), {}, [](const QVariantMap &) {});
        missing.popup(QPoint(20, 20));
        QTRY_COMPARE(missing.actions().first()->text(), QString("Folder is unavailable"));
        QCOMPARE(missing.actions().size(), 1);
        QVERIFY(!missing.actions().first()->isEnabled());
        missing.close();
    }
};
QTEST_MAIN(FolderPopupTest)
#include "test.moc"
