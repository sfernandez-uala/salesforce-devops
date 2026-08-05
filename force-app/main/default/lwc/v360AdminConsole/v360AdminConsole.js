import { LightningElement } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import { names as registeredCardNames } from 'c/v360CardRegistry';
import getCatalog from '@salesforce/apex/V360AdminController.getCatalog';
import updateCardOrder from '@salesforce/apex/V360AdminController.updateCardOrder';
import saveCardProperties from '@salesforce/apex/V360AdminController.saveCardProperties';
import activateCard from '@salesforce/apex/V360AdminController.activateCard';
import deactivateCard from '@salesforce/apex/V360AdminController.deactivateCard';
import validateRuleFormula from '@salesforce/apex/V360AdminController.validateRuleFormula';
import saveRuleFormula from '@salesforce/apex/V360AdminController.saveRuleFormula';
import createCard from '@salesforce/apex/V360AdminController.createCard';
import createRule from '@salesforce/apex/V360AdminController.createRule';
import addRulePredicate from '@salesforce/apex/V360AdminController.addRulePredicate';
import deleteRulePredicate from '@salesforce/apex/V360AdminController.deleteRulePredicate';
import deleteRule from '@salesforce/apex/V360AdminController.deleteRule';
import deleteCard from '@salesforce/apex/V360AdminController.deleteCard';
import engageKillSwitch from '@salesforce/apex/V360AdminController.engageKillSwitch';
import saveTab from '@salesforce/apex/V360AdminController.saveTab';
import deleteTab from '@salesforce/apex/V360AdminController.deleteTab';
import releaseKillSwitch from '@salesforce/apex/V360AdminController.releaseKillSwitch';

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
    refreshing = false;
    busy = false;
    activationOpen = false;
    helpOpen = false;
    newCardOpen = false;
    newCardType = COMPONENT_TYPE_LWC;
    newCardIcon = '';
    iconPickerOpen = false;
    iconPickerTarget = null;
    tabModalOpen = false;
    editingTabId = null;
    addRuleOpen = false;
    deleteTarget = null;
    formulaFeedback = {};
    iconDraft;

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

    /**
     * Re-reads the catalog while keeping the current one on screen, with a
     * centered spinner overlaid on the console -- the treatment for every
     * re-read after a save. Tearing the whole view down to the initial
     * loading state is reserved for the first load and error retries,
     * where there is nothing to keep on screen.
     */
    async refreshCatalog() {
        if (this.status !== STATUS_LOADED) {
            return this.loadCatalog();
        }
        this.refreshing = true;
        try {
            this.data = await getCatalog();
            this.ensureSelection();
        } catch (error) {
            this.toast('Refresh failed', this.errorMessage(error), 'error');
        } finally {
            this.refreshing = false;
        }
        return undefined;
    }

    handleRetry() {
        this.loadCatalog();
    }

    handleRefresh() {
        this.refreshCatalog();
    }

    handleTabSelect(event) {
        this.selectedTabId = event.detail.name;
        this.selectedCardId = undefined;
        this.formulaFeedback = {};
        this.iconDraft = undefined;
        this.ensureSelection();
    }

    handleCardOpen(event) {
        this.selectedCardId = event.currentTarget.dataset.cardId;
        this.formulaFeedback = {};
        this.iconDraft = undefined;
    }

    /**
     * Opens the shared icon picker for either the card-properties panel or
     * the new-card wizard, recorded in iconPickerTarget so the single
     * onselect handler below knows which draft to update.
     */
    handleOpenIconPicker(event) {
        this.iconPickerTarget = event.currentTarget.dataset.target;
        this.iconPickerOpen = true;
    }

    handleCloseIconPicker() {
        this.iconPickerOpen = false;
    }

    handleIconSelect(event) {
        const iconName = event.detail.value;
        if (this.iconPickerTarget === 'newCard') {
            this.newCardIcon = iconName;
        } else {
            this.iconDraft = iconName;
        }
        this.iconPickerOpen = false;
    }

    /** The card-properties icon, from an open picker selection or the card's saved value. */
    get iconRawValue() {
        return this.iconDraft ?? this.selectedCard?.iconName ?? '';
    }

    get iconTriggerLabel() {
        return this.iconRawValue || 'Choose an icon';
    }

    /** The glyph shown on the properties trigger button; blank falls back like the shell does. */
    get iconPreviewName() {
        return this.iconRawValue || 'standard:default';
    }

    get newCardIconTriggerLabel() {
        return this.newCardIcon || 'Choose an icon';
    }

    get newCardIconPreviewName() {
        return this.newCardIcon || 'standard:default';
    }

    /** Preselects the picker's category and highlights the value for whichever field opened it. */
    get selectedIconForPicker() {
        return this.iconPickerTarget === 'newCard' ? this.newCardIcon : this.iconRawValue;
    }

    handleCardKeydown(event) {
        if (event.key === 'Enter' || event.key === ' ') {
            event.preventDefault();
            this.handleCardOpen(event);
        }
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
            await this.refreshCatalog();
        } finally {
            this.savingOrder = false;
        }
    }

    async handleSaveProperties() {
        if (this.busy) {
            return;
        }
        if (!this.requiredFieldsValid(['[data-id="prop-label"]'])) {
            return;
        }
        this.busy = true;
        const card = this.selectedCard;
        const label = this.template.querySelector('[data-id="prop-label"]').value;
        const description = this.template.querySelector('[data-id="prop-description"]').value;
        const iconName = this.iconRawValue;
        const buttonLabel = this.template.querySelector('[data-id="prop-button-label"]').value;
        const binding = this.template.querySelector('[data-id="prop-component"]').value;
        const separatorAt = binding.indexOf(BINDING_SEPARATOR);
        const componentType = binding.slice(0, separatorAt);
        const componentName = binding.slice(separatorAt + 1);
        try {
            await saveCardProperties({
                input: {
                    cardId: card.cardId,
                    label,
                    description,
                    iconName,
                    buttonLabel,
                    componentType,
                    componentName
                }
            });
            this.toast('Card saved', `“${label}” was saved.`, 'success');
            await this.refreshCatalog();
        } catch (error) {
            this.toast('Save failed', this.errorMessage(error), 'error');
        } finally {
            this.busy = false;
        }
    }

    async handleValidateFormula(event) {
        if (this.busy) {
            return;
        }
        this.busy = true;
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
        } finally {
            this.busy = false;
        }
    }

    async handleSaveFormula(event) {
        if (this.busy) {
            return;
        }
        this.busy = true;
        const ruleId = event.currentTarget.dataset.ruleId;
        const formulaText = this.template.querySelector(`[data-id="formula-${ruleId}"]`).value;
        try {
            await saveRuleFormula({ ruleId, cardId: this.selectedCardId, formulaText });
            this.toast('Rule saved', 'The visibility formula was saved.', 'success');
            await this.refreshCatalog();
        } catch (error) {
            this.toast('Save failed', this.errorMessage(error), 'error');
        } finally {
            this.busy = false;
        }
    }

    handleOpenHelp() {
        this.helpOpen = true;
    }

    handleCloseHelp() {
        this.helpOpen = false;
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
            await activateCard({ cardId: card.cardId });
            this.toast('Card activated', `“${card.label}” is now live for end users.`, 'success');
            await this.refreshCatalog();
        } catch (error) {
            this.toast('Activation failed', this.errorMessage(error), 'error');
        }
    }

    /**
     * Client-side gate before any create/save call: every listed field must
     * be non-blank. Fields that support reportValidity surface their own
     * inline error; the shared toast covers the rest.
     */
    requiredFieldsValid(selectors) {
        let valid = true;
        for (const selector of selectors) {
            const field = this.template.querySelector(selector);
            if (!field) {
                continue;
            }
            if (typeof field.reportValidity === 'function') {
                field.reportValidity();
            }
            if (!String(field.value ?? '').trim()) {
                valid = false;
            }
        }
        if (!valid) {
            this.toast('Missing information', 'Complete the required fields.', 'error');
        }
        return valid;
    }

    handleNewTab() {
        this.editingTabId = null;
        this.tabModalOpen = true;
    }

    handleEditTab() {
        this.editingTabId = this.selectedTabId;
        this.tabModalOpen = true;
    }

    handleCloseTabModal() {
        this.tabModalOpen = false;
    }

    async handleSaveTab() {
        if (this.busy) {
            return;
        }
        if (!this.requiredFieldsValid(['[data-id="nt-devname"]', '[data-id="nt-anchor"]', '[data-id="nt-sequence"]'])) {
            return;
        }
        this.busy = true;
        try {
            await saveTab({
                input: {
                    tabId: this.editingTabId,
                    developerName: this.template.querySelector('[data-id="nt-devname"]').value,
                    sObjectApiName: this.template.querySelector('[data-id="nt-anchor"]').value,
                    sequence: Number(this.template.querySelector('[data-id="nt-sequence"]').value),
                    active: this.template.querySelector('[data-id="nt-active"]').checked
                }
            });
            this.tabModalOpen = false;
            this.toast('Tab saved', 'The tab was saved.', 'success');
            await this.refreshCatalog();
        } catch (error) {
            this.toast('Save failed', this.errorMessage(error), 'error');
        } finally {
            this.busy = false;
        }
    }

    handleRequestDeleteTab() {
        const tab = this.selectedTab;
        this.tabModalOpen = false;
        this.deleteTarget = { kind: 'tab', id: tab.tabId, label: tab.developerName };
    }

    get tabModalTitle() {
        return this.editingTabId ? 'Edit tab' : 'New tab';
    }

    get isEditingTab() {
        return Boolean(this.editingTabId);
    }

    /** The tab modal's field values: the edited tab, or create-mode defaults. */
    get tabForm() {
        const editing = this.data?.tabs.find((tab) => tab.tabId === this.editingTabId);
        if (editing) {
            return {
                developerName: editing.developerName,
                sObjectApiName: editing.sObjectApiName,
                sequence: editing.sequence,
                active: editing.active
            };
        }
        return {
            developerName: '',
            sObjectApiName: '',
            sequence: (this.data?.tabs.length ?? 0) + 1,
            active: true
        };
    }

    handleNewCard() {
        this.newCardType = COMPONENT_TYPE_LWC;
        this.newCardIcon = '';
        this.newCardOpen = true;
    }

    handleCloseNewCard() {
        this.newCardOpen = false;
    }

    handleNewCardTypeChange(event) {
        this.newCardType = event.detail.value;
    }

    async handleCreateCard() {
        if (this.busy) {
            return;
        }
        const bindingField = this.isNewCardLwc ? '[data-id="nc-component"]' : '[data-id="nc-flow"]';
        if (!this.requiredFieldsValid(['[data-id="nc-devname"]', '[data-id="nc-label"]', bindingField])) {
            return;
        }
        this.busy = true;
        const tab = this.selectedTab;
        const componentName = this.isNewCardLwc
            ? this.template.querySelector('[data-id="nc-component"]').value.slice(COMPONENT_TYPE_LWC.length + 1)
            : this.template.querySelector('[data-id="nc-flow"]').value;
        try {
            await createCard({
                input: {
                    tabId: tab.tabId,
                    developerName: this.template.querySelector('[data-id="nc-devname"]').value,
                    label: this.template.querySelector('[data-id="nc-label"]').value,
                    description: this.template.querySelector('[data-id="nc-description"]').value,
                    iconName: this.newCardIcon,
                    buttonLabel: this.template.querySelector('[data-id="nc-button-label"]').value,
                    componentType: this.newCardType,
                    componentName,
                    order: tab.cards.length + 1
                }
            });
            this.newCardOpen = false;
            this.toast('Card created', 'The card starts as a draft — activate it when it is ready.', 'success');
            await this.refreshCatalog();
        } catch (error) {
            this.toast('Create failed', this.errorMessage(error), 'error');
        } finally {
            this.busy = false;
        }
    }

    handleAddRule() {
        this.addRuleOpen = true;
    }

    handleCloseAddRule() {
        this.addRuleOpen = false;
    }

    async handleCreateRule() {
        if (this.busy) {
            return;
        }
        if (!this.requiredFieldsValid(['[data-id="nr-devname"]'])) {
            return;
        }
        this.busy = true;
        try {
            await createRule({
                cardId: this.selectedCardId,
                developerName: this.template.querySelector('[data-id="nr-devname"]').value,
                formulaText: this.template.querySelector('[data-id="nr-formula"]').value
            });
            this.addRuleOpen = false;
            this.toast('Rule created', 'The visibility rule was created.', 'success');
            await this.refreshCatalog();
        } catch (error) {
            this.toast('Create failed', this.errorMessage(error), 'error');
        } finally {
            this.busy = false;
        }
    }

    async handleAddPredicate(event) {
        if (this.busy) {
            return;
        }
        const ruleId = event.currentTarget.dataset.ruleId;
        if (!this.requiredFieldsValid([`[data-id="pred-target-${ruleId}"]`])) {
            return;
        }
        this.busy = true;
        try {
            await addRulePredicate({
                ruleId,
                predicateType: this.template.querySelector(`[data-id="pred-type-${ruleId}"]`).value,
                targetApiName: this.template.querySelector(`[data-id="pred-target-${ruleId}"]`).value
            });
            await this.refreshCatalog();
        } catch (error) {
            this.toast('Add failed', this.errorMessage(error), 'error');
        } finally {
            this.busy = false;
        }
    }

    async handleRemovePredicate(event) {
        if (this.busy) {
            return;
        }
        this.busy = true;
        try {
            await deleteRulePredicate({ predicateId: event.currentTarget.dataset.predicateId });
            await this.refreshCatalog();
        } catch (error) {
            this.toast('Delete failed', this.errorMessage(error), 'error');
        } finally {
            this.busy = false;
        }
    }

    async handleDeactivate() {
        if (this.busy) {
            return;
        }
        this.busy = true;
        const card = this.selectedCard;
        try {
            await deactivateCard({ cardId: card.cardId });
            this.toast('Card deactivated', `“${card.label}” is a draft again — end users no longer see it.`, 'success');
            await this.refreshCatalog();
        } catch (error) {
            this.toast('Deactivation failed', this.errorMessage(error), 'error');
        } finally {
            this.busy = false;
        }
    }

    async handleEngageKillSwitch() {
        if (this.busy) {
            return;
        }
        this.busy = true;
        const card = this.selectedCard;
        try {
            await engageKillSwitch({ cardId: card.cardId });
            this.toast('Kill switch on', `“${card.label}” is hidden everywhere until the switch is released.`, 'warning');
            await this.refreshCatalog();
        } catch (error) {
            this.toast('Kill switch failed', this.errorMessage(error), 'error');
        } finally {
            this.busy = false;
        }
    }

    async handleReleaseKillSwitch() {
        if (this.busy) {
            return;
        }
        this.busy = true;
        const card = this.selectedCard;
        try {
            await releaseKillSwitch({ cardId: card.cardId });
            this.toast('Kill switch released', `“${card.label}” follows its visibility rules again.`, 'success');
            await this.refreshCatalog();
        } catch (error) {
            this.toast('Release failed', this.errorMessage(error), 'error');
        } finally {
            this.busy = false;
        }
    }

    handleRequestDeleteCard() {
        const card = this.selectedCard;
        this.deleteTarget = { kind: 'card', id: card.cardId, label: card.label };
    }

    handleRequestDeleteRule(event) {
        const ruleId = event.currentTarget.dataset.ruleId;
        const rule = this.selectedCard.rules.find((candidate) => candidate.ruleId === ruleId);
        this.deleteTarget = { kind: 'rule', id: ruleId, label: rule.developerName };
    }

    handleCancelDelete() {
        this.deleteTarget = null;
    }

    async handleConfirmDelete() {
        if (this.busy || !this.deleteTarget) {
            return;
        }
        this.busy = true;
        const target = this.deleteTarget;
        this.deleteTarget = null;
        try {
            if (target.kind === 'card') {
                await deleteCard({ cardId: target.id });
                this.toast('Card deleted', `“${target.label}” and its rules were deleted.`, 'success');
            } else if (target.kind === 'tab') {
                await deleteTab({ tabId: target.id });
                this.toast('Tab deleted', `“${target.label}” was deleted.`, 'success');
            } else {
                await deleteRule({ ruleId: target.id });
                this.toast('Rule deleted', `“${target.label}” was deleted.`, 'success');
            }
            await this.refreshCatalog();
        } catch (error) {
            this.toast('Delete failed', this.errorMessage(error), 'error');
        } finally {
            this.busy = false;
        }
    }

    get isNewCardLwc() {
        return this.newCardType === COMPONENT_TYPE_LWC;
    }

    get newCardTypeOptions() {
        return [
            { label: 'Lightning component', value: COMPONENT_TYPE_LWC },
            { label: 'Screen flow', value: COMPONENT_TYPE_FLOW }
        ];
    }

    get predicateTypeOptions() {
        return [
            { label: 'Permission set', value: 'PERMISSION_SET' },
            { label: 'Field read access', value: 'FLS_READ' }
        ];
    }

    get deleteMessage() {
        if (!this.deleteTarget) {
            return '';
        }
        if (this.deleteTarget.kind === 'card') {
            return `“${this.deleteTarget.label}” will be deleted together with its visibility rules. This cannot be undone.`;
        }
        if (this.deleteTarget.kind === 'tab') {
            return `The tab “${this.deleteTarget.label}” will be deleted. A tab that still has cards is rejected.`;
        }
        return `The rule “${this.deleteTarget.label}” and its predicates will be deleted. This cannot be undone.`;
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

    /** The page header's one-line summary of what this console manages. */
    get headerMeta() {
        if (this.status !== STATUS_LOADED || !this.data.hasManagePermission) {
            return 'Cards, visibility rules, and activation for the Vista 360 shell';
        }
        const tabs = this.data.tabs;
        const cardCount = tabs.reduce((total, tab) => total + tab.cards.length, 0);
        const objectCount = new Set(tabs.map((tab) => tab.sObjectApiName)).size;
        return `${tabs.length} tab${tabs.length === 1 ? '' : 's'} · ${cardCount} card${cardCount === 1 ? '' : 's'} · ${objectCount} object${objectCount === 1 ? '' : 's'}`;
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
            hasNoCards: tab.cards.length === 0,
            cards: tab.cards.map((card, index) => this.toCardRow(card, index, lastIndex))
        };
    }

    toCardRow(card, index, lastIndex) {
        const presentation = this.cardPresentation(card);
        const isSelected = card.cardId === this.selectedCardId;
        return {
            ...card,
            ...presentation,
            isSelected,
            rowClass: isSelected
                ? 'slds-box slds-box_link slds-box_x-small slds-media slds-m-bottom_x-small v360-admin-row_selected'
                : 'slds-box slds-box_link slds-box_x-small slds-media slds-m-bottom_x-small',
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
            isLive: state === 'live',
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
                    predicateTypeFieldId: `pred-type-${rule.ruleId}`,
                    predicateTargetFieldId: `pred-target-${rule.ruleId}`,
                    activeLabel: rule.active ? 'Active' : 'Off',
                    activeClass: rule.active ? 'slds-badge slds-theme_success' : 'slds-badge',
                    predicatePills: (rule.predicates ?? []).map((predicate, index) => ({
                        key: `${rule.ruleId}-${index}`,
                        predicateId: predicate.predicateId,
                        label: `${predicate.predicateType} · ${predicate.targetApiName}`
                    })),
                    feedbackMessage: feedback?.message,
                    feedbackClass: feedback?.isValid
                        ? 'slds-text-body_small slds-text-color_success slds-m-left_x-small'
                        : 'slds-text-body_small slds-text-color_error slds-m-left_x-small'
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
            boxClass: check.ok
                ? 'slds-box slds-box_x-small slds-m-bottom_x-small'
                : 'slds-box slds-box_x-small slds-m-bottom_x-small slds-theme_warning',
            iconName: check.ok ? 'utility:success' : 'utility:warning',
            iconVariant: check.ok ? 'success' : 'warning'
        }));
    }
}
