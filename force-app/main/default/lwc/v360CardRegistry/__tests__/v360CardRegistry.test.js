import fs from 'fs';
import path from 'path';
import PipelineProbe from 'c/pipelineProbe';
import V360AccountSnapshot from 'c/v360AccountSnapshot';
import { has, load } from 'c/v360CardRegistry';

describe('c-v360-card-registry', () => {
    it('knows its registered component names', () => {
        expect(has('pipelineProbe')).toBe(true);
        expect(has('v360AccountSnapshot')).toBe(true);
    });

    it('does not know unknown, blank, or missing component names', () => {
        expect(has('doesNotExist')).toBe(false);
        expect(has('')).toBe(false);
        expect(has(undefined)).toBe(false);
    });

    it('loads a known component name to its constructor', async () => {
        await expect(load('pipelineProbe')).resolves.toBe(PipelineProbe);
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
