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
 */
export default class V360AccountSnapshot extends LightningElement {
    @api recordId;

    @wire(getRecord, { recordId: '$recordId', fields: FIELDS })
    account;

    get hasError() {
        return Boolean(this.account?.error);
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
