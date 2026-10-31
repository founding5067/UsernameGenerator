// Asks the app's Swift generator for usernames. Safari ignores the first argument.
export async function generateUsernames(count) {
    const reply = await browser.runtime.sendNativeMessage("application.id", { action: "generate", count });
    return reply?.usernames ?? [];
}

// Runs inside the page. Must be self-contained because it is serialized into the tab.
function fillFocusedField(value) {
    let el = document.activeElement;
    while (el?.shadowRoot?.activeElement) el = el.shadowRoot.activeElement;
    if (!el) return false;

    const textTypes = ["", "text", "search", "email", "url", "tel"];
    const proto = el instanceof HTMLInputElement && textTypes.includes(el.type) ? HTMLInputElement.prototype
        : el instanceof HTMLTextAreaElement ? HTMLTextAreaElement.prototype
        : null;

    if (proto) {
        // The native setter bypasses the value tracking frameworks like React install on the element.
        Object.getOwnPropertyDescriptor(proto, "value").set.call(el, value);
        el.dispatchEvent(new Event("input", { bubbles: true }));
        el.dispatchEvent(new Event("change", { bubbles: true }));
        return true;
    }
    if (el.isContentEditable) {
        document.execCommand("selectAll");
        return document.execCommand("insertText", false, value);
    }
    return false;
}

// Fills the focused text field in the tab. Returns true if a field was filled.
export async function fillFocusedFieldInTab(tabId, value, frameId) {
    const target = frameId === undefined ? { tabId, allFrames: true } : { tabId, frameIds: [frameId] };
    const results = await browser.scripting.executeScript({ target, func: fillFocusedField, args: [value] });
    return results.some(r => r.result === true);
}
