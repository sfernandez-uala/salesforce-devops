/**
 * The real values a visibility rule can be built from, so the rule editor
 * offers them instead of asking an admin to type an API name from memory and
 * find out at validation time.
 *
 * Split out of V360AdminController because this reads reference metadata and
 * decides nothing: no card is created, activated or saved here. The controller
 * had grown past the complexity gate carrying it, which was the prompt, but
 * the seam was already there — nothing in this class knows what a card is.
 *
 * The two lists it serves are deliberately separate. A formula cannot read
 * Permission Set membership at all; that is what the PERMISSION_SET predicate
 * exists for. Serving them together would blur the one distinction that
 * decides which mechanism an admin should reach for.
 */
public with sharing class V360RuleVocabulary {

    /** One offerable value: what to show, what to insert, what it is called. */
    public class Entry {
        @AuraEnabled
        public String label;
        @AuraEnabled
        public String insertText;
        @AuraEnabled
        public String apiName;
    }

    /** The identity globals a formula may reference, grouped by kind. */
    public class FormulaVocabulary {
        @AuraEnabled
        public List<Entry> customPermissions = new List<Entry>();
        @AuraEnabled
        public List<Entry> profiles = new List<Entry>();
    }

    /**
     * The identity vocabulary a visibility formula may reference.
     *
     * Only what V360FormulaGateway actually enables is served. Its four globals
     * are Custom Permission, Profile, User and User Role — and $Permission is a
     * Custom Permission, not a Permission Set.
     *
     * User and User Role fields are deliberately absent: the UI API's
     * getObjectInfo already describes them client-side, so routing them through
     * Apex would add a round trip and a second source of truth.
     *
     * @return the queryable identity values, each already formatted as the
     *         merge field a formula would carry
     */
    @AuraEnabled(cacheable=true)
    public static FormulaVocabulary getFormulaVocabulary() {
        try {
            FormulaVocabulary vocabulary = new FormulaVocabulary();
            // The server is the authority on the manage permission, and an
            // unpermitted caller gets empty lists rather than an error, because
            // the console already renders its access state from getCatalog.
            if (!V360AdminService.hasManagePermission()) {
                return vocabulary;
            }
            for (CustomPermission permission : [
                SELECT DeveloperName, MasterLabel
                FROM CustomPermission
                WITH USER_MODE
                ORDER BY MasterLabel
                LIMIT 2000
            ]) {
                vocabulary.customPermissions.add(
                    entry(permission.MasterLabel, '$Permission.' + permission.DeveloperName, permission.DeveloperName)
                );
            }
            for (Profile userProfile : [SELECT Name FROM Profile WITH USER_MODE ORDER BY Name LIMIT 2000]) {
                // Quoted because a profile name carries spaces; unquoted it
                // would not build.
                vocabulary.profiles.add(
                    entry(userProfile.Name, '$Profile.Name = "' + userProfile.Name + '"', userProfile.Name)
                );
            }
            return vocabulary;
        } catch (Exception unexpected) {
            throw new AuraHandledException('Unable to read the formula vocabulary.');
        }
    }

    /**
     * The permission sets a PERMISSION_SET predicate can require.
     *
     * Profile-owned permission sets are excluded — they are the platform's own
     * per-profile containers, not something anyone assigns.
     *
     * Each one is reported namespace-qualified, because Name is unique only
     * within a namespace: cloning a packaged permission set produces a local
     * one carrying the same Name, and two entries sharing an identifier are
     * both unrenderable in a list and unresolvable at evaluation time.
     * c/V360UserContext.hasPermissionSet reads the same qualified form back.
     *
     * @return every assignable permission set, by namespace-qualified API name
     */
    @AuraEnabled(cacheable=true)
    public static List<Entry> getPermissionSetOptions() {
        try {
            List<Entry> options = new List<Entry>();
            if (!V360AdminService.hasManagePermission()) {
                return options;
            }
            for (PermissionSet permissionSet : [
                SELECT Name, Label, NamespacePrefix
                FROM PermissionSet
                WHERE IsOwnedByProfile = false
                WITH USER_MODE
                ORDER BY Label
                LIMIT 2000
            ]) {
                // An absent prefix leaves the separator stranded at the front,
                // where removing it yields the bare Name -- so both forms come
                // out of one expression rather than a branch.
                String apiName = ((permissionSet.NamespacePrefix ?? '') + '__' + permissionSet.Name)
                    .removeStart('__');
                options.add(entry(permissionSet.Label, apiName, apiName));
            }
            return options;
        } catch (Exception unexpected) {
            throw new AuraHandledException('Unable to read the permission sets.');
        }
    }

    private static Entry entry(String label, String insertText, String apiName) {
        Entry vocabularyEntry = new Entry();
        vocabularyEntry.label = label;
        vocabularyEntry.insertText = insertText;
        vocabularyEntry.apiName = apiName;
        return vocabularyEntry;
    }
}
