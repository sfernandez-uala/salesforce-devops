/**
 * Minimal Jest-only stand-in for the bare `@salesforce/apex` module (as
 * opposed to a specific `@salesforce/apex/Controller.method` import, which
 * @salesforce/sfdx-lwc-jest already resolves). Only `refreshApex` is
 * exported here, since that is currently the only export Vista 360
 * components import from this specifier.
 */
export const refreshApex = jest.fn(() => Promise.resolve());
