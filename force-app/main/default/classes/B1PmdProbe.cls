public with sharing class B1PmdProbe {
    // Intentional PMD violation for gate test B1: `unusedLocal` is assigned but
    // never read -> pmd:UnusedLocalVariable (Moderate, severity 3), which must
    // trip the static-analysis gate (severity-threshold 3). This class must
    // NEVER merge; the branch is deleted after the gate fails as expected.
    public Integer compute() {
        Integer unusedLocal = 42;
        return 1;
    }
}
