import { LightningElement } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import { names as registeredCardNames } from 'c/v360CardRegistry';
import getCatalog from '@salesforce/apex/V360AdminController.getCatalog';
import updateCardOrder from '@salesforce/apex/V360AdminController.updateCardOrder';
import saveCardProperties from '@salesforce/apex/V360AdminController.saveCardProperties';
import setCardActive from '@salesforce/apex/V360AdminController.setCardActive';
import validateRuleFormula from '@salesforce/apex/V360AdminController.validateRuleFormula';
import saveRuleFormula from '@salesforce/apex/V360AdminController.saveRuleFormula';

const STATUS_LOADING = 'loading';
const STATUS_LOADED = 'loaded';
const STATUS_ERROR = 'error';
const COMPONENT_TYPE_LWC = 'LWC';
const COMPONENT_TYPE_FLOW = 'Flow';
const BINDING_SEPARATOR = ':';

/**
 * The Vista 360 admin console for users holding the
 * V360_ManageVisibilityRules custom permission. Three zones, the way
 * admins think about the configuration:
 *
 *   - Navigation: every tab, grouped under its anchor SObject (a tab is a
 *     named surface anchored to exactly one SObject; one SObject may have
 *     many tabs).
 *   - Workspace: the selected tab's cards as reorderable rows with
 *     first-class state (Draft = inactive, hidden from end users before
 *     any rule runs; Live; Kill switch on).
 *   - Detail: the selected card's presentation and component binding (the
 *     LWC picker offers only registry names, so a saved binding always
 *     resolves), plus its visibility rules with live server-side formula
 *     validation.
 *
 * Activating a draft runs through an explicit checklist, and a live card
 * with no rules says "visible to everyone" instead of leaving that
 * default implicit. The server is the authority on the manage permission;
 * this component renders what the controller reports.
 */
export default class V360AdminConsole extends LightningElement {
    status = STATUS_LOADING;
    data;
    error;
    selectedTabId;
    selectedCardId;
    savingOrder = false;
    activationOpen = false;
    formulaFeedback = {};

    connectedCallback() {
        this.loadCatalog();
    }

    async loadCatalog() {
        this.status = STATUS_LOADING;
        this.error = undefined;
        try {
            this.data = await getCatalog();
            this.status = STATUS_LOADED;
            this.ensureSelection();
        } catch (error) {
            this.error = error;
            this.status = STATUS_ERROR;
        }
    }

    ensureSelection() {
        const tabs = this.data?.tabs ?? [];
        if (!tabs.some((tab) => tab.tabId === this.selectedTabId)) {
            this.selectedTabId = tabs.length ? tabs[0].tabId : undefined;
        }
        const cards = this.selectedTabCards;
        if (!cards.some((card) => card.cardId === this.selectedCardId)) {
            this.selectedCardId = cards.length ? cards[0].cardId : undefined;
        }
    }

    handleRetry() {
        this.loadCatalog();
    }

    handleRefresh() {
        this.loadCatalog();
    }

    handleTabSelect(event) {
        this.selectedTabId = event.detail.name;
        this.selectedCardId = undefined;
        this.formulaFeedback = {};
        this.ensureSelection();
    }

    handleCardOpen(event) {
        this.selectedCardId = event.currentTarget.dataset.cardId;
        this.formulaFeedback = {};
    }

    async handleMoveUp(event) {
        event.stopPropagation();
        this.moveCard(event.currentTarget.dataset.cardId, -1);
    }

    async handleMoveDown(event) {
        event.stopPropagation();
        this.moveCard(event.currentTarget.dataset.cardId, 1);
    }

    /**
     * Optimistic reorder: the row moves immediately, the new sequence is
     * persisted through the gated write path, and a failed save restores
     * the server's truth by reloading the catalog.
     */
    async moveCard(cardId, offset) {
        const tab = this.selectedTab;
        if (!tab || this.savingOrder) {
            return;
        }
        const cards = [...tab.cards];
        const fromIndex = cards.findIndex((card) => card.cardId === cardId);
        const toIndex = fromIndex + offset;
        if (fromIndex < 0 || toIndex < 0 || toIndex >= cards.length) {
            return;
        }
        const [moved] = cards.splice(fromIndex, 1);
        cards.splice(toIndex, 0, moved);
        this.patchSelectedTab({ cards });

        this.savingOrder = true;
        try {
            await updateCardOrder({ orderedCardIds: cards.map((card) => card.cardId) });
        } catch (error) {
            this.toast('Reorder failed', 'The new order could not be saved. Showing the last saved order.', 'error');
            await this.loadCatalog();
        } finally {
            this.savingOrder = false;
        }
    }

