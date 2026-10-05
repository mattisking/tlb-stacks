#pragma once

#include <QMenu>
#include <QUrl>
#include <QVariantMap>
#include <QPointer>
#include <functional>

// Each level is enumerated only when opened, including on subsequent visits.
// QMenu owns submenu positioning, pointer travel and dismissal.
class FolderPopup : public QMenu
{
public:
    using ActivateEntry = std::function<void(const QVariantMap &)>;
    FolderPopup(const QUrl &folder, const QStringList &filters, ActivateEntry activateEntry,
                QWidget *parent = nullptr, int hoverDelay = 250);
    void enterKeyboardMode();
    std::function<void(int)> previewNavigation;
    std::function<void()> keyboardEntered;
protected:
    void keyPressEvent(QKeyEvent *event) override;
    void mouseMoveEvent(QMouseEvent *event) override;
    void mousePressEvent(QMouseEvent *event) override;
    void mouseReleaseEvent(QMouseEvent *event) override;
    void contextMenuEvent(QContextMenuEvent *event) override;
private:
    void showFileActions(QAction *action, const QPoint &globalPosition);
    QPointer<QMenu> m_fileActions;
    void populate();
    bool m_selectFirstWhenReady = false;
    bool m_keyboardEntered = false;
    QPointer<QObject> m_request;
    int m_hoverDelay;
    QUrl m_folder;
    QStringList m_filters;
    ActivateEntry m_activateEntry;
};
