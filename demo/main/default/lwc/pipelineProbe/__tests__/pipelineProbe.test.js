import { createElement } from 'lwc';
import PipelineProbe from 'c/pipelineProbe';

describe('c-pipeline-probe', () => {
    afterEach(() => {
        while (document.body.firstChild) {
            document.body.removeChild(document.body.firstChild);
        }
    });

    it('renders the pipeline lifecycle probe message', () => {
        const element = createElement('c-pipeline-probe', {
            is: PipelineProbe
        });
        document.body.appendChild(element);

        const p = element.shadowRoot.querySelector('p');
        expect(p.textContent).toBe('C3 pipeline lifecycle probe');
    });
});
