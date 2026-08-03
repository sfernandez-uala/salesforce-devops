import { LightningElement } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import getCatalog from '@salesforce/apex/V360AdminController.getCatalog';
import updateCardOrder from '@salesforce/apex/V360AdminController.updateCardOrder';

const STATUS_LOADING = 'loading';
const STATUS_LOADED = 'loaded';
const STATUS_ERROR = 'error';

/**
 * The Vista 360 admin console for users holding the
 * V360_ManageVisibilityRules custom permission. Organized the way admins
 * think: a vertical navigation of tabs on the left, and the selected tab's
 * workspace on the right, where its cards appear as reorderable rows.
 * Reordering rewrites Order__c through the permission-gated write path,
 * optimistically in the UI and rolled back with a toast if the save fails.
 *
 * Card state is first-class: a card that is not active is a DRAFT --
 * invisible to end users (the visibility engine hides inactive cards
 * before evaluating anything), which is what makes configure-then-activate
 * a safe workflow. A live card with no rules is visible to everyone by
 * design, and the row says so instead of leaving it implicit.
 *
 * The server is the authority on the manage permission -- this component
 * only renders what the controller reports, including the no-permission
 * state.
 */
export default class V360AdminConsole extends LightningElement {
    status = STATUS_LOADING;
    data;
    error;
    selectedTabId;
    savingOrder = false;

    connectedCallback() {
        this.loadCatalog();
    }

    async loadCatalog() {
        this.status = STATUS_LOADING;
        this.error = undefined;
        try {
            this.data = await getCatalog();
            this.status = STATUS_LOADED;
            this.ensureSelectedTab();
        } catch (error) {
            this.error = error;
            this.status = STATUS_ERROR;
        }
    }

    ensureSelectedTab() {
        const tabs = this.data?.tabs ?? [];
        const stillExists = tabs.some((tab) => tab.tabId === this.selectedTabId);
        if (!stillExists) {
            this.selectedTabId = tabs.length ? tabs[0].tabId : undefined;
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
    }

    async handleMoveUp(event) {
        this.moveCard(event.currentTarget.dataset.cardId, -1);
    }

    async handleMoveDown(event) {
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
        this.applyLocalCardOrder(tab.tabId, cards);

        this.savingOrder = true;
        try {
            await updateCardOrder({ orderedCardIds: cards.map((card) => card.cardId) });
        } catch (error) {
            this.dispatchEvent(
                new ShowToastEvent({
                    title: 'Reorder failed',
                    message: 'The new order could not be saved. Showing the last saved order.',
                    variant: 'error'
                })
            );
            await this.loadCatalog();
        } finally {
            this.savingOrder = false;
        }
    }

    applyLocalCardOrder(tabId, cards) {
        this.data = {
            ...this.data,
            tabs: this.data.tabs.map((tab) => (tab.tabId === tabId ? { ...tab, cards } : tab))
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

    get navigationTabs() {
        return this.data.tabs.map((tab) => ({
            ...tab,
            navLabel: `${tab.developerName} (${tab.sObjectApiName})`
        }));
    }

    get selectedTab() {
        return this.data?.tabs.find((tab) => tab.tabId === this.selectedTabId) ?? null;
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
        const state = card.killSwitch ? 'killed' : card.active ? 'live' : 'draft';
        const stateLabel = { killed: 'Kill switch on', live: 'Live', draft: 'Draft' }[state];
        const stateClass = {
            killed: 'slds-badge slds-theme_warning',
            live: 'slds-badge slds-theme_success',
            draft: 'slds-badge'
        }[state];
        return {
            ...card,
            iconNameOrDefault: card.iconName || 'standard:default',
            binding: `${card.componentType}: ${card.componentName}`,
            stateLabel,
            stateClass,
            isDraft: state === 'draft',
            ruleSummary:
                card.ruleCount > 0
                    ? `${card.ruleCount} visibility rule${card.ruleCount === 1 ? '' : 's'}`
                    : 'No rules — visible to everyone who can see the page',
            hasNoRules: card.ruleCount === 0,
            moveUpDisabled: index === 0 || this.savingOrder,
            moveDownDisabled: index === lastIndex || this.savingOrder
        };
    }
}
