import { LightningElement, api } from 'lwc';

/**
 * A searchable list that resolves to one value, for the case
 * lightning-combobox and lightning-record-picker both leave open: a long list
 * of values that is not backed by records, so it needs filtering but has no
 * record id to look up.
 *
 * The owner supplies the options and receives a `select` event carrying the
 * chosen value; nothing here knows where the list came from.
 */
export default class SearchPicker extends LightningElement {
    /** Shown above the control. */
    @api label;

    /** [{ key, label, value, detail }] — detail is optional secondary text. */
    @api options = [];

    /** The currently chosen value, shown on the trigger. */
    @api value;

    @api placeholder = 'Search…';

    @api disabled = false;

    /** Renders the field as required, matching the SLDS form element. */
    @api required = false;

    /**
     * How the trigger presents itself.
     *
     *   field  — a form control: a label above, and the chosen value shown on
     *            the trigger. For picking one value and keeping it.
     *   button — a toolbar button with a fixed label. For acting on the choice
     *            and forgetting it, where nothing is "currently selected".
     *
     * The searchable list underneath is the same either way, which is the
     * whole reason both shapes live in one component.
     */
    @api variant = 'field';

    /** The button variant's fixed label; ignored by the field variant. */
    @api triggerLabel;

    open = false;
    query = '';

    get isButtonVariant() {
        return this.variant === 'button';
    }

    get displayLabel() {
        return this.isButtonVariant ? this.triggerLabel : this.value || this.placeholder;
    }

    /** A placeholder must not read as a chosen value. */
    get triggerClass() {
        if (this.isButtonVariant) {
            return 'slds-button slds-button_neutral';
        }
        const base = 'slds-input slds-combobox__input search-picker-trigger';
        return this.value ? base : `${base} search-picker-trigger_empty`;
    }

    get comboboxClass() {
        const base = 'slds-combobox slds-dropdown-trigger slds-dropdown-trigger_click';
        return this.open ? `${base} slds-is-open` : base;
    }

    get filteredOptions() {
        const query = this.query.trim().toLowerCase();
        if (!query) {
            return this.options;
        }
        return this.options.filter(
            (option) =>
                option.label.toLowerCase().includes(query) ||
                (option.detail ?? '').toLowerCase().includes(query) ||
                (option.value ?? '').toLowerCase().includes(query)
        );
    }

    get hasNoMatch() {
        return this.filteredOptions.length === 0;
    }

    get noMatchMessage() {
        return `Nothing matches “${this.query}”.`;
    }

    handleToggle() {
        this.open = !this.open;
        this.query = '';
    }

    handleQuery(event) {
        this.query = event.target.value;
    }

    handleSelect(event) {
        const value = event.currentTarget.dataset.value;
        this.open = false;
        this.query = '';
        this.dispatchEvent(new CustomEvent('select', { detail: { value } }));
    }

    /** Closes when focus leaves the whole control, not on every inner blur. */
    handleFocusOut(event) {
        if (!this.template.host.contains(event.relatedTarget)) {
            this.open = false;
        }
    }

    /** Focuses the search box as the list opens, so typing filters immediately. */
    renderedCallback() {
        if (!this.open) {
            return;
        }
        const search = this.template.querySelector('[data-id="picker-search"]');
        if (search && this.template.activeElement !== search) {
            search.focus();
        }
    }
}
