/**
 * Sole @salesforce/apex boundary for Vista 360. State managers are the only
 * callers of this module — cards and other UI code must never import
 * '@salesforce/apex/V360VisibilityController' directly.
 */
import getVisibleCardsApex from '@salesforce/apex/V360VisibilityController.getVisibleCards';
import getVisibleCardsFreshApex from '@salesforce/apex/V360VisibilityController.getVisibleCardsFresh';

/**
 * Cacheable read of the cards visible to the current user for a record's
 * tab. Safe to call repeatedly — the server-side method is cacheable, so
 * identical (recordId, tabApiName) requests can be served from the
 * platform's own cache.
 *
 * @param {string} recordId - the anchor record Id.
 * @param {string} tabApiName - the tab's developer name.
 * @returns {Promise<Array>} resolves to the visible card decisions.
 */
export function getVisibleCards(recordId, tabApiName) {
    return getVisibleCardsApex({ recordId, tabApiName });
}

/**
 * Non-cacheable escape hatch: forces a fresh server-side evaluation,
 * bypassing any client-side cache. Reserved for explicit refresh actions.
 *
 * @param {string} recordId - the anchor record Id.
 * @param {string} tabApiName - the tab's developer name.
 * @returns {Promise<Array>} resolves to the visible card decisions.
 */
export function getVisibleCardsFresh(recordId, tabApiName) {
    return getVisibleCardsFreshApex({ recordId, tabApiName });
}
