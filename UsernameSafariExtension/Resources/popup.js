import { generateUsernames, fillFocusedFieldInTab } from "./usernames.js";

const list = document.getElementById("list");
const status = document.getElementById("status");

async function refresh() {
    const usernames = await generateUsernames(5);
    list.replaceChildren(...usernames.map(name => {
        const item = document.createElement("li");
        const button = document.createElement("button");
        button.type = "button";
        button.textContent = name;
        button.addEventListener("click", () => choose(name));
        item.append(button);
        return item;
    }));
}

async function choose(name) {
    let copied = false;
    try {
        await navigator.clipboard.writeText(name);
        copied = true;
    } catch {}

    let filled = false;
    try {
        const [tab] = await browser.tabs.query({ active: true, currentWindow: true });
        if (tab) filled = await fillFocusedFieldInTab(tab.id, name);
    } catch {}

    status.textContent = filled && copied ? "Copied and filled." : filled ? "Filled." : copied ? "Copied." : "Couldn't copy or fill.";
}

document.getElementById("refresh").addEventListener("click", refresh);
refresh().catch(() => { status.textContent = "Couldn't reach the app."; });
