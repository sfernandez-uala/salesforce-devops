import v360CustomerState from 'c/v360CustomerState';
import { getVisibleCards, getVisibleCardsFresh } from 'c/v360Service';

jest.mock('c/v360Service', () => ({
    getVisibleCards: jest.fn(),
    getVisibleCardsFresh: jest.fn()
}));

/**
 * A promise this test can resolve/reject on demand, used to hold a service
 * call "in flight" long enough to prove concurrent loads share one call.
 */
function deferred() {
    let resolve;
    let reject;
    const promise = new Promise((res, rej) => {
        resolve = res;
        reject = rej;
    });
    return { promise, resolve, reject };
}

describe('c-v360-customer-state', () => {
    afterEach(() => {
        jest.clearAllMocks();
    });

    it('starts unconfigured with no data and no error', () => {
        const state = v360CustomerState('001000000000101AAA');

        expect(state.value.status).toBe('unconfigured');
        expect(state.value.data).toBeNull();
        expect(state.value.error).toBeNull();
    });

    it('returns the same instance for the same recordId', () => {
        const first = v360CustomerState('001000000000102AAA');
        const second = v360CustomerState('001000000000102AAA');

        expect(first).toBe(second);
    });

    it('returns a different instance for a different recordId', () => {
        const first = v360CustomerState('001000000000103AAA');
        const second = v360CustomerState('001000000000104AAA');

        expect(first).not.toBe(second);
    });

    it('loads visible cards through the cacheable service call and reaches loaded status', async () => {
        const mockDecisions = [{ cardName: 'v360AccountSnapshot' }];
        getVisibleCards.mockResolvedValue(mockDecisions);

        const state = v360CustomerState('001000000000105AAA');
        await state.value.load('AccountOverview');

        expect(state.value.status).toBe('loaded');
        expect(state.value.data).toBe(mockDecisions);
        expect(state.value.error).toBeNull();
        expect(getVisibleCards).toHaveBeenCalledTimes(1);
        expect(getVisibleCards).toHaveBeenCalledWith('001000000000105AAA', 'AccountOverview');
    });

    it('sets loading status synchronously while the service call is in flight', () => {
        const { promise } = deferred();
        getVisibleCards.mockReturnValue(promise);

        const state = v360CustomerState('001000000000106AAA');
        state.value.load('AccountOverview');

        expect(state.value.status).toBe('loading');
    });

    it('sets error status and keeps data null when the service call rejects', async () => {
        const apexError = new Error('boom');
        getVisibleCards.mockRejectedValue(apexError);

        const state = v360CustomerState('001000000000107AAA');
        await state.value.load('AccountOverview');

        expect(state.value.status).toBe('error');
        expect(state.value.error).toBe(apexError);
        expect(state.value.data).toBeNull();
    });

    it('dedupes concurrent loads for the same (recordId, tabApiName) into exactly one service call', async () => {
        const { promise, resolve } = deferred();
        getVisibleCards.mockReturnValue(promise);

        const state = v360CustomerState('001000000000108AAA');

        // Two concurrent loads for the identical (recordId, tabApiName) key,
        // neither awaited before the second is issued.
        const firstLoad = state.value.load('AccountOverview');
        const secondLoad = state.value.load('AccountOverview');

        expect(getVisibleCards).toHaveBeenCalledTimes(1);

        resolve([{ cardName: 'v360AccountSnapshot' }]);
        await Promise.all([firstLoad, secondLoad]);

        expect(getVisibleCards).toHaveBeenCalledTimes(1);
        expect(state.value.status).toBe('loaded');
    });

    it('does not dedupe loads for different tabApiName values on the same recordId', async () => {
        getVisibleCards.mockResolvedValue([]);

        const state = v360CustomerState('001000000000109AAA');

        await Promise.all([state.value.load('AccountOverview'), state.value.load('CreditCards')]);

        expect(getVisibleCards).toHaveBeenCalledTimes(2);
    });

    it('refresh() always calls the non-cacheable fresh service call, never the cacheable one', async () => {
        getVisibleCardsFresh.mockResolvedValue([{ cardName: 'v360AccountSnapshot' }]);

        const state = v360CustomerState('001000000000110AAA');
        await state.value.refresh('AccountOverview');

        expect(getVisibleCardsFresh).toHaveBeenCalledTimes(1);
        expect(getVisibleCardsFresh).toHaveBeenCalledWith('001000000000110AAA', 'AccountOverview');
        expect(getVisibleCards).not.toHaveBeenCalled();
        expect(state.value.status).toBe('loaded');
        expect(state.value.data).toEqual([{ cardName: 'v360AccountSnapshot' }]);
    });

    it('a load that starts while a refresh is in flight joins the refresh instead of issuing its own call', async () => {
        const { promise, resolve } = deferred();
        getVisibleCardsFresh.mockReturnValue(promise);
        getVisibleCards.mockResolvedValue([{ cardName: 'should-not-be-used' }]);

        const state = v360CustomerState('001000000000111AAA');

        const refreshCall = state.value.refresh('AccountOverview');
        const loadCall = state.value.load('AccountOverview');

        resolve([{ cardName: 'from-refresh' }]);
        await Promise.all([refreshCall, loadCall]);

        expect(getVisibleCardsFresh).toHaveBeenCalledTimes(1);
        expect(getVisibleCards).not.toHaveBeenCalled();
        expect(state.value.data).toEqual([{ cardName: 'from-refresh' }]);
    });
});
