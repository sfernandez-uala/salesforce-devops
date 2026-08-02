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

// Structural placeholder only: pipelineProbe is a repo smoke-test
// component, not a real visibility card. It exercises the static-import
// wiring end to end until the first real card lands and is registered here.
const REGISTRY = {
    pipelineProbe: PipelineProbe
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
