/**
 * Per-recordId state manager for the visible-card set. Built with
 * @lwc/state's defineState so it exposes the uniform
 * { status, data, error } contract shared with platform state managers.
 *
 * There is exactly one instance per (recordId, tabApiName) pair — a
 * module-level registry enforces that — and concurrent load requests for that
 * same pair share a single underlying service call rather than each issuing
 * their own, which the dedupe map below is what makes true, independent of
 * anything @lwc/state itself provides.
 *
 * The pair, not the record. A record page may carry several Vista 360 tabs,
 * each pointed at its own configured tab, and the card list belongs to the
 * combination. Keying the registry on the record alone while the dedupe map
 * keyed on both meant the second tab's load overwrote the first tab's cards,
 * and the first shell — subscribed to that very instance — re-rendered
 * someone else's answer: leaving a three-card tab for a one-card tab and
 * coming back showed one card.
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
        // Which tab the held cards belong to. The dedupe map already keys on
        // it, so the manager knew it and simply threw it away; retaining it
        // lets a card ask what it is rendering inside, which nothing else can
        // tell it -- the shell hands a card its record and nothing more.
        const tabApiNameAtom = atom(null);
        /**
         * Whether this record's shell is hearing about config changes:
         * 'unknown' before it tries, 'live' once subscribed, 'unavailable'
         * when the subscription failed.
         *
         * Kept here rather than inside the shell because a swallowed failure
         * is indistinguishable from a working subscription that nothing has
         * happened on yet -- and that is precisely the state someone is in
         * when they activate a card and the page does not move.
         */
        const liveUpdatesAtom = atom('unknown');

        async function resolveVisibleCards(tabApiName, forceFresh) {
            setAtom(statusAtom, 'loading');
            setAtom(tabApiNameAtom, tabApiName);
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

        function reportLiveUpdates(state) {
            setAtom(liveUpdatesAtom, state);
        }

        return {
            status: statusAtom,
            data: dataAtom,
            error: errorAtom,
            tabApiName: tabApiNameAtom,
            liveUpdates: liveUpdatesAtom,
            load,
            refresh,
            reportLiveUpdates
        };
    },
    { metadata: { definedBy: 'v360CustomerState', type: 'external' } }
);

/**
 * Returns the one v360CustomerState instance for a given recordId, creating
 * it on first access.
 *
 * @param {string} recordId - the anchor record Id this state manager owns.
 * @param {string} tabApiName - the configured tab whose cards it holds; part
 * of the identity, because one record can show several tabs at once.
 * @returns {Signal} a state manager signal whose .value exposes
 * { status, data, error, tabApiName, liveUpdates, load, refresh,
 * reportLiveUpdates }.
 */
export default function v360CustomerState(recordId, tabApiName) {
    const key = requestKey(recordId, tabApiName);
    if (!instances.has(key)) {
        instances.set(key, defineCustomerState(recordId));
    }
    return instances.get(key);
}
