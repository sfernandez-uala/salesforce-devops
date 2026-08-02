/**
 * Live grant resolution for the running user: nothing here is ever mirrored
 * or cached, every check hits the platform directly. Runs without sharing
 * because each check is self-scoped to the running user's own identity
 * (their own Permission Set assignments, their own Profile) rather than
 * another user's data, and must resolve correctly even though an ordinary
 * end user typically has no object permission on PermissionSetAssignment
 * or Profile.
 */
public without sharing class V360UserContext implements IUserContext {

    // Deliberately system-mode: this checks the running user's own assignment (self-scoped, no
    // cross-user exposure) and must work even though ordinary end users have no object permission
    // on PermissionSetAssignment.
    @SuppressWarnings('PMD.ApexCRUDViolation')
    public Boolean hasPermissionSet(String apiName) {
        if (String.isBlank(apiName)) {
            return false;
        }
        List<PermissionSetAssignment> assignments = [
            SELECT Id
            FROM PermissionSetAssignment
            WHERE AssigneeId = :UserInfo.getUserId()
            AND PermissionSet.Name = :apiName
            LIMIT 1
        ];
        return !assignments.isEmpty();
    }

    public Boolean hasCustomPermission(String apiName) {
        return String.isNotBlank(apiName) && FeatureManagement.checkPermission(apiName);
    }

    // Deliberately system-mode, same rationale as hasPermissionSet: resolving the running user's
    // own Profile name must work even without explicit object access to Profile.
    @SuppressWarnings('PMD.ApexCRUDViolation')
    public Boolean hasProfile(String profileName) {
        if (String.isBlank(profileName)) {
            return false;
        }
        List<Profile> profiles = [
            SELECT Id
            FROM Profile
            WHERE Id = :UserInfo.getProfileId()
            AND Name = :profileName
            LIMIT 1
        ];
        return !profiles.isEmpty();
    }

    public Boolean isFieldReadable(String sObjectApiName, String fieldApiName) {
        if (String.isBlank(sObjectApiName)) {
            return false;
        }
        Schema.SObjectType sObjType = Schema.getGlobalDescribe().get(sObjectApiName.toLowerCase());
        Schema.DescribeFieldResult fieldDescribe = V360FieldPathUtil.describeFieldPath(sObjType, fieldApiName);
        return fieldDescribe != null && fieldDescribe.isAccessible();
    }
}
