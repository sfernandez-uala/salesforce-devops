import { createElement } from 'lwc';
import SearchPicker from 'c/searchPicker';

const OPTIONS = [
    { key: 'a', label: 'Agent access', value: 'V360_Agent', detail: 'V360_Agent' },
    { key: 'b', label: 'Collections', value: 'V360_Collections', detail: 'V360_Collections' },
    { key: 'c', label: 'Risk analyst', value: 'V360_Risk', detail: 'V360_Risk' }
];

const flush = () => new Promise((res) => setTimeout(res, 0));

function createPicker(props = {}) {
    const element = createElement('c-search-picker', { is: SearchPicker });
    Object.assign(element, { label: 'Permission set', options: OPTIONS, ...props });
    document.body.appendChild(element);
    return element;
}

describe('c-search-picker', () => {
    afterEach(() => {
        while (document.body.firstChild) {
            document.body.removeChild(document.body.firstChild);
        }
    });

    /**
     * Both variants render every branch of the template. The component has
     * twice shipped a template reading a getter the class never declared --
     * which compiles, and only fails once the branch actually renders.
     */
    it('names the field variant with a label above the control', async () => {
        const element = createPicker();
        await flush();

        const label = element.shadowRoot.querySelector('label');
        expect(label).not.toBeNull();
        expect(label.textContent).toContain('Permission set');
    });

    it('carries the button variant label on the trigger and not above it', async () => {
        const element = createPicker({ variant: 'button', triggerLabel: 'Field' });
        await flush();

        // A label above and the same word on the button would say it twice.
        expect(element.shadowRoot.querySelector('label')).toBeNull();
        expect(element.shadowRoot.querySelector('[data-id="picker-trigger"]').textContent).toContain('Field');
    });

    it('shows the chosen value on the field trigger, and the placeholder when there is none', async () => {
        const element = createPicker({ placeholder: 'Search permission sets' });
        await flush();
        expect(element.shadowRoot.querySelector('[data-id="picker-trigger"]').textContent).toContain(
            'Search permission sets'
        );

        element.value = 'V360_Agent';
        await flush();
        expect(element.shadowRoot.querySelector('[data-id="picker-trigger"]').textContent).toContain('V360_Agent');
    });

    it('opens on the trigger and lists every option', async () => {
        const element = createPicker();
        await flush();

        element.shadowRoot.querySelector('[data-id="picker-trigger"]').click();
        await flush();

        expect(element.shadowRoot.querySelectorAll('[data-id="picker-option"]')).toHaveLength(3);
    });

    it('filters on label, on value and on detail', async () => {
        const element = createPicker();
        await flush();
        element.shadowRoot.querySelector('[data-id="picker-trigger"]').click();
        await flush();

        const search = element.shadowRoot.querySelector('[data-id="picker-search"]');
        search.value = 'collect';
        search.dispatchEvent(new CustomEvent('change', { detail: { value: 'collect' } }));
        await flush();

        const options = element.shadowRoot.querySelectorAll('[data-id="picker-option"]');
        expect(options).toHaveLength(1);
        expect(options[0].textContent).toContain('Collections');
    });

    it('says so when nothing matches instead of showing an empty list', async () => {
        const element = createPicker();
        await flush();
        element.shadowRoot.querySelector('[data-id="picker-trigger"]').click();
        await flush();

        const search = element.shadowRoot.querySelector('[data-id="picker-search"]');
        search.value = 'zzz';
        search.dispatchEvent(new CustomEvent('change', { detail: { value: 'zzz' } }));
        await flush();

        expect(element.shadowRoot.querySelectorAll('[data-id="picker-option"]')).toHaveLength(0);
        expect(element.shadowRoot.querySelector('[data-id="picker-empty"]').textContent).toContain('zzz');
    });

    it('emits the chosen value and closes', async () => {
        const element = createPicker();
        const selected = jest.fn();
        element.addEventListener('select', selected);
        await flush();

        element.shadowRoot.querySelector('[data-id="picker-trigger"]').click();
        await flush();
        element.shadowRoot.querySelectorAll('[data-id="picker-option"]')[1].click();
        await flush();

        expect(selected).toHaveBeenCalledTimes(1);
        expect(selected.mock.calls[0][0].detail.value).toBe('V360_Collections');
        expect(element.shadowRoot.querySelector('[data-id="picker-option"]')).toBeNull();
    });

    /**
     * The test above clicks the option directly, which is not how a mouse
     * reaches it: pressing the button moves focus first, and the component
     * once closed the list on that focus move and unmounted the option before
     * its click could land. Clicking straight through never saw it, so the
     * suite stayed green while nothing was selectable in a browser.
     *
     * `element.contains(option)` is false here on purpose -- shadow children
     * are descendants of the shadow root, not of the host -- which is exactly
     * the containment mistake that caused it.
     */
    it('survives the focus move that pressing an option causes', async () => {
        const element = createPicker();
        const selected = jest.fn();
        element.addEventListener('select', selected);
        await flush();

        element.shadowRoot.querySelector('[data-id="picker-trigger"]').click();
        await flush();

        const option = element.shadowRoot.querySelector('[data-id="picker-option"]');
        expect(element.contains(option)).toBe(false);

        element.shadowRoot
            .querySelector('.slds-form-element')
            .dispatchEvent(new FocusEvent('focusout', { relatedTarget: option }));
        await flush();

        const live = element.shadowRoot.querySelector('[data-id="picker-option"]');
        expect(live).not.toBeNull();

        live.click();
        await flush();
        expect(selected).toHaveBeenCalledTimes(1);
    });

    it('closes once focus really leaves the control', async () => {
        const element = createPicker();
        await flush();
        element.shadowRoot.querySelector('[data-id="picker-trigger"]').click();
        await flush();

        const outside = document.createElement('button');
        document.body.appendChild(outside);

        element.shadowRoot
            .querySelector('.slds-form-element')
            .dispatchEvent(new FocusEvent('focusout', { relatedTarget: outside }));
        await flush();

        expect(element.shadowRoot.querySelector('[data-id="picker-option"]')).toBeNull();
    });
});
