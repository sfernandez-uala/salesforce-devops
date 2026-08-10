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

    /**
     * The field variant is a form control and needs its label above it, both
     * to name the value and to line up with the controls beside it. The button
     * variant carries its label on the trigger, so a second one above would be
     * the same word twice.
     */
    get showLabel() {
        return !this.isButtonVariant && this.label;
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

    /**
     * The list is never narrower than SLDS's medium dropdown, because what it
     * holds are API names: at the trigger's own width a toolbar button gave a
     * list where every entry truncated to the same prefix, which is no list at
     * all. The field variant additionally grows to its form control, where
     * matching the input it belongs to is the point.
     *
     * Every class is assembled here. A static class sitting beside a bound one
     * in the template is discarded, and this component has paid for that twice.
     */
    get dropdownClass() {
        const base = 'slds-dropdown slds-dropdown_left slds-dropdown_medium';
        return this.isButtonVariant ? base : `${base} slds-dropdown_fluid`;
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

    /**
     * Pressing the mouse on an option would move focus to it and fire focusout
     * first, unmounting the option before its click could land -- and on the
     * platforms where a button takes no focus on mousedown, focus would leave
     * for nothing at all, with the same result. Keeping the default from
     * running leaves focus in the search box, so the click always arrives.
     */
    handleOptionMouseDown(event) {
        event.preventDefault();
    }

    /**
     * Closes when focus leaves the whole control, not on every inner blur.
     *
     * Asked of the shadow root, never the host: Node.contains walks the node
     * tree, where this component's own elements are children of the shadow
     * root and NOT of the host. host.contains() is therefore false for every
     * element in here, which closed the list on any internal focus move.
     */
    handleFocusOut(event) {
        if (!this.template.contains(event.relatedTarget)) {
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
