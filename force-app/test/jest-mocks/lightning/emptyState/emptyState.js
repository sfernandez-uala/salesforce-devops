import { LightningElement, api } from 'lwc';

/**
 * Minimal Jest-only stand-in for the platform's lightning-empty-state
 * (Beta) base component, which the installed @salesforce/sfdx-lwc-jest
 * version does not ship a built-in stub for. Mirrors just enough of the
 * real component's public shape (attributes plus the description/cta
 * slots) so consumers of c/v360EmptyState can exercise real slotting
 * behavior in tests without depending on the actual Beta implementation.
 */
export default class EmptyState extends LightningElement {
    @api title;
    @api illustrationName;
    @api size;
    @api alternativeText;
}
