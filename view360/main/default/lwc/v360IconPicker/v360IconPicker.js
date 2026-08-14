import { LightningElement, api } from 'lwc';
import { getCategories } from 'c/iconCatalog';

const MAX_VISIBLE_WHEN_BROWSING = 120;
const DEFAULT_CATEGORY = 'standard';

/**
 * A modal for choosing an SLDS icon by browsing its category (standard,
 * utility, action, custom, doctype) or searching across all of them.
 * Fires `select` with `detail.value` set to the full `category:name`
 * once the admin clicks a tile, and `close` when they cancel. Owns no
 * open/closed state of its own -- the parent mounts it only while the
 * picker should be visible, the same convention every other console
 * modal follows.
 */
export default class V360IconPicker extends LightningElement {
    @api selectedIcon;

    searchTerm = '';
    activeCategory = DEFAULT_CATEGORY;

    connectedCallback() {
        const prefix = this.selectedIcon?.split(':')[0];
        if (prefix && getCategories().some((category) => category.key === prefix)) {
            this.activeCategory = prefix;
        }
    }

    handleSearch(event) {
        this.searchTerm = event.detail.value.trim().toLowerCase();
    }

    handleCategorySelect(event) {
        this.activeCategory = event.currentTarget.dataset.category;
        this.searchTerm = '';
        const searchInput = this.template.querySelector('[data-id="icon-search"]');
        if (searchInput) {
            searchInput.value = '';
        }
    }

    handleSelect(event) {
        this.dispatchEvent(new CustomEvent('select', { detail: { value: event.currentTarget.dataset.icon } }));
    }

    handleCancel() {
        this.dispatchEvent(new CustomEvent('close'));
    }

    get categories() {
        return getCategories().map((category) => ({
            key: category.key,
            label: category.label,
            variant: category.key === this.activeCategory ? 'brand' : 'neutral'
        }));
    }

    get isBrowsing() {
        return !this.searchTerm;
    }

    /** Searching looks across every category; browsing shows only the active one. */
    get matches() {
        if (this.searchTerm) {
            const term = this.searchTerm;
            const found = [];
            for (const category of getCategories()) {
                for (const name of category.icons) {
                    if (name.includes(term)) {
                        found.push({ category: category.key, name });
                    }
                }
            }
            return found;
        }
        const active = getCategories().find((category) => category.key === this.activeCategory);
        return (active?.icons ?? []).map((name) => ({ category: active.key, name }));
    }

    get totalCount() {
        return this.matches.length;
    }

    get hasResults() {
        return this.totalCount > 0;
    }

    /** Browsing caps the grid for a fast first paint; a search always shows every match. */
    get isTruncated() {
        return this.isBrowsing && this.totalCount > MAX_VISIBLE_WHEN_BROWSING;
    }

    get visibleIcons() {
        const shown = this.isBrowsing ? this.matches.slice(0, MAX_VISIBLE_WHEN_BROWSING) : this.matches;
        return shown.map((icon) => {
            const fullName = `${icon.category}:${icon.name}`;
            return {
                fullName,
                name: icon.name,
                tileClass:
                    fullName === this.selectedIcon
                        ? 'v360-icon-picker-tile v360-icon-picker-tile_selected'
                        : 'v360-icon-picker-tile'
            };
        });
    }

    get visibleCount() {
        return this.visibleIcons.length;
    }
}
