import { createElement } from 'lwc';
import V360Shell from 'c/v360Shell';
import { getVisibleCards, getVisibleCardsFresh } from 'c/v360Service';
import { has, load } from 'c/v360CardRegistry';
import v360ShellState from 'c/v360ShellState';
import V360AccountSnapshot from 'c/v360AccountSnapshot';

jest.mock('c/v360Service', () => ({
    getVisibleCards: jest.fn(),
    getVisibleCardsFresh: jest.fn()
}));

jest.mock('c/v360CardRegistry', () => ({
    has: jest.fn(),
    load: jest.fn()
}));

// Yields ten macrotask turns rather than one. The work a test waits on --
// a wire emit, a state-manager notification, a re-render, a dynamic import --
// often spans several chained turns, and a single setTimeout hop is exactly
// the assumption that goes flaky on a loaded CI worker while passing on a
// fast idle laptop. Ten is generous headroom, not a measured count.
const flushPromises = async () => {
    for (let turn = 0; turn < 10; turn += 1) {
        // eslint-disable-next-line no-await-in-loop
        await new Promise((res) => setTimeout(res, 0));
    }
};

/**
 * A configured placement. The tab is set explicitly because the component has
 * no default one -- these tests used to inherit a fallback tab name, which is
 * exactly the thing that made an unconfigured component look configured.
 */
function createShell(recordId, tabApiName = 'AccountOverview') {
    const element = createElement('c-v360-shell', { is: V360Shell });
    element.recordId = recordId;
    element.tabApiName = tabApiName;
    document.body.appendChild(element);
    return element;
}