    async handleSaveProperties() {
        const card = this.selectedCard;
        const label = this.template.querySelector('[data-id="prop-label"]').value;
        const buttonLabel = this.template.querySelector('[data-id="prop-button-label"]').value;
        const binding = this.template.querySelector('[data-id="prop-component"]').value;
        const separatorAt = binding.indexOf(BINDING_SEPARATOR);
        const componentType = binding.slice(0, separatorAt);
        const componentName = binding.slice(separatorAt + 1);
        try {
            await saveCardProperties({
                cardId: card.cardId,
                label,
                buttonLabel,
                componentType,
                componentName
            });
            this.toast('Card saved', `“${label}” was saved.`, 'success');
            await this.loadCatalog();
        } catch (error) {
            this.toast('Save failed', this.errorMessage(error), 'error');
        }
    }

    async handleValidateFormula(event) {
        const ruleId = event.currentTarget.dataset.ruleId;
        const formulaText = this.template.querySelector(`[data-id="formula-${ruleId}"]`).value;
        try {
            const result = await validateRuleFormula({ cardId: this.selectedCardId, formulaText });
            this.formulaFeedback = { ...this.formulaFeedback, [ruleId]: result };
        } catch (error) {
            this.formulaFeedback = {
                ...this.formulaFeedback,
                [ruleId]: { isValid: false, message: this.errorMessage(error) }
            };
        }
    }

    async handleSaveFormula(event) {
        const ruleId = event.currentTarget.dataset.ruleId;
        const formulaText = this.template.querySelector(`[data-id="formula-${ruleId}"]`).value;
        try {
            await saveRuleFormula({ ruleId, cardId: this.selectedCardId, formulaText });
            this.toast('Rule saved', 'The visibility formula was saved.', 'success');
            await this.loadCatalog();
        } catch (error) {
            this.toast('Save failed', this.errorMessage(error), 'error');
        }
    }

    handleOpenActivation() {
        this.activationOpen = true;
    }

    handleCloseActivation() {
        this.activationOpen = false;
    }

    async handleConfirmActivation() {
        const card = this.selectedCard;
        this.activationOpen = false;
        try {
            await setCardActive({ cardId: card.cardId, isActive: true });
            this.toast('Card activated', `“${card.label}” is now live for end users.`, 'success');
            await this.loadCatalog();
        } catch (error) {
            this.toast('Activation failed', this.errorMessage(error), 'error');
        }
    }

    handleNewCard() {
        this.toast('Not yet available', 'The new-card wizard ships in the next round; new cards will start as drafts.', 'info');
    }

    handleAddRule() {
        this.toast('Not yet available', 'The rule builder ships in the next round.', 'info');
    }

    toast(title, message, variant) {
        this.dispatchEvent(new ShowToastEvent({ title, message, variant }));
    }

    errorMessage(error) {
        return error?.body?.message || 'Something went wrong.';
    }

    patchSelectedTab(patch) {
        this.data = {
            ...this.data,
            tabs: this.data.tabs.map((tab) => (tab.tabId === this.selectedTabId ? { ...tab, ...patch } : tab))
        };
    }

    get isLoading() {
        return this.status === STATUS_LOADING;
    }

    get isError() {
        return this.status === STATUS_ERROR;
    }

    get isDenied() {
        return this.status === STATUS_LOADED && !this.data.hasManagePermission;
    }

    get isEmpty() {
        return this.status === STATUS_LOADED && this.data.hasManagePermission && this.data.tabs.length === 0;
    }

    get isCatalogVisible() {
        return this.status === STATUS_LOADED && this.data.hasManagePermission && this.data.tabs.length > 0;
    }

    /** Tabs grouped under their anchor SObject: one nav section per SObject. */
    get navigationSections() {
        const sections = [];
        for (const tab of this.data.tabs) {
            let section = sections.find((candidate) => candidate.sObjectApiName === tab.sObjectApiName);
            if (!section) {
                section = { sObjectApiName: tab.sObjectApiName, tabs: [] };
                sections.push(section);
            }
            section.tabs.push({
                ...tab,
                navLabel: `${tab.developerName} (${tab.cards.length})`
            });
        }
        return sections;
    }

    get selectedTab() {
        return this.data?.tabs.find((tab) => tab.tabId === this.selectedTabId) ?? null;
    }

    get selectedTabCards() {
        return this.selectedTab?.cards ?? [];
    }

    get selectedCard() {
        return this.selectedTabCards.find((card) => card.cardId === this.selectedCardId) ?? null;
    }

    get workspace() {
        const tab = this.selectedTab;
        if (!tab) {
            return null;
        }
        const lastIndex = tab.cards.length - 1;
        return {
            ...tab,
            title: tab.developerName,
            subtitle: `Anchor object: ${tab.sObjectApiName}`,
            statusLabel: tab.active ? 'Active' : 'Inactive',
            statusClass: tab.active ? 'slds-badge slds-theme_success' : 'slds-badge',
            cardCountLabel: `${tab.cards.length} card${tab.cards.length === 1 ? '' : 's'}`,
            cards: tab.cards.map((card, index) => this.toCardRow(card, index, lastIndex))
        };
    }

