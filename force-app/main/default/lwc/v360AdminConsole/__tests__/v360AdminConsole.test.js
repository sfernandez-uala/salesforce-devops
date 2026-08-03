import { createElement } from 'lwc';
import V360AdminConsole from 'c/v360AdminConsole';
import getCatalog from '@salesforce/apex/V360AdminController.getCatalog';
import updateCardOrder from '@salesforce/apex/V360AdminController.updateCardOrder';
import saveCardProperties from '@salesforce/apex/V360AdminController.saveCardProperties';
import setCardActive from '@salesforce/apex/V360AdminController.setCardActive';
import validateRuleFormula from '@salesforce/apex/V360AdminController.validateRuleFormula';
import saveRuleFormula from '@salesforce/apex/V360AdminController.saveRuleFormula';

jest.mock('@salesforce/apex/V360AdminController.getCatalog', () => ({ default: jest.fn() }), { virtual: true });
jest.mock('@salesforce/apex/V360AdminController.updateCardOrder', () => ({ default: jest.fn() }), { virtual: true });
jest.mock('@salesforce/apex/V360AdminController.saveCardProperties', () => ({ default: jest.fn() }), { virtual: true });
jest.mock('@salesforce/apex/V360AdminController.setCardActive', () => ({ default: jest.fn() }), { virtual: true });
jest.mock('@salesforce/apex/V360AdminController.validateRuleFormula', () => ({ default: jest.fn() }), { virtual: true });
jest.mock('@salesforce/apex/V360AdminController.saveRuleFormula', () => ({ default: jest.fn() }), { virtual: true });

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
        buttonLabel: 'Consultar',
        order: 1,
        active: true,
        killSwitch: false,
        ruleCount: 0,
        rules: [],
        ...overrides
    };
}

