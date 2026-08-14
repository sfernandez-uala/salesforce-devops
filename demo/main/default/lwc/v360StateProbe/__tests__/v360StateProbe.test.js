import { createElement } from 'lwc';
import V360StateProbe from 'c/v360StateProbe';
import { getVisibleCards } from 'c/v360Service';

jest.mock('c/v360Service', () => ({
    getVisibleCards: jest.fn(),
    getVisibleCardsFresh: jest.fn()
}));

const flush = () => new Promise((res) => setTimeout(res, 0));

let nextRecordId = 700;
/** A fresh record per test: the store keeps one instance per recordId. */
function createProbe() {
    const element = createElement('c-v360-state-probe', { is: V360StateProbe });
    element.recordId = `00100000000${nextRecordId++}AAA`;
    document.body.appendChild(element);
    return element;
}

const entries = (element) => Array.from(element.shadowRoot.querySelectorAll('[data-id="log-entry"]'));
const actions = (element) =>
    entries(element).map((entry) => entry.querySelector('[data-id="log-action"]').textContent);

describe('c-v360-state-probe', () => {
    afterEach(() => {
        while (document.body.firstChild) {
            document.body.removeChild(document.body.firstChild);
        }
        jest.clearAllMocks();
    });

    it('logs its own mount, so the card is never blank on arrival', async () => {
        const element = createProbe();
        await flush();

        expect(actions(element)).toContain('mounted');
    });

    /**
     * The rule this card exists to demonstrate, and the one it broke first:
     * pressing a control must always leave a trace. Re-reading state in place
     * changes no number, so without a log entry the button looked broken --
     * which is exactly how it was reported.
     */
    it('leaves a log entry for every control, including the one that changes no number', async () => {
        getVisibleCards.mockResolvedValue([]);
        const element = createProbe();
        await flush();
        const before = entries(element).length;

        element.shadowRoot.querySelector('[data-id="read-store"]').click();
        await flush();

        expect(entries(element).length).toBe(before + 1);
        expect(actions(element)[0]).toBe('read the store');
    });

    it('reads the store without calling the server, and says so', async () => {
        const element = createProbe();
        await flush();

        element.shadowRoot.querySelector('[data-id="read-store"]').click();
        await flush();

        expect(getVisibleCards).not.toHaveBeenCalled();
        expect(entries(element)[0].querySelector('[data-id="log-detail"]').textContent).toContain(
            'Zero network calls'
        );
    });

    it('bills a direct call and reports the running total', async () => {
        getVisibleCards.mockResolvedValue([{ cardName: 'a' }, { cardName: 'b' }]);
        const element = createProbe();
        await flush();

        element.shadowRoot.querySelector('[data-id="direct-call"]').click();
        await flush();

        expect(getVisibleCards).toHaveBeenCalledTimes(1);
        expect(actions(element)[0]).toBe('called the server myself');
        expect(entries(element)[0].querySelector('[data-id="log-detail"]').textContent).toContain('2 card(s)');
    });

    it('reports a failed direct call rather than swallowing it', async () => {
        getVisibleCards.mockRejectedValue({ body: { message: 'no access' } });
        const element = createProbe();
        await flush();

        element.shadowRoot.querySelector('[data-id="direct-call"]').click();
        await flush();

        expect(actions(element)[0]).toBe('direct call failed');
        expect(entries(element)[0].querySelector('[data-id="log-detail"]').textContent).toContain('no access');
    });

    /**
     * Until the shell reports, the badge must not claim live updates work.
     * A failed subscription used to be indistinguishable from a working one,
     * which is what made "I activated a card and nothing happened"
     * unanswerable.
     */
    it('does not claim live updates before the shell has reported', async () => {
        const element = createProbe();
        await flush();

        expect(element.shadowRoot.querySelector('[data-id="live-badge"]').textContent).toBe(
            'Live updates not established'
        );
        expect(element.shadowRoot.querySelector('[data-id="live-note"]').textContent).toContain(
            'has not reported yet'
        );
    });

    it('clears the log on request without touching the page counters', async () => {
        const element = createProbe();
        await flush();
        const mountsBefore = element.shadowRoot
            .querySelector('[data-id="counter-value"][data-counter="mounts"]')
            .textContent.trim();

        element.shadowRoot.querySelector('[data-id="clear-log"]').click();
        await flush();

        expect(actions(element)).toEqual(['log cleared']);
        expect(
            element.shadowRoot
                .querySelector('[data-id="counter-value"][data-counter="mounts"]')
                .textContent.trim()
        ).toBe(mountsBefore);
    });
});
