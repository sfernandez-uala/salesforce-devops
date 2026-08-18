import { LightningElement, api, wire } from 'lwc';
import getAnchorObjectOptions from '@salesforce/apex/V360SchemaVocabulary.getAnchorObjectOptions';

const OPTION_BASE_CLASS = 'slds-media slds-listbox__option slds-listbox__option_entity';

/**
 * Picks the object a Vista 360 surface is anchored on.
 *
 * The field this replaces was a free-text box: an admin typed an API name from
 * memory and found out at save time whether it existed. What is actually being
 * asked -- which object -- is a closed list the org already knows, so it is
 * offered as one, searchable by the label an admin reads and by the API name
 * the tab stores.
 *
 * It is a combobox rather than a picklist because orgs carry hundreds of
 * objects, and rather than a modal because the field it fills already lives in
 * one.
 */
export default class V360ObjectPicker extends LightningElement {
    @api label = 'Anchor object';
    @api placeholder = 'Search objects';
    @api fieldLevelHelp;
    @api required = false;
    @api disabled = false;

    options = [];
    optionsError = false;
    open = false;

    /**
     * What the user has typed, or null when they are not searching. Null is a
     * distinct state from the empty string: empty means "searching, and the box
     * is clear", which offers everything, while null means the box is showing
     * the stored value.
     */
    searchTerm = null;

    /** The row the arrow keys are on; -1 until they are used. */
    activeIndex = -1;

    _value = '';

    @api
    get value() {
        return this._value;
    }

    set value(next) {
        this._value = next ?? '';
        // A value set from outside settles the field, so a half-typed term
        // stops standing in front of it.
        this.searchTerm = null;
    }

    @wire(getAnchorObjectOptions)
    wiredOptions({ data, error }) {
        if (data) {
            this.options = data;
            this.optionsError = false;
        } else if (error) {
            this.options = [];
            this.optionsError = true;
        }
    }

    // ---- rendering ----------------------------------------------------

    get displayValue() {
        return this.searchTerm ?? this._value;
    }

    get expanded() {
        return this.open ? 'true' : 'false';
    }

    get comboboxClass() {
        const base = 'slds-combobox slds-dropdown-trigger slds-dropdown-trigger_click';
        return this.open ? `${base} slds-is-open` : base;
    }

    /**
     * The options the list is currently showing: every object until the user
     * types, then those whose label or API name contains what they typed.
     * Admins search by both -- "loan" finds it by name, "Uala_" by prefix.
     */
    get visibleOptions() {
        const term = (this.searchTerm ?? '').trim().toLowerCase();
        const matches = term
            ? this.options.filter(
                  (option) =>
                      option.label.toLowerCase().includes(term) ||
                      option.apiName.toLowerCase().includes(term)
              )
            : this.options;
        return matches.map((option, index) => {
            const isSelected = option.apiName === this._value;
            return {
                ...option,
                ariaSelected: isSelected ? 'true' : 'false',
                itemClass: this.optionClass(isSelected, index === this.activeIndex)
            };
        });
    }

    optionClass(isSelected, isActive) {
        let classes = OPTION_BASE_CLASS;
        if (isSelected) {
            classes += ' slds-is-selected';
        }
        // slds-has-focus is the listbox's own way of showing where the arrow
        // keys are without moving real focus off the input, which has to keep
        // it to stay typeable.
        if (isActive) {
            classes += ' slds-has-focus';
        }
        return classes;
    }

    get activeOptionId() {
        return this.visibleOptions[this.activeIndex]?.apiName ?? null;
    }

    get hasNoMatch() {
        return this.searchTerm !== null && this.visibleOptions.length === 0 && !this.optionsError;
    }

    get hasOptionsError() {
        return this.optionsError;
    }

    // ---- interaction --------------------------------------------------

    handleFocus() {
        this.open = true;
    }

    /**
     * Leaving the field abandons the search rather than committing it: what is
     * left in the box has to be the stored value, or the field reads as
     * configured with something it is not.
     */
    handleBlur() {
        this.open = false;
        this.searchTerm = null;
        this.activeIndex = -1;
    }

    handleInput(event) {
        this.searchTerm = event.target.value;
        this.open = true;
        this.activeIndex = -1;
    }

    handleKeyDown(event) {
        switch (event.key) {
            case 'ArrowDown':
                event.preventDefault();
                this.moveActive(1);
                break;
            case 'ArrowUp':
                event.preventDefault();
                this.moveActive(-1);
                break;
            case 'Enter': {
                const active = this.visibleOptions[this.activeIndex];
                if (!active) {
                    return;
                }
                // Only once there is something to pick, so Enter still submits
                // the form around it when the list is untouched.
                event.preventDefault();
                this.select(active.apiName);
                break;
            }
            case 'Escape':
                event.preventDefault();
                this.open = false;
                this.searchTerm = null;
                this.activeIndex = -1;
                break;
            default:
                break;
        }
    }

    moveActive(offset) {
        const count = this.visibleOptions.length;
        if (count === 0) {
            return;
        }
        // Opening, or arriving from no row at all, enters the list at the end
        // the key points to rather than one row past it.
        if (!this.open || this.activeIndex < 0) {
            this.open = true;
            this.activeIndex = offset > 0 ? 0 : count - 1;
            return;
        }
        this.activeIndex = (this.activeIndex + offset + count) % count;
    }

    handleOptionMouseDown(event) {
        event.preventDefault();
    }

    handleOptionClick(event) {
        this.select(event.currentTarget.dataset.apiName);
    }

    select(apiName) {
        this._value = apiName;
        this.searchTerm = null;
        this.open = false;
        this.activeIndex = -1;
        this.dispatchEvent(new CustomEvent('change', { detail: { value: apiName } }));
    }
}
