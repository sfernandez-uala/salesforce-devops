const { jestConfig } = require('@salesforce/sfdx-lwc-jest/config');

module.exports = {
    ...jestConfig,
    moduleNameMapper: {
        // The installed @salesforce/sfdx-lwc-jest version ships no built-in
        // stub for the Beta lightning-empty-state base component; map it to
        // a minimal local stand-in so components consuming it (via
        // c/v360EmptyState) can be unit tested.
        '^lightning/emptyState$': '<rootDir>/force-app/test/jest-mocks/lightning/emptyState/emptyState',
        // The bare `@salesforce/apex` specifier (distinct from a specific
        // `@salesforce/apex/Controller.method` import, which sfdx-lwc-jest
        // already resolves) has no built-in stub either; only `refreshApex`
        // is needed from it today.
        '^@salesforce/apex$': '<rootDir>/force-app/test/jest-mocks/apex/apex',
        // c/v360Styles is a CSS-only bundle (stylesheet + metadata, no
        // JavaScript — the documented shape for shared styles), so Jest's
        // resolver needs a direct pointer at the stylesheet.
        '^c/v360Styles$': '<rootDir>/force-app/main/default/lwc/v360Styles/v360Styles.css'
    }
};
