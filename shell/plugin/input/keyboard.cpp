#include "keyboard.hpp"

#include <QGuiApplication>

int Keyboard::modifiers() const {
    return static_cast<int>(QGuiApplication::queryKeyboardModifiers());
}
