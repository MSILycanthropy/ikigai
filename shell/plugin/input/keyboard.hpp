#pragma once

#include <QObject>
#include <QtQml/qqml.h>

struct wl_keyboard;
struct xkb_context;
struct xkb_keymap;
struct xkb_state;

// The keyboard as the compositor reports it to this client: a modifier query, so a window
// that took focus can tell whether a modifier was already released before it mapped, and
// the lock state, which Qt drops on the way to QML. The locks come from a wl_keyboard of
// our own on Qt's seat, fed through xkbcommon; the compositor sends modifiers to every
// keyboard object of the focused client, so it tracks while a card is up.
class Keyboard : public QObject {
    Q_OBJECT
    QML_ELEMENT
    QML_SINGLETON
    Q_PROPERTY(bool capsLock READ capsLock NOTIFY locksChanged)
    Q_PROPERTY(bool numLock READ numLock NOTIFY locksChanged)

public:
    explicit Keyboard(QObject *parent = nullptr);
    ~Keyboard() override;

    Q_INVOKABLE int modifiers() const;
    bool capsLock() const { return m_capsLock; }
    bool numLock() const { return m_numLock; }

signals:
    void locksChanged();

private:
    static const struct wl_keyboard_listener s_listener;
    void keymap(uint32_t format, int fd, uint32_t size);
    void modifiers(uint32_t depressed, uint32_t latched, uint32_t locked, uint32_t group);
    void update();

    wl_keyboard *m_keyboard = nullptr;
    xkb_context *m_context = nullptr;
    xkb_keymap *m_keymap = nullptr;
    xkb_state *m_state = nullptr;
    bool m_capsLock = false;
    bool m_numLock = false;
};
