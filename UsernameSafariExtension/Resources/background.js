import { generateUsernames, fillFocusedFieldInTab } from "./usernames.js";

const MENU_ID = "generate-username";

async function fillWithNewUsername(tabId, frameId) {
    const [username] = await generateUsernames(1);
    if (username) await fillFocusedFieldInTab(tabId, username, frameId);
}

// iOS Safari has no context menus.
if (browser.contextMenus) {
    // Registered on every start, not just onInstalled, which Safari doesn't fire for a reloaded extension.
    browser.contextMenus.removeAll().then(() => {
        browser.contextMenus.create({
            id: MENU_ID,
            title: "Generate Username",
            contexts: ["editable"]
        });
    });

    browser.contextMenus.onClicked.addListener((info, tab) => {
        if (info.menuItemId === MENU_ID && tab) return fillWithNewUsername(tab.id, info.frameId);
    });
}

// Keyboard shortcuts are only available with a hardware keyboard on iOS.
browser.commands?.onCommand.addListener(async (command, tab) => {
    if (command !== MENU_ID) return;
    tab ??= (await browser.tabs.query({ active: true, currentWindow: true }))[0];
    if (tab) await fillWithNewUsername(tab.id);
});
