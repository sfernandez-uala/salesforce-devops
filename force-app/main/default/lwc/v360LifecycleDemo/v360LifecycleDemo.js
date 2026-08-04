import { LightningElement, api } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';

const SIMULATED_LATENCY_MS = 1600;

// Five actions on purpose: enough to exercise the shell's inline-plus-
// overflow header policy (two stay inline, the rest collapse into a menu).
// Restart is functional; the numbered ones prove the invocation reaches
// the card by raising a toast.
const DEMO_ACTIONS = [
    { name: 'restart', label: 'Restart demo', iconName: 'utility:refresh' },
    { name: 'demo-action-2', label: 'Demo action 2', iconName: 'utility:announcement' },
    { name: 'demo-action-3', label: 'Demo action 3', iconName: 'utility:favorite' },
    { name: 'demo-action-4', label: 'Demo action 4', iconName: 'utility:bookmark' },
    { name: 'demo-action-5', label: 'Demo action 5', iconName: 'utility:world' }
];

/**
 * Reference card for the lifecycle stage machine, with no data dependency:
 * every "request" is a simulated latency that always ends in a recoverable
 * error, so the SKELETON stage and the ERROR illustration with its retry
 * path are observable deterministically -- on any org, any record, any
 * user. It also exposes five header actions, making it the living
 * demonstration of the shell's action overflow policy.
 * v360AccountSnapshot remains the reference for a real data-backed card;
 * this one exists so the stages and the shell contracts can be
 * demonstrated and visually reviewed.
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

    @api get headerActions() {
        return DEMO_ACTIONS;
    }

    @api invokeHeaderAction(name) {
        if (name === 'restart') {
            this.startSimulatedRequest();
            return;
        }
        const action = DEMO_ACTIONS.find((candidate) => candidate.name === name);
        if (action) {
            this.dispatchEvent(
                new ShowToastEvent({
                    title: action.label,
                    message: 'Header action invoked on the card.',
                    variant: 'info'
                })
            );
        }
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
