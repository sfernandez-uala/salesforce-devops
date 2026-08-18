import { createElement } from 'lwc';
import V360ObjectPicker from 'c/v360ObjectPicker';
import getAnchorObjectOptions from '@salesforce/apex/V360SchemaVocabulary.getAnchorObjectOptions';

// sfdx-lwc-jest auto-mocks an Apex import as a plain jest.fn, which is right
// for an imperative call and useless for a wired one -- it carries no emit or
// error. The adapter has to be asked for by name.
jest.mock(
    '@salesforce/apex/V360SchemaVocabulary.getAnchorObjectOptions',
    () => {
        const { createApexTestWireAdapter } = require('@salesforce/sfdx-lwc-jest');
        return { default: createApexTestWireAdapter(jest.fn()) };
    },
    { virtual: true }
);

const OPTIONS = [
    { label: 'Account', apiName: 'Account' },
    { label: 'Case', apiName: 'Case' },
    { label: 'Contact', apiName: 'Contact' },
    { label: 'Loan Application', apiName: 'Uala_Loan_Application__c' }
];

// Yields ten macrotask turns rather than one. The work a test waits on --
// a wire emit, a state-manager notification, a re-render, a dynamic import --
// often spans several chained turns, and a single setTimeout hop is exactly
// the assumption that goes flaky on a loaded CI worker while passing on a
// fast idle laptop. Ten is generous headroom, not a measured count.
const flushPromises = async () => {
    for (let turn = 0; turn < 10; turn += 1) {
        // eslint-disable-next-line no-await-in-loop
        await new Promise((res) => setTimeout(res, 0));
    }
};

function createPicker({ value } = {}) {
    const element = createElement('c-v360-object-picker', { is: V360ObjectPicker });
    if (value !== undefined) {
        element.value = value;
    }
    document.body.appendChild(element);
    return element;
}

/** Mounts the picker and lets the wired option list land. */
async function createLoadedPicker(config) {
    const element = createPicker(config);
    getAnchorObjectOptions.emit(OPTIONS);
    await flushPromises();
    return element;
}

const input = (element) => element.shadowRoot.querySelector('[data-id="combobox-input"]');
const listbox = (element) => element.shadowRoot.querySelector('[data-id="listbox"]');
const optionRows = (element) =>
    Array.from(element.shadowRoot.querySelectorAll('[data-id="object-option"]'));
const optionNames = (element) => optionRows(element).map((row) => row.dataset.apiName);

function type(element, text) {
    const field = input(element);
    field.value = text;
    field.dispatchEvent(new CustomEvent('input', { bubbles: true, composed: true }));
}

function press(element, key) {
    input(element).dispatchEvent(
        new KeyboardEvent('keydown', { key, bubbles: true, composed: true })
    );
}

const isOpen = (element) =>
    element.shadowRoot.querySelector('.slds-combobox').classList.contains('slds-is-open');

