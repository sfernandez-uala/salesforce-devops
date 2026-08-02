import v360ShellState, {
    __resetV360ShellStateRegistryForTests
} from 'c/v360ShellState';

describe('c-v360-shell-state', () => {
    beforeEach(() => {
        sessionStorage.clear();
        __resetV360ShellStateRegistryForTests();
    });

    it('starts with no selected card, no open cards, no subtabs, and no header actions', () => {
        const state = v360ShellState('001000000000201AAA');

        expect(state.value.selectedCard).toBeNull();
        expect(state.value.openCards).toEqual([]);
        expect(state.value.subtabs).toEqual([]);
        expect(state.value.headerActions).toEqual({});
    });

    it('returns the same instance for the same recordId', () => {
        const first = v360ShellState('001000000000202AAA');
        const second = v360ShellState('001000000000202AAA');

        expect(first).toBe(second);
    });

    it('returns a different instance for a different recordId', () => {
        const first = v360ShellState('001000000000203AAA');
        const second = v360ShellState('001000000000204AAA');

        expect(first).not.toBe(second);
    });

    it('selecting a card marks it selected and adds it to openCards', () => {
        const state = v360ShellState('001000000000205AAA');

        state.value.selectCard('v360AccountSnapshot');

        expect(state.value.selectedCard).toBe('v360AccountSnapshot');
        expect(state.value.openCards).toEqual(['v360AccountSnapshot']);
    });

    it('opening a card without selecting it adds it to openCards but leaves selection untouched', () => {
        const state = v360ShellState('001000000000206AAA');

        state.value.selectCard('cardA');
        state.value.openCard('cardB');

        expect(state.value.selectedCard).toBe('cardA');
        expect(state.value.openCards).toEqual(['cardA', 'cardB']);
    });

    it('closing the selected card removes it from openCards and clears the selection', () => {
        const state = v360ShellState('001000000000207AAA');

        state.value.selectCard('v360AccountSnapshot');
        state.value.closeCard('v360AccountSnapshot');

        expect(state.value.selectedCard).toBeNull();
        expect(state.value.openCards).toEqual([]);
    });

    it('closing a non-selected open card leaves the current selection untouched', () => {
        const state = v360ShellState('001000000000208AAA');

        state.value.selectCard('cardA');
        state.value.openCard('cardB');
        state.value.closeCard('cardB');

        expect(state.value.selectedCard).toBe('cardA');
        expect(state.value.openCards).toEqual(['cardA']);
    });

    it('setSubtabs replaces the subtab list', () => {
        const state = v360ShellState('001000000000209AAA');

        state.value.setSubtabs(['overview', 'history']);

        expect(state.value.subtabs).toEqual(['overview', 'history']);
    });

    it('registerHeaderActions stores actions keyed by cardId without touching other cards', () => {
        const state = v360ShellState('001000000000210AAA');
        const actionsForA = [{ label: 'Refresh A' }];
        const actionsForB = [{ label: 'Refresh B' }];

        state.value.registerHeaderActions('cardA', actionsForA);
        state.value.registerHeaderActions('cardB', actionsForB);

        expect(state.value.headerActions.cardA).toBe(actionsForA);
        expect(state.value.headerActions.cardB).toBe(actionsForB);
    });

    it('persists selectedCard, openCards, and subtabs to sessionStorage keyed by recordId', () => {
        const state = v360ShellState('001000000000211AAA');

        state.value.selectCard('v360AccountSnapshot');
        state.value.setSubtabs(['overview']);

        const raw = sessionStorage.getItem('v360ShellState:001000000000211AAA');
        expect(JSON.parse(raw)).toEqual({
            selectedCard: 'v360AccountSnapshot',
            openCards: ['v360AccountSnapshot'],
            subtabs: ['overview']
        });
    });

    it('does not persist header actions (functions cannot be serialized)', () => {
        const state = v360ShellState('001000000000212AAA');

        state.value.registerHeaderActions('v360AccountSnapshot', [{ label: 'Refresh' }]);

        const raw = sessionStorage.getItem('v360ShellState:001000000000212AAA');
        expect(raw).toBeNull();
    });

    it('rehydrates a fresh instance for the same recordId from a previously persisted session', () => {
        const first = v360ShellState('001000000000213AAA');
        first.value.selectCard('v360AccountSnapshot');
        first.value.setSubtabs(['overview']);

        // Simulate a fresh page load: a clean module registry that must
        // rebuild its instance for this recordId from sessionStorage alone.
        __resetV360ShellStateRegistryForTests();

        const rehydrated = v360ShellState('001000000000213AAA');
        expect(rehydrated.value.selectedCard).toBe('v360AccountSnapshot');
        expect(rehydrated.value.openCards).toEqual(['v360AccountSnapshot']);
        expect(rehydrated.value.subtabs).toEqual(['overview']);
    });

    it('keeps sessions isolated between different recordIds', () => {
        const stateA = v360ShellState('001000000000214AAA');
        stateA.value.selectCard('cardA');
        stateA.value.setSubtabs(['overview']);

        const stateB = v360ShellState('001000000000215AAA');

        expect(stateB.value.selectedCard).toBeNull();
        expect(stateB.value.openCards).toEqual([]);
        expect(stateB.value.subtabs).toEqual([]);

        const rawA = sessionStorage.getItem('v360ShellState:001000000000214AAA');
        const rawB = sessionStorage.getItem('v360ShellState:001000000000215AAA');
        expect(JSON.parse(rawA).selectedCard).toBe('cardA');
        expect(rawB).toBeNull();
    });
});
