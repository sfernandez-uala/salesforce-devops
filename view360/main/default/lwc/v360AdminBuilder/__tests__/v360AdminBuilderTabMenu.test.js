import { createElement } from 'lwc';
import V360AdminBuilder from 'c/v360AdminBuilder';
import getCatalog from '@salesforce/apex/V360AdminController.getCatalog';

jest.mock(
    '@salesforce/apex/V360AdminController.getCatalog',
    () => ({ default: jest.fn() }),
    { virtual: true }
);

jest.mock(
    'lightning/platformWorkspaceApi',
    () => ({
        EnclosingTabId: jest.fn(),
        IsConsoleNavigation: jest.fn(),
        setTabLabel: jest.fn(() => Promise.resolve()),
        setTabIcon: jest.fn(() => Promise.resolve())
    }),
    { virtual: true }
);

jest.mock('c/v360CardRegistry', () => ({ names: jest.fn(() => []) }), { virtual: true });

// The builder measures its own top offset through a ResizeObserver, which
// jsdom does not implement. Nothing about the switcher depends on the
// measurement, so a stub that never fires is enough to let it render.
global.ResizeObserver = class {
    observe() {}
    unobserve() {}
    disconnect() {}
};

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

function tab(tabId, developerName, sObjectApiName) {
    return { tabId, developerName, sObjectApiName, sequence: 1, cards: [] };
}

/**
 * The switcher is the only thing under test, so every tab is card-free: the
 * canvas below it renders an empty state and stays out of the way.
 */
function catalog(tabs) {
    return { hasManagePermission: true, tabs };
}

const TWO_OBJECTS = catalog([
    tab('a01000000000001', 'AccountOverview', 'Account'),
    tab('a01000000000002', 'AccountRisk', 'Account'),
    tab('a01000000000003', 'CaseTimeline', 'Case')
]);

/** Past the filter threshold, so the search field earns its place. */
const MANY = catalog(
    Array.from({ length: 12 }, (_, index) =>
        tab(`a0100000000${String(index).padStart(4, '0')}`, `Surface${index}`, 'Account')
    )
);

async function createBuilder(payload = TWO_OBJECTS) {
    getCatalog.mockResolvedValue(payload);
    const element = createElement('c-v360-admin-builder', { is: V360AdminBuilder });
    document.body.appendChild(element);
    await flushPromises();
    return element;
}

const trigger = (element) => element.shadowRoot.querySelector('[data-id="tab-switcher"]');
const menu = (element) => element.shadowRoot.querySelector('[data-id="tab-menu"]');
const items = (element) =>
    Array.from(element.shadowRoot.querySelectorAll('[data-menu-item]'));
const options = (element) =>
    Array.from(element.shadowRoot.querySelectorAll('[data-id="tab-option"]'));

function press(target, key) {
    target.dispatchEvent(new KeyboardEvent('keydown', { key, bubbles: true, composed: true }));
}

async function open(element) {
    trigger(element).click();
    await flushPromises();
}

