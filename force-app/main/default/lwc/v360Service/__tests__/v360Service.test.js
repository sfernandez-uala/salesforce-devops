import { getVisibleCards, getVisibleCardsFresh } from 'c/v360Service';
import getVisibleCardsApex from '@salesforce/apex/V360VisibilityController.getVisibleCards';
import getVisibleCardsFreshApex from '@salesforce/apex/V360VisibilityController.getVisibleCardsFresh';

jest.mock(
    '@salesforce/apex/V360VisibilityController.getVisibleCards',
    () => ({ default: jest.fn() }),
    { virtual: true }
);
jest.mock(
    '@salesforce/apex/V360VisibilityController.getVisibleCardsFresh',
    () => ({ default: jest.fn() }),
    { virtual: true }
);

describe('c-v360-service', () => {
    afterEach(() => {
        jest.clearAllMocks();
    });

    it('wraps the cacheable getVisibleCards Apex method with a params object', async () => {
        const mockDecisions = [{ cardName: 'v360AccountSnapshot' }];
        getVisibleCardsApex.mockResolvedValue(mockDecisions);

        const result = await getVisibleCards('001000000000001AAA', 'AccountOverview');

        expect(getVisibleCardsApex).toHaveBeenCalledTimes(1);
        expect(getVisibleCardsApex).toHaveBeenCalledWith({
            recordId: '001000000000001AAA',
            tabApiName: 'AccountOverview'
        });
        expect(result).toBe(mockDecisions);
    });

    it('wraps the non-cacheable getVisibleCardsFresh Apex method with a params object', async () => {
        const mockDecisions = [];
        getVisibleCardsFreshApex.mockResolvedValue(mockDecisions);

        const result = await getVisibleCardsFresh('001000000000001AAA', 'AccountOverview');

        expect(getVisibleCardsFreshApex).toHaveBeenCalledTimes(1);
        expect(getVisibleCardsFreshApex).toHaveBeenCalledWith({
            recordId: '001000000000001AAA',
            tabApiName: 'AccountOverview'
        });
        expect(result).toBe(mockDecisions);
    });

    it('never calls the non-cacheable method from the cacheable wrapper', async () => {
        getVisibleCardsApex.mockResolvedValue([]);

        await getVisibleCards('001000000000001AAA', 'AccountOverview');

        expect(getVisibleCardsFreshApex).not.toHaveBeenCalled();
    });

    it('propagates a rejection from the cacheable call unchanged', async () => {
        const apexError = new Error('boom');
        getVisibleCardsApex.mockRejectedValue(apexError);

        await expect(getVisibleCards('001000000000001AAA', 'AccountOverview')).rejects.toBe(
            apexError
        );
    });
});
