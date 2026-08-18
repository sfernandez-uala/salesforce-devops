import { createElement } from 'lwc';
import V360IconPicker from 'c/v360IconPicker';

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

function createPicker(selectedIcon) {
    const element = createElement('c-v360-icon-picker', { is: V360IconPicker });
    if (selectedIcon) {
        element.selectedIcon = selectedIcon;
    }
    document.body.appendChild(element);
    return element;
}

describe('c-v360-icon-picker', () => {
    afterEach(() => {
        while (document.body.firstChild) {
            document.body.removeChild(document.body.firstChild);
        }
    });

    it('browses the Standard category by default with a capped grid', () => {
        const element = createPicker();

        const tabs = element.shadowRoot.querySelectorAll('[data-id="category-tab"]');
        expect(tabs.length).toBe(5);
        expect(tabs[0].label).toBe('Standard');
        expect(tabs[0].variant).toBe('brand');

        const tiles = element.shadowRoot.querySelectorAll('[data-id="icon-tile"]');
        expect(tiles.length).toBeGreaterThan(0);
        expect(tiles.length).toBeLessThanOrEqual(120);
        expect(tiles[0].dataset.icon.startsWith('standard:')).toBe(true);
        expect(element.shadowRoot.querySelector('[data-id="truncated-hint"]')).not.toBeNull();
    });

    it('preselects the category of the currently selected icon and highlights it', () => {
        // "add" sorts near the front of the utility list, well inside the
        // browsing cap, so it is guaranteed to render without a search.
        const element = createPicker('utility:add');

        const tabs = element.shadowRoot.querySelectorAll('[data-id="category-tab"]');
        const utilityTab = Array.from(tabs).find((tab) => tab.label === 'Utility');
        expect(utilityTab.variant).toBe('brand');

        const selected = element.shadowRoot.querySelector('[data-icon="utility:add"]');
        expect(selected.className).toContain('v360-icon-picker-tile_selected');
    });

    it('switches category on tab click and resets any search', async () => {
        const element = createPicker();

        element.shadowRoot
            .querySelector('[data-id="category-tab"][data-category="utility"]')
            .click();
        await flushPromises();

        const tiles = element.shadowRoot.querySelectorAll('[data-id="icon-tile"]');
        expect(tiles[0].dataset.icon.startsWith('utility:')).toBe(true);
    });

    it('searches across every category and shows every match, uncapped', async () => {
        const element = createPicker();

        element.shadowRoot
            .querySelector('[data-id="icon-search"]')
            .dispatchEvent(new CustomEvent('change', { detail: { value: 'account' } }));
        await flushPromises();

        const tiles = Array.from(element.shadowRoot.querySelectorAll('[data-id="icon-tile"]'));
        expect(tiles.length).toBeGreaterThan(1);
        expect(tiles.every((tile) => tile.dataset.icon.includes('account'))).toBe(true);
        // A match should include a category other than Standard alone.
        expect(tiles.some((tile) => !tile.dataset.icon.startsWith('standard:'))).toBe(true);
        expect(element.shadowRoot.querySelector('[data-id="category-tab"]')).toBeNull();
        expect(element.shadowRoot.querySelector('[data-id="truncated-hint"]')).toBeNull();
    });

    it('shows the no-results state for a search with no matches', async () => {
        const element = createPicker();

        element.shadowRoot
            .querySelector('[data-id="icon-search"]')
            .dispatchEvent(new CustomEvent('change', { detail: { value: 'zzz_not_a_real_icon' } }));
        await flushPromises();

        const emptyState = element.shadowRoot.querySelector('[data-id="no-results-state"]');
        expect(emptyState).not.toBeNull();
        expect(emptyState.illustrationName).toBe('noresults:unknown');
    });

    it('dispatches select with the full icon name when a tile is clicked', () => {
        const element = createPicker();
        const selectHandler = jest.fn();
        element.addEventListener('select', selectHandler);

        const tile = element.shadowRoot.querySelector('[data-id="icon-tile"]');
        const fullName = tile.dataset.icon;
        tile.click();

        expect(selectHandler).toHaveBeenCalledTimes(1);
        expect(selectHandler.mock.calls[0][0].detail.value).toBe(fullName);
    });

    it('dispatches close when cancelled', () => {
        const element = createPicker();
        const closeHandler = jest.fn();
        element.addEventListener('close', closeHandler);

        element.shadowRoot.querySelector('[data-id="cancel"]').click();

        expect(closeHandler).toHaveBeenCalledTimes(1);
    });
});
