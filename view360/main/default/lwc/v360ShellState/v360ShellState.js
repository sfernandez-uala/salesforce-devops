/**
 * Per-recordId UI session state for the Vista 360 shell: which card is
 * selected, which cards are open, the current subtab list, and the header
 * actions each mounted card registers. Built with @lwc/state's defineState.
 *
 * There is exactly one instance per recordId (a module-level registry
 * enforces that), and its selection/open-card/subtab state is persisted to
 * sessionStorage keyed by recordId so a same-tab reload restores the
 * session. Header actions are live wiring registered by mounted cards each
 * session — functions cannot be serialized to sessionStorage, so that piece
 * of state is intentionally never persisted.
 */
import { defineState } from '@lwc/state';

const instances = new Map();

function storageKey(recordId) {
    return `v360ShellState:${recordId}`;
}

function readPersistedSession(recordId) {
    try {
        const raw = sessionStorage.getItem(storageKey(recordId));
        return raw ? JSON.parse(raw) : null;
    } catch (error) {
        // A malformed or inaccessible sessionStorage entry must never break
        // the shell — fall back to a clean session for this record.
        return null;
    }
}

function writePersistedSession(recordId, session) {
    try {
        sessionStorage.setItem(storageKey(recordId), JSON.stringify(session));
    } catch (error) {
        // Storage can be full or unavailable (private browsing, quota) —
        // session state still works in-memory for the current page load.
    }
}

const defineShellState = defineState(
    ({ atom, setAtom }, recordId) => {
        const persisted = readPersistedSession(recordId) ?? {};

        const selectedCardAtom = atom(persisted.selectedCard ?? null);
        const openCardsAtom = atom(persisted.openCards ?? []);
        const subtabsAtom = atom(persisted.subtabs ?? []);
        const headerActionsAtom = atom({});

        function persistSession() {
            writePersistedSession(recordId, {
                selectedCard: selectedCardAtom.value,
                openCards: openCardsAtom.value,
                subtabs: subtabsAtom.value
            });
        }

        function selectCard(cardId) {
            setAtom(selectedCardAtom, cardId);
            if (cardId != null && !openCardsAtom.value.includes(cardId)) {
                setAtom(openCardsAtom, [...openCardsAtom.value, cardId]);
            }
            persistSession();
        }

        function openCard(cardId) {
            if (!openCardsAtom.value.includes(cardId)) {
                setAtom(openCardsAtom, [...openCardsAtom.value, cardId]);
                persistSession();
            }
        }

        function closeCard(cardId) {
            setAtom(
                openCardsAtom,
                openCardsAtom.value.filter((id) => id !== cardId)
            );
            if (selectedCardAtom.value === cardId) {
                setAtom(selectedCardAtom, null);
            }
            persistSession();
        }

        function setSubtabs(subtabs) {
            setAtom(subtabsAtom, subtabs);
            persistSession();
        }

        /**
         * Registers (or replaces) the header actions a mounted card wants
         * the shell's shared header/toolbar to render while that card is
         * active. Replaces the legacy CustomEvent-based subscriber pattern.
         */
        function registerHeaderActions(cardId, actions) {
            setAtom(headerActionsAtom, { ...headerActionsAtom.value, [cardId]: actions });
        }

        return {
            selectedCard: selectedCardAtom,
            openCards: openCardsAtom,
            subtabs: subtabsAtom,
            headerActions: headerActionsAtom,
            selectCard,
            openCard,
            closeCard,
            setSubtabs,
            registerHeaderActions
        };
    },
    { metadata: { definedBy: 'v360ShellState', type: 'external' } }
);

/**
 * Returns the one v360ShellState instance for a given recordId, creating it
 * (and hydrating it from sessionStorage) on first access.
 *
 * @param {string} recordId - the anchor record Id this session belongs to.
 * @returns {Signal} a state manager signal whose .value exposes
 * { selectedCard, openCards, subtabs, headerActions, selectCard, openCard,
 * closeCard, setSubtabs, registerHeaderActions }.
 */
export default function v360ShellState(recordId) {
    if (!instances.has(recordId)) {
        instances.set(recordId, defineShellState(recordId));
    }
    return instances.get(recordId);
}

/**
 * Test-only helper: clears the module-level instance registry so a fresh
 * instance can be created for a recordId that already has one, simulating a
 * new page load that must rehydrate from sessionStorage. Not used by
 * production code.
 */
export function __resetV360ShellStateRegistryForTests() {
    instances.clear();
}
