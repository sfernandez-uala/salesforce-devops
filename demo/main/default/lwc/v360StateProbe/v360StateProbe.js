import { LightningElement, api } from 'lwc';
import v360CustomerState from 'c/v360CustomerState';
import { getVisibleCards } from 'c/v360Service';

/**
 * Module scope on purpose: these outlive any single instance, which is the
 * whole point. A counter held on the component would reset on every mount and
 * so could never answer "did this load twice?".
 */
let mountsSincePageLoad = 0;
let directServiceCalls = 0;
let nextInstanceNumber = 1;
let nextEntryId = 1;

/**
 * Renders per instance, held out here rather than on the component.
 *
 * Not a style choice: counting renders in renderedCallback means writing on
 * every render, and a field the template reads is reactive, so writing it asks
 * for another render, which writes again. The first version of this card
 * looped forever and hung the test runner before printing a line. Module state
 * is not reactive, so the count is recorded without provoking the thing it
 * counts.
 */
const rendersByInstance = new Map();

const MAX_ENTRIES = 40;

/**
 * A card that reports on the shell around it rather than on the record under
 * it, built as a log rather than a dashboard.
 *
 * The log is the point. A panel of counters answers "what is the number now",
 * which is not the question anyone actually has -- the questions are "did
 * anything happen when I pressed that", "did this cost a round trip", and "did
 * my page hear about the card I just activated". Those are about cause and
 * effect over time, so every action writes a line and no control is ever
 * silent: reading shared state logs that it cost nothing, which is precisely
 * what makes it worth reading.
 *
 * Instrumentation, not a business card. It reads no field of the record it is
 * placed on; recordId appears only to confirm the shell passes it.
 */
export default class V360StateProbe extends LightningElement {
    @api recordId;

    instanceNumber = nextInstanceNumber++;
    entries = [];
    storeStatus = 'unread';
    storeCardCount = 0;
    storeChanges = 0;
    busy = false;

    customerState;
    unsubscribe;

    connectedCallback() {
        mountsSincePageLoad++;
        // Reading shared state costs nothing: the instance already exists for
        // this record and holds whatever the shell fetched. No request here.
        this.customerState = v360CustomerState(this.recordId);
        this.unsubscribe = this.customerState.subscribe(() => this.handleStoreChange());
        this.readStoreInto();
        this.log(
            'mounted',
            mountsSincePageLoad === 1
                ? `Instance #${this.instanceNumber}. First mount on this page.`
                : `Instance #${this.instanceNumber}. Mount number ${mountsSincePageLoad} on this page — a remount, not a re-render.`
        );
    }

    disconnectedCallback() {
        if (this.unsubscribe) {
            this.unsubscribe();
        }
    }

    renderedCallback() {
        rendersByInstance.set(this.instanceNumber, this.rendersThisInstance + 1);
    }

    get rendersThisInstance() {
        return rendersByInstance.get(this.instanceNumber) ?? 0;
    }

    // ---- reading the shared store ---------------------------------------

    readStoreInto() {
        const { status, data } = this.customerState.value;
        this.storeStatus = status;
        this.storeCardCount = (data ?? []).length;
    }

    /**
     * The store changed without this card asking. Either the shell loaded, or
     * an admin changed the tab's cards and the shell was told -- which is the
     * one thing you cannot see by pressing a button, so it has to announce
     * itself here.
     */
    handleStoreChange() {
        const previousCount = this.storeCardCount;
        const previousStatus = this.storeStatus;
        this.readStoreInto();
        this.storeChanges++;
        this.log(
            'store changed',
            `Nobody here asked. Status ${previousStatus} → ${this.storeStatus}, cards ${previousCount} → ${this.storeCardCount}. This is what an admin activating a card looks like from inside a card.`
        );
    }

    /** Answers from what is already in memory, and says what that cost. */
    handleReadStore() {
        this.readStoreInto();
        this.log(
            'read the store',
            `${this.storeCardCount} card(s), status "${this.storeStatus}", tab "${this.tabApiName}". Zero network calls — the answer was already here.`
        );
    }