    toCardRow(card, index, lastIndex) {
        const presentation = this.cardPresentation(card);
        return {
            ...card,
            ...presentation,
            rowClass:
                card.cardId === this.selectedCardId
                    ? 'v360-admin-card-row v360-admin-card-row_selected'
                    : 'v360-admin-card-row',
            moveUpDisabled: index === 0 || this.savingOrder,
            moveDownDisabled: index === lastIndex || this.savingOrder
        };
    }

    cardPresentation(card) {
        const state = card.killSwitch ? 'killed' : card.active ? 'live' : 'draft';
        return {
            iconNameOrDefault: card.iconName || 'standard:default',
            binding: `${card.componentType}: ${card.componentName}`,
            stateLabel: { killed: 'Kill switch on', live: 'Live', draft: 'Draft' }[state],
            stateClass: {
                killed: 'slds-badge slds-theme_warning',
                live: 'slds-badge slds-theme_success',
                draft: 'slds-badge'
            }[state],
            isDraft: state === 'draft',
            isKilled: state === 'killed',
            ruleSummary:
                card.ruleCount > 0
                    ? `${card.ruleCount} visibility rule${card.ruleCount === 1 ? '' : 's'}`
                    : 'No rules — visible to everyone who can see the page',
            hasNoRules: card.ruleCount === 0
        };
    }

    get detail() {
        const card = this.selectedCard;
        if (!card) {
            return null;
        }
        return {
            ...card,
            ...this.cardPresentation(card),
            bindingValue: `${card.componentType}${BINDING_SEPARATOR}${card.componentName}`,
            rules: card.rules.map((rule) => {
                const feedback = this.formulaFeedback[rule.ruleId];
                return {
                    ...rule,
                    formulaFieldId: `formula-${rule.ruleId}`,
                    activeLabel: rule.active ? 'Active' : 'Off',
                    activeClass: rule.active ? 'slds-badge slds-theme_success' : 'slds-badge',
                    predicatePills: (rule.predicates ?? []).map((predicate, index) => ({
                        key: `${rule.ruleId}-${index}`,
                        label: `${predicate.predicateType} · ${predicate.targetApiName}`
                    })),
                    feedbackMessage: feedback?.message,
                    feedbackClass: feedback?.isValid
                        ? 'slds-text-color_success v360-admin-validate-msg'
                        : 'slds-text-color_error v360-admin-validate-msg'
                };
            })
        };
    }

    /**
     * The LWC options come from the card registry, so the picker can only
     * produce bindings the bundler guarantees exist; a Flow binding is
     * offered as the card's current value and validated server-side.
     */
    get componentOptions() {
        const options = registeredCardNames().map((name) => ({
            label: `${COMPONENT_TYPE_LWC}: ${name}`,
            value: `${COMPONENT_TYPE_LWC}${BINDING_SEPARATOR}${name}`
        }));
        const card = this.selectedCard;
        if (card && card.componentType === COMPONENT_TYPE_FLOW) {
            options.unshift({
                label: `${COMPONENT_TYPE_FLOW}: ${card.componentName}`,
                value: `${COMPONENT_TYPE_FLOW}${BINDING_SEPARATOR}${card.componentName}`
            });
        }
        return options;
    }

    get activationChecklist() {
        const card = this.selectedCard;
        if (!card) {
            return [];
        }
        const checks = [
            {
                key: 'binding',
                ok: true,
                text: 'Component binding is valid',
                detail: `${card.componentType}: ${card.componentName} is configured.`
            }
        ];
        if (card.ruleCount > 0) {
            checks.push({
                key: 'rules',
                ok: true,
                text: `${card.ruleCount} visibility rule${card.ruleCount === 1 ? '' : 's'} configured`,
                detail: 'Only users passing the rules will see this card.'
            });
        } else {
            checks.push({
                key: 'rules',
                ok: false,
                text: 'No visibility rules',
                detail: 'Everyone who can see the page will see this card. Activate only if that is intended.'
            });
        }
        checks.push({
            key: 'presentation',
            ok: true,
            text: 'Tile presentation set',
            detail: `Label “${card.label}”, button “${card.buttonLabel || 'Consultar'}”.`
        });
        return checks.map((check) => ({
            ...check,
            markClass: check.ok ? 'v360-admin-check v360-admin-check_ok' : 'v360-admin-check v360-admin-check_warn',
            mark: check.ok ? '✓' : '⚠'
        }));
    }
}
