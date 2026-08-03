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

const flushPromises = () => new Promise((res) => setTimeout(res, 0));

function createShell(recordId) {
    const element = createElement('c-v360-shell', { is: V360Shell });
    element.recordId = recordId;
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

        expect(load).toHaveBeenCalledWith('v360AccountSnapshot');
        const cardWrapper = element.shadowRoot.querySelector('[data-card-name="v360AccountSnapshot"]');
        expect(cardWrapper).not.toBeNull();
        // A dynamically instantiated component's tag name is
        // environment-defined (the Jest harness uses a synthetic one), so the
        // mounted card is asserted through its position and the props it
        // received rather than a tag selector.
        const mountedCard = cardWrapper.firstElementChild;
        expect(mountedCard).not.toBeNull();
        expect(mountedCard.recordId).toBe('001000000000404AAA');
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
});