describe('c-v360-admin-builder tab menu', () => {
    afterEach(() => {
        while (document.body.firstChild) {
            document.body.removeChild(document.body.firstChild);
        }
        jest.clearAllMocks();
    });

    // ---- structure ----------------------------------------------------

    it('wires the trigger to the menu it controls', async () => {
        const element = await createBuilder();

        const button = trigger(element);
        expect(button.getAttribute('aria-haspopup')).toBe('menu');
        expect(button.getAttribute('aria-expanded')).toBe('false');
        expect(button.getAttribute('aria-controls')).toBe(menu(element).getAttribute('id'));
        expect(menu(element).getAttribute('role')).toBe('menu');

        await open(element);
        expect(trigger(element).getAttribute('aria-expanded')).toBe('true');
    });

    it('marks the open tab as the checked option and leaves the others unchecked', async () => {
        const element = await createBuilder();
        await open(element);

        const checked = options(element).filter(
            (option) => option.getAttribute('aria-checked') === 'true'
        );
        expect(checked).toHaveLength(1);
        expect(checked[0].dataset.tabId).toBe('a01000000000001');
        expect(options(element).every((o) => o.getAttribute('role') === 'menuitemradio')).toBe(true);
    });

    it('bounds the list so a long tab set scrolls inside the menu instead of past the viewport', async () => {
        const element = await createBuilder(MANY);
        await open(element);

        const list = element.shadowRoot.querySelector('.slds-dropdown__list');
        expect(list.className).toContain('slds-dropdown_length-with-icon-10');
    });

    it('groups options under their anchor object', async () => {
        const element = await createBuilder();
        await open(element);

        const groups = Array.from(
            element.shadowRoot.querySelectorAll('[data-id="tab-group"]')
        ).map((group) => group.textContent.trim());
        expect(groups).toEqual(['Account', 'Case']);
    });

    // ---- keyboard -----------------------------------------------------

    it('opens on ArrowDown from the trigger and lands focus on the first item', async () => {
        const element = await createBuilder();

        press(trigger(element), 'ArrowDown');
        await flushPromises();

        expect(trigger(element).getAttribute('aria-expanded')).toBe('true');
        expect(element.shadowRoot.activeElement).toBe(items(element)[0]);
    });

    it('walks the items with the arrow keys and wraps at both ends', async () => {
        const element = await createBuilder();
        await open(element);

        const all = items(element);
        expect(element.shadowRoot.activeElement).toBe(all[0]);

        press(all[0], 'ArrowDown');
        expect(element.shadowRoot.activeElement).toBe(all[1]);

        press(all[1], 'ArrowUp');
        expect(element.shadowRoot.activeElement).toBe(all[0]);

        press(all[0], 'ArrowUp');
        expect(element.shadowRoot.activeElement).toBe(all[all.length - 1]);

        press(all[all.length - 1], 'ArrowDown');
        expect(element.shadowRoot.activeElement).toBe(all[0]);
    });

    it('jumps to the ends with Home and End', async () => {
        const element = await createBuilder();
        await open(element);

        const all = items(element);
        press(all[0], 'End');
        expect(element.shadowRoot.activeElement).toBe(all[all.length - 1]);

        press(all[all.length - 1], 'Home');
        expect(element.shadowRoot.activeElement).toBe(all[0]);
    });

    it('closes on Escape and hands focus back to the trigger', async () => {
        const element = await createBuilder();
        await open(element);

        press(items(element)[0], 'Escape');
        await flushPromises();

        expect(trigger(element).getAttribute('aria-expanded')).toBe('false');
        expect(element.shadowRoot.activeElement).toBe(trigger(element));
    });

    it('activates the focused option with Enter, the way a click would', async () => {
        const element = await createBuilder();
        await open(element);

        const second = options(element)[1];
        press(second, 'Enter');
        await flushPromises();

        expect(trigger(element).getAttribute('aria-expanded')).toBe('false');
        expect(trigger(element).textContent).toContain('AccountRisk');
    });

    // ---- filtering ----------------------------------------------------

    it('leaves the search field out of a menu short enough to read at a glance', async () => {
        const element = await createBuilder();
        await open(element);

        expect(element.shadowRoot.querySelector('[data-id="tab-filter"]')).toBeNull();
    });

    it('offers a search field once the tab set outgrows the menu, and focuses it on open', async () => {
        const element = await createBuilder(MANY);
        await open(element);

        const filter = element.shadowRoot.querySelector('[data-id="tab-filter"]');
        expect(filter).not.toBeNull();
        expect(element.shadowRoot.activeElement).toBe(filter);
    });

    it('narrows the options to the search term and drops groups left with nothing', async () => {
        const element = await createBuilder(
            catalog([
                ...MANY.tabs,
                tab('a01000000000099', 'CaseTimeline', 'Case')
            ])
        );
        await open(element);

        const filter = element.shadowRoot.querySelector('[data-id="tab-filter"]');
        filter.value = 'timeline';
        filter.dispatchEvent(new CustomEvent('input', { bubbles: true, composed: true }));
        await flushPromises();

        expect(options(element).map((o) => o.dataset.tabId)).toEqual(['a01000000000099']);
        expect(
            Array.from(element.shadowRoot.querySelectorAll('[data-id="tab-group"]')).map((g) =>
                g.textContent.trim()
            )
        ).toEqual(['Case']);
    });

    it('says so when the search matches nothing rather than showing an empty menu', async () => {
        const element = await createBuilder(MANY);
        await open(element);

        const filter = element.shadowRoot.querySelector('[data-id="tab-filter"]');
        filter.value = 'nothing-matches-this';
        filter.dispatchEvent(new CustomEvent('input', { bubbles: true, composed: true }));
        await flushPromises();

        expect(options(element)).toHaveLength(0);
        expect(element.shadowRoot.querySelector('[data-id="tab-menu-empty"]')).not.toBeNull();
    });

    it('moves from the search field into the list with ArrowDown', async () => {
        const element = await createBuilder(MANY);
        await open(element);

        const filter = element.shadowRoot.querySelector('[data-id="tab-filter"]');
        press(filter, 'ArrowDown');

        expect(element.shadowRoot.activeElement).toBe(options(element)[0]);
    });

    it('forgets the search term between openings', async () => {
        const element = await createBuilder(MANY);
        await open(element);

        const filter = element.shadowRoot.querySelector('[data-id="tab-filter"]');
        filter.value = 'Surface1';
        filter.dispatchEvent(new CustomEvent('input', { bubbles: true, composed: true }));
        await flushPromises();
        expect(options(element).length).toBeLessThan(MANY.tabs.length);

        press(element.shadowRoot.querySelector('[data-id="tab-filter"]'), 'Escape');
        await flushPromises();
        await open(element);

        expect(options(element)).toHaveLength(MANY.tabs.length);
    });

    // ---- actions ------------------------------------------------------

    it('separates the tab actions from the options they sit under', async () => {
        const element = await createBuilder();
        await open(element);

        const editItem = element.shadowRoot.querySelector('[data-id="edit-tab"]');
        expect(editItem.closest('li').className).toContain('slds-has-divider_top-space');
        expect(editItem.getAttribute('role')).toBe('menuitem');
    });

    it('reaches the actions by keyboard like any other item', async () => {
        const element = await createBuilder();
        await open(element);

        const all = items(element);
        press(all[0], 'End');
        expect(element.shadowRoot.activeElement).toBe(
            element.shadowRoot.querySelector('[data-id="new-tab"]')
        );

        press(element.shadowRoot.activeElement, 'Enter');
        await flushPromises();

        expect(element.shadowRoot.querySelector('[data-id="tab-modal"]')).not.toBeNull();
    });
});
