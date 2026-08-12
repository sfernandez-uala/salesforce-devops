import { getPinnedKeys, togglePin } from 'c/v360CardPreferences';

const TAB = 'AccountOverview';
const KEY = `v360PinnedCards:${TAB}`;

describe('c-v360-card-preferences', () => {
    afterEach(() => {
        window.localStorage.clear();
    });

    it('returns an empty set when nothing was ever pinned', () => {
        expect(getPinnedKeys(TAB)).toEqual([]);
    });

    it('persists a pin and removes it when toggled again', () => {
        expect(togglePin(TAB, 'cardA')).toEqual(['cardA']);
        expect(getPinnedKeys(TAB)).toEqual(['cardA']);

        expect(togglePin(TAB, 'cardA')).toEqual([]);
        expect(getPinnedKeys(TAB)).toEqual([]);
    });

    it('keeps pins from different tabs separate', () => {
        togglePin(TAB, 'cardA');
        togglePin('OtherTab', 'cardB');

        expect(getPinnedKeys(TAB)).toEqual(['cardA']);
        expect(getPinnedKeys('OtherTab')).toEqual(['cardB']);
    });

    it('degrades to nothing-pinned when the stored value is corrupted', () => {
        window.localStorage.setItem(KEY, '{not json');
        expect(getPinnedKeys(TAB)).toEqual([]);

        window.localStorage.setItem(KEY, '42');
        expect(getPinnedKeys(TAB)).toEqual([]);

        window.localStorage.setItem(KEY, '["ok", 7]');
        expect(getPinnedKeys(TAB)).toEqual(['ok']);
    });
});
