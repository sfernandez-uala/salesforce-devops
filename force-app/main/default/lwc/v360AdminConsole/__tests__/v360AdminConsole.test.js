import { createElement } from 'lwc';
import V360AdminConsole from 'c/v360AdminConsole';
import getCatalog from '@salesforce/apex/V360AdminController.getCatalog';
import updateCardOrder from '@salesforce/apex/V360AdminController.updateCardOrder';

jest.mock(
    '@salesforce/apex/V360AdminController.getCatalog',
    () => ({ default: jest.fn() }),
    { virtual: true }
);

jest.mock(
    '@salesforce/apex/V360AdminController.updateCardOrder',
    () => ({ default: jest.fn() }),
    { virtual: true }
);

const flushPromises = () => new Promise((res) => setTimeout(res, 0));

function card(cardId, developerName, overrides = {}) {
    return {
        cardId,
        developerName,
        label: developerName,
        description: '',
        componentType: 'LWC',
        componentName: 'v360AccountSnapshot',
        iconName: 'standard:account',
        order: 1,
        active: true,
        killSwitch: false,
        ruleCount: 0,
        ...overrides
    };
}

function adminCatalog() {
    return {
        hasManagePermission: true,
        tabs: [
            {
                tabId: 'tab-account',
                developerName: 'AccountOverview',
                sObjectApiName: 'Account',
                sequence: 1,
                active: true,
                cards: [
                    card('card-a', 'CardA', { ruleCount: 2 }),
                    card('card-b', 'CardB', { active: false }),
                    card('card-c', 'CardC', { killSwitch: true })
                ]
            },
            {
                tabId: 'tab-case',
                developerName: 'CaseOverview',
                sObjectApiName: 'Case',
                sequence: 2,
                active: false,
                cards: [card('card-d', 'CardD')]
            }
        ]
    };
}

function createConsole() {
    const element = createElement('c-v360-admin-console', { is: V360AdminConsole });
    document.body.appendChild(element);
    return element;
}

function rowNames(element) {
    return Array.from(element.shadowRoot.querySelectorAll('[data-id="card-row"]')).map(
        (row) => row.textContent
    );
}

describe('c-v360-admin-console', () => {
    afterEach(() => {
        while (document.body.firstChild) {
            document.body.removeChild(document.body.firstChild);
        }
        jest.clearAllMocks();
    });

    it('shows the loading stencils while the catalog request is in flight', () => {
        getCatalog.mockReturnValue(new Promise(() => {}));

        const element = createConsole();

        expect(element.shadowRoot.querySelector('[data-id="loading-state"]')).not.toBeNull();
    });

    it('renders the first tab workspace with one row per card and its state badge', async () => {
        getCatalog.mockResolvedValue(adminCatalog());

        const element = createConsole();
        await flushPromises();

        expect(element.shadowRoot.querySelector('[data-id="workspace-title"]').textContent).toBe(
            'AccountOverview'
        );
        const states = Array.from(
            element.shadowRoot.querySelectorAll('[data-id="card-state"]')
        ).map((badge) => badge.textContent);
        expect(states).toEqual(['Live', 'Draft', 'Kill switch on']);
        const summaries = Array.from(
            element.shadowRoot.querySelectorAll('[data-id="rule-summary"]')
        ).map((p) => p.textContent.trim());
        expect(summaries[0]).toBe('2 visibility rules');
        expect(summaries[1]).toContain('visible to everyone');
    });

    it('switches the workspace when another tab is selected in the navigation', async () => {
        getCatalog.mockResolvedValue(adminCatalog());

        const element = createConsole();
        await flushPromises();

        element.shadowRoot
            .querySelector('[data-id="tab-navigation"]')
            .dispatchEvent(new CustomEvent('select', { detail: { name: 'tab-case' } }));
        await flushPromises();

        expect(element.shadowRoot.querySelector('[data-id="workspace-title"]').textContent).toBe(
            'CaseOverview'
        );
        expect(element.shadowRoot.querySelectorAll('[data-id="card-row"]')).toHaveLength(1);
    });

    it('moves a card down optimistically and persists the full new sequence', async () => {
        getCatalog.mockResolvedValue(adminCatalog());
        updateCardOrder.mockResolvedValue(undefined);

        const element = createConsole();
        await flushPromises();

        element.shadowRoot.querySelector('[data-id="move-down"][data-card-id="card-a"]').click();
        await flushPromises();

        expect(updateCardOrder).toHaveBeenCalledWith({
            orderedCardIds: ['card-b', 'card-a', 'card-c']
        });
        expect(rowNames(element)[0]).toContain('CardB');
    });

    it('disables moving the first card up and the last card down', async () => {
        getCatalog.mockResolvedValue(adminCatalog());

        const element = createConsole();
        await flushPromises();

        expect(
            element.shadowRoot.querySelector('[data-id="move-up"][data-card-id="card-a"]').disabled
        ).toBe(true);
        expect(
            element.shadowRoot.querySelector('[data-id="move-down"][data-card-id="card-c"]')
                .disabled
        ).toBe(true);
    });

    it('rolls back to the server order with a toast when the reorder save fails', async () => {
        getCatalog.mockResolvedValue(adminCatalog());
        updateCardOrder.mockRejectedValue(new Error('gate'));
        const element = createConsole();
        const toastHandler = jest.fn();
        element.addEventListener('lightning__showtoast', toastHandler);
        await flushPromises();

        element.shadowRoot.querySelector('[data-id="move-down"][data-card-id="card-a"]').click();
        await flushPromises();

        expect(toastHandler).toHaveBeenCalledTimes(1);
        expect(getCatalog).toHaveBeenCalledTimes(2);
        expect(rowNames(element)[0]).toContain('CardA');
    });

    it('renders the access state when the server reports no manage permission', async () => {
        getCatalog.mockResolvedValue({ hasManagePermission: false, tabs: [] });

        const element = createConsole();
        await flushPromises();

        const denied = element.shadowRoot.querySelector('[data-id="denied-state"]');
        expect(denied).not.toBeNull();
        expect(denied.illustrationName).toBe('access:request');
    });

    it('renders the no-configuration state for a permitted admin with no tabs', async () => {
        getCatalog.mockResolvedValue({ hasManagePermission: true, tabs: [] });

        const element = createConsole();
        await flushPromises();

        expect(element.shadowRoot.querySelector('[data-id="empty-state"]')).not.toBeNull();
    });

    it('shows the recoverable-error state and retries the request', async () => {
        getCatalog.mockRejectedValueOnce(new Error('boom')).mockResolvedValueOnce(adminCatalog());

        const element = createConsole();
        await flushPromises();

        const errorState = element.shadowRoot.querySelector('[data-id="error-state"]');
        expect(errorState).not.toBeNull();
        errorState.dispatchEvent(new CustomEvent('retry'));
        await flushPromises();

        expect(getCatalog).toHaveBeenCalledTimes(2);
        expect(element.shadowRoot.querySelector('[data-id="card-row"]')).not.toBeNull();
    });
});
