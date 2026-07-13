/**
 * SandboxPostCopy entry point: prepares a freshly copied sandbox (sanitize data,
 * assign dev permission sets). Must be `global` — the System.SandboxPostCopy
 * interface requires a global class and method, so AvoidGlobalModifier is
 * suppressed here by necessity, not by choice.
 */
@SuppressWarnings('PMD.AvoidGlobalModifier')
global class SandboxSetup implements System.SandboxPostCopy {
    global void runApexClass(System.SandboxContext context) {
        // 1) Sanitize — prevent emailing real customers from a sandbox
        SandboxDataSanitizer.scrambleEmails();

        // 2) Permission sets — make the sandbox dev-ready immediately
        SandboxAccessSetup.assignDeveloperPermissionSets();

        // 3) NOTE: External Credential secrets are NOT set here. Apex cannot fetch
        // external vault secrets, and a callout needs a credential first (chicken &
        // egg). Set them out-of-band after copy — manually in Setup, or via a
        // dedicated secret-injection step with real secret names at the org cutover.
    }
}

// upload-sarif@v4 validation probe (PR closed, never merged).
