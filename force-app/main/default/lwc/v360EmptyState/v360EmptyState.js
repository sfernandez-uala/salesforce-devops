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

    handleRetryClick() {
        this.dispatchEvent(new CustomEvent('retry'));
    }
}
