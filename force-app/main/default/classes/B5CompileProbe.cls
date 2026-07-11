public with sharing class B5CompileProbe {
    // B5 gate probe: references a type that does NOT exist, so this file parses
    // cleanly (static-analysis/PMD passes) but FAILS to compile during the
    // delta-check-deploy validation. Must NEVER merge.
    public void run() {
        NonExistentType_XYZ.doWork();
    }
}
