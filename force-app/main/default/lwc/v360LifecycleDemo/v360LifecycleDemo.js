import { LightningElement, api } from 'lwc';

const SIMULATED_LATENCY_MS = 1600;

/**
 * Reference card for the lifecycle stage machine, with no data dependency:
 * every "request" is a simulated latency that always ends in a recoverable
 * error, so the SKELETON stage and the ERROR illustration with its retry
 * path are observable deterministically -- on any org, any record, any
 * user. v360AccountSnapshot remains the reference for a real data-backed
 * card; this one exists so the stages themselves can be demonstrated and
 * visually reviewed.
 *
 * Engine-agnostic like every card: recordId is accepted because the shell
 * passes it to all cards, but nothing here reads it and nothing is imported
 * from Vista 360.
 */
export default class V360LifecycleDemo extends LightningElement {
    @api recordId;

    requestFailed = false;
    timeoutId;

    connectedCallback() {
        this.startSimulatedRequest();
    }

    disconnectedCallback() {
        clearTimeout(this.timeoutId);
    }

    /**
     * Stands in for a card's real data request: pending for a realistic
     * beat (the SKELETON stage), then always failing (the ERROR stage).
     */
    startSimulatedRequest() {
        this.requestFailed = false;
        // eslint-disable-next-line @lwc/lwc/no-async-operation
        this.timeoutId = setTimeout(() => {
            this.requestFailed = true;
        }, SIMULATED_LATENCY_MS);
    }

    get isSkeleton() {
        return !this.requestFailed;
    }

    get hasError() {
        return this.requestFailed;
    }

    handleRetry() {
        this.startSimulatedRequest();
    }
}
