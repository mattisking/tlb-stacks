#pragma once
#include <QAbstractItemModel>
#include <QByteArray>
#include <QHash>
#include <QList>
#include <QStringList>
#include <QVariant>
#include <QVariantList>
#include <QVariantMap>
#include <memory>
#include <vector>

// Stand-in for Plasma's TasksModel: a tree of rows whose role names match the real model.
// A row map may carry a "children" list of nested row maps (a group parent's windows).
class MockTasksModel : public QAbstractItemModel {
    Q_OBJECT
public:
    explicit MockTasksModel(QObject *parent = nullptr) : QAbstractItemModel(parent)
    {
        const QStringList names{"isWindow", "isActive", "isMinimized", "isLauncher", "IsGroupParent",
                                "LauncherUrl", "AppId", "display", "icon"};
        int role = Qt::UserRole + 1;
        for (const QString &name : names) {
            m_roles.insert(role++, name.toUtf8());
        }
    }

    QHash<int, QByteArray> roleNames() const override { return m_roles; }
    int columnCount(const QModelIndex & = {}) const override { return 1; }
    int rowCount(const QModelIndex &parent = {}) const override { return childrenOf(parent).size(); }

    QModelIndex index(int row, int column, const QModelIndex &parent = {}) const override
    {
        const auto &siblings = childrenOf(parent);
        if (column != 0 || row < 0 || row >= int(siblings.size()))
            return {};
        return createIndex(row, column, siblings[row].get());
    }

    QModelIndex parent(const QModelIndex &child) const override
    {
        if (!child.isValid())
            return {};
        const Row *parentRow = static_cast<const Row *>(child.internalPointer())->parent;
        if (!parentRow)
            return {};
        return createIndex(rowOf(parentRow), 0, const_cast<Row *>(parentRow));
    }

    QVariant data(const QModelIndex &index, int role) const override
    {
        if (!index.isValid())
            return {};
        const QByteArray name = m_roles.value(role);
        return name.isEmpty() ? QVariant() : static_cast<const Row *>(index.internalPointer())->values.value(name);
    }

    Q_INVOKABLE void setRows(const QVariantList &rows)
    {
        beginResetModel();
        m_rows.clear();
        for (const QVariant &row : rows)
            m_rows.push_back(makeRow(row.toMap(), nullptr));
        endResetModel();
    }
    Q_INVOKABLE void appendRow(const QVariantMap &row)
    {
        beginInsertRows({}, int(m_rows.size()), int(m_rows.size()));
        m_rows.push_back(makeRow(row, nullptr));
        endInsertRows();
    }
    Q_INVOKABLE void removeRowAt(int row)
    {
        beginRemoveRows({}, row, row);
        m_rows.erase(m_rows.begin() + row);
        endRemoveRows();
    }
    Q_INVOKABLE void updateRow(int row, const QVariantMap &values)
    {
        m_rows[row]->values.insert(values);
        emit dataChanged(index(row, 0), index(row, 0));
    }

    Q_INVOKABLE QVariantList activateCalls() const { return m_activateCalls; }
    Q_INVOKABLE QVariantList toggleMinimizedCalls() const { return m_toggleCalls; }
    Q_INVOKABLE QVariantList newInstanceCalls() const { return m_newInstanceCalls; }
    Q_INVOKABLE void requestActivate(const QModelIndex &index) { m_activateCalls << index.row(); }
    Q_INVOKABLE void requestToggleMinimized(const QModelIndex &index) { m_toggleCalls << index.row(); }
    Q_INVOKABLE void requestNewInstance(const QModelIndex &index) { m_newInstanceCalls << index.row(); }

private:
    struct Row {
        QVariantMap values;
        Row *parent = nullptr;
        std::vector<std::unique_ptr<Row>> children;
    };

    std::unique_ptr<Row> makeRow(const QVariantMap &values, Row *parent) const
    {
        auto row = std::make_unique<Row>();
        row->values = values;
        row->values.remove("children");
        row->parent = parent;
        for (const QVariant &child : values.value("children").toList())
            row->children.push_back(makeRow(child.toMap(), row.get()));
        return row;
    }

    const std::vector<std::unique_ptr<Row>> &childrenOf(const QModelIndex &parent) const
    {
        return parent.isValid() ? static_cast<const Row *>(parent.internalPointer())->children : m_rows;
    }

    int rowOf(const Row *row) const
    {
        const auto &siblings = row->parent ? row->parent->children : m_rows;
        for (int i = 0; i < int(siblings.size()); ++i)
            if (siblings[i].get() == row)
                return i;
        return -1;
    }

    QHash<int, QByteArray> m_roles;
    std::vector<std::unique_ptr<Row>> m_rows;
    QVariantList m_activateCalls, m_toggleCalls, m_newInstanceCalls;
};