describe('c-v360-shell', () => {
    afterEach(() => {
        while (document.body.firstChild) {
            document.body.removeChild(document.body.firstChild);
        }
        jest.clearAllMocks();
    });

    /**
     * A placement with no tab is a configuration gap, and the component says
     * so rather than guessing. It used to fall back to a tab name, which meant
     * a component dropped on a page rendered somebody else's cards and looked
     * configured while nobody had chosen anything.
     */
    it('says no tab is selected, and asks the server for nothing, when tabApiName is absent', () => {
        const element = createElement('c-v360-shell', { is: V360Shell });
        element.recordId = '001000000000400AAA';
        document.body.appendChild(element);

        expect(element.shadowRoot.querySelector('[data-id="no-tab-state"]')).not.toBeNull();
        expect(getVisibleCards).not.toHaveBeenCalled();
    });

    /** A blank string is a cleared property, not a tab named "". */
    it('treats a blank tabApiName the same as none at all', () => {
        const element = createElement('c-v360-shell', { is: V360Shell });
        element.recordId = '001000000000400AAA';
        element.tabApiName = '   ';
        document.body.appendChild(element);

        expect(element.shadowRoot.querySelector('[data-id="no-tab-state"]')).not.toBeNull();
        expect(getVisibleCards).not.toHaveBeenCalled();
    });

    /** Nothing was ever requested, so there is nothing to wait for. */
    it('does not sit on a spinner when there is no tab to load', () => {
        const element = createElement('c-v360-shell', { is: V360Shell });
        element.recordId = '001000000000400AAA';
        document.body.appendChild(element);

        expect(element.shadowRoot.querySelector('[data-id="loading-state"]')).toBeNull();
    });

    it('shows a loading state while the visible-card request is in flight', () => {
        getVisibleCards.mockReturnValue(new Promise(() => {}));

        const element = createShell('001000000000401AAA');

        expect(element.shadowRoot.querySelector('[data-id="loading-state"]')).not.toBeNull();
    });

    it('shows a recoverable-error empty state when the visible-card request fails, and retry re-requests fresh data', async () => {
        getVisibleCards.mockRejectedValue(new Error('boom'));
        getVisibleCardsFresh.mockResolvedValue([]);

        const element = createShell('001000000000402AAA');
        await flushPromises();

        const errorState = element.shadowRoot.querySelector('[data-id="error-state"]');
        expect(errorState).not.toBeNull();
        expect(errorState.illustrationName).toBe('error:recoverable');
        expect(errorState.retryLabel).toBe('Retry');

        errorState.dispatchEvent(new CustomEvent('retry'));
        await flushPromises();

        expect(getVisibleCardsFresh).toHaveBeenCalledWith('001000000000402AAA', 'AccountOverview');
    });

    it('shows a no-results empty state when no cards are configured for the tab', async () => {
        getVisibleCards.mockResolvedValue([]);

        const element = createShell('001000000000403AAA');
        await flushPromises();

        const emptyState = element.shadowRoot.querySelector('[data-id="empty-state"]');
        expect(emptyState).not.toBeNull();
        expect(emptyState.illustrationName).toBe('noresults:unknown');
    });

    it('renders a registered LWC card through dynamic dispatch', async () => {
        has.mockReturnValue(true);
        load.mockResolvedValue(V360AccountSnapshot);
        getVisibleCards.mockResolvedValue([
            {
                cardName: 'v360AccountSnapshot',
                componentType: 'LWC',
                componentName: 'v360AccountSnapshot',
                label: 'Snapshot',
                iconName: 'standard:account',
                buttonLabel: 'Open',
                order: 1
            }
        ]);

        const element = createShell('001000000000404AAA');
        await flushPromises();
        await flushPromises();

        // Gallery first: the tile launches the card, it never mounts it.
        const tile = element.shadowRoot.querySelector('[data-id="gallery-tile"][data-card-name="v360AccountSnapshot"]');
        expect(tile).not.toBeNull();
        tile.click();
        await flushPromises();
        await flushPromises();

        expect(load).toHaveBeenCalledWith('v360AccountSnapshot');
        const focusedTitle = element.shadowRoot.querySelector('[data-id="focused-title"]');
        expect(focusedTitle).not.toBeNull();
        expect(focusedTitle.textContent).toBe('Snapshot');
        // A dynamically instantiated component's tag name is
        // environment-defined (the Jest harness uses a synthetic one), so the
        // mounted card is asserted through the props it received rather than
        // a tag selector: it is the element carrying the recordId.
        const mounted = Array.from(element.shadowRoot.querySelectorAll('*')).find(
            (node) => node.recordId === '001000000000404AAA'
        );
        expect(mounted).not.toBeUndefined();
        expect(element.shadowRoot.querySelector('[data-id="unknown-binding"]')).toBeNull();
    });

    it('renders a labeled placeholder for a Flow card', async () => {
        getVisibleCards.mockResolvedValue([
            {
                cardName: 'someFlowCard',
                componentType: 'Flow',
                componentName: 'Some_Screen_Flow',
                label: 'Flow Card',
                iconName: 'standard:flow',
                buttonLabel: 'Open',
                order: 1
            }
        ]);

        const element = createShell('001000000000405AAA');
        await flushPromises();

        const tile = element.shadowRoot.querySelector('[data-id="gallery-tile"][data-card-name="someFlowCard"]');
        expect(tile).not.toBeNull();
        tile.click();
        await flushPromises();

        const placeholder = element.shadowRoot.querySelector('[data-id="flow-placeholder"]');
        expect(placeholder).not.toBeNull();
        expect(placeholder.textContent).toContain('Some_Screen_Flow');
        expect(has).not.toHaveBeenCalled();
    });

    it('renders a safe inline error for an LWC binding the registry does not recognize', async () => {
        has.mockReturnValue(false);
        getVisibleCards.mockResolvedValue([
            {
                cardName: 'unknownCard',
                componentType: 'LWC',
                componentName: 'doesNotExist',
                label: 'Unknown',
                iconName: null,
                buttonLabel: null,
                order: 1
            }
        ]);

        const element = createShell('001000000000406AAA');
        await flushPromises();

        const tile = element.shadowRoot.querySelector('[data-id="gallery-tile"][data-card-name="unknownCard"]');
        expect(tile).not.toBeNull();
        tile.click();
        await flushPromises();

        const unknownBinding = element.shadowRoot.querySelector('[data-id="unknown-binding"]');
        expect(unknownBinding).not.toBeNull();
        expect(unknownBinding.illustrationName).toBe('error:unrecoverable');
        expect(element.shadowRoot.querySelector('c-pipeline-probe')).toBeNull();
    });

    it('selects a card in shell state when its wrapper is clicked', async () => {
        has.mockReturnValue(true);
        load.mockResolvedValue(V360AccountSnapshot);
        getVisibleCards.mockResolvedValue([
            {
                cardName: 'v360AccountSnapshot',
                componentType: 'LWC',
                componentName: 'v360AccountSnapshot',
                label: 'Snapshot',
                iconName: 'standard:account',
                buttonLabel: 'Open',
                order: 1
            }
        ]);
        const recordId = '001000000000407AAA';

        const element = createShell(recordId);
        await flushPromises();

        const cardWrapper = element.shadowRoot.querySelector('[data-card-name="v360AccountSnapshot"]');
        expect(cardWrapper).not.toBeNull();
        cardWrapper.click();

        expect(v360ShellState(recordId).value.selectedCard).toBe('v360AccountSnapshot');
    });

    it('requests the visible-card list for the configured tabApiName', () => {
        getVisibleCards.mockReturnValue(new Promise(() => {}));

        const element = createElement('c-v360-shell', { is: V360Shell });
        element.recordId = '001000000000408AAA';
        element.tabApiName = 'CreditCards';
        document.body.appendChild(element);

        expect(getVisibleCards).toHaveBeenCalledWith('001000000000408AAA', 'CreditCards');
    });

    it('focused view lists every card in the sidebar, switches selection, and returns to gallery via back', async () => {
        has.mockReturnValue(true);
        load.mockResolvedValue(V360AccountSnapshot);
        getVisibleCards.mockResolvedValue([
            { cardName: 'cardA', componentType: 'LWC', componentName: 'a', label: 'Card A', iconName: 'standard:account', buttonLabel: 'Open', order: 1 },
            { cardName: 'cardB', componentType: 'LWC', componentName: 'b', label: 'Card B', iconName: 'standard:contact', buttonLabel: 'Open', order: 2 }
        ]);

        const element = createShell('001000000000409AAA');
        await flushPromises();
        await flushPromises();

        element.shadowRoot.querySelector('[data-id="gallery-tile"][data-card-name="cardA"]').click();
        await flushPromises();

        const sidebarItems = element.shadowRoot.querySelectorAll('[data-id="sidebar-item"]');
        expect(sidebarItems.length).toBe(2);
        expect(element.shadowRoot.querySelector('[data-id="focused-title"]').textContent).toBe('Card A');

        element.shadowRoot.querySelector('[data-id="sidebar-item"][data-card-name="cardB"]').click();
        await flushPromises();
        expect(element.shadowRoot.querySelector('[data-id="focused-title"]').textContent).toBe('Card B');

        element.shadowRoot.querySelector('[data-id="back-button"]').click();
        await flushPromises();
        expect(element.shadowRoot.querySelector('[data-id="gallery-view"]')).not.toBeNull();
        expect(element.shadowRoot.querySelector('[data-id="focused-view"]')).toBeNull();
    });

    it('renders the header actions a mounted card exposes and invokes them on click', async () => {
        // The real snapshot card implements the optional protocol (a
        // 'refresh' action wired to refreshApex) — mount it and assert the
        // shell surfaces and invokes it.
        const { refreshApex } = require('@salesforce/apex');
        refreshApex.mockClear();
        has.mockReturnValue(true);
        load.mockResolvedValue(V360AccountSnapshot);
        getVisibleCards.mockResolvedValue([
            { cardName: 'protoCard', componentType: 'LWC', componentName: 'protoCard', label: 'Proto', iconName: 'standard:bot', buttonLabel: 'Open', order: 1 }
        ]);

        const element = createShell('001000000000410AAA');
        await flushPromises();
        await flushPromises();
        element.shadowRoot.querySelector('[data-id="gallery-tile"][data-card-name="protoCard"]').click();
        await flushPromises();
        await flushPromises();

        const actionButtons = element.shadowRoot.querySelectorAll('[data-id="header-action"]');
        expect(actionButtons.length).toBe(1);
        expect(actionButtons[0].iconName).toBe('utility:refresh');
        expect(actionButtons[0].title).toBe('Refresh');

        actionButtons[0].click();
        expect(refreshApex).toHaveBeenCalled();
    });
});
