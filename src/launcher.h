#pragma once

#include <QObject>
#include <QString>

class Launcher : public QObject
{
    Q_OBJECT

public:
    explicit Launcher(QObject *parent = nullptr);

    Q_INVOKABLE bool exists(const QString &desktopId) const;
    Q_INVOKABLE QString name(const QString &desktopId) const;
    Q_INVOKABLE QString icon(const QString &desktopId) const;
    Q_INVOKABLE bool launch(const QString &desktopId);
};