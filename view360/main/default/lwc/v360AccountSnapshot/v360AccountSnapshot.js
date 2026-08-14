import { LightningElement, api, wire } from 'lwc';
import { refreshApex } from '@salesforce/apex';
import { getRecord, getFieldValue } from 'lightning/uiRecordApi';
import INDUSTRY_FIELD from '@salesforce/schema/Account.Industry';
import ANNUAL_REVENUE_FIELD from '@salesforce/schema/Account.AnnualRevenue';

const FIELDS = [INDUSTRY_FIELD, ANNUAL_REVENUE_FIELD];

/**
 * Minimal proof card for the Vista 360 vertical slice: shows a couple of
 * Account fields through the standard UI API record wire.
 *
 * Engine-agnostic by design: this component has zero awareness of Vista
 * 360's visibility engine, rules, or evaluator. It only knows how to render
 * whatever fields the UI API returns for the given recordId, and how to
 * degrade gracefully when a field is absent from that response -- the UI
 * API silently omits a field the running user cannot read rather than
 * erroring, which is what makes this card FLS-graceful with no rule
 * awareness of its own.
 *
 * Reference implementation of the card lifecycle stage machine (see
 * v360-design's SKILL.md for the full contract): a SKELETON stencil while
 * the wire has neither data nor error, the PRESENTATION view once data
 * arrives, an ERROR state on wire failure, and the OTHERS no-visible-fields
 * state when the record loads but every field was stripped by FLS. The
 * shell owns the earlier hydration/mounting stage on its own -- this card
 * only ever needs to reason about its own data.
 *
 * Also the reference implementation of the shell's optional header-actions
 * protocol: exposes a plain `@api get headerActions()` and
 * `@api invokeHeaderAction(name)` with no import from Vista 360's shell or
 * visibility engine, proving a card can offer header actions while staying
 * fully engine-agnostic.
 */
export default class V360AccountSnapshot extends LightningElement {
    @api recordId;

    @wire(getRecord, { recordId: '$recordId', fields: FIELDS })
    account;

    /** The one action this reference card proves the header-actions protocol with: re-running its own refreshApex path. */
    @api get headerActions() {
        return [{ name: 'refresh', label: 'Refresh', iconName: 'utility:refresh' }];
    }

    @api invokeHeaderAction(name) {
        if (name === 'refresh') {
            this.handleRetry();
        }
    }

    get hasError() {
        return Boolean(this.account?.error);
    }

    /** SKELETON stage: true while the wire is pending -- it has resolved neither data nor an error yet. */
    get isSkeleton() {
        return !this.account?.data && !this.hasError;
    }

    get industry() {
        return this.account?.data ? getFieldValue(this.account.data, INDUSTRY_FIELD) : undefined;
    }

    get hasIndustry() {
        return this.industry != null;
    }

    get annualRevenue() {
        return this.account?.data ? getFieldValue(this.account.data, ANNUAL_REVENUE_FIELD) : undefined;
    }

    get hasAnnualRevenue() {
        return this.annualRevenue != null;
    }

    get hasNoVisibleFields() {
        return Boolean(this.account?.data) && !this.hasIndustry && !this.hasAnnualRevenue;
    }

    handleRetry() {
        refreshApex(this.account);
    }
}
