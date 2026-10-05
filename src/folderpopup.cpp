#include "folderpopup.h"
#include "folderreader.h"

#include <QIcon>
#include <QMouseEvent>
#include <QKeyEvent>
#include <QCoreApplication>
#include <QContextMenuEvent>
#include <QProxyStyle>

namespace {
class FolderMenuStyle : public QProxyStyle
{
public:
    explicit FolderMenuStyle(int delay) : m_delay(delay) {}
    int styleHint(StyleHint hint, const QStyleOption *option = nullptr,
                  const QWidget *widget = nullptr, QStyleHintReturn *data = nullptr) const override
    {
        if (hint == SH_Menu_SubMenuPopupDelay) return m_delay;
        return QProxyStyle::styleHint(hint, option, widget, data);
    }
private:
    int m_delay;
};
}


FolderPopup::FolderPopup(const QUrl &folder, const QStringList &filters,
                         ActivateEntry activateEntry, QWidget *parent, int hoverDelay)
    : QMenu(parent), m_hoverDelay(qBound(0, hoverDelay, 2000)), m_folder(folder), m_filters(filters), m_activateEntry(std::move(activateEntry))
{
    // A private style copy changes only these menus, never Plasma's global style.
    auto *menuStyle = new FolderMenuStyle(m_hoverDelay);
    menuStyle->setParent(this);
    setStyle(menuStyle);
    setToolTipsVisible(true);
    connect(this, &QMenu::aboutToShow, this, [this] { populate(); });
    connect(this, &QMenu::aboutToHide, this, [this] { delete m_request; m_selectFirstWhenReady = false; m_keyboardEntered = false; });
}

void FolderPopup::populate()
{
    // Explicitly release owned child menus before clearing their actions.
    const auto oldActions = actions();
    for (auto *action : oldActions) {
        if (auto *child = action->menu()) delete child;
    }
    clear();
    addAction(tr("Loading…"))->setEnabled(false);
    delete m_request;
    auto *token = new QObject(this);
    m_request = token;
    requestFolder(token, m_folder, m_filters, [this, token](const FolderListing &listing) {
        m_request = nullptr;
        token->deleteLater();
        if (!isVisible()) return;
        clear();
        if (!listing.available) {
            addAction(listing.error.isEmpty() ? tr("Folder is unavailable") : listing.error)->setEnabled(false);
            return;
        }
        for (const auto &value : listing.entries) {
            const auto entry = value.toMap();
            const auto iconName = entry.value("icon").toString();
            const auto url = QUrl(entry.value("target").toString());
            const auto name = entry.value("name").toString();
            const QIcon icon = iconName.startsWith('/')
                ? QIcon(iconName) : QIcon::fromTheme(iconName);
            const QString label = QString(name).replace('&', QStringLiteral("&&"));
            QAction *action;
            if (entry.value("hasChildren").toBool()) {
                auto *child = new FolderPopup(url, m_filters, m_activateEntry, this, m_hoverDelay);
                child->setTitle(label);
                child->setIcon(icon);
                action = addMenu(child);
            } else {
                action = addAction(icon, label);
                connect(action, &QAction::triggered, this,
                        [open = m_activateEntry, entry]() { open(entry); });
            }
            action->setData(entry);
            action->setToolTip(name);
        }
        if (actions().isEmpty()) addAction(tr("No files match these patterns"))->setEnabled(false);
        if (m_selectFirstWhenReady) enterKeyboardMode();
    });

}

void FolderPopup::mousePressEvent(QMouseEvent *event)
{
    if (event->button() == Qt::RightButton) { event->accept(); return; }
    QMenu::mousePressEvent(event);
}
void FolderPopup::mouseReleaseEvent(QMouseEvent *event)
{
    if (event->button() == Qt::RightButton) {
        showFileActions(actionAt(event->position().toPoint()), event->globalPosition().toPoint());
        event->accept();
        return;
    }
    QMenu::mouseReleaseEvent(event);
}
void FolderPopup::contextMenuEvent(QContextMenuEvent *event)
{
    if (event->reason() == QContextMenuEvent::Keyboard) {
        auto *action = activeAction();
        showFileActions(action, mapToGlobal(actionGeometry(action).center()));
    }
    event->accept(); // mouse context menus are handled on release; never launch
}
void FolderPopup::showFileActions(QAction *action, const QPoint &globalPosition)
{
    if (!action) return;
    const auto entry = action->data().toMap();
    if (!entry.value("actions").toStringList().contains("moveToTrash")) return;
    if (m_fileActions) delete m_fileActions;
    m_fileActions = new QMenu(this);
    auto *trash = m_fileActions->addAction(tr("Move to Trash"));
    connect(trash, &QAction::triggered, this, [this, entry] {
        auto operation = entry;
        operation["action"] = "moveToTrash";
        m_activateEntry(operation);
        // Refresh this snapshot on the next visit, like other folder changes.
        close();
    });
    m_fileActions->popup(globalPosition);
}

void FolderPopup::enterKeyboardMode()
{
    const bool entering = !m_keyboardEntered;
    m_keyboardEntered = true;
    if (entering && keyboardEntered) keyboardEntered();
    m_selectFirstWhenReady = true;
    if (m_request) return;
    for (auto *action : actions()) {
        if (action->isEnabled() && !action->isSeparator()) {
            setActiveAction(action);
            return;
        }
    }
}
void FolderPopup::keyPressEvent(QKeyEvent *event)
{
    // A preview can own Qt's popup grab while keyboard selection still belongs
    // to its parent. Route navigation there until Right explicitly enters us.
    if (!m_keyboardEntered && event->key() != Qt::Key_Escape) {
        if (auto *parent = dynamic_cast<FolderPopup *>(parentWidget())) {
            QCoreApplication::sendEvent(parent, event);
            return;
        }
        if (previewNavigation) {
            if (event->key() == Qt::Key_Up || event->key() == Qt::Key_Down) {
                previewNavigation(event->key() == Qt::Key_Up ? -1 : 1);
                event->accept();
                return;
            }
        }
        // Hover-opened root menus have no previewNavigation callback, but
        // Right must still enter them just as it enters a keyboard preview.
        if (event->key() == Qt::Key_Right) {
            enterKeyboardMode();
            event->accept();
            return;
        }
    }
    if (event->key() == Qt::Key_Left) {
        if (auto *parent = dynamic_cast<FolderPopup *>(parentWidget())) {
            parent->m_keyboardEntered = true;
            parent->setActiveAction(menuAction());
            parent->setFocus(Qt::BacktabFocusReason);
            // Selecting a submenu action can open it immediately (zero delay).
            // Close after restoring the parent selection, not before it.
            close();
            event->accept();
            return;
        }
    }
    if (event->key() == Qt::Key_Right && activeAction()) {
        if (auto *child = dynamic_cast<FolderPopup *>(activeAction()->menu())) {
            if (child->isVisible()) {
                child->enterKeyboardMode();
                event->accept();
                return;
            }
            child->enterKeyboardMode();
        }
    }
    QMenu::keyPressEvent(event);
}
void FolderPopup::mouseMoveEvent(QMouseEvent *event)
{
    if (rect().contains(event->position().toPoint())) m_keyboardEntered = true;
    QMenu::mouseMoveEvent(event);
}
