import { createElement } from 'lwc';
import V360AccountSnapshot from 'c/v360AccountSnapshot';
import { refreshApex } from '@salesforce/apex';
import { getRecord } from 'lightning/uiRecordApi';

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

function createSnapshot() {
    const element = createElement('c-v360-account-snapshot', { is: V360AccountSnapshot });
    element.recordId = '001000000000301AAA';
    document.body.appendChild(element);
    return element;
}

describe('c-v360-account-snapshot', () => {
    afterEach(() => {
        while (document.body.firstChild) {
            document.body.removeChild(document.body.firstChild);
        }
        jest.clearAllMocks();
    });

    it('renders both fields when the UI API returns them', async () => {
        const element = createSnapshot();

        getRecord.emit({
            fields: {
                Industry: { value: 'Banking' },
                AnnualRevenue: { value: 5000000 }
            }
        });
        await flushPromises();

        const paragraphs = element.shadowRoot.querySelectorAll('.slds-form-element__static');
        const text = Array.from(paragraphs)
            .map((p) => p.textContent)
            .join(' ');
        expect(text).toContain('Banking');
        const revenue = element.shadowRoot.querySelector('lightning-formatted-number');
        expect(revenue).not.toBeNull();
        expect(revenue.value).toBe(5000000);
        expect(element.shadowRoot.querySelector('[data-id="no-fields-state"]')).toBeNull();
        expect(element.shadowRoot.querySelector('[data-id="error-state"]')).toBeNull();
    });

    it('degrades gracefully when a field is absent from the response (FLS-stripped)', async () => {
        const element = createSnapshot();

        // The UI API omits a field the running user cannot read rather than
        // erroring -- only Industry comes back here.
        getRecord.emit({
            fields: {
                Industry: { value: 'Banking' }
            }
        });
        await flushPromises();

        const text = element.shadowRoot.textContent;
        expect(text).toContain('Banking');
        expect(text).not.toContain('Annual Revenue');
        expect(element.shadowRoot.querySelector('[data-id="no-fields-state"]')).toBeNull();
    });

    it('shows a no-access empty state when the record loads with neither field readable', async () => {
        const element = createSnapshot();

        getRecord.emit({ fields: {} });
        await flushPromises();

        const noFieldsState = element.shadowRoot.querySelector('[data-id="no-fields-state"]');
        expect(noFieldsState).not.toBeNull();
        expect(noFieldsState.illustrationName).toBe('access:request');
        expect(element.shadowRoot.querySelector('[data-id="error-state"]')).toBeNull();
    });

    it('shows a recoverable-error empty state when the wire adapter errors, and retry refreshes the wire', async () => {
        const element = createSnapshot();

        getRecord.error();
        await flushPromises();

        const errorState = element.shadowRoot.querySelector('[data-id="error-state"]');
        expect(errorState).not.toBeNull();
        expect(errorState.illustrationName).toBe('error:recoverable');
        expect(errorState.retryLabel).toBe('Retry');

        errorState.dispatchEvent(new CustomEvent('retry'));

        expect(refreshApex).toHaveBeenCalledTimes(1);
    });
});