describe('c-v360-object-picker', () => {
    afterEach(() => {
        while (document.body.firstChild) {
            document.body.removeChild(document.body.firstChild);
        }
        jest.clearAllMocks();
    });

    // ---- shape --------------------------------------------------------

    it('starts closed and shows the value it was given', async () => {
        const element = await createLoadedPicker({ value: 'Contact' });

        expect(isOpen(element)).toBe(false);
        expect(input(element).value).toBe('Contact');
        expect(input(element).getAttribute('role')).toBe('combobox');
        expect(input(element).getAttribute('aria-expanded')).toBe('false');
        expect(listbox(element).getAttribute('role')).toBe('listbox');
    });

    it('opens on focus with every object offered', async () => {
        const element = await createLoadedPicker();

        input(element).dispatchEvent(new CustomEvent('focus', { bubbles: true, composed: true }));
        await flushPromises();

        expect(isOpen(element)).toBe(true);
        expect(input(element).getAttribute('aria-expanded')).toBe('true');
        expect(optionNames(element)).toEqual(OPTIONS.map((option) => option.apiName));
    });

    it('marks the selected object in the list', async () => {
        const element = await createLoadedPicker({ value: 'Case' });

        input(element).dispatchEvent(new CustomEvent('focus', { bubbles: true, composed: true }));
        await flushPromises();

        const selected = optionRows(element).filter(
            (row) => row.getAttribute('aria-selected') === 'true'
        );
        expect(selected).toHaveLength(1);
        expect(selected[0].dataset.apiName).toBe('Case');
    });

    // ---- searching ----------------------------------------------------

    it('narrows the list by label, which is the word an admin knows', async () => {
        const element = await createLoadedPicker();

        type(element, 'loan');
        await flushPromises();

        expect(optionNames(element)).toEqual(['Uala_Loan_Application__c']);
    });

    it('narrows the list by API name too, because that is what gets stored', async () => {
        const element = await createLoadedPicker();

        type(element, 'uala_');
        await flushPromises();

        expect(optionNames(element)).toEqual(['Uala_Loan_Application__c']);
    });

    it('says nothing matched instead of dropping an empty list open', async () => {
        const element = await createLoadedPicker();

        type(element, 'zzz');
        await flushPromises();

        expect(optionRows(element)).toHaveLength(0);
        expect(element.shadowRoot.querySelector('[data-id="no-results"]')).not.toBeNull();
    });

    // ---- choosing -----------------------------------------------------

    it('reports the API name when an object is clicked, and closes', async () => {
        const element = await createLoadedPicker();
        const changes = [];
        element.addEventListener('change', (event) => changes.push(event.detail.value));

        input(element).dispatchEvent(new CustomEvent('focus', { bubbles: true, composed: true }));
        await flushPromises();
        element.shadowRoot
            .querySelector('[data-id="object-option"][data-api-name="Uala_Loan_Application__c"]')
            .click();
        await flushPromises();

        expect(changes).toEqual(['Uala_Loan_Application__c']);
        expect(input(element).value).toBe('Uala_Loan_Application__c');
        expect(isOpen(element)).toBe(false);
    });

    it('walks the list with the arrows and picks with Enter', async () => {
        const element = await createLoadedPicker();
        const changes = [];
        element.addEventListener('change', (event) => changes.push(event.detail.value));

        press(element, 'ArrowDown');
        await flushPromises();
        expect(isOpen(element)).toBe(true);
        expect(input(element).getAttribute('aria-activedescendant')).toBe(optionRows(element)[0].id);

        press(element, 'ArrowDown');
        await flushPromises();
        expect(input(element).getAttribute('aria-activedescendant')).toBe(optionRows(element)[1].id);

        press(element, 'Enter');
        await flushPromises();
        expect(changes).toEqual(['Case']);
        expect(isOpen(element)).toBe(false);
    });

    it('wraps at both ends of the list', async () => {
        const element = await createLoadedPicker();

        press(element, 'ArrowUp');
        await flushPromises();
        const rows = optionRows(element);
        expect(input(element).getAttribute('aria-activedescendant')).toBe(rows[rows.length - 1].id);

        press(element, 'ArrowDown');
        await flushPromises();
        expect(input(element).getAttribute('aria-activedescendant')).toBe(optionRows(element)[0].id);
    });

    it('closes on Escape without choosing anything', async () => {
        const element = await createLoadedPicker({ value: 'Account' });
        const changes = [];
        element.addEventListener('change', (event) => changes.push(event.detail.value));

        press(element, 'ArrowDown');
        await flushPromises();
        press(element, 'Escape');
        await flushPromises();

        expect(isOpen(element)).toBe(false);
        expect(changes).toEqual([]);
        expect(input(element).value).toBe('Account');
    });

    /**
     * A half-typed term left in the box would read as the configured value and
     * is not one -- the field has to end up showing what is actually stored.
     */
    it('restores the stored value when focus leaves mid-search', async () => {
        const element = await createLoadedPicker({ value: 'Account' });

        type(element, 'cont');
        await flushPromises();
        input(element).dispatchEvent(new CustomEvent('blur', { bubbles: true, composed: true }));
        await flushPromises();

        expect(isOpen(element)).toBe(false);
        expect(input(element).value).toBe('Account');
    });

    it('reflects a value set from outside after the user has searched', async () => {
        const element = await createLoadedPicker({ value: 'Account' });

        type(element, 'cont');
        await flushPromises();
        element.value = 'Case';
        await flushPromises();

        expect(input(element).value).toBe('Case');
    });

    // ---- failure ------------------------------------------------------

    it('says so when the object list cannot be read, rather than looking empty', async () => {
        const element = createPicker();
        getAnchorObjectOptions.error();
        await flushPromises();

        expect(element.shadowRoot.querySelector('[data-id="options-error"]')).not.toBeNull();
    });
});
