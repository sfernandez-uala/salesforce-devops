import { LightningElement } from 'lwc';
import getCatalog from '@salesforce/apex/V360AdminController.getCatalog';

const STATUS_LOADING = 'loading';
const STATUS_LOADED = 'loaded';
const STATUS_ERROR = 'error';

/**
 * The Vista 360 admin console: a read-only browser of the configuration
 * graph (tabs, their cards, and rule counts) for users holding the
 * V360_ManageVisibilityRules custom permission. The server is the
 * authority on that permission -- this component only renders what the
 * controller reports, including the no-permission state.
 */
export default class V360AdminConsole extends LightningElement {
    status = STATUS_LOADING;
    data;
    error;

    connectedCallback() {
        this.loadCatalog();
    }

    async loadCatalog() {
        this.status = STATUS_LOADING;
        this.error = undefined;
        try {
            this.data = await getCatalog();
            this.status = STATUS_LOADED;
        } catch (error) {
            this.error = error;
            this.status = STATUS_ERROR;
        }
    }

    handleRetry() {
        this.loadCatalog();
    }

    handleRefresh() {
        this.loadCatalog();
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

    get tabs() {
        return this.data.tabs.map((tab) => ({
            ...tab,
            title: `${tab.developerName} (${tab.sObjectApiName})`,
            statusLabel: tab.active ? 'Active' : 'Inactive',
            statusClass: tab.active ? 'slds-badge slds-theme_success' : 'slds-badge',
            cards: tab.cards.map((card) => ({
                ...card,
                activeLabel: card.active ? 'Yes' : 'No',
                killSwitchLabel: card.killSwitch ? 'On' : 'Off',
                killSwitchClass: card.killSwitch ? 'slds-badge slds-theme_warning' : 'slds-badge'
            }))
        }));
    }
}