    /** Asks the store to go and get it again: one call, shared by every card. */
    async handleRefreshStore() {
        if (this.busy) {
            return;
        }
        this.busy = true;
        this.log('asked the store to refresh', 'One request, and every card reading this store gets the result.');
        try {
            await this.customerState.value.refresh(this.tabApiName);
        } finally {
            this.busy = false;
        }
    }

    /**
     * What a card that fetches for itself costs, made visible. Press it a few
     * times and compare this counter with the store's: same answer, one bill
     * per press.
     */
    async handleDirectCall() {
        if (this.busy) {
            return;
        }
        this.busy = true;
        try {
            directServiceCalls++;
            const decisions = await getVisibleCards(this.recordId, this.tabApiName);
            this.log(
                'called the server myself',
                `${(decisions ?? []).length} card(s) — the same answer the store already had. ${directServiceCalls} direct call(s) so far. Every card doing this pays separately, on every mount.`
            );
        } catch (error) {
            this.log('direct call failed', error?.body?.message ?? error?.message ?? 'Unknown error', true);
        } finally {
            this.busy = false;
        }
    }

    handleClearLog() {
        this.entries = [];
        this.log('log cleared', 'Counters are untouched — they belong to the page, not to this list.');
    }

    // ---- the log ---------------------------------------------------------

    log(action, detail, isError = false) {
        const now = new Date();
        const entry = {
            id: nextEntryId++,
            at: `${String(now.getHours()).padStart(2, '0')}:${String(now.getMinutes()).padStart(2, '0')}:${String(
                now.getSeconds()
            ).padStart(2, '0')}`,
            action,
            detail,
            rowClass: isError
                ? 'v360-probe-entry v360-probe-entry_error'
                : 'v360-probe-entry'
        };
        // Newest first, and bounded: a log you have to scroll to the bottom of
        // is a log nobody reads.
        this.entries = [entry, ...this.entries].slice(0, MAX_ENTRIES);
    }

    // ---- what the header shows -------------------------------------------

    get tabApiName() {
        return this.customerState?.value?.tabApiName ?? '';
    }

    /**
     * Whether this page would hear about an admin activating a card. The shell
     * records it on the store; before this existed a failed subscription
     * looked exactly like a working one that nothing had happened on.
     */
    get liveUpdates() {
        return this.customerState?.value?.liveUpdates ?? 'unknown';
    }

    get liveUpdatesLabel() {
        return {
            live: 'Live updates on',
            unavailable: 'Live updates unavailable',
            unknown: 'Live updates not established'
        }[this.liveUpdates];
    }

    get liveUpdatesClass() {
        const base = 'slds-badge';
        if (this.liveUpdates === 'live') {
            return `${base} slds-theme_success`;
        }
        return this.liveUpdates === 'unavailable' ? `${base} slds-theme_error` : base;
    }

    get liveUpdatesNote() {
        return {
            live: 'Subscribed to V360_ConfigChange__e. Activate a card in the admin console and watch a "store changed" line appear below without touching this page.',
            unavailable:
                'The shell could not subscribe. Subscribing is checked against Read on V360_ConfigChange__e, so a user whose permission set does not grant it never hears about a config change — the page simply never moves.',
            unknown: 'The shell has not reported yet.'
        }[this.liveUpdates];
    }

    get counters() {
        return [
            { key: 'mounts', label: 'Mounts', value: `${mountsSincePageLoad}` },
            { key: 'renders', label: 'Renders (this instance)', value: `${this.rendersThisInstance}` },
            { key: 'store-changes', label: 'Store changes seen', value: `${this.storeChanges}` },
            { key: 'direct', label: 'Direct server calls', value: `${directServiceCalls}` }
        ];
    }

    get hasEntries() {
        return this.entries.length > 0;
    }
}
