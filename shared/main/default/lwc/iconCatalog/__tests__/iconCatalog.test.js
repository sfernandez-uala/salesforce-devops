import { getCategories } from 'c/iconCatalog';

describe('c/iconCatalog', () => {
    it('returns the five SLDS icon categories, each with names', () => {
        const categories = getCategories();

        expect(categories.map((category) => category.key)).toEqual([
            'standard',
            'utility',
            'action',
            'custom',
            'doctype'
        ]);
        categories.forEach((category) => {
            expect(category.icons.length).toBeGreaterThan(0);
        });
    });

    it('carries no duplicate names within a category', () => {
        getCategories().forEach((category) => {
            expect(new Set(category.icons).size).toBe(category.icons.length);
        });
    });

    it('includes icons this codebase already relies on', () => {
        const byKey = Object.fromEntries(getCategories().map((category) => [category.key, category.icons]));

        expect(byKey.standard).toContain('account');
        expect(byKey.standard).toContain('default');
        expect(byKey.standard).toContain('customer_360');
        expect(byKey.utility).toContain('refresh');
        expect(byKey.utility).toContain('screen');
    });
});
