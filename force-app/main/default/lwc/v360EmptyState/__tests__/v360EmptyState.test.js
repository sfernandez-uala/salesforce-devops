import { createElement } from 'lwc';
import V360EmptyState from 'c/v360EmptyState';

function createEmptyState(props) {
    const element = createElement('c-v360-empty-state', { is: V360EmptyState });
    Object.assign(element, props);
    document.body.appendChild(element);
    return element;
}

describe('c-v360-empty-state', () => {
    afterEach(() => {
        while (document.body.firstChild) {
            document.body.removeChild(document.body.firstChild);
        }
    });

    it('forwards title, illustration, size, and alternative text to lightning-empty-state', () => {
        const element = createEmptyState({
            title: 'Something went wrong',
            illustrationName: 'error:recoverable',
            size: 'small',
            alternativeText: 'Error illustration'
        });

        const emptyState = element.shadowRoot.querySelector('lightning-empty-state');
        expect(emptyState).not.toBeNull();
        expect(emptyState.title).toBe('Something went wrong');
        expect(emptyState.illustrationName).toBe('error:recoverable');
        expect(emptyState.size).toBe('small');
        expect(emptyState.alternativeText).toBe('Error illustration');
    });

    it('renders the description string prop into the description slot', () => {
        const element = createEmptyState({
            title: 'No cards',
            illustrationName: 'noresults:unknown',
            description: 'No cards are configured for this tab.'
        });

        // The slot attribute sits on the region wrapper, not on the content:
        // assigning it to a <slot> instead re-projects one slot into another
        // and consumer content never reaches the platform component.
        const description = element.shadowRoot.querySelector('[slot="description"] p');
        expect(description).not.toBeNull();
        expect(description.textContent).toBe('No cards are configured for this tab.');
    });

    it('does not render a retry button when no retryLabel is provided', () => {
        const element = createEmptyState({
            title: 'No cards',
            illustrationName: 'noresults:unknown',
            description: 'No cards are configured for this tab.'
        });

        expect(element.shadowRoot.querySelector('lightning-button[slot="cta"]')).toBeNull();
    });

    it('renders a retry button and dispatches "retry" when clicked', () => {
        const element = createEmptyState({
            title: 'Something went wrong',
            illustrationName: 'error:recoverable',
            description: 'Unable to load Vista 360 cards for this record right now.',
            retryLabel: 'Retry'
        });

        const handler = jest.fn();
        element.addEventListener('retry', handler);

        const retryButton = element.shadowRoot.querySelector('[slot="cta"] lightning-button');
        expect(retryButton).not.toBeNull();
        expect(retryButton.label).toBe('Retry');

        retryButton.click();

        expect(handler).toHaveBeenCalledTimes(1);
    });
});
