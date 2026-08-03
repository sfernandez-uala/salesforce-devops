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
 */
import PipelineProbe from 'c/pipelineProbe';
import V360AccountSnapshot from 'c/v360AccountSnapshot';

// pipelineProbe is a repo smoke-test component, not a real visibility card,
// kept registered from the shell-foundation work unit that first exercised
// this registry wiring end to end. v360AccountSnapshot is the first real
// Vista 360 card.
const REGISTRY = {
    pipelineProbe: PipelineProbe,
    v360AccountSnapshot: V360AccountSnapshot
};

/**
 * @param {string} componentName - the card's configured component name.
 * @returns {boolean} whether the name is a known registry entry.
 */
export function has(componentName) {
    return Object.prototype.hasOwnProperty.call(REGISTRY, componentName);
}

/**
 * Returns a registered card's constructor.
 *
 * @param {string} componentName - the card's configured component name.
 * @returns {Promise<Function|null>} the component constructor, or null when
 * the name is not a known registry entry.
 */
export function load(componentName) {
    return Promise.resolve(has(componentName) ? REGISTRY[componentName] : null);
}
