import v360CustomerState from 'c/v360CustomerState';
import { getVisibleCards } from 'c/v360Service';

jest.mock('c/v360Service', () => ({
    getVisibleCards: jest.fn(),
    getVisibleCardsFresh: jest.fn()
}));

const RECORD_ID = '001000000000801AAA';

describe('c/v360CustomerState — one record, several tabs', () => {
    afterEach(() => jest.clearAllMocks());

    /**
     * A record page can carry more than one Vista 360 tab, each pointed at its
     * own configured tab. The card list belongs to the pair, not to the record:
     * the in-flight dedupe map always keyed on both, while the instance
     * registry keyed on the record alone -- so the second tab's load overwrote
     * the first tab's cards, and the first shell, subscribed to that same
     * instance, re-rendered someone else's answer. Opening a three-card tab,
     * visiting a one-card tab and coming back showed one card.
     */
    it('keeps each tab of the same record on its own state', async () => {
        getVisibleCards.mockImplementation((recordId, tabApiName) =>
            Promise.resolve(
                tabApiName === 'AccountOverview'
                    ? [{ cardName: 'a' }, { cardName: 'b' }, { cardName: 'c' }]
                    : [{ cardName: 'z' }]
            )
        );

        const overview = v360CustomerState(RECORD_ID, 'AccountOverview');
        const risk = v360CustomerState(RECORD_ID, 'RiskReview');

        await overview.value.load('AccountOverview');
        await risk.value.load('RiskReview');

        expect(overview.value.data.map((card) => card.cardName)).toEqual(['a', 'b', 'c']);
        expect(risk.value.data.map((card) => card.cardName)).toEqual(['z']);
        expect(overview.value.tabApiName).toBe('AccountOverview');
        expect(risk.value.tabApiName).toBe('RiskReview');
    });

    /** The same pair still resolves to one instance — the dedupe still holds. */
    it('returns the same instance for the same record and tab', () => {
        expect(v360CustomerState(RECORD_ID, 'AccountOverview')).toBe(
            v360CustomerState(RECORD_ID, 'AccountOverview')
        );
    });

    /** And a different record is still a different instance. */
    it('keeps records apart', () => {
        expect(v360CustomerState(RECORD_ID, 'AccountOverview')).not.toBe(
            v360CustomerState('001000000000802AAA', 'AccountOverview')
        );
    });
});
