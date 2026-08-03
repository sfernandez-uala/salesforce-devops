import { createElement } from 'lwc';
import V360AdminConsole from 'c/v360AdminConsole';
import getCatalog from '@salesforce/apex/V360AdminController.getCatalog';

jest.mock(
    '@salesforce/apex/V360AdminController.getCatalog',
    () => ({ default: jest.fn() }),
    { virtual: true }
);

const flushPromises = () => new Promise((res) => setTimeout(res, 0));

const ADMIN_CATALOG = {
    hasManagePermission: true,
    tabs: [
        {
            tabId: 'a0B000000000001',
            developerName: 'AccountOverview',
            sObjectApiName: 'Account',
            sequence: 1,
            active: true,
            cards: [
                {
                    cardId: 'a09000000000001',
                    developerName: 'V360AccountSnapshot',
                    label: 'Account Snapshot',
                    description: 'Shows the account key details.',
                    componentType: 'LWC',
                    componentName: 'v360AccountSnapshot',
                    iconName: 'standard:account',
                    order: 1,
                    active: true,
                    killSwitch: false,
                    ruleCount: 2
                },
                {
                    cardId: 'a09000000000002',
                    developerName: 'V360LifecycleDemo',
                    label: 'Lifecycle Demo',
                    description: 'Reference card.',
                    componentType: 'LWC',
                    componentName: 'v360LifecycleDemo',
                    iconName: 'standard:screen',
                    order: 3,
                    active: true,
                    killSwitch: true,
                    ruleCount: 0
                }
            ]
        }
    ]
};

function createConsole() {
    const element = createElement('c-v360-admin-console', { is: V360AdminConsole });
    document.body.appendChild(element);
    return element;
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

    it('renders the configuration graph grouped by tab', async () => {
        getCatalog.mockResolvedValue(ADMIN_CATALOG);

        const element = createConsole();
        await flushPromises();

        const tabTitle = element.shadowRoot.querySelector('[data-id="tab-title"]');
        expect(tabTitle.textContent).toBe('AccountOverview (Account)');
        const rows = element.shadowRoot.querySelectorAll('[data-id="card-row"]');
        expect(rows).toHaveLength(2);
        expect(rows[0].textContent).toContain('Account Snapshot');
        expect(rows[0].textContent).toContain('2');
        expect(rows[1].textContent).toContain('On');
    });

    it('renders the access state when the server reports no manage permission', async () => {
        getCatalog.mockResolvedValue({ hasManagePermission: false, tabs: [] });

        const element = createConsole();
        await flushPromises();

        const denied = element.shadowRoot.querySelector('[data-id="denied-state"]');
        expect(denied).not.toBeNull();
        expect(denied.illustrationName).toBe('access:request');
        expect(element.shadowRoot.querySelector('[data-id="card-row"]')).toBeNull();
    });

    it('renders the no-configuration state for a permitted admin with no tabs', async () => {
        getCatalog.mockResolvedValue({ hasManagePermission: true, tabs: [] });

        const element = createConsole();
        await flushPromises();

        expect(element.shadowRoot.querySelector('[data-id="empty-state"]')).not.toBeNull();
    });

    it('shows the recoverable-error state and retries the request', async () => {
        getCatalog.mockRejectedValueOnce(new Error('boom')).mockResolvedValueOnce(ADMIN_CATALOG);

        const element = createConsole();
        await flushPromises();

        const errorState = element.shadowRoot.querySelector('[data-id="error-state"]');
        expect(errorState).not.toBeNull();
        errorState.dispatchEvent(new CustomEvent('retry'));
        await flushPromises();

        expect(getCatalog).toHaveBeenCalledTimes(2);
        expect(element.shadowRoot.querySelector('[data-id="card-row"]')).not.toBeNull();
    });

    it('refreshes the catalog from the header action', async () => {
        getCatalog.mockResolvedValue(ADMIN_CATALOG);

        const element = createConsole();
        await flushPromises();

        element.shadowRoot.querySelector('[data-id="refresh"]').click();
        await flushPromises();

        expect(getCatalog).toHaveBeenCalledTimes(2);
    });
});
