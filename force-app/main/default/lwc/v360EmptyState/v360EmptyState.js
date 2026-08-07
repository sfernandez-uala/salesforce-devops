import { LightningElement, api } from 'lwc';

/**
 * Thin wrapper around the platform's lightning-empty-state (Beta) base
 * component. Every Vista 360 component renders its empty/error/no-access
 * states through this wrapper instead of importing lightning-empty-state
 * directly, so a future change to that Beta component's API only needs to
 * be absorbed in one place.
 *
 * Consumers pass description content either as the `description` string
 * property, or by slotting their own markup into the default slot when
 * richer content is needed. Passing `retryLabel` renders a call-to-action
 * button that dispatches a `retry` event; consumers can also slot their own
 * buttons into the named `cta` slot (the platform component supports up to
 * two call-to-action buttons).
 */
export default class V360EmptyState extends LightningElement {
    @api title;
    @api illustrationName;
    @api size;
    @api alternativeText;
    @api description;
    @api retryLabel;

    /**
     * Draws the state on its own SLDS box. Off by default: most empty states
     * already sit inside a surface that owns the border, and boxing those
     * would double it. Turn it on where the state is the only thing in its
     * region and would otherwise read as floating.
     */
    @api boxed = false;

    get containerClass() {
        return this.boxed ? 'slds-box slds-box_small slds-theme_default' : '';
    }

    handleRetryClick() {
        this.dispatchEvent(new CustomEvent('retry'));
    }
}
