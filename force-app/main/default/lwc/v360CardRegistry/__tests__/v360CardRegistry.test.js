import fs from 'fs';
import path from 'path';
import PipelineProbe from 'c/pipelineProbe';
import { resolve } from 'c/v360CardRegistry';

describe('c-v360-card-registry', () => {
    it('resolves a known component name to its constructor', () => {
        expect(resolve('pipelineProbe')).toBe(PipelineProbe);
    });

    it('returns null for an unknown component name', () => {
        expect(resolve('doesNotExist')).toBeNull();
    });

    it('returns null for a blank or missing component name', () => {
        expect(resolve('')).toBeNull();
        expect(resolve(undefined)).toBeNull();
    });

    it('never uses a dynamic import — every component is resolved through a static-import map', () => {
        const source = fs.readFileSync(
            path.resolve(__dirname, '..', 'v360CardRegistry.js'),
            'utf-8'
        );

        expect(source).not.toMatch(/import\s*\(/);
    });
});
