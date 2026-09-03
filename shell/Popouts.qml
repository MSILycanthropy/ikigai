import QtQuick

// Cards live in the rail's own window rather than in popup windows, so a shader can
// later draw rail and card as one surface. Bar masks input to the open card; leaving
// it closes the card after the same grace the rail uses.
Item {
    id: popouts

    property Item anchorItem: null
    property bool hovered: false
    readonly property bool workspacesOpen: workspaces.active
    readonly property list<Item> cards: [menu, windows, workspaces]
    // The open card, or the one still shrinking back, so the goo can absorb it.
    readonly property Item card: cards.find(c => c.active) || cards.find(c => c.visible) || null

    width: 260

    function openMenu(task, at) {
        show(menu, at, task);
    }

    function openWindows(task, at) {
        if (!menu.active)
            show(windows, at, task);
    }

    function toggleWorkspaces(at) {
        if (workspaces.active)
            close();
        else
            show(workspaces, at, null);
    }

    function show(card, at, task) {
        for (const c of cards)
            c.active = c === card;
        card.task = task;
        anchorItem = at;
    }

    function close() {
        for (const c of cards)
            c.active = false;
    }

    // Centre the card on its button, kept inside the screen.
    function alignedY(card) {
        if (!anchorItem)
            return 0;
        const centre = anchorItem.mapToItem(popouts, 0, anchorItem.height / 2).y;
        return Math.max(0, Math.min(height - card.height, centre - card.height / 2));
    }

    onHoveredChanged: hovered ? leave.stop() : leave.restart()

    Timer {
        id: leave
        interval: Motion.grace
        onTriggered: popouts.close()
    }

    TaskMenu {
        id: menu
        y: popouts.alignedY(menu)
    }

    TaskWindows {
        id: windows
        y: popouts.alignedY(windows)
    }

    Workspaces {
        id: workspaces
        y: popouts.alignedY(workspaces)
    }
}
