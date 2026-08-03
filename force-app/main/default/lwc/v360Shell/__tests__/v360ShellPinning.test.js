import { createElement } from 'lwc';
import V360Shell from 'c/v360Shell';
import { getVisibleCards } from 'c/v360Service';

jest.mock('c/v360Service', () => ({
    getVisibleCards: jest.fn(),
    getVisibleCardsFresh: jest.fn()
}));

jest.mock('c/v360CardRegistry', () => ({
    has: jest.fn(() => false),
    load: jest.fn(() => Promise.resolve(null))
}));

const STORAGE_KEY = 'v360PinnedCards:AccountOverview';

const flushPromises = () => new Promise((res) => setTimeout(res, 0));

// Flow-typed decisions keep the registry out of these tests: the gallery
// renders tiles for any component type.
function decision(cardName, label) {
    return {
        cardName,
        componentType: 'Flow',
        componentName: `${cardName}_Flow`,
        label,
        iconName: 'standard:screen',
        buttonLabel: 'Open'
    };
}

function createShell(recordId) {
    const element = createElement('c-v360-shell', { is: V360Shell });
    element.recordId = recordId;
    document.body.appendChild(element);
    return element;
}

function tileOrder(element) {
    return Array.from(element.shadowRoot.querySelectorAll('[data-id="gallery-tile"]')).map(
        (tile) => tile.dataset.cardName
    );
}

describe('c-v360-shell card pinning', () => {
    beforeEach(() => {
        getVisibleCards.mockResolvedValue([
            decision('alpha', 'Alpha'),
            decision('beta', 'Beta'),
            decision('gamma', 'Gamma')
        ]);
    });

    afterEach(() => {
        while (document.body.firstChild) {
            document.body.removeChild(document.body.firstChild);
        }
        window.localStorage.clear();
        jest.clearAllMocks();
    });

    it('renders tiles in the server-provided admin order when nothing is pinned', async () => {
        const element = createShell('001000000000501AAA');
        await flushPromises();

        expect(tileOrder(element)).toEqual(['alpha', 'beta', 'gamma']);
    });

    it('lifts a pinned card to the front, persists it, and does not launch the card', async () => {
        const element = createShell('001000000000502AAA');
        await flushPromises();

        element.shadowRoot.querySelector('[data-id="pin-toggle"][data-card-name="gamma"]').click();
        await flushPromises();

        expect(tileOrder(element)).toEqual(['gamma', 'alpha', 'beta']);
        expect(JSON.parse(window.localStorage.getItem(STORAGE_KEY))).toEqual(['gamma']);
        // Toggling a pin is not a selection: the gallery stays on screen.
        expect(element.shadowRoot.querySelector('[data-id="gallery-view"]')).not.toBeNull();
        const pinnedToggle = element.shadowRoot.querySelector(
            '[data-id="pin-toggle"][data-card-name="gamma"]'
        );
        expect(pinnedToggle.iconName).toBe('utility:pinned');
        expect(pinnedToggle.alternativeText).toBe('Unpin');
    });

    it('restores the pinned-first order from a previous session', async () => {
        window.localStorage.setItem(STORAGE_KEY, JSON.stringify(['beta']));

        const element = createShell('001000000000503AAA');
        await flushPromises();

        expect(tileOrder(element)).toEqual(['beta', 'alpha', 'gamma']);
    });

    it('returns an unpinned card to its admin position', async () => {
        window.localStorage.setItem(STORAGE_KEY, JSON.stringify(['beta']));

        const element = createShell('001000000000504AAA');
        await flushPromises();

        element.shadowRoot.querySelector('[data-id="pin-toggle"][data-card-name="beta"]').click();
        await flushPromises();

        expect(tileOrder(element)).toEqual(['alpha', 'beta', 'gamma']);
        expect(JSON.parse(window.localStorage.getItem(STORAGE_KEY))).toEqual([]);
    });

    it('orders the focused-view sidebar with pinned cards first as well', async () => {
        window.localStorage.setItem(STORAGE_KEY, JSON.stringify(['gamma']));

        const element = createShell('001000000000505AAA');
        await flushPromises();
        element.shadowRoot.querySelector('[data-id="gallery-tile"][data-card-name="alpha"]').click();
        await flushPromises();

        const railOrder = Array.from(
            element.shadowRoot.querySelectorAll('[data-id="sidebar-item"]')
        ).map((item) => item.dataset.cardName);
        expect(railOrder).toEqual(['gamma', 'alpha', 'beta']);
    });
});
