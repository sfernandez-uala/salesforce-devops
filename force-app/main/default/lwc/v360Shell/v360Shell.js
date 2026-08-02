import { LightningElement, api } from 'lwc';
import v360CustomerState from 'c/v360CustomerState';
import v360ShellState from 'c/v360ShellState';
import { resolve as resolveCardComponent } from 'c/v360CardRegistry';

const DEFAULT_TAB_API_NAME = 'AccountOverview';
const COMPONENT_TYPE_LWC = 'LWC';
const COMPONENT_TYPE_FLOW = 'Flow';

/**
 * Converts a registered card component name (e.g. "v360AccountSnapshot",
 * matching its bundle folder name exactly) to the custom element tag name
 * the platform generates for it (e.g. "c-v360-account-snapshot"): insert a
 * hyphen before each internal uppercase letter, lowercase the result, and
 * prefix the default namespace.
 *
 * @param {string} componentName - a card's registered component name.
 * @returns {string} the corresponding custom element tag name.
 */
function toCustomElementTagName(componentName) {
    return `c-${componentName.replace(/([A-Z])/g, '-$1').toLowerCase()}`;
}

/**
 * The Vista 360 shell container: the record-page surface that asks the
 * server which cards the current user may see for this record's tab, and
 * renders exactly what comes back -- nothing more. This component makes no
 * visibility decision of its own; v360CustomerState is the only thing it
 * asks, and it renders whatever { status, data, error } that manager
 * reports.
 *
 * Render dispatch is by componentType, the contract every card decision
 * carries:
 *   - LWC: a componentName the dev-owned v360CardRegistry recognizes is
 *     mounted manually (an `lwc:dom="manual"` mount point per card, with the
 *     matching custom element created and appended imperatively -- this
 *     component targets a real org's default LWC compiler settings, where
 *     the newer `lwc:component`/`lwc:is` dynamic-component directives are
 *     gated behind an org-level opt-in this change does not require). A
 *     componentName the registry does not recognize renders a safe inline
 *     error and nothing dynamic -- the render-time fail-closed backstop the
 *     design promises.
 *   - Flow: renders a clearly-labeled placeholder here. The generic Flow
 *     host that actually embeds a screen flow ships in a later work unit;
 *     this exercises the render-dispatch contract end to end without
 *     waiting on that component.
 *
 * Kept lean on purpose -- this is the vertical slice, not the final chrome.
 */
export default class V360Shell extends LightningElement {
    @api recordId;
    @api tabApiName = DEFAULT_TAB_API_NAME;

    customerState;
    shellState;
    unsubscribeCustomerState;

    status = 'unconfigured';
    cards = [];
    error;

    mountedCardKeys = new Set();

    connectedCallback() {
        this.customerState = v360CustomerState(this.recordId);
        this.shellState = v360ShellState(this.recordId);
        this.unsubscribeCustomerState = this.customerState.subscribe(() => this.syncFromCustomerState());
        this.syncFromCustomerState();
        this.customerState.value.load(this.tabApiName);
    }

    disconnectedCallback() {
        if (this.unsubscribeCustomerState) {
            this.unsubscribeCustomerState();
        }
    }

    renderedCallback() {
        if (!this.hasCards) {
            return;
        }
        for (const card of this.cards) {
            if (card.isLwc && !this.mountedCardKeys.has(card.key)) {
                this.mountLwcCard(card);
            }
        }
    }

    mountLwcCard(card) {
        const mountPoint = this.template.querySelector(`[data-lwc-mount="${card.key}"]`);
        if (!mountPoint) {
            return;
        }
        const cardElement = document.createElement(card.tagName);
        cardElement.recordId = this.recordId;
        mountPoint.appendChild(cardElement);
        this.mountedCardKeys.add(card.key);
    }

    syncFromCustomerState() {
        const { status, data, error } = this.customerState.value;
        this.status = status;
        this.error = error;
        this.cards = (data ?? []).map((decision) => this.toRenderableCard(decision));
    }

    toRenderableCard(decision) {
        const isLwc = decision.componentType === COMPONENT_TYPE_LWC;
        const isFlow = decision.componentType === COMPONENT_TYPE_FLOW;
        const isKnownLwc = isLwc && resolveCardComponent(decision.componentName) != null;
        return {
            key: decision.cardName,
            label: decision.label,
            iconName: decision.iconName,
            componentName: decision.componentName,
            tagName: isKnownLwc ? toCustomElementTagName(decision.componentName) : null,
            isLwc: isKnownLwc,
            isFlow,
            isUnknownBinding: isLwc && !isKnownLwc
        };
    }

    handleSelectCard(event) {
        const cardName = event.currentTarget.dataset.cardName;
        this.shellState.value.selectCard(cardName);
    }

    handleRetry() {
        this.customerState.value.refresh(this.tabApiName);
    }

    get isLoading() {
        return this.status === 'unconfigured' || this.status === 'loading';
    }

    get isError() {
        return this.status === 'error';
    }

    get isEmpty() {
        return this.status === 'loaded' && this.cards.length === 0;
    }

    get hasCards() {
        return this.status === 'loaded' && this.cards.length > 0;
    }
}
