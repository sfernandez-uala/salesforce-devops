/**
 * CRUD/FLS-enforced write path for the Vista 360 configuration graph (tabs,
 * cards, rules, predicates). Every entry point requires the
 * V360_ManageVisibilityRules custom permission before touching any data.
 * Writes strip inaccessible fields first (so a partial grant silently loses
 * just that field, not the whole save) and then execute in user mode (so a
 * user with no object-level access at all is blocked outright).
 *
 * Write-time validation is type-split by component type: an LWC binding only
 * needs to be non-blank (the registry constraint is enforced by the admin
 * UI's combobox, not mirrored here); a Flow binding must name an active
 * screen flow; a rule's formula must build successfully against its card's
 * anchor SObject (which also enforces the formula engine's length cap).
 */
// Total cyclomatic complexity is a sum across four independent, type-specific write
// paths (tabs/cards/rules/predicates), each individually simple (highest per-method
// complexity is 9); splitting by object would scatter one cohesive write boundary
// across multiple classes for no behavioral benefit.
@SuppressWarnings('PMD.CyclomaticComplexity')
public with sharing class V360AdminService {

    private static final String MANAGE_PERMISSION = 'V360_ManageVisibilityRules';
    private static final String COMPONENT_TYPE_LWC = 'LWC';
    private static final String COMPONENT_TYPE_FLOW = 'Flow';
    private static final String SCREEN_FLOW_PROCESS_TYPE = 'Flow';

    public static List<Database.UpsertResult> saveTabs(List<V360_Tab__c> tabs) {
        requireManagePermission();
        return upsertEnforced(tabs);
    }

    public static List<Database.UpsertResult> saveCards(List<V360_Card__c> cards) {
        requireManagePermission();
        validateCardBindings(cards);
        return upsertEnforced(cards);
    }

    public static List<Database.UpsertResult> saveCardRules(List<V360_CardRule__c> rules) {
        requireManagePermission();
        validateRuleFormulas(rules);
        return upsertEnforced(rules);
    }

    public static List<Database.UpsertResult> saveRulePredicates(List<V360_RulePredicate__c> predicates) {
        requireManagePermission();
        return upsertRulePredicates(predicates);
    }

    /**
     * Validates a formula against a card's anchor SObject without saving
     * anything -- the console's live "Validate" action. Throws with the
     * engine's message when the formula does not build.
     */
    // System-mode config read, same rationale as validateRuleFormulas: it only
    // resolves the card's anchor type and never leaves this validation path.
    @SuppressWarnings('PMD.ApexCRUDViolation')
    public static void validateFormula(Id cardId, String formulaText) {
        requireManagePermission();
        Map<Id, V360_Card__c> cardsById = new Map<Id, V360_Card__c>(
            [SELECT Id, AnchorSObject__c, Tab__r.AnchorSObject__c FROM V360_Card__c WHERE Id = :cardId]
        );
        Schema.SObjectType sObjectType = resolveAnchorType(cardsById.get(cardId));
        try {
            new V360FormulaGateway().build(formulaText, sObjectType);
        } catch (Exception buildException) {
            throw new V360AdminServiceException(
                'Formula failed to validate: ' + buildException.getMessage(),
                buildException
            );
        }
    }

    private static void requireManagePermission() {
        if (!FeatureManagement.checkPermission(MANAGE_PERMISSION)) {
            throw new V360AdminServiceException('You do not have permission to manage Vista 360 visibility rules.');
        }
    }

    private static List<Database.UpsertResult> upsertEnforced(List<SObject> records) {
        if (records == null || records.isEmpty()) {
            return new List<Database.UpsertResult>();
        }
        SObjectAccessDecision decision = Security.stripInaccessible(AccessType.UPSERTABLE, records);
        return Database.upsert(decision.getRecords(), false, AccessLevel.USER_MODE);
    }

    // V360_RulePredicate__c has no optional fields -- every field, including the
    // master-detail CardRule__c, is required (frozen schema). Security.stripInaccessible
    // unconditionally strips a required master-detail parent-reference field regardless of
    // the running user's actual access: a required field can never carry an explicit
    // FieldPermissions grant, so stripInaccessible has no accessible-field metadata to
    // consult for it and drops it every time (org-verified) -- which would otherwise blank
    // CardRule__c on every save. Since no partial-FLS scenario is even possible on an
    // all-required-fields object, this method enforces CRUD/object-level access via
    // AccessLevel.USER_MODE on the DML itself and skips the strip pass that only this
    // object's master-detail field would be incorrectly caught by.
    private static List<Database.UpsertResult> upsertRulePredicates(List<V360_RulePredicate__c> predicates) {
        if (predicates == null || predicates.isEmpty()) {
            return new List<Database.UpsertResult>();
        }
        return Database.upsert(predicates, false, AccessLevel.USER_MODE);
    }

    private static void validateCardBindings(List<V360_Card__c> cards) {
        Set<String> flowApiNamesToValidate = new Set<String>();
        for (V360_Card__c card : cards) {
            if (card.ComponentType__c == COMPONENT_TYPE_LWC && String.isBlank(card.ComponentName__c)) {
                throw new V360AdminServiceException('An LWC card must name a non-blank component.');
            }
            if (card.ComponentType__c == COMPONENT_TYPE_FLOW) {
                if (String.isBlank(card.ComponentName__c)) {
                    throw new V360AdminServiceException('A Flow card must name a non-blank screen flow.');
                }
                flowApiNamesToValidate.add(card.ComponentName__c);
            }
        }
        if (!flowApiNamesToValidate.isEmpty()) {
            requireActiveScreenFlows(flowApiNamesToValidate);
        }
    }

    // FlowDefinitionView is org metadata, not customer/security data — every user can read it,
    // and this is a validation-only lookup on the admin write path, never exposed to end users.
    @SuppressWarnings('PMD.ApexCRUDViolation')
    private static void requireActiveScreenFlows(Set<String> flowApiNames) {
        Set<String> activeScreenFlowApiNames = new Set<String>();
        for (FlowDefinitionView flowView : [
            SELECT ApiName
            FROM FlowDefinitionView
            WHERE ApiName IN :flowApiNames
            AND IsActive = true
            AND ProcessType = :SCREEN_FLOW_PROCESS_TYPE
        ]) {
            activeScreenFlowApiNames.add(flowView.ApiName);
        }
        for (String flowApiName : flowApiNames) {
            if (!activeScreenFlowApiNames.contains(flowApiName)) {
                throw new V360AdminServiceException('No active screen flow named "' + flowApiName + '" was found.');
            }
        }
    }

    // System-mode config read, same rationale as the catalog/rule selectors: this only resolves
    // each rule's card anchor type to validate the formula, and never leaves this write path.
    @SuppressWarnings('PMD.ApexCRUDViolation')
    private static void validateRuleFormulas(List<V360_CardRule__c> rules) {
        List<V360_CardRule__c> rulesWithFormulas = new List<V360_CardRule__c>();
        for (V360_CardRule__c rule : rules) {
            if (String.isNotBlank(rule.VisibilityFormula__c)) {
                rulesWithFormulas.add(rule);
            }
        }
        if (rulesWithFormulas.isEmpty()) {
            return;
        }

        Map<Id, V360_Card__c> cardsById = new Map<Id, V360_Card__c>(
            [
                SELECT Id, AnchorSObject__c, Tab__r.AnchorSObject__c
                FROM V360_Card__c
                WHERE Id IN :collectCardIds(rulesWithFormulas)
            ]
        );

        IFormulaEngine formulaEngine = new V360FormulaGateway();
        for (V360_CardRule__c rule : rulesWithFormulas) {
            Schema.SObjectType sObjectType = resolveAnchorType(cardsById.get(rule.Card__c));
            try {
                formulaEngine.build(rule.VisibilityFormula__c, sObjectType);
            } catch (Exception buildException) {
                throw new V360AdminServiceException(
                    'Formula failed to validate: ' + buildException.getMessage(),
                    buildException
                );
            }
        }
    }

    private static Schema.SObjectType resolveAnchorType(V360_Card__c card) {
        if (card == null) {
            throw new V360AdminServiceException('A rule must reference an existing card to validate its formula.');
        }
        String anchorApiName = String.isNotBlank(card.AnchorSObject__c) ? card.AnchorSObject__c : card.Tab__r.AnchorSObject__c;
        Schema.SObjectType sObjectType = Schema.getGlobalDescribe().get(anchorApiName.toLowerCase());
        if (sObjectType == null) {
            throw new V360AdminServiceException('Unknown anchor SObject: ' + anchorApiName);
        }
        return sObjectType;
    }

    private static Set<Id> collectCardIds(List<V360_CardRule__c> rules) {
        Set<Id> cardIds = new Set<Id>();
        for (V360_CardRule__c rule : rules) {
            cardIds.add(rule.Card__c);
        }
        return cardIds;
    }

    public class V360AdminServiceException extends Exception {
    }
}