const BANKING_RULE = {
    ruleId: 'rule-1',
    developerName: 'BankingAdvisorsOnly',
    description: '',
    formula: "ISPICKVAL(Industry, 'Banking')",
    active: true,
    predicates: [{ predicateType: 'FLS_READ', targetApiName: 'AnnualRevenue' }]
};

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
                    card('card-a', 'CardA', { ruleCount: 1, rules: [BANKING_RULE] }),
                    card('card-b', 'CardB', { active: false }),
                    card('card-c', 'CardC', { killSwitch: true })
                ]
            },
            {
                tabId: 'tab-account-risk',
                developerName: 'AccountRisk',
                sObjectApiName: 'Account',
                sequence: 2,
                active: true,
                cards: [card('card-d', 'CardD')]
            },
            {
                tabId: 'tab-case',
                developerName: 'CaseOverview',
                sObjectApiName: 'Case',
                sequence: 3,
                active: false,
                cards: [card('card-e', 'CardE')]
            }
        ]
    };
}

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

    it('groups the navigation into one section per anchor SObject', async () => {
        getCatalog.mockResolvedValue(adminCatalog());

        const element = createConsole();
        await flushPromises();

        const sections = element.shadowRoot.querySelectorAll('lightning-vertical-navigation-section');
        expect(sections).toHaveLength(2);
        expect(sections[0].label).toBe('Account');
        expect(sections[1].label).toBe('Case');
        expect(sections[0].querySelectorAll('lightning-vertical-navigation-item')).toHaveLength(2);
    });

    it('renders the workspace rows with state badges and opens the first card in the detail panel', async () => {
        getCatalog.mockResolvedValue(adminCatalog());

        const element = createConsole();
        await flushPromises();

        const states = Array.from(element.shadowRoot.querySelectorAll('[data-id="card-state"]')).map(
            (badge) => badge.textContent
        );
        expect(states).toEqual(['Live', 'Draft', 'Kill switch on']);
        expect(element.shadowRoot.querySelector('[data-id="detail-title"]').textContent).toBe('CardA');
        expect(element.shadowRoot.querySelectorAll('[data-id="rule"]')).toHaveLength(1);
        expect(element.shadowRoot.querySelector('[data-id="predicate-pill"]').textContent).toBe(
            'FLS_READ · AnnualRevenue'
        );
    });

    it('opens a clicked card in the detail panel with its draft banner', async () => {
        getCatalog.mockResolvedValue(adminCatalog());

        const element = createConsole();
        await flushPromises();

        element.shadowRoot.querySelector('[data-id="card-row"][data-card-id="card-b"]').click();
        await flushPromises();

        expect(element.shadowRoot.querySelector('[data-id="detail-title"]').textContent).toBe('CardB');
        expect(element.shadowRoot.querySelector('[data-id="draft-banner"]')).not.toBeNull();
    });

    it('activates a draft card through the checklist modal', async () => {
        getCatalog.mockResolvedValue(adminCatalog());
        setCardActive.mockResolvedValue(undefined);

        const element = createConsole();
        await flushPromises();
        element.shadowRoot.querySelector('[data-id="card-row"][data-card-id="card-b"]').click();
        await flushPromises();

        element.shadowRoot.querySelector('[data-id="activate-open"]').click();
        await flushPromises();

        const checks = element.shadowRoot.querySelectorAll('[data-id="activation-check"]');
        expect(checks).toHaveLength(3);
        expect(checks[1].textContent).toContain('No visibility rules');

        element.shadowRoot.querySelector('[data-id="activate-confirm"]').click();
        await flushPromises();

        expect(setCardActive).toHaveBeenCalledWith({ cardId: 'card-b', isActive: true });
        expect(getCatalog).toHaveBeenCalledTimes(2);
    });

    it('validates a rule formula server-side and shows the verdict', async () => {
        getCatalog.mockResolvedValue(adminCatalog());
        validateRuleFormula.mockResolvedValue({ isValid: false, message: 'Formula failed to validate: boom' });

        const element = createConsole();
        await flushPromises();

        element.shadowRoot.querySelector('[data-id="validate-formula"]').click();
        await flushPromises();

        expect(validateRuleFormula).toHaveBeenCalledWith({
            cardId: 'card-a',
            formulaText: "ISPICKVAL(Industry, 'Banking')"
        });
        expect(element.shadowRoot.querySelector('[data-id="formula-feedback"]').textContent).toBe(
            'Formula failed to validate: boom'
        );
    });

    it('saves a rule formula through the gated write path', async () => {
        getCatalog.mockResolvedValue(adminCatalog());
        saveRuleFormula.mockResolvedValue(undefined);

        const element = createConsole();
        await flushPromises();

        element.shadowRoot.querySelector('[data-id="save-formula"]').click();
        await flushPromises();

        expect(saveRuleFormula).toHaveBeenCalledWith({
            ruleId: 'rule-1',
            cardId: 'card-a',
            formulaText: "ISPICKVAL(Industry, 'Banking')"
        });
    });

    it('saves card properties parsing the component binding', async () => {
        getCatalog.mockResolvedValue(adminCatalog());
        saveCardProperties.mockResolvedValue(undefined);

        const element = createConsole();
        await flushPromises();

        element.shadowRoot.querySelector('[data-id="save-properties"]').click();
        await flushPromises();

        expect(saveCardProperties).toHaveBeenCalledWith({
            cardId: 'card-a',
            label: 'CardA',
            buttonLabel: 'Consultar',
            componentType: 'LWC',
            componentName: 'v360AccountSnapshot'
        });
    });

    it('offers only registry names as LWC component options', async () => {
        getCatalog.mockResolvedValue(adminCatalog());

        const element = createConsole();
        await flushPromises();

        const combobox = element.shadowRoot.querySelector('[data-id="prop-component"]');
        const values = combobox.options.map((option) => option.value);
        expect(values).toContain('LWC:v360AccountSnapshot');
        expect(values).toContain('LWC:v360LifecycleDemo');
        expect(values.every((value) => value.startsWith('LWC:'))).toBe(true);
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
