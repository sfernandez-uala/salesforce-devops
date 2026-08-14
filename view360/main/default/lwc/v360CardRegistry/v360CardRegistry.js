/**
 * Dev-owned static-import map from a card's component name to its LWC
 * constructor. Every entry is a static import, so the bundler fails the
 * build if a referenced component does not exist, and no import path is
 * ever built from configured data.
 *
 * The shell checks a name with has() and obtains its constructor with
 * load(); an unknown key resolves to null and the shell owns rendering its
 * own safe error state for that case — this module has no rendering
 * responsibility. load() is Promise-shaped so the shell's consumption stays
 * the same if a platform-supported deferred-loading path is ever adopted.
 *
 * ── Adding a card ────────────────────────────────────────────────────────
 * A card renders only if it is named here. Import it and add it to REGISTRY;
 * that is the whole seam. Salesforce validates these imports at deploy time
 * ("No MODULE named markup://c:x found"), resolving them against the target
 * org — so a name here obliges every org that receives this file to have
 * that component too.
 *
 * Which is why nothing from the demo/ package directory is named here. The
 * cards that live there (c/pipelineProbe, c/v360LifecycleDemo) are demos, not
 * product, and naming them would drag them into every org this file reaches.
 * To exercise them in a sandbox, add the import locally and leave it out of
 * the commit — but note the org reverts to this list on the next deploy of
 * this bundle.
 *
 * A diagnostic that does not need to be a card should not be one:
 * c/v360StateProbe reads the same per-record store the shell does, so it is
 * an ordinary component placed beside the shell instead of an entry here.
 */
import V360AccountSnapshot from 'c/v360AccountSnapshot';

const REGISTRY = {
    v360AccountSnapshot: V360AccountSnapshot
};

// Registered for runtime compatibility but not offered to admins: a card
// bound to one of these still renders, yet the picker never suggests it.
const NOT_SELECTABLE = new Set();

/**
 * @returns {string[]} every card component name an admin may bind -- the
 * admin console's component picker offers exactly this list, so a newly
 * configured LWC binding can only ever name a real, registered card.
 */
export function names() {
    return Object.keys(REGISTRY).filter((componentName) => !NOT_SELECTABLE.has(componentName));
}

/**
 * @param {string} componentName - a configured card's component name.
 * @returns {boolean} whether this registry can resolve that name.
 */
export function has(componentName) {
    return Object.prototype.hasOwnProperty.call(REGISTRY, componentName);
}

/**
 * @param {string} componentName - a configured card's component name.
 * @returns {Promise<Function|null>} the LWC constructor, or null when the
 * name is not registered -- the caller decides what to render instead.
 */
export function load(componentName) {
    return Promise.resolve(has(componentName) ? REGISTRY[componentName] : null);
}
