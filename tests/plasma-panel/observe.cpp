// Loaded only into the disposable plasmashell. Observes Qt events without
// accepting them or changing the applet, menu, or event delivery.
#include <QApplication>
#include <QEvent>
#include <QJsonArray>
#include <QJsonDocument>
#include <QJsonObject>
#include <QMenu>
#include <QMouseEvent>
#include <QQuickItem>
#include <QQuickWindow>
#include <QElapsedTimer>
#include <QMetaEnum>
#include <QWindow>
#include <cstdio>

class Observer final : public QObject
{
public:
    using QObject::QObject;

private:
    QElapsedTimer clock;

    static void buttons(QQuickItem *item, QJsonArray &result)
    {
        const auto model = item->property("modelData").toMap();
        if (model.contains("id") && item->metaObject()->indexOfProperty("hovered") >= 0) {
            const auto r = item->mapRectToScene(item->boundingRect());
            result.append(QJsonObject{{"id", model.value("id").toString()},
                                      {"hovered", item->property("hovered").toBool()},
                                      {"geometry", QJsonArray{r.x(), r.y(), r.width(), r.height()}}});
        }
        for (auto *child : item->childItems()) buttons(child, result);
    }

    bool eventFilter(QObject *object, QEvent *event) override
    {
        if (!clock.isValid()) clock.start();
        const auto type = event->type();
        const bool button = type == QEvent::MouseButtonPress || type == QEvent::MouseButtonRelease;
        if (type != QEvent::Show && type != QEvent::Hide && type != QEvent::Enter
            && type != QEvent::Leave && type != QEvent::WindowActivate && type != QEvent::WindowDeactivate && !button)
            return false;
        QJsonObject record{{"event", QString(QMetaEnum::fromType<QEvent::Type>().valueToKey(type))},
                           {"class", object->metaObject()->className()}, {"ms", clock.elapsed()}};
        if (const auto *menu = qobject_cast<QMenu *>(object)) {
            QJsonArray actions;
            for (const auto *action : menu->actions()) {
                if (!action->isSeparator() && action->isVisible())
                    actions.append(QJsonObject{{"text", action->text()}, {"enabled", action->isEnabled()}});
            }
            record.insert("actions", actions);
        } else if (const auto *window = qobject_cast<QWindow *>(object)) {
            const auto r = window->geometry();
            record.insert("geometry", QJsonArray{r.x(), r.y(), r.width(), r.height()});
            record.insert("title", window->title());
            if (window->metaObject()->indexOfProperty("openedAt") >= 0)
                record.insert("stackPopup", true);
            if (button) {
                const auto *mouse = static_cast<QMouseEvent *>(event);
                const auto pos = mouse->position();
                record.insert("button", int(mouse->button()));
                record.insert("position", QJsonArray{pos.x(), pos.y()});
                if (const auto *quick = qobject_cast<QQuickWindow *>(object)) {
                    QJsonArray items;
                    buttons(quick->contentItem(), items);
                    record.insert("buttons", items);
                }
            }
        } else {
            return false;
        }
        const auto json = QJsonDocument(record).toJson(QJsonDocument::Compact);
        std::fprintf(stderr, "TLB_PANEL_EVENT %s\n", json.constData());
        return false;
    }
};

static void installObserver()
{
    if (auto *app = QCoreApplication::instance())
        app->installEventFilter(new Observer(app));
}
Q_COREAPP_STARTUP_FUNCTION(installObserver)
