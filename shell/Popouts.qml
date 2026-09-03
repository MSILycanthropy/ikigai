import QtQuick

// Cards live in the rail's own window rather than in popup windows, so a shader can
// later draw rail and card as one surface. Bar masks input to the open card; leaving
// it closes the card after the same grace the rail uses.
Item {
    id: popouts

    property Item anchorItem: null
    property bool hovered: false
    readonly property bool workspacesOpen: workspaces.active
    // The open card, or the one still sliding back in, so the goo can absorb it.
    readonly property Item card: menu.active ? menu : workspaces.active ? workspaces : menu.visible ? menu : workspaces.visible ? workspaces : null

    width: 260 + 2 * Motion.slack

    function openMenu(task, at) {
        workspaces.active = false;
        menu.task = task;
        anchorItem = at;
        menu.active = true;
    }

    function toggleWorkspaces(at) {
        menu.active = false;
        anchorItem = at;
        workspaces.active = !workspaces.active;
    }

    function close() {
        menu.active = false;
        workspaces.active = false;
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
        interval: 400
        onTriggered: popouts.close()
    }

    TaskMenu {
        id: menu
        y: popouts.alignedY(menu)
    }

    Workspaces {
        id: workspaces
        y: popouts.alignedY(workspaces)
    }
}
