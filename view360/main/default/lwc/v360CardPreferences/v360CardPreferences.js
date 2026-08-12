/**
 * Per-user, per-browser presentation preferences for Vista 360 cards --
 * currently the set of pinned card names per tab. Pinning is a display
 * preference layered over the admin-configured card order at render time;
 * it never touches the visibility engine or the catalog, and cards
 * themselves are unaware of it.
 *
 * localStorage is the deliberate persistence choice: zero schema and zero
 * server round-trips, at the cost of the preference living per browser.
 * When storage is unavailable (blocked, full, or corrupted), every helper
 * degrades to "nothing pinned" and a pin toggle only lasts for the current
 * view.
 */
const STORAGE_PREFIX = 'v360PinnedCards:';

function storageKey(tabApiName) {
    return `${STORAGE_PREFIX}${tabApiName}`;
}

/**
 * @param {string} tabApiName - the Vista 360 tab the preference belongs to.
 * @returns {string[]} the pinned card names.
 */
export function getPinnedKeys(tabApiName) {
    try {
        const raw = window.localStorage.getItem(storageKey(tabApiName));
        const parsed = raw ? JSON.parse(raw) : [];
        return Array.isArray(parsed) ? parsed.filter((key) => typeof key === 'string') : [];
    } catch {
        return [];
    }
}

/**
 * Adds or removes a card from the tab's pinned set and persists the result.
 *
 * @param {string} tabApiName - the Vista 360 tab the preference belongs to.
 * @param {string} cardName - the card to toggle.
 * @returns {string[]} the updated pinned card names.
 */
export function togglePin(tabApiName, cardName) {
    const current = getPinnedKeys(tabApiName);
    const next = current.includes(cardName)
        ? current.filter((key) => key !== cardName)
        : [...current, cardName];
    try {
        window.localStorage.setItem(storageKey(tabApiName), JSON.stringify(next));
    } catch {
        // Storage rejected the write: the returned set still applies to the
        // current view, it just will not survive a reload.
    }
    return next;
}
