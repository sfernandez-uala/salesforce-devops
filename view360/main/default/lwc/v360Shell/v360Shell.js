import { LightningElement, api } from 'lwc';
import v360CustomerState from 'c/v360CustomerState';
import v360ShellState from 'c/v360ShellState';
import { has as isRegisteredCard, load as loadCardConstructor } from 'c/v360CardRegistry';
import { getPinnedKeys, togglePin } from 'c/v360CardPreferences';
import { subscribe, unsubscribe } from 'lightning/empApi';

/** Server-side signal that an admin changed a tab's cards. */
const CONFIG_CHANGE_CHANNEL = '/event/V360_ConfigChange__e';

const DEFAULT_BUTTON_LABEL = 'Consultar';
const COMPONENT_TYPE_LWC = 'LWC';
const COMPONENT_TYPE_FLOW = 'Flow';
const HEADER_ACTION_NAME = 'name';
const HEADER_ACTION_LABEL = 'label';
const HEADER_ACTION_ICON = 'iconName';
const DEFAULT_CARD_ICON = 'standard:default';

/**
 * The Vista 360 shell container: the record-page surface that asks the
 * server which cards the current user may see for this record's tab, and
 * renders exactly what comes back -- nothing more. This component makes no
 * visibility decision of its own; v360CustomerState is the only thing it
 * asks, and it renders whatever { status, data, error } that manager
 * reports.
 *
 * Two view states, driven entirely by v360ShellState's per-record selection:
 *   - GALLERY (no card selected): a grid of card tiles that only launch a
 *     card into view -- tiles never mount a card's component.
 *   - FOCUSED (a card is selected): a narrow sidebar listing every visible
 *     card as a minimized launcher, plus a main area whose header carries
 *     the selected card's identity and any header actions it exposes, and
 *     whose content mounts exactly that one card's component.
 *
 * Render dispatch for the mounted card is by componentType, the contract
 * every card decision carries:
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
 * Header actions protocol: a card MAY expose `@api get headerActions()`
 * (an array of { name, label, iconName }) and `@api invokeHeaderAction(name)`
 * without importing anything from Vista 360 -- the card stays fully
 * engine-agnostic. Once mounted, this shell reads that optional interface
 * off the dynamic component instance and renders each action as a
 * lightning-button-icon in the focused header's right zone; clicking one
 * invokes it on the card. Actions are also registered on v360ShellState via
 * registerHeaderActions so the existing state contract stays the single
 * source of truth, even though rendering itself reads the freshly-synced
 * local copy for immediate reactivity. A card may dispatch a bubbling
 * `headeractionschange` event to ask the shell to re-read its action set;
 * cards that implement neither member simply show no actions.
 *
 * Kept lean on purpose -- this is the vertical slice, not the final chrome.
 */
export default class V360Shell extends LightningElement {
    @api recordId;

    /**
     * Which configured tab this placement renders. Deliberately without a
     * default: a fallback tab name means a component dropped on a page shows
     * somebody else's cards, and looks configured while it is not. Absent, the
     * shell says so and renders nothing.
     */
    @api tabApiName;

    customerState;
    shellState;
    unsubscribeCustomerState;
    unsubscribeShellState;

    status = 'unconfigured';
    cards = [];
    error;
    selectedCardKey = null;
    headerActions = [];
    railOverflowing = false;
    railResizeObserver;
    pinnedKeys = [];
    railOverflowInline = false;
    railOverflowBlock = false;
    configSubscription;

    /**
     * Without a tab there is nothing to read, so nothing is read: no state
     * session, no subscription, no server call whose empty answer would be
     * indistinguishable from a tab that genuinely has no cards.
     */
    get hasTab() {
        return Boolean(this.tabApiName && this.tabApiName.trim());
    }

    connectedCallback() {
        if (!this.hasTab) {
            return;
        }
        this.pinnedKeys = getPinnedKeys(this.tabApiName);
        this.customerState = v360CustomerState(this.recordId, this.tabApiName);
        this.shellState = v360ShellState(this.recordId, this.tabApiName);
        this.unsubscribeCustomerState = this.customerState.subscribe(() => this.syncFromCustomerState());
        this.unsubscribeShellState = this.shellState.subscribe(() => this.syncFromShellState());
        this.syncFromCustomerState();
        this.syncFromShellState();
        this.customerState.value.load(this.tabApiName);
        this.subscribeToConfigChanges();
    }

    /**
     * An admin activating a card is a change this user's session has no other
     * way of hearing about: it happens in a different session, often under a
     * different user, so neither a state-manager subscription nor the Lightning
     * Message Service reaches across to it. The server-side event does.
     *
     * Only changes to the tab this shell renders trigger a re-read; a shell on
     * another anchor object ignores the event rather than re-querying.
     */
    async subscribeToConfigChanges() {
        try {
            this.configSubscription = await subscribe(CONFIG_CHANGE_CHANNEL, -1, (message) => {
                const changedTab = message?.data?.payload?.TabName__c;
                if (changedTab === this.tabApiName) {
                    this.customerState.value.refresh(this.tabApiName);
                }
            });
            this.customerState.value.reportLiveUpdates('live');
        } catch (error) {
            // Still a degradation rather than a failure -- the catalog loads,
            // and reloads on the next visit -- but it is recorded rather than
            // swallowed. Subscribing through empApi is checked against Read on
            // the event, so the usual cause is a user whose permission set
            // does not grant it, and the symptom is a page that never moves
            // when an admin activates a card. Silence made that unanswerable.
            this.configSubscription = undefined;
            this.customerState.value.reportLiveUpdates('unavailable');
        }
    }

