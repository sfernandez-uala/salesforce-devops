/**
 * Pure, side-effect-free helpers for resolving a formula or predicate field
 * path (a direct field, or exactly one level of parent-relationship
 * traversal, e.g. "Parent.Name") against Schema describes. Shared by every
 * class that needs to validate or resolve such a path against an anchor
 * SObject type, so the one-level-only rule lives in exactly one place.
 */
public class V360FieldPathUtil {

    // Intentionally empty: a private no-arg constructor is the standard idiom to prevent
    // instantiation of a static-only utility class.
    @SuppressWarnings('PMD.EmptyStatementBlock')
    private V360FieldPathUtil() {
    }

    /**
     * @param sObjType the SObject type the path starts from
     * @param fieldPath a direct field name, or a one-level parent path like "Parent.Name"
     * @return the target field's describe result, or null when the path is unknown,
     *         blank, or more than one relationship level deep
     */
    public static Schema.DescribeFieldResult describeFieldPath(Schema.SObjectType sObjType, String fieldPath) {
        if (sObjType == null || String.isBlank(fieldPath)) {
            return null;
        }
        List<String> segments = fieldPath.split('\\.');
        if (segments.size() == 1) {
            return describeField(sObjType, segments[0]);
        }
        if (segments.size() == 2) {
            Schema.SObjectType parentType = describeParentType(sObjType, segments[0]);
            return parentType == null ? null : describeField(parentType, segments[1]);
        }
        return null;
    }

    private static Schema.DescribeFieldResult describeField(Schema.SObjectType sObjType, String fieldApiName) {
        Schema.SObjectField field = sObjType.getDescribe().fields.getMap().get(fieldApiName.toLowerCase());
        return field == null ? null : field.getDescribe();
    }

    private static Schema.SObjectType describeParentType(Schema.SObjectType sObjType, String relationshipName) {
        for (Schema.SObjectField field : sObjType.getDescribe().fields.getMap().values()) {
            Schema.DescribeFieldResult fieldDescribe = field.getDescribe();
            List<Schema.SObjectType> referenceTo = fieldDescribe.getReferenceTo();
            if (relationshipName.equalsIgnoreCase(fieldDescribe.getRelationshipName()) && !referenceTo.isEmpty()) {
                return referenceTo[0];
            }
        }
        return null;
    }
}
