import { createElement } from 'lwc';
import V360AdminBuilder from 'c/v360AdminBuilder';
import getCatalog from '@salesforce/apex/V360AdminController.getCatalog';

jest.mock(
    '@salesforce/apex/V360AdminController.getCatalog',
    () => ({ default: jest.fn() }),
    { virtual: true }
);

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

// The preview mounts the real shell, so the registry has to answer the shape
// the shell asks of it, not just the one the builder does.
jest.mock(
    'c/v360CardRegistry',
    () => ({
        names: jest.fn(() => []),
        has: jest.fn(() => false),
        load: jest.fn(() => Promise.resolve(null))
    }),
    { virtual: true }
);

jest.mock(
    'c/v360Service',
    () => ({
        getVisibleCards: jest.fn(() => Promise.resolve([])),
        getVisibleCardsFresh: jest.fn(() => Promise.resolve([]))
    }),
    { virtual: true }
);

global.ResizeObserver = class {
    observe() {}
    unobserve() {}
    disconnect() {}
};

const flushPromises = () => new Promise((res) => setTimeout(res, 0));

/**
 * Cards default to live and protected. Each test bends only the fact it is
 * about, so an exposed card in a fixture is exposed on purpose.
 */
function card(cardId, label, overrides = {}) {
    return {
        cardId,
        developerName: label.replace(/\s/g, ''),
        label,
        description: '',
        componentType: 'LWC',
        componentName: 'v360AccountSnapshot',
        iconName: 'standard:account',
        buttonLabel: 'Open',
        order: 1,
        active: true,
        killSwitch: false,
        ruleMatchLogic: 'ALL',
        ruleCount: 1,
        activeRuleCount: 1,
        rules: [],
        ...overrides
    };
}

const EXPOSED = { ruleCount: 0, activeRuleCount: 0 };
const DRAFT = { active: false };
const KILLED = { killSwitch: true, ruleCount: 0, activeRuleCount: 0 };

function catalogOf(cards) {
    return {
        hasManagePermission: true,
        tabs: [
            {
                tabId: 'a01000000000001',
                developerName: 'AccountOverview',
                sObjectApiName: 'Account',
                sequence: 1,
                cards
            }
        ]
    };
}

async function createBuilder(cards) {
    getCatalog.mockResolvedValue(catalogOf(cards));
    const element = createElement('c-v360-admin-builder', { is: V360AdminBuilder });
    document.body.appendChild(element);
    await flushPromises();
    return element;
}

const toolbar = (element) => element.shadowRoot.querySelector('[data-id="builder-toolbar"]');
const indicator = (element) => element.shadowRoot.querySelector('[data-id="exposure-indicator"]');
const previewButton = (element) => element.shadowRoot.querySelector('[data-id="preview"]');
const previewModal = (element) => element.shadowRoot.querySelector('[data-id="preview-modal"]');
const recordPicker = (element) => element.shadowRoot.querySelector('[data-id="preview-record"]');
const previewShell = (element) => element.shadowRoot.querySelector('[data-id="preview-shell"]');

async function openPreview(element) {
    previewButton(element).click();
    await flushPromises();
}

async function pickRecord(element, recordId) {
    recordPicker(element).dispatchEvent(new CustomEvent('change', { detail: { recordId } }));
    await flushPromises();
}

describe('c-v360-admin-builder toolbar', () => {
    afterEach(() => {
        while (document.body.firstChild) {
            document.body.removeChild(document.body.firstChild);
        }
        jest.clearAllMocks();
    });

    // ---- shape --------------------------------------------------------

    it('carries a toolbar with a preview action', async () => {
        const element = await createBuilder([card('c1', 'Snapshot')]);

        expect(toolbar(element).getAttribute('role')).toBe('toolbar');
        expect(previewButton(element)).not.toBeNull();
    });

    // ---- exposure -----------------------------------------------------

    it('stays quiet when every live card is restricted by a rule', async () => {
        const element = await createBuilder([card('c1', 'Snapshot'), card('c2', 'Risk')]);

        expect(indicator(element)).toBeNull();
    });

    it('counts the live cards no active rule restricts', async () => {
        const element = await createBuilder([
            card('c1', 'Snapshot'),
            card('c2', 'Risk', EXPOSED),
            card('c3', 'Timeline', EXPOSED)
        ]);

        expect(indicator(element)).not.toBeNull();
        expect(indicator(element).textContent).toContain('2');
    });

    /**
     * A card nobody can reach is not exposed, however few rules it carries --
     * the count has to mean "visible to everyone", or it stops being read.
     */
    it('leaves out drafts and killed cards, which reach nobody', async () => {
        const element = await createBuilder([
            card('c1', 'Draft', { ...DRAFT, ...EXPOSED }),
            card('c2', 'Killed', KILLED),
            card('c3', 'Open', EXPOSED)
        ]);

        expect(indicator(element).textContent).toContain('1');
    });

    it('opens the first exposed card when the warning is clicked', async () => {
        const element = await createBuilder([
            card('c1', 'Snapshot'),
            card('c2', 'Risk', EXPOSED)
        ]);

        indicator(element).click();
        await flushPromises();

        expect(element.shadowRoot.querySelector('[data-id="canvas-title"]').textContent).toContain(
            'Risk'
        );
    });

    // ---- preview ------------------------------------------------------

    it('asks which record to preview on before rendering anything', async () => {
        const element = await createBuilder([card('c1', 'Snapshot')]);
        await openPreview(element);

        expect(previewModal(element)).not.toBeNull();
        expect(recordPicker(element).objectApiName).toBe('Account');
        expect(previewShell(element)).toBeNull();
    });

    /**
     * The preview runs the real visibility engine for the running user, so it
     * shows their cards and not everyone's. Saying so is the difference between
     * a preview and a claim about what users see.
     */
    it('says whose view it is showing', async () => {
        const element = await createBuilder([card('c1', 'Snapshot')]);
        await openPreview(element);

        expect(element.shadowRoot.querySelector('[data-id="preview-notice"]')).not.toBeNull();
    });

    it('mounts the real shell on the chosen record and this tab', async () => {
        const element = await createBuilder([card('c1', 'Snapshot')]);
        await openPreview(element);
        await pickRecord(element, '001000000000501AAA');

        const shell = previewShell(element);
        expect(shell).not.toBeNull();
        expect(shell.recordId).toBe('001000000000501AAA');
        expect(shell.tabApiName).toBe('AccountOverview');
    });

    it('drops back to the picker when the record is cleared', async () => {
        const element = await createBuilder([card('c1', 'Snapshot')]);
        await openPreview(element);
        await pickRecord(element, '001000000000501AAA');
        await pickRecord(element, null);

        expect(previewShell(element)).toBeNull();
    });

    it('forgets the previewed record when the preview is closed', async () => {
        const element = await createBuilder([card('c1', 'Snapshot')]);
        await openPreview(element);
        await pickRecord(element, '001000000000501AAA');

        element.shadowRoot.querySelector('[data-id="preview-close"]').click();
        await flushPromises();
        expect(previewModal(element)).toBeNull();

        await openPreview(element);
        expect(previewShell(element)).toBeNull();
    });
});
