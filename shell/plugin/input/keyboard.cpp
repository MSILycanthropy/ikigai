#include "keyboard.hpp"

#include <QGuiApplication>
#include <QtGui/qguiapplication_platform.h>

#include <sys/mman.h>
#include <unistd.h>
#include <wayland-client.h>
#include <xkbcommon/xkbcommon.h>

const struct wl_keyboard_listener Keyboard::s_listener = {
    .keymap = [](void *data, wl_keyboard *, uint32_t format, int fd, uint32_t size) {
        static_cast<Keyboard *>(data)->keymap(format, fd, size);
    },
    .enter = [](void *, wl_keyboard *, uint32_t, wl_surface *, wl_array *) {},
    .leave = [](void *, wl_keyboard *, uint32_t, wl_surface *) {},
    .key = [](void *, wl_keyboard *, uint32_t, uint32_t, uint32_t, uint32_t) {},
    .modifiers = [](void *data, wl_keyboard *, uint32_t, uint32_t depressed, uint32_t latched, uint32_t locked, uint32_t group) {
        static_cast<Keyboard *>(data)->modifiers(depressed, latched, locked, group);
    },
    .repeat_info = [](void *, wl_keyboard *, int32_t, int32_t) {},
};

Keyboard::Keyboard(QObject *parent) : QObject(parent) {
    auto *app = qGuiApp ? qGuiApp->nativeInterface<QNativeInterface::QWaylandApplication>() : nullptr;
    wl_seat *seat = app ? app->seat() : nullptr;
    if (!seat)
        return;
    m_context = xkb_context_new(XKB_CONTEXT_NO_FLAGS);
    m_keyboard = wl_seat_get_keyboard(seat);
    wl_keyboard_add_listener(m_keyboard, &s_listener, this);
}

Keyboard::~Keyboard() {
    if (m_keyboard)
        wl_keyboard_release(m_keyboard);
    if (m_state)
        xkb_state_unref(m_state);
    if (m_keymap)
        xkb_keymap_unref(m_keymap);
    if (m_context)
        xkb_context_unref(m_context);
}

int Keyboard::modifiers() const {
    return static_cast<int>(QGuiApplication::queryKeyboardModifiers());
}

void Keyboard::keymap(uint32_t format, int fd, uint32_t size) {
    if (format == WL_KEYBOARD_KEYMAP_FORMAT_XKB_V1 && m_context) {
        void *map = mmap(nullptr, size, PROT_READ, MAP_PRIVATE, fd, 0);
        if (map != MAP_FAILED) {
            xkb_keymap *keymap = xkb_keymap_new_from_string(m_context, static_cast<const char *>(map), XKB_KEYMAP_FORMAT_TEXT_V1, XKB_KEYMAP_COMPILE_NO_FLAGS);
            munmap(map, size);
            if (keymap) {
                if (m_state)
                    xkb_state_unref(m_state);
                if (m_keymap)
                    xkb_keymap_unref(m_keymap);
                m_keymap = keymap;
                m_state = xkb_state_new(keymap);
            }
        }
    }
    close(fd);
}

void Keyboard::modifiers(uint32_t depressed, uint32_t latched, uint32_t locked, uint32_t group) {
    if (!m_state)
        return;
    xkb_state_update_mask(m_state, depressed, latched, locked, 0, 0, group);
    update();
}

void Keyboard::update() {
    const bool caps = xkb_state_mod_name_is_active(m_state, XKB_MOD_NAME_CAPS, XKB_STATE_MODS_LOCKED) > 0;
    const bool num = xkb_state_mod_name_is_active(m_state, XKB_MOD_NAME_NUM, XKB_STATE_MODS_LOCKED) > 0;
    if (caps == m_capsLock && num == m_numLock)
        return;
    m_capsLock = caps;
    m_numLock = num;
    emit locksChanged();
}
