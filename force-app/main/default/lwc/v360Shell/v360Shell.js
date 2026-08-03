import { LightningElement, api } from 'lwc';
import v360CustomerState from 'c/v360CustomerState';
import v360ShellState from 'c/v360ShellState';
import { has as isRegisteredCard, load as loadCardConstructor } from 'c/v360CardRegistry';

const DEFAULT_TAB_API_NAME = 'AccountOverview';
const COMPONENT_TYPE_LWC = 'LWC';
const COMPONENT_TYPE_FLOW = 'Flow';

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
 *     rendered through the platform's dynamic-component support
 *     (lwc:component with lwc:is, declared via the
 *     lightning__dynamicComponent capability in this component's meta). The
 *     registry hands back constructors from literal dynamic imports, so no
 *     import path is ever built from configured data. A componentName the
 *     registry does not recognize renders a safe error state and nothing
 *     dynamic -- the render-time fail-closed backstop the design promises.
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

    syncFromCustomerState() {
        const { status, data, error } = this.customerState.value;
        this.status = status;
        this.error = error;
        this.cards = (data ?? []).map((decision) => this.toRenderableCard(decision));
        this.hydrateCardConstructors();
    }

    toRenderableCard(decision) {
        const isLwc = decision.componentType === COMPONENT_TYPE_LWC;
        const isFlow = decision.componentType === COMPONENT_TYPE_FLOW;
        const isKnownLwc = isLwc && isRegisteredCard(decision.componentName);
        return {
            key: decision.cardName,
            label: decision.label,
            iconName: decision.iconName,
            componentName: decision.componentName,
            ctor: null,
            isLwc: isKnownLwc,
            isFlow,
            isUnknownBinding: isLwc && !isKnownLwc
        };
    }

    /**
     * Fills in the constructor of every known LWC card as its module
     * resolves. Constructors arrive asynchronously (the registry loads each
     * module once and memoizes it), so each arrival patches the cards list
     * immutably to trigger a re-render of just-ready cards.
     */
    hydrateCardConstructors() {
        for (const card of this.cards) {
            if (!card.isLwc || card.ctor) {
                continue;
            }
            loadCardConstructor(card.componentName).then((ctor) => {
                if (!ctor) {
                    return;
                }
                this.cards = this.cards.map((current) =>
                    current.key === card.key && !current.ctor ? { ...current, ctor } : current
                );
            });
        }
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
