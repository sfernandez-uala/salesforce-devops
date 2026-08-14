/**
 * Read seam for the running user's live grants: Permission Set assignments,
 * Custom Permissions, Profile, and field-level security. Every check is resolved
 * live against the platform — nothing here is ever mirrored or cached into
 * stored configuration.
 *
 * Kept as a pure contract so the evaluation core can be unit-tested with a stub,
 * with no dependency on a connected org.
 */
public interface IUserContext {
    /**
     * @param apiName the Permission Set's API name
     * @return true when the running user is currently assigned that Permission Set
     */
    Boolean hasPermissionSet(String apiName);

    /**
     * @param apiName the Custom Permission's API name
     * @return true when the running user currently holds that Custom Permission
     */
    Boolean hasCustomPermission(String apiName);

    /**
     * @param profileName the Profile's name (never its record Id)
     * @return true when the running user's Profile matches the given name
     */
    Boolean hasProfile(String profileName);

    /**
     * @param sObjectApiName the SObject's API name the field belongs to
     * @param fieldApiName the field's API name
     * @return true when the running user currently has read access to that field
     */
    Boolean isFieldReadable(String sObjectApiName, String fieldApiName);
}
