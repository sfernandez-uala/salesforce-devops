import { createElement } from 'lwc';
import V360AccountSnapshot from 'c/v360AccountSnapshot';
import { refreshApex } from '@salesforce/apex';
import { getRecord } from 'lightning/uiRecordApi';

const flushPromises = () => new Promise((resolve) => setTimeout(resolve, 0));

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

        const paragraphs = element.shadowRoot.querySelectorAll('p');
        const text = Array.from(paragraphs)
            .map((p) => p.textContent)
            .join(' ');
        expect(text).toContain('Banking');
        expect(text).toContain('5000000');
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
