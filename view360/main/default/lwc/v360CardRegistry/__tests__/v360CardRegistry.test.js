import fs from 'fs';
import path from 'path';
import V360AccountSnapshot from 'c/v360AccountSnapshot';
import { has, load } from 'c/v360CardRegistry';

describe('c-v360-card-registry', () => {
    it('knows its registered component names', () => {
        expect(has('v360AccountSnapshot')).toBe(true);
    });

    /**
     * The decoupling this package depends on: naming a component here obliges
     * every org receiving this file to have it, and Salesforce enforces that
     * at deploy time. So nothing from the demo package directory may appear.
     */
    it('names nothing from the demo package directory', () => {
        expect(has('pipelineProbe')).toBe(false);
        expect(has('v360LifecycleDemo')).toBe(false);
        expect(has('v360StateProbe')).toBe(false);
    });

    it('does not know unknown, blank, or missing component names', () => {
        expect(has('doesNotExist')).toBe(false);
        expect(has('')).toBe(false);
        expect(has(undefined)).toBe(false);
    });

    it('loads a known component name to its constructor', async () => {
        await expect(load('v360AccountSnapshot')).resolves.toBe(V360AccountSnapshot);
    });

    it('loads consistently on repeated calls (memoized)', async () => {
        const first = await load('v360AccountSnapshot');
        const second = await load('v360AccountSnapshot');
        expect(second).toBe(first);
    });

    it('resolves null for an unknown component name', async () => {
        await expect(load('doesNotExist')).resolves.toBeNull();
    });

    it('never uses a dynamic import — every component is resolved through a static-import map', () => {
        const source = fs.readFileSync(
            path.resolve(__dirname, '..', 'v360CardRegistry.js'),
            'utf-8'
        );

        expect(source).not.toMatch(/import\s*\(/);
    });
});
