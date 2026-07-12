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
