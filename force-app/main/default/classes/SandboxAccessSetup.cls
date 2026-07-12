/**
 * Assigns the org's developer permission sets to active dev users during
 * sandbox post-copy. Invoked from SandboxSetup (System.SandboxPostCopy), so it
 * runs in system context by design and intentionally operates in system mode —
 * CRUD enforcement is deliberately suppressed here, not overlooked.
 */
@SuppressWarnings('PMD.ApexCRUDViolation')
public without sharing class SandboxAccessSetup {
    // Real developer permission sets to auto-assign on sandbox copy.
    // Empty by default — populate with the org's actual dev permission sets.
    // While empty, assignDeveloperPermissionSets() is a safe no-op.
    private static final List<String> DEV_PERMISSION_SETS = new List<String>();

    public static void assignDeveloperPermissionSets() {
        List<PermissionSet> permSets = [
            SELECT Id, Name FROM PermissionSet
            WHERE Name IN :DEV_PERMISSION_SETS
        ];
        if (permSets.isEmpty()) {
            return;
        }

        List<User> developers = [
            SELECT Id FROM User
            WHERE IsActive = true
            AND Profile.UserLicense.LicenseDefinitionKey = 'SFDC'
        ];

        List<PermissionSetAssignment> existing = [
            SELECT PermissionSetId, AssigneeId
            FROM PermissionSetAssignment
            WHERE AssigneeId IN :developers
            AND PermissionSet.Name IN :DEV_PERMISSION_SETS
        ];

        Set<String> existingKeys = new Set<String>();
        for (PermissionSetAssignment psa : existing) {
            existingKeys.add(psa.AssigneeId + '-' + psa.PermissionSetId);
        }

        List<PermissionSetAssignment> toInsert = new List<PermissionSetAssignment>();
        for (User u : developers) {
            for (PermissionSet ps : permSets) {
                if (!existingKeys.contains(u.Id + '-' + ps.Id)) {
                    toInsert.add(new PermissionSetAssignment(
                        AssigneeId = u.Id,
                        PermissionSetId = ps.Id
                    ));
                }
            }
        }

        if (!toInsert.isEmpty()) {
            insert toInsert;
        }
    }
}
