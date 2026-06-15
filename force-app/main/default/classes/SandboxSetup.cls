global class SandboxSetup implements System.SandboxPostCopy {
    global void runApexClass(System.SandboxContext context) {
        // 1) Sanitize — prevent emailing real customers from a sandbox
        SandboxDataSanitizer.scrambleEmails();

        // 2) Permission sets — make the sandbox dev-ready immediately
        SandboxAccessSetup.assignDeveloperPermissionSets();

        // 3) NOTE: NC secrets are injected by CI AFTER sandbox copy, not here.
        // Apex cannot fetch external vault secrets — callout needs a credential (chicken & egg).
    }
}