    disconnectedCallback() {
        if (this.configSubscription) {
            unsubscribe(this.configSubscription);
            this.configSubscription = undefined;
        }
        if (this.unsubscribeCustomerState) {
            this.unsubscribeCustomerState();
        }
        if (this.unsubscribeShellState) {
            this.unsubscribeShellState();
        }
        if (this.railResizeObserver) {
            this.railResizeObserver.disconnect();
            this.railResizeObserver = null;
        }
    }

    /**
     * The sidebar rail advertises hidden items with a trailing-edge fade,
     * but only while items actually overflow -- a permanent fade would
     * signal more content when there is none. CSS cannot detect overflow,
     * so the shell measures: on every render (item set may have changed)
     * and on rail resizes (region width may have changed, without any
     * re-render). ResizeObserver is absent in test DOMs; the fade then
     * simply never engages.
     */
    syncRailOverflowObserver() {
        if (typeof ResizeObserver === 'undefined') {
            return;
        }
        const rail = this.refs?.sidebar ?? null;
        if (rail === this.observedRail) {
            return;
        }
        if (this.railResizeObserver) {
            this.railResizeObserver.disconnect();
            this.railResizeObserver = null;
        }
        this.observedRail = rail;
        if (rail) {
            this.railResizeObserver = new ResizeObserver(() => this.measureRailOverflow());
            this.railResizeObserver.observe(rail);
        }
    }

    measureRailOverflow() {
        const rail = this.refs?.sidebar;
        const inline = Boolean(rail) && rail.scrollWidth > rail.clientWidth;
        const block = Boolean(rail) && rail.scrollHeight > rail.clientHeight;
        if (inline !== this.railOverflowInline) {
            this.railOverflowInline = inline;
        }
        if (block !== this.railOverflowBlock) {
            this.railOverflowBlock = block;
        }
    }

    get sidebarClass() {
        let classes = 'v360-shell-sidebar';
        if (this.railOverflowInline) {
            classes += ' v360-shell-sidebar_overflow-inline';
        }
        if (this.railOverflowBlock) {
            classes += ' v360-shell-sidebar_overflow-block';
        }
        return classes;
    }

    renderedCallback() {
        this.syncHeaderActionsFromMountedCard();
        this.syncRailOverflowObserver();
        this.measureRailOverflow();
    }

    syncFromCustomerState() {
        const { status, data, error } = this.customerState.value;
        this.status = status;
        this.error = error;
        this.cards = (data ?? []).map((decision) => this.toRenderableCard(decision));
        this.hydrateCardConstructors();
    }

    /**
     * Reacts to any change on this record's shell-state session. Only a
     * change to the selected card resets the locally-tracked header actions
     * -- registerHeaderActions itself writes into this same session, so
     * blindly resetting on every notification would wipe out the actions we
     * just registered and loop forever.
     */
    syncFromShellState() {
        const nextSelectedCardKey = this.shellState.value.selectedCard;
        if (nextSelectedCardKey !== this.selectedCardKey) {
            this.selectedCardKey = nextSelectedCardKey;
            this.headerActions = [];
        }
    }

