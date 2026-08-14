import { createElement } from 'lwc';
import V360LifecycleDemo from 'c/v360LifecycleDemo';

function createDemo() {
    const element = createElement('c-v360-lifecycle-demo', { is: V360LifecycleDemo });
    element.recordId = '001000000000301AAA';
    document.body.appendChild(element);
    return element;
}

async function flushRender() {
    // Resolves pending microtasks without advancing the fake timers.
    await Promise.resolve();
}

describe('c-v360-lifecycle-demo', () => {
    beforeEach(() => {
        jest.useFakeTimers();
    });

    afterEach(() => {
        while (document.body.firstChild) {
            document.body.removeChild(document.body.firstChild);
        }
        jest.useRealTimers();
    });

    it('renders the skeleton stage while the simulated request is pending', () => {
        const element = createDemo();

        const skeleton = element.shadowRoot.querySelector('[data-id="skeleton-state"]');
        expect(skeleton).not.toBeNull();
        expect(skeleton.querySelectorAll('.v360-stencil-bar').length).toBeGreaterThan(0);
        expect(element.shadowRoot.querySelector('[data-id="error-state"]')).toBeNull();
    });

    it('shows the recoverable-error illustration once the simulated request fails', async () => {
        const element = createDemo();

        jest.runAllTimers();
        await flushRender();

        const errorState = element.shadowRoot.querySelector('[data-id="error-state"]');
        expect(errorState).not.toBeNull();
        expect(errorState.illustrationName).toBe('error:recoverable');
        expect(errorState.retryLabel).toBe('Retry');
        expect(element.shadowRoot.querySelector('[data-id="skeleton-state"]')).toBeNull();
    });

    it('returns to the skeleton stage on retry, then fails again', async () => {
        const element = createDemo();

        jest.runAllTimers();
        await flushRender();
        element.shadowRoot
            .querySelector('[data-id="error-state"]')
            .dispatchEvent(new CustomEvent('retry'));
        await flushRender();

        expect(element.shadowRoot.querySelector('[data-id="skeleton-state"]')).not.toBeNull();
        expect(element.shadowRoot.querySelector('[data-id="error-state"]')).toBeNull();

        jest.runAllTimers();
        await flushRender();

        expect(element.shadowRoot.querySelector('[data-id="error-state"]')).not.toBeNull();
    });

    it('exposes five header actions to exercise the shell overflow policy', () => {
        const element = createDemo();

        const actions = element.headerActions;
        expect(actions).toHaveLength(5);
        actions.forEach((action) => {
            expect(action.name).toEqual(expect.any(String));
            expect(action.label).toEqual(expect.any(String));
            expect(action.iconName).toEqual(expect.stringMatching(/^utility:/));
        });
    });

    it('restarts the simulation through the restart header action', async () => {
        const element = createDemo();

        jest.runAllTimers();
        await flushRender();
        expect(element.shadowRoot.querySelector('[data-id="error-state"]')).not.toBeNull();

        element.invokeHeaderAction('restart');
        await flushRender();

        expect(element.shadowRoot.querySelector('[data-id="skeleton-state"]')).not.toBeNull();
    });

    it('raises a toast when a demo header action is invoked', () => {
        const element = createDemo();
        const toastHandler = jest.fn();
        element.addEventListener('lightning__showtoast', toastHandler);

        element.invokeHeaderAction('demo-action-3');

        expect(toastHandler).toHaveBeenCalledTimes(1);
        expect(toastHandler.mock.calls[0][0].detail.title).toBe('Demo action 3');
    });

    it('clears the pending simulated request when removed from the DOM', () => {
        const element = createDemo();

        document.body.removeChild(element);
        jest.runAllTimers();

        expect(jest.getTimerCount()).toBe(0);
    });
});
