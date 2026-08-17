/**
 * The objects a tab can be anchored on, so the admin console offers them
 * instead of asking for an API name from memory and answering at save time.
 *
 * Separate from V360RuleVocabulary on purpose. That class serves what a
 * visibility rule may reference and reads it with SOQL over setup objects;
 * this one serves what a surface may be anchored on and reads it from the
 * schema. Same instinct -- reference metadata, decides nothing -- but two
 * different sources, and folding them together would have put "rule" in the
 * name of something no rule ever asks for.
 */
public with sharing class V360SchemaVocabulary {

    /** One offerable object: what an admin reads, and what gets stored. */
    public class ObjectOption {
        @AuraEnabled
        public String label;
        @AuraEnabled
        public String apiName;
    }

    /**
     * Every object a Vista 360 tab can be anchored on, by label and API name.
     *
     * Behind the same manage-permission gate as the rest of the console: this
     * is a describe of the org's schema, which is not something to hand to a
     * user who cannot configure anything with it.
     *
     * @return the anchorable objects, ordered by label
     */
    @AuraEnabled(cacheable=true)
    public static List<ObjectOption> getAnchorObjectOptions() {
        try {
            List<ObjectOption> options = new List<ObjectOption>();
            if (!V360AdminService.hasManagePermission()) {
                return options;
            }
            // EntityDefinition rather than getGlobalDescribe. A tab is placed
            // on a record page, so the question is literally whether the object
            // has one, and IsLayoutable answers it -- Apex's own
            // DescribeSObjectResult has no equivalent.
            //
            // Matching on name endings was tried first and is wrong: the
            // companion tables to exclude are named AccountShare,
            // AccountHistory and AccountFeed, with no separator to key off, so
            // a suffix list either misses them or starts guessing at every
            // object whose name happens to end in the same letters.
            //
            // It also arrives already filtered by what the running user can
            // see, and carries the label, so one query replaces a describe of
            // every object in the org.
            for (EntityDefinition entity : [
                SELECT QualifiedApiName, Label
                FROM EntityDefinition
                WHERE IsLayoutable = TRUE AND IsQueryable = TRUE AND IsDeprecatedAndHidden = FALSE
                WITH USER_MODE
                ORDER BY Label
                LIMIT 2000
            ]) {
                options.add(option(entity.Label, entity.QualifiedApiName));
            }
            return options;
        } catch (Exception unexpected) {
            throw new AuraHandledException('Unable to read the objects in this org.');
        }
    }

    private static ObjectOption option(String label, String apiName) {
        ObjectOption objectOption = new ObjectOption();
        objectOption.label = label;
        objectOption.apiName = apiName;
        return objectOption;
    }
}
