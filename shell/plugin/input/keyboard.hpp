#pragma once

#include <QObject>
#include <QtQml/qqml.h>

// Modifier state as the compositor last reported it to this client, so a window that took
// focus can tell whether a modifier was already released before it mapped.
class Keyboard : public QObject {
    Q_OBJECT
    QML_ELEMENT
    QML_SINGLETON

public:
    Q_INVOKABLE int modifiers() const;
};