    toRenderableCard(decision) {
        const isLwc = decision.componentType === COMPONENT_TYPE_LWC;
        const isFlow = decision.componentType === COMPONENT_TYPE_FLOW;
        const isKnownLwc = isLwc && isRegisteredCard(decision.componentName);
        return {
            key: decision.cardName,
            label: decision.label,
            description: decision.description,
            // A card with no configured icon still gets one: the tile and
            // sidebar rail rely on the icon for visual rhythm, and a config
            // gap must degrade to a neutral glyph, not a hole in the chrome.
            iconName: decision.iconName || DEFAULT_CARD_ICON,
            buttonLabel: decision.buttonLabel || DEFAULT_BUTTON_LABEL,
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
     * immutably to trigger a re-render of just-ready cards. Hydrating every
     * card up front (not only the selected one) means a card is usually
     * already resolved by the time the user selects it from the gallery or
     * sidebar, minimizing the shell's own hydration placeholder.
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

    /**
     * Reads the optional header-actions interface off the currently mounted
     * dynamic card, if any, and registers/renders a fresh copy only when the
     * action set actually changed -- the card's headerActions getter is free
     * to return a new array literal on every access, so a reference
     * comparison would reassign (and re-render, and re-run this very method)
     * forever.
     */
    syncHeaderActionsFromMountedCard() {
        const mountedCard = this.refs?.mountedCard;
        const actions =
            mountedCard && typeof mountedCard.headerActions !== 'undefined' ? mountedCard.headerActions ?? [] : [];
        if (this.areHeaderActionsEqual(actions, this.headerActions)) {
            return;
        }
        this.headerActions = actions;
        if (this.selectedCardKey) {
            this.shellState.value.registerHeaderActions(this.selectedCardKey, actions);
        }
    }

    areHeaderActionsEqual(left, right) {
        if (left.length !== right.length) {
            return false;
        }
        return left.every((action, index) => {
            const other = right[index];
            return (
                other &&
                action[HEADER_ACTION_NAME] === other[HEADER_ACTION_NAME] &&
                action[HEADER_ACTION_LABEL] === other[HEADER_ACTION_LABEL] &&
                action[HEADER_ACTION_ICON] === other[HEADER_ACTION_ICON]
            );
        });
    }

    handleSelectCard(event) {
        const cardName = event.currentTarget.dataset.cardName;
        this.shellState.value.selectCard(cardName);
    }

    /**
     * Pinning is the user's own presentation preference (see
     * c/v360CardPreferences); the click must not bubble into the tile's
     * select handler, or toggling a pin would also launch the card.
     */
    handleTogglePin(event) {
        event.stopPropagation();
        this.pinnedKeys = togglePin(this.tabApiName, event.currentTarget.dataset.cardName);
    }

    /**
     * The server returns cards in admin-configured Order__c sequence; the
     * user's pinned cards lift to the front while keeping that same
     * relative order among themselves, so the result stays predictable.
     */
    sortByPins(cards) {
        const pinned = cards.filter((card) => this.pinnedKeys.includes(card.key));
        const unpinned = cards.filter((card) => !this.pinnedKeys.includes(card.key));
        return [...pinned, ...unpinned];
    }

    handleBack() {
        this.shellState.value.selectCard(null);
    }

    handleHeaderActionsChange() {
        this.syncHeaderActionsFromMountedCard();
    }

    handleHeaderActionClick(event) {
        this.invokeHeaderAction(event.currentTarget.dataset.actionName);
    }

    handleOverflowActionSelect(event) {
        this.invokeHeaderAction(event.detail.value);
    }

    invokeHeaderAction(actionName) {
        const mountedCard = this.refs?.mountedCard;
        if (mountedCard && typeof mountedCard.invokeHeaderAction === 'function') {
            mountedCard.invokeHeaderAction(actionName);
        }
    }

    /**
     * Up to three actions render inline; beyond that, two stay inline and
     * the rest collapse into an overflow menu, so the header never grows an
     * unbounded button row.
     */
    get visibleHeaderActions() {
        return this.headerActions.length > 3 ? this.headerActions.slice(0, 2) : this.headerActions;
    }

    get overflowHeaderActions() {
        return this.headerActions.length > 3 ? this.headerActions.slice(2) : [];
    }

    get hasOverflowHeaderActions() {
        return this.overflowHeaderActions.length > 0;
    }

    handleRetry() {
        this.customerState.value.refresh(this.tabApiName);
    }

    /** A template cannot negate, and this branch has to come before the rest. */
    get hasNoTab() {
        return !this.hasTab;
    }

    /**
     * Never loading without a tab: the status atom starts at 'unconfigured'
     * and nothing will move it, since no read was ever started -- so this
     * would spin for as long as the page is open.
     */
    get isLoading() {
        return this.hasTab && (this.status === 'unconfigured' || this.status === 'loading');
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

    /** The full decision for the selected card, or null when none matches (including a stale selection for a card no longer visible). */
    get selectedCard() {
        if (!this.selectedCardKey) {
            return null;
        }
        return this.cards.find((card) => card.key === this.selectedCardKey) ?? null;
    }

    get isGalleryView() {
        return this.hasCards && !this.selectedCard;
    }

    get isFocusedView() {
        return this.hasCards && Boolean(this.selectedCard);
    }

    /** True while a selected LWC card's constructor is still resolving -- the shell's own loading placeholder for stage 1 of the card lifecycle. */
    get isSelectedCardHydrating() {
        const selected = this.selectedCard;
        return Boolean(selected) && selected.isLwc && !selected.ctor;
    }

    /**
     * The rail reflects the pinned-first order but carries no pin control:
     * it is the fast card-switching surface, and pinning is a deliberate
     * curation act that lives on the gallery tiles.
     */
    get sidebarCards() {
        return this.sortByPins(this.cards).map((card) => ({
            ...card,
            itemClass:
                card.key === this.selectedCardKey
                    ? 'v360-shell-sidebar-item v360-shell-sidebar-item_active'
                    : 'v360-shell-sidebar-item'
        }));
    }

    get galleryCards() {
        return this.sortByPins(this.cards).map((card) => {
            const isPinned = this.pinnedKeys.includes(card.key);
            return {
                ...card,
                isPinned,
                pinIconName: isPinned ? 'utility:pinned' : 'utility:pin',
                pinLabel: isPinned ? 'Unpin' : 'Pin to top',
                pinClass: isPinned
                    ? 'v360-shell-tile-pin v360-shell-tile-pin_active slds-m-left_x-small'
                    : 'v360-shell-tile-pin slds-m-left_x-small'
            };
        });
    }
}
