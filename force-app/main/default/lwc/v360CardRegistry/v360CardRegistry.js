/**
 * Dev-owned static-import map from a card's component name to its LWC
 * constructor. Every entry is a static import, so the bundler fails the
 * build if a referenced component does not exist — this module never
 * resolves a component through a dynamic import of an arbitrary string.
 *
 * The shell resolves a card's component through resolve(componentName). An
 * unknown key returns null; the shell owns rendering its own safe error
 * state for that case — this module has no rendering responsibility.
 */
import PipelineProbe from 'c/pipelineProbe';
import V360AccountSnapshot from 'c/v360AccountSnapshot';

// pipelineProbe is a repo smoke-test component, not a real visibility card,
// kept registered from the shell-foundation work unit that first exercised
// this static-import wiring end to end. v360AccountSnapshot is the first
// real Vista 360 card.
const REGISTRY = {
    pipelineProbe: PipelineProbe,
    v360AccountSnapshot: V360AccountSnapshot
};

/**
 * Resolves a card's component name to its constructor.
 *
 * @param {string} componentName - the card's configured component name.
 * @returns {Function|null} the component constructor, or null when the name
 * is not a known registry entry.
 */
export function resolve(componentName) {
    return REGISTRY[componentName] ?? null;
}
