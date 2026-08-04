import { createElement } from 'lwc';
import V360AdminConsole from 'c/v360AdminConsole';
import getCatalog from '@salesforce/apex/V360AdminController.getCatalog';
import updateCardOrder from '@salesforce/apex/V360AdminController.updateCardOrder';
import saveCardProperties from '@salesforce/apex/V360AdminController.saveCardProperties';
import activateCard from '@salesforce/apex/V360AdminController.activateCard';
import deactivateCard from '@salesforce/apex/V360AdminController.deactivateCard';
import createCard from '@salesforce/apex/V360AdminController.createCard';
import createRule from '@salesforce/apex/V360AdminController.createRule';
import addRulePredicate from '@salesforce/apex/V360AdminController.addRulePredicate';
import deleteRulePredicate from '@salesforce/apex/V360AdminController.deleteRulePredicate';
import deleteCard from '@salesforce/apex/V360AdminController.deleteCard';
import engageKillSwitch from '@salesforce/apex/V360AdminController.engageKillSwitch';
import validateRuleFormula from '@salesforce/apex/V360AdminController.validateRuleFormula';
import saveRuleFormula from '@salesforce/apex/V360AdminController.saveRuleFormula';

jest.mock('@salesforce/apex/V360AdminController.getCatalog', () => ({ default: jest.fn() }), { virtual: true });
jest.mock('@salesforce/apex/V360AdminController.updateCardOrder', () => ({ default: jest.fn() }), { virtual: true });
jest.mock('@salesforce/apex/V360AdminController.saveCardProperties', () => ({ default: jest.fn() }), { virtual: true });
jest.mock('@salesforce/apex/V360AdminController.activateCard', () => ({ default: jest.fn() }), { virtual: true });
jest.mock('@salesforce/apex/V360AdminController.deactivateCard', () => ({ default: jest.fn() }), { virtual: true });
jest.mock('@salesforce/apex/V360AdminController.createCard', () => ({ default: jest.fn() }), { virtual: true });
jest.mock('@salesforce/apex/V360AdminController.createRule', () => ({ default: jest.fn() }), { virtual: true });
jest.mock('@salesforce/apex/V360AdminController.addRulePredicate', () => ({ default: jest.fn() }), { virtual: true });
jest.mock('@salesforce/apex/V360AdminController.deleteRulePredicate', () => ({ default: jest.fn() }), { virtual: true });
jest.mock('@salesforce/apex/V360AdminController.deleteRule', () => ({ default: jest.fn() }), { virtual: true });
jest.mock('@salesforce/apex/V360AdminController.deleteCard', () => ({ default: jest.fn() }), { virtual: true });
jest.mock('@salesforce/apex/V360AdminController.engageKillSwitch', () => ({ default: jest.fn() }), { virtual: true });
jest.mock('@salesforce/apex/V360AdminController.releaseKillSwitch', () => ({ default: jest.fn() }), { virtual: true });
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
    predicates: [{ predicateId: 'pred-1', predicateType: 'FLS_READ', targetApiName: 'AnnualRevenue' }]
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
                cards: []
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
        expect(element.shadowRoot.querySelector('[data-id="predicate-pill"]').label).toBe(
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
        activateCard.mockResolvedValue(undefined);

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

        expect(activateCard).toHaveBeenCalledWith({ cardId: 'card-b' });
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
            input: {
                cardId: 'card-a',
                label: 'CardA',
                description: '',
                iconName: 'standard:account',
                buttonLabel: 'Consultar',
                componentType: 'LWC',
                componentName: 'v360AccountSnapshot'
            }
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

    it('summarizes the catalog in the page header and opens the help guide', async () => {
        getCatalog.mockResolvedValue(adminCatalog());

        const element = createConsole();
        await flushPromises();

        expect(element.shadowRoot.querySelector('[data-id="header-meta"]').textContent).toBe(
            '3 tabs · 4 cards · 2 objects'
        );

        element.shadowRoot.querySelector('[data-id="help-open"]').click();
        await flushPromises();

        const helpModal = element.shadowRoot.querySelector('[data-id="help-modal"]');
        expect(helpModal).not.toBeNull();
        expect(helpModal.textContent).toContain('visible to everyone who can see the page');

        element.shadowRoot.querySelector('[data-id="help-close"]').click();
        await flushPromises();

        expect(element.shadowRoot.querySelector('[data-id="help-modal"]')).toBeNull();
    });

    it('shows a per-tab empty state when the selected tab has no cards', async () => {
        getCatalog.mockResolvedValue(adminCatalog());

        const element = createConsole();
        await flushPromises();

        element.shadowRoot
            .querySelector('[data-id="tab-navigation"]')
            .dispatchEvent(new CustomEvent('select', { detail: { name: 'tab-case' } }));
        await flushPromises();

        const workspaceEmpty = element.shadowRoot.querySelector('[data-id="workspace-empty"]');
        expect(workspaceEmpty).not.toBeNull();
        expect(workspaceEmpty.illustrationName).toBe('noresults:unknown');
        expect(element.shadowRoot.querySelectorAll('[data-id="card-row"]')).toHaveLength(0);
    });

    it('keeps the catalog on screen with an overlay spinner during a post-save refresh', async () => {
        getCatalog.mockResolvedValueOnce(adminCatalog()).mockReturnValueOnce(new Promise(() => {}));
        saveCardProperties.mockResolvedValue(undefined);

        const element = createConsole();
        await flushPromises();

        element.shadowRoot.querySelector('[data-id="save-properties"]').click();
        await flushPromises();

        expect(element.shadowRoot.querySelector('[data-id="refresh-spinner"]')).not.toBeNull();
        expect(element.shadowRoot.querySelectorAll('[data-id="card-row"]').length).toBeGreaterThan(0);
        expect(element.shadowRoot.querySelector('[data-id="loading-state"]')).toBeNull();
    });

    it('creates a card as a draft from the wizard with the next order', async () => {
        getCatalog.mockResolvedValue(adminCatalog());
        createCard.mockResolvedValue(undefined);

        const element = createConsole();
        await flushPromises();

        element.shadowRoot.querySelector('[data-id="new-card"]').click();
        await flushPromises();

        element.shadowRoot.querySelector('[data-id="nc-devname"]').value = 'V360NewCard';
        element.shadowRoot.querySelector('[data-id="nc-label"]').value = 'New Card';
        element.shadowRoot.querySelector('[data-id="nc-description"]').value = 'Fresh.';
        element.shadowRoot.querySelector('[data-id="nc-icon"]').value = 'standard:screen';
        element.shadowRoot.querySelector('[data-id="nc-button-label"]').value = 'Open';
        element.shadowRoot.querySelector('[data-id="nc-component"]').value = 'LWC:v360LifecycleDemo';
        element.shadowRoot.querySelector('[data-id="nc-create"]').click();
        await flushPromises();

        expect(createCard).toHaveBeenCalledWith({
            input: {
                tabId: 'tab-account',
                developerName: 'V360NewCard',
                label: 'New Card',
                description: 'Fresh.',
                iconName: 'standard:screen',
                buttonLabel: 'Open',
                componentType: 'LWC',
                componentName: 'v360LifecycleDemo',
                order: 4
            }
        });
        expect(element.shadowRoot.querySelector('[data-id="new-card-modal"]')).toBeNull();
    });

    it('creates a visibility rule from the add-rule modal', async () => {
        getCatalog.mockResolvedValue(adminCatalog());
        createRule.mockResolvedValue(undefined);

        const element = createConsole();
        await flushPromises();

        element.shadowRoot.querySelector('[data-id="add-rule"]').click();
        await flushPromises();
        element.shadowRoot.querySelector('[data-id="nr-devname"]').value = 'NewRule';
        element.shadowRoot.querySelector('[data-id="nr-formula"]').value = '$Permission.X';
        element.shadowRoot.querySelector('[data-id="nr-create"]').click();
        await flushPromises();

        expect(createRule).toHaveBeenCalledWith({
            cardId: 'card-a',
            developerName: 'NewRule',
            formulaText: '$Permission.X'
        });
    });

    it('adds and removes rule predicates', async () => {
        getCatalog.mockResolvedValue(adminCatalog());
        addRulePredicate.mockResolvedValue(undefined);
        deleteRulePredicate.mockResolvedValue(undefined);

        const element = createConsole();
        await flushPromises();

        element.shadowRoot.querySelector('[data-id="pred-type-rule-1"]').value = 'PERMISSION_SET';
        element.shadowRoot.querySelector('[data-id="pred-target-rule-1"]').value = 'Advisor_Access';
        element.shadowRoot.querySelector('[data-id="add-predicate"][data-rule-id="rule-1"]').click();
        await flushPromises();

        expect(addRulePredicate).toHaveBeenCalledWith({
            ruleId: 'rule-1',
            predicateType: 'PERMISSION_SET',
            targetApiName: 'Advisor_Access'
        });

        element.shadowRoot
            .querySelector('[data-id="predicate-pill"]')
            .dispatchEvent(new CustomEvent('remove'));
        await flushPromises();

        expect(deleteRulePredicate).toHaveBeenCalledWith({ predicateId: 'pred-1' });
    });

    it('deletes the selected card through the confirm modal', async () => {
        getCatalog.mockResolvedValue(adminCatalog());
        deleteCard.mockResolvedValue(undefined);

        const element = createConsole();
        await flushPromises();

        element.shadowRoot.querySelector('[data-id="action-delete-card"]').click();
        await flushPromises();

        expect(element.shadowRoot.querySelector('[data-id="delete-message"]').textContent).toContain('CardA');

        element.shadowRoot.querySelector('[data-id="delete-confirm"]').click();
        await flushPromises();

        expect(deleteCard).toHaveBeenCalledWith({ cardId: 'card-a' });
    });

    it('deactivates a live card and engages its kill switch from the action row', async () => {
        getCatalog.mockResolvedValue(adminCatalog());
        deactivateCard.mockResolvedValue(undefined);
        engageKillSwitch.mockResolvedValue(undefined);

        const element = createConsole();
        await flushPromises();

        element.shadowRoot.querySelector('[data-id="action-deactivate"]').click();
        await flushPromises();
        expect(deactivateCard).toHaveBeenCalledWith({ cardId: 'card-a' });

        element.shadowRoot.querySelector('[data-id="action-kill"]').click();
        await flushPromises();
        expect(engageKillSwitch).toHaveBeenCalledWith({ cardId: 'card-a' });
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
