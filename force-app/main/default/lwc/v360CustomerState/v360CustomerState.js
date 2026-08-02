/**
 * Per-recordId state manager for the visible-card set. Built with
 * @lwc/state's defineState so it exposes the uniform
 * { status, data, error } contract shared with platform state managers.
 *
 * There is exactly one instance per recordId (a module-level registry
 * enforces that), and concurrent load requests for the same
 * (recordId, tabApiName) pair share a single underlying service call rather
 * than each issuing their own — the dedupe map below is what makes that
 * true, independent of anything @lwc/state itself provides.
 *
 * Scope note: this module only owns the visible-card list returned by
 * v360Service. It does not compose record-field state (e.g. LDS identity
 * fields) — that composition, if a future card needs it, belongs to that
 * card's own concern, not this shared manager.
 */
import { defineState } from '@lwc/state';
import { getVisibleCards, getVisibleCardsFresh } from 'c/v360Service';

const instances = new Map();
const inFlightRequests = new Map();

function requestKey(recordId, tabApiName) {
    return `${recordId}::${tabApiName}`;
}

/**
 * Issues (or joins) a request for the visible-card list.
 *
 * A plain load joins an already in-flight request for the same key instead
 * of issuing a second service call. A forced-fresh request always issues
 * its own call, but still registers itself as the in-flight request for
 * that key so any load that starts while it is running joins it instead of
 * triggering a redundant cacheable call.
 */
function requestVisibleCards(recordId, tabApiName, forceFresh) {
    const key = requestKey(recordId, tabApiName);

    if (!forceFresh) {
        const existing = inFlightRequests.get(key);
        if (existing) {
            return existing;
        }
    }

    const fetch = forceFresh ? getVisibleCardsFresh : getVisibleCards;
    const request = fetch(recordId, tabApiName).finally(() => {
        if (inFlightRequests.get(key) === request) {
            inFlightRequests.delete(key);
        }
    });

    inFlightRequests.set(key, request);
    return request;
}

const defineCustomerState = defineState(
    ({ atom, setAtom }, recordId) => {
        const statusAtom = atom('unconfigured');
        const dataAtom = atom(null);
        const errorAtom = atom(null);

        async function resolveVisibleCards(tabApiName, forceFresh) {
            setAtom(statusAtom, 'loading');
            try {
                const decisions = await requestVisibleCards(recordId, tabApiName, forceFresh);
                setAtom(dataAtom, decisions);
                setAtom(errorAtom, null);
                setAtom(statusAtom, 'loaded');
            } catch (error) {
                setAtom(errorAtom, error);
                setAtom(statusAtom, 'error');
            }
        }

        function load(tabApiName) {
            return resolveVisibleCards(tabApiName, false);
        }

        function refresh(tabApiName) {
            return resolveVisibleCards(tabApiName, true);
        }

        return {
            status: statusAtom,
            data: dataAtom,
            error: errorAtom,
            load,
            refresh
        };
    },
    { metadata: { definedBy: 'v360CustomerState', type: 'external' } }
);

/**
 * Returns the one v360CustomerState instance for a given recordId, creating
 * it on first access.
 *
 * @param {string} recordId - the anchor record Id this state manager owns.
 * @returns {Signal} a state manager signal whose .value exposes
 * { status, data, error, load, refresh }.
 */
export default function v360CustomerState(recordId) {
    if (!instances.has(recordId)) {
        instances.set(recordId, defineCustomerState(recordId));
    }
    return instances.get(recordId);
}
