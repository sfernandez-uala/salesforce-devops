/**
 * Builds the ONE dynamic, user-mode SOQL that reads exactly the anchor
 * record fields the tab's active rules need: the union of every formula's
 * referenced fields plus every FLS_READ predicate target. Runs with sharing
 * and WITH USER_MODE because the anchor record is the customer's own data —
 * unlike the system-mode catalog/rule selectors, the running user's real
 * CRUD/FLS and record-level sharing must apply here.
 *
 * A field that does not describe-validate (unknown, or more than one
 * relationship level deep) is simply left out of the query and reported as
 * an UNKNOWN_FIELD diagnostic for the rule it came from; the rule that
 * referenced it then fails closed naturally when the evaluator tries to
 * read a field the anchor record was never queried for.
 */
public with sharing class V360AnchorRecordSelector {

    /**
     * Everything one anchor-record resolution pass needs. Plain data holder:
     * construct empty and assign fields.
     */
    public class Request {
        public Id recordId;
        public String tabApiName;
        public String anchorSObjectApiName;
        public List<V360CardCatalogDTO> cards;
        public Map<Id, V360RuleGraph> ruleGraphsByCardId;
        public IFormulaEngine formulaEngine;
        public V360Diagnostics diagnostics;
    }

    /**
     * @param request the record/tab being evaluated plus every collaborator needed to
     *        discover, validate, and query the anchor record's field set
     * @return the anchor record populated with exactly the fields the rules need
     */
    public SObject resolveAnchorRecord(Request request) {
        if (request.recordId == null) {
            throw new V360AnchorRecordSelectorException('A record Id is required to resolve the anchor record.');
        }
        if (String.isBlank(request.anchorSObjectApiName)) {
            throw new V360AnchorRecordSelectorException('An anchor SObject API name is required.');
        }
        Schema.SObjectType anchorType = Schema.getGlobalDescribe().get(request.anchorSObjectApiName.toLowerCase());
        if (anchorType == null) {
            throw new V360AnchorRecordSelectorException('Unknown anchor SObject: ' + request.anchorSObjectApiName);
        }

        FieldCollectionContext ctx = new FieldCollectionContext(request, anchorType);
        collectFieldPaths(request.ruleGraphsByCardId, ctx);
        request.diagnostics.publishAll(ctx.unknownFieldEntries);

        return queryAnchorRecord(request.recordId, request.anchorSObjectApiName, ctx.fieldPaths);
    }

    // Object/field names in a dynamic SOQL string can never be bind variables — only values can.
    // Every name below is describe-validated before this method runs: the SObject type comes from
    // Schema.getGlobalDescribe(), and each field path is confirmed by V360FieldPathUtil against
    // that same type, so nothing unvalidated reaches this query string.
    @SuppressWarnings('PMD.ApexSOQLInjection')
    private SObject queryAnchorRecord(Id recordId, String anchorSObjectApiName, Set<String> fieldPaths) {
        String fieldList = fieldPaths.isEmpty() ? '' : ', ' + String.join(new List<String>(fieldPaths), ', ');
        String query = 'SELECT Id' + fieldList + ' FROM ' + anchorSObjectApiName
            + ' WHERE Id = :recordId WITH USER_MODE';
        List<SObject> results = Database.query(query);
        if (results.isEmpty()) {
            throw new V360AnchorRecordSelectorException('Anchor record not found or not readable: ' + recordId);
        }
        return results[0];
    }

    private void collectFieldPaths(Map<Id, V360RuleGraph> ruleGraphsByCardId, FieldCollectionContext ctx) {
        for (Id cardId : ruleGraphsByCardId.keySet()) {
            for (V360RuleGraph.RuleRow rule : ruleGraphsByCardId.get(cardId).rules) {
                if (!rule.active) {
                    continue;
                }
                collectFormulaFields(rule, cardId, ctx);
                collectPredicateFields(rule, cardId, ctx);
            }
        }
    }

    private void collectFormulaFields(V360RuleGraph.RuleRow rule, Id cardId, FieldCollectionContext ctx) {
        if (String.isBlank(rule.visibilityFormula)) {
            return;
        }
        Set<String> referencedFields;
        try {
            ctx.formulaEngine.build(rule.visibilityFormula, ctx.anchorType);
            referencedFields = ctx.formulaEngine.getReferencedFields();
        } catch (Exception buildException) {
            // An invalid formula surfaces as FORMULA_INVALID when the evaluator independently
            // builds this same formula during evaluation; nothing to gather here.
            return;
        }
        for (String fieldPath : referencedFields) {
            addOrReportField(fieldPath, cardId, ctx);
        }
    }

    private void collectPredicateFields(V360RuleGraph.RuleRow rule, Id cardId, FieldCollectionContext ctx) {
        for (V360RuleGraph.PredicateRow predicate : rule.predicates) {
            if (predicate.predicateType == V360PredicateEvaluator.FLS_READ) {
                addOrReportField(predicate.targetApiName, cardId, ctx);
            }
        }
    }

    private void addOrReportField(String fieldPath, Id cardId, FieldCollectionContext ctx) {
        if (V360FieldPathUtil.describeFieldPath(ctx.anchorType, fieldPath) != null) {
            ctx.fieldPaths.add(fieldPath);
        } else {
            ctx.unknownFieldEntries.add(ctx.unknownFieldEntry(cardId, fieldPath));
        }
    }

    /** Groups everything one resolution pass threads through its private helpers. */
    private class FieldCollectionContext {
        Id recordId;
        String tabApiName;
        Schema.SObjectType anchorType;
        IFormulaEngine formulaEngine;
        Map<Id, String> cardNamesById = new Map<Id, String>();
        Set<String> fieldPaths = new Set<String>();
        List<V360Diagnostics.Entry> unknownFieldEntries = new List<V360Diagnostics.Entry>();

        FieldCollectionContext(Request request, Schema.SObjectType anchorType) {
            this.recordId = request.recordId;
            this.tabApiName = request.tabApiName;
            this.anchorType = anchorType;
            this.formulaEngine = request.formulaEngine;
            for (V360CardCatalogDTO card : request.cards) {
                this.cardNamesById.put(card.cardId, card.developerName);
            }
        }

        V360Diagnostics.Entry unknownFieldEntry(Id cardId, String fieldPath) {
            V360Diagnostics.Entry entry = new V360Diagnostics.Entry();
            entry.recordId = this.recordId;
            entry.tabName = this.tabApiName;
            entry.cardName = this.cardNamesById.get(cardId);
            entry.reason = V360Diagnostics.Reason.UNKNOWN_FIELD;
            entry.detail = 'Field not usable in the anchor query (unknown, or deeper than one parent level): ' + fieldPath;
            return entry;
        }
    }

    public class V360AnchorRecordSelectorException extends Exception {
    }
}
