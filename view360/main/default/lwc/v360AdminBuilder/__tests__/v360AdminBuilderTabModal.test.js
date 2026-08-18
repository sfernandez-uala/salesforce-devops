import { createElement } from 'lwc';
import V360AdminBuilder from 'c/v360AdminBuilder';
import getCatalog from '@salesforce/apex/V360AdminController.getCatalog';
import saveTab from '@salesforce/apex/V360AdminController.saveTab';

jest.mock(
    '@salesforce/apex/V360AdminController.getCatalog',
    () => ({ default: jest.fn() }),
    { virtual: true }
);

jest.mock(
    '@salesforce/apex/V360AdminController.saveTab',
    () => ({ default: jest.fn() }),
    { virtual: true }
);

// The picker mounts for real inside the modal, so its own wire has to resolve
// or it renders an error state over the assertions here.
jest.mock(
    '@salesforce/apex/V360SchemaVocabulary.getAnchorObjectOptions',
    () => {
        const { createApexTestWireAdapter } = require('@salesforce/sfdx-lwc-jest');
        return { default: createApexTestWireAdapter(jest.fn()) };
    },
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

global.ResizeObserver = class {
    observe() {}
    unobserve() {}
    disconnect() {}
};

const flushPromises = () => new Promise((res) => setTimeout(res, 0));

const CATALOG = {
    hasManagePermission: true,
    tabs: [
        {
            tabId: 'a01000000000001',
            developerName: 'AccountOverview',
            sObjectApiName: 'Account',
            sequence: 1,
            cards: []
        }
    ]
};

async function createBuilder() {
    getCatalog.mockResolvedValue(CATALOG);
    const element = createElement('c-v360-admin-builder', { is: V360AdminBuilder });
    document.body.appendChild(element);
    await flushPromises();
    return element;
}

/** Reaches the tab actions the way the UI does: through the switcher menu. */
async function openTabModal(element, action) {
    element.shadowRoot.querySelector('[data-id="tab-switcher"]').click();
    await flushPromises();
    element.shadowRoot.querySelector(`[data-id="${action}"]`).click();
    await flushPromises();
}

const anchorField = (element) => element.shadowRoot.querySelector('[data-id="nt-anchor"]');

describe('c-v360-admin-builder tab modal anchor object', () => {
    afterEach(() => {
        while (document.body.firstChild) {
            document.body.removeChild(document.body.firstChild);
        }
        jest.clearAllMocks();
    });

    /**
     * The anchor is a closed list the org already knows. Asking for it as free
     * text is what made a typo something the server had to catch.
     */
    it('asks for the anchor with the object picker, not a text box', async () => {
        const element = await createBuilder();
        await openTabModal(element, 'new-tab');

        const field = anchorField(element);
        expect(field).not.toBeNull();
        expect(field.tagName.toLowerCase()).toBe('c-v360-object-picker');
    });

    it('opens a new tab with no object chosen', async () => {
        const element = await createBuilder();
        await openTabModal(element, 'new-tab');

        expect(anchorField(element).value).toBe('');
    });

    it('opens an existing tab on the object it is already anchored to', async () => {
        const element = await createBuilder();
        await openTabModal(element, 'edit-tab');

        expect(anchorField(element).value).toBe('Account');
    });

    it('saves the object the picker holds', async () => {
        saveTab.mockResolvedValue(undefined);
        const element = await createBuilder();
        await openTabModal(element, 'new-tab');

        element.shadowRoot.querySelector('[data-id="nt-devname"]').value = 'CaseTimeline';
        anchorField(element).value = 'Case';
        await flushPromises();

        element.shadowRoot.querySelector('[data-id="nt-save"]').click();
        await flushPromises();

        expect(saveTab).toHaveBeenCalledWith({
            input: expect.objectContaining({
                developerName: 'CaseTimeline',
                sObjectApiName: 'Case'
            })
        });
    });

    it('refuses to save a tab with no object chosen', async () => {
        const element = await createBuilder();
        await openTabModal(element, 'new-tab');

        element.shadowRoot.querySelector('[data-id="nt-devname"]').value = 'CaseTimeline';
        await flushPromises();

        element.shadowRoot.querySelector('[data-id="nt-save"]').click();
        await flushPromises();

        expect(saveTab).not.toHaveBeenCalled();
    });
});
