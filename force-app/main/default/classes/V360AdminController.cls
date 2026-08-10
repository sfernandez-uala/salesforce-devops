/**
 * The thin @AuraEnabled boundary for the Vista 360 admin console. It
 * reports whether the running user holds the manage permission and, when
 * they do, returns the configuration graph (tabs, their cards, and each
 * card's rules) for the console to browse and edit.
 *
 * All reads run in user mode: the admin console is a real-access surface
 * for users granted the V360_Admin permission set, never a trusted
 * mediator like the end-user visibility read path.
 */
// The class-total complexity is a sum across many independently simple
// @AuraEnabled entry points and DTO mappers (highest per-method complexity
// is 6); splitting the console's one boundary across classes would scatter
// it for no behavioral benefit.
@SuppressWarnings('PMD.CyclomaticComplexity')
public with sharing class V360AdminController {

    /**
     * Loads the whole configuration graph for the console. The permission
     * verdict always comes back; the data comes back only when the running
     * user holds the manage permission.
     *
     * @return the permission verdict plus every tab with its cards and rules
     */
    // The console browses the entire configuration graph by design, and its
    // volume is config-scale (a handful of tabs and cards per org), so an
    // unrestricted read is the intended semantics, not an oversight.
    @SuppressWarnings('PMD.AvoidNonRestrictiveQueries')
    @AuraEnabled
    public static AdminCatalog getCatalog() {
        try {
            AdminCatalog catalog = new AdminCatalog();
            catalog.hasManagePermission = V360AdminService.hasManagePermission();
            catalog.tabs = new List<AdminTab>();
            if (!catalog.hasManagePermission) {
                return catalog;
            }
            Map<Id, List<AdminRule>> rulesByCardId = loadRulesByCard();
            for (V360_Tab__c tab : [
                SELECT
                    Id,
                    DeveloperName__c,
                    AnchorSObject__c,
                    Sequence__c,
                    (
                        SELECT
                            Id,
                            DeveloperName__c,
                            Label__c,
                            Description__c,
                            ComponentType__c,
                            ComponentName__c,
                            IconName__c,
                            ButtonLabel__c,
                            Order__c,
                            Active__c,
                            KillSwitch__c,
                            RuleMatchLogic__c
                        FROM V360_Cards__r
                        ORDER BY Order__c NULLS LAST, DeveloperName__c
                    )
                FROM V360_Tab__c
                WITH USER_MODE
                ORDER BY Sequence__c NULLS LAST, DeveloperName__c
            ]) {
                catalog.tabs.add(toAdminTab(tab, rulesByCardId));
            }
            return catalog;
        } catch (Exception unexpected) {
            throw new AuraHandledException('Unable to load the Vista 360 configuration.');
        }
    }

    /**
     * Saves the card's presentation and component binding. Routed through
     * V360AdminService, so the manage-permission gate, CRUD/FLS enforcement,
     * and binding validation (registry-fed LWC names, active screen flows)
     * all apply.
     *
     * @param input the card id plus every editable property
     */
    @AuraEnabled
    public static void saveCardProperties(CardPropertiesInput input) {
        try {
            V360AdminService.saveCards(
                new List<V360_Card__c>{
                    new V360_Card__c(
                        Id = input.cardId,
                        Label__c = input.label,
                        Description__c = input.description,
                        IconName__c = input.iconName,
                        ButtonLabel__c = input.buttonLabel,
                        ComponentType__c = input.componentType,
                        ComponentName__c = input.componentName
                    )
                }
            );
        } catch (V360AdminService.V360AdminServiceException adminError) {
            throw new AuraHandledException(adminError.getMessage());
        } catch (Exception unexpected) {
            throw new AuraHandledException('Unable to save the card.');
        }
    }

    /**
     * Creates or updates a tab. The anchor SObject is validated to resolve
     * to a real object before anything is written.
     *
     * @param input the tab id (blank to create) plus every editable property
     */
    @AuraEnabled
    public static void saveTab(TabInput input) {
        try {
            V360AdminService.saveTabs(
                new List<V360_Tab__c>{
                    new V360_Tab__c(
                        Id = input.tabId,
                        DeveloperName__c = input.developerName,
                        AnchorSObject__c = input.sObjectApiName,
                        Sequence__c = input.sequence
                    )
                }
            );
        } catch (V360AdminService.V360AdminServiceException adminError) {
            throw new AuraHandledException(adminError.getMessage());
        } catch (Exception unexpected) {
            throw new AuraHandledException('Unable to save the tab.');
        }
    }

    /**
     * Deletes a tab; a tab that still has cards is rejected with a clear
     * message.
     *
     * @param tabId the tab to delete
     */
    @AuraEnabled
    public static void deleteTab(Id tabId) {
        try {
            V360AdminService.deleteTabs(new Set<Id>{ tabId });
        } catch (V360AdminService.V360AdminServiceException adminError) {
            throw new AuraHandledException(adminError.getMessage());
        } catch (Exception unexpected) {
            throw new AuraHandledException('Unable to delete the tab.');
        }
    }

    /**
     * Creates a card as a draft: inactive, invisible to end users until an
     * admin activates it. The binding is validated the same way as an edit.
     *
     * @param input the tab, developer name, and every editable property
     */
    @AuraEnabled
    public static void createCard(NewCardInput input) {
        try {
            V360AdminService.saveCards(
                new List<V360_Card__c>{
                    new V360_Card__c(
                        Tab__c = input.tabId,
                        DeveloperName__c = input.developerName,
                        Label__c = input.label,
                        Description__c = input.description,
                        IconName__c = input.iconName,
                        ButtonLabel__c = input.buttonLabel,
                        ComponentType__c = input.componentType,
                        ComponentName__c = input.componentName,
                        Order__c = input.order,
                        Active__c = false,
                        KillSwitch__c = false
                    )
                }
            );
        } catch (V360AdminService.V360AdminServiceException adminError) {
            throw new AuraHandledException(adminError.getMessage());
        } catch (Exception unexpected) {
            throw new AuraHandledException('Unable to create the card.');
        }
    }

    /**
     * Creates a visibility rule for a card; a non-blank formula is built
     * against the card's anchor SObject before anything is written.
     *
     * @param cardId the card the rule belongs to
     * @param developerName the rule's stable unique name
     * @param formulaText the visibility formula, optional
     */
    @AuraEnabled
    public static void createRule(Id cardId, String developerName, String formulaText) {
        try {
            V360AdminService.saveCardRules(
                new List<V360_CardRule__c>{
                    new V360_CardRule__c(
                        Card__c = cardId,
                        DeveloperName__c = developerName,
                        VisibilityFormula__c = formulaText,
                        Active__c = true
                    )
                }
            );
        } catch (V360AdminService.V360AdminServiceException adminError) {
            throw new AuraHandledException(adminError.getMessage());
        } catch (Exception unexpected) {
            throw new AuraHandledException('Unable to create the rule.');
        }
    }

    /**
     * Adds a structured predicate to a rule.
     *
     * @param ruleId the rule the predicate belongs to
     * @param predicateType PERMISSION_SET or FLS_READ
     * @param targetApiName the permission set or field the predicate checks
     */
    @AuraEnabled
    public static void addRulePredicate(Id ruleId, String predicateType, String targetApiName) {
        try {
            V360AdminService.saveRulePredicates(
                new List<V360_RulePredicate__c>{
                    new V360_RulePredicate__c(
                        CardRule__c = ruleId,
                        PredicateType__c = predicateType,
                        TargetApiName__c = targetApiName
                    )
                }
            );
        } catch (V360AdminService.V360AdminServiceException adminError) {
            throw new AuraHandledException(adminError.getMessage());
        } catch (Exception unexpected) {
            throw new AuraHandledException('Unable to add the predicate.');
        }
    }

    /**
     * Deletes a rule predicate.
     *
     * @param predicateId the predicate to delete
     */
    @AuraEnabled
    public static void deleteRulePredicate(Id predicateId) {
        try {
            V360AdminService.deleteRulePredicates(new Set<Id>{ predicateId });
        } catch (V360AdminService.V360AdminServiceException adminError) {
            throw new AuraHandledException(adminError.getMessage());
        } catch (Exception unexpected) {
            throw new AuraHandledException('Unable to delete the predicate.');
        }
    }

    /**
     * Deletes a visibility rule; its predicates cascade.
     *
     * @param ruleId the rule to delete
     */
    @AuraEnabled
    public static void deleteRule(Id ruleId) {
        try {
            V360AdminService.deleteCardRules(new Set<Id>{ ruleId });
        } catch (V360AdminService.V360AdminServiceException adminError) {
            throw new AuraHandledException(adminError.getMessage());
        } catch (Exception unexpected) {
            throw new AuraHandledException('Unable to delete the rule.');
        }
    }

    /**
     * Deletes a card together with its rules and their predicates.
     *
     * @param cardId the card to delete
     */
    @AuraEnabled
    public static void deleteCard(Id cardId) {
        try {
            V360AdminService.deleteCards(new Set<Id>{ cardId });
        } catch (V360AdminService.V360AdminServiceException adminError) {
            throw new AuraHandledException(adminError.getMessage());
        } catch (Exception unexpected) {
            throw new AuraHandledException('Unable to delete the card.');
        }
    }

    /**
     * Hides a card everywhere immediately, without evaluating any rule --
     * the incident control.
     *
     * @param cardId the card to hide
     */
    @AuraEnabled
    public static void engageKillSwitch(Id cardId) {
        setKillSwitch(cardId, true);
    }

    /**
     * Releases a card's kill switch; visibility rules apply again.
     *
     * @param cardId the card to release
     */
    @AuraEnabled
    public static void releaseKillSwitch(Id cardId) {
        setKillSwitch(cardId, false);
    }

    /**
     * Chooses how a card's rules combine.
     *
     * ALL makes each rule a requirement; ANY makes each one a way to qualify.
     * The value is validated here rather than trusted from the client, because
     * anything the evaluator does not recognise as ANY it reads as ALL, and a
     * typo that silently lands on the restrictive side would look like the
     * screen simply ignoring the admin.
     *
     * @param cardId the card whose rules are being re-read
     * @param matchLogic ALL or ANY
     */
    @AuraEnabled
    public static void setRuleMatchLogic(Id cardId, String matchLogic) {
        if (matchLogic != 'ALL' && matchLogic != 'ANY') {
            throw new AuraHandledException('Rules combine with ALL or ANY, not "' + matchLogic + '".');
        }
        try {
            V360AdminService.saveCards(
                new List<V360_Card__c>{ new V360_Card__c(Id = cardId, RuleMatchLogic__c = matchLogic) }
            );
        } catch (V360AdminService.V360AdminServiceException adminError) {
            throw new AuraHandledException(adminError.getMessage());
        } catch (Exception unexpected) {
            throw new AuraHandledException('Unable to change how this card combines its rules.');
        }
    }

    private static void setKillSwitch(Id cardId, Boolean engaged) {
        try {
            V360AdminService.saveCards(
                new List<V360_Card__c>{ new V360_Card__c(Id = cardId, KillSwitch__c = engaged) }
            );
        } catch (V360AdminService.V360AdminServiceException adminError) {
            throw new AuraHandledException(adminError.getMessage());
        } catch (Exception unexpected) {
            throw new AuraHandledException('Unable to change the kill switch.');
        }
    }

    /**
     * Takes a draft card live for end users.
     *
     * @param cardId the card to activate
     */
    @AuraEnabled
    public static void activateCard(Id cardId) {
        setCardActive(cardId, true);
    }

    /**
     * Returns a card to draft: inactive cards are hidden from end users
     * before any rule runs.
     *
     * @param cardId the card to deactivate
     */
    @AuraEnabled
    public static void deactivateCard(Id cardId) {
        setCardActive(cardId, false);
    }

    private static void setCardActive(Id cardId, Boolean isActive) {
        try {
            V360AdminService.saveCards(
                new List<V360_Card__c>{ new V360_Card__c(Id = cardId, Active__c = isActive) }
            );
        } catch (V360AdminService.V360AdminServiceException adminError) {
            throw new AuraHandledException(adminError.getMessage());
        } catch (Exception unexpected) {
            throw new AuraHandledException('Unable to change the card state.');
        }
    }

    /**
     * Live formula validation for the rule editor; never saves anything.
     *
     * @param cardId the card whose anchor SObject the formula resolves against
     * @param formulaText the formula to build
     * @return the verdict and a user-facing message
     */
    @AuraEnabled
    public static FormulaValidation validateRuleFormula(Id cardId, String formulaText) {
        try {
            FormulaValidation validation = new FormulaValidation();
            try {
                V360AdminService.validateFormula(cardId, formulaText);
                validation.isValid = true;
                validation.message = 'Formula is valid — ' + formulaText.length() + ' of 3,900 characters.';
            } catch (V360AdminService.V360AdminServiceException adminError) {
                validation.isValid = false;
                validation.message = adminError.getMessage();
            }
            return validation;
        } catch (Exception unexpected) {
            throw new AuraHandledException('Unable to validate the formula.');
        }
    }

    /**
     * Saves a rule's visibility formula. The card id rides along because
     * save-time validation resolves the formula against that card's anchor
     * SObject.
     *
     * @param ruleId the rule being edited
     * @param cardId the rule's card, for anchor resolution
     * @param formulaText the formula to persist
     */
    @AuraEnabled
    public static void saveRuleFormula(Id ruleId, Id cardId, String formulaText) {
        try {
            V360AdminService.saveCardRules(
                new List<V360_CardRule__c>{
                    new V360_CardRule__c(Id = ruleId, Card__c = cardId, VisibilityFormula__c = formulaText)
                }
            );
        } catch (V360AdminService.V360AdminServiceException adminError) {
            throw new AuraHandledException(adminError.getMessage());
        } catch (Exception unexpected) {
            throw new AuraHandledException('Unable to save the rule.');
        }
    }

    /**
     * Rewrites Order__c for every card of a tab from the given sequence
     * (first id becomes 1, and so on). Routed through V360AdminService so
     * the manage-permission gate and CRUD/FLS enforcement apply; the sparse
     * records carry no component binding, so no binding validation fires.
     *
     * @param orderedCardIds every card of the tab, in the desired order
     */
    @AuraEnabled
    public static void updateCardOrder(List<Id> orderedCardIds) {
        try {
            List<V360_Card__c> reordered = new List<V360_Card__c>();
            Integer position = 1;
            for (Id cardId : orderedCardIds) {
                reordered.add(new V360_Card__c(Id = cardId, Order__c = position));
                position++;
            }
            V360AdminService.saveCards(reordered);
        } catch (V360AdminService.V360AdminServiceException adminError) {
            throw new AuraHandledException(adminError.getMessage());
        } catch (Exception unexpected) {
            throw new AuraHandledException('Unable to reorder the cards.');
        }
    }

    // Same rationale as getCatalog: the console shows every rule of every
    // card, and rule volume is config-scale.
    @SuppressWarnings('PMD.AvoidNonRestrictiveQueries')
    private static Map<Id, List<AdminRule>> loadRulesByCard() {
        Map<Id, List<AdminRule>> rulesByCardId = new Map<Id, List<AdminRule>>();
        for (V360_CardRule__c rule : [
            SELECT
                Id,
                Card__c,
                DeveloperName__c,
                Description__c,
                VisibilityFormula__c,
                Active__c,
                (SELECT Id, PredicateType__c, TargetApiName__c FROM V360_Rule_Predicates__r ORDER BY PredicateType__c)
            FROM V360_CardRule__c
            WITH USER_MODE
            ORDER BY DeveloperName__c
        ]) {
            if (!rulesByCardId.containsKey(rule.Card__c)) {
                rulesByCardId.put(rule.Card__c, new List<AdminRule>());
            }
            rulesByCardId.get(rule.Card__c).add(toAdminRule(rule));
        }
        return rulesByCardId;
    }

    private static AdminRule toAdminRule(V360_CardRule__c rule) {
        AdminRule adminRule = new AdminRule();
        adminRule.ruleId = rule.Id;
        adminRule.developerName = rule.DeveloperName__c;
        adminRule.description = rule.Description__c;
        adminRule.formula = rule.VisibilityFormula__c;
        adminRule.active = rule.Active__c;
        adminRule.predicates = new List<AdminPredicate>();
        for (V360_RulePredicate__c predicate : rule.V360_Rule_Predicates__r) {
            AdminPredicate adminPredicate = new AdminPredicate();
            adminPredicate.predicateId = predicate.Id;
            adminPredicate.predicateType = predicate.PredicateType__c;
            adminPredicate.targetApiName = predicate.TargetApiName__c;
            adminRule.predicates.add(adminPredicate);
        }
        return adminRule;
    }

    private static AdminTab toAdminTab(V360_Tab__c tab, Map<Id, List<AdminRule>> rulesByCardId) {
        AdminTab adminTab = new AdminTab();
        adminTab.tabId = tab.Id;
        adminTab.developerName = tab.DeveloperName__c;
        adminTab.sObjectApiName = tab.AnchorSObject__c;
        adminTab.sequence = tab.Sequence__c;
        adminTab.cards = new List<AdminCard>();
        for (V360_Card__c card : tab.V360_Cards__r) {
            adminTab.cards.add(toAdminCard(card, rulesByCardId));
        }
        return adminTab;
    }

    private static AdminCard toAdminCard(V360_Card__c card, Map<Id, List<AdminRule>> rulesByCardId) {
        AdminCard adminCard = new AdminCard();
        adminCard.cardId = card.Id;
        adminCard.developerName = card.DeveloperName__c;
        adminCard.label = card.Label__c;
        adminCard.description = card.Description__c;
        adminCard.componentType = card.ComponentType__c;
        adminCard.componentName = card.ComponentName__c;
        adminCard.iconName = card.IconName__c;
        adminCard.buttonLabel = card.ButtonLabel__c;
        adminCard.order = card.Order__c;
        adminCard.active = card.Active__c;
        adminCard.killSwitch = card.KillSwitch__c;
        // The console must never render a blank here: a card saved before the
        // field existed carries null, and the evaluator reads that as ALL, so
        // the screen has to say ALL rather than leave the admin guessing.
        adminCard.ruleMatchLogic = card.RuleMatchLogic__c ?? 'ALL';
        List<AdminRule> rules = rulesByCardId.get(card.Id);
        adminCard.rules = rules == null ? new List<AdminRule>() : rules;
        adminCard.ruleCount = adminCard.rules.size();
        adminCard.activeRuleCount = countActiveRules(adminCard.rules);
        return adminCard;
    }

    /**
     * The rules that actually restrict someone.
     *
     * Two ways a stored rule fails to: it is parked, or it asks for nothing.
     * A parked rule is skipped by V360VisibilityEvaluator outright, and a rule
     * with neither a formula nor a required access adds no requirement under
     * ALL and is refused as a way in under ANY. Either way it protects nobody,
     * so counting it would let the console call a card guarded when it is
     * open -- and this count is what every exposure warning turns on.
     *
     * @param rules every rule of one card, active or not
     * @return how many of them the evaluator will actually enforce
     */
    private static Integer countActiveRules(List<AdminRule> rules) {
        Integer enforced = 0;
        for (AdminRule rule : rules) {
            if (rule.active == true && asksForSomething(rule)) {
                enforced++;
            }
        }
        return enforced;
    }

    private static Boolean asksForSomething(AdminRule rule) {
        return String.isNotBlank(rule.formula) || !rule.predicates.isEmpty();
    }

    /** Everything saveCardProperties may change on a card, plus its id. */
    // Transport properties named after the fields they carry; per-property
    // ApexDoc would only restate each name.
    @SuppressWarnings('PMD.ApexDoc')
    public class CardPropertiesInput {
        @AuraEnabled
        public Id cardId { get; set; }
        @AuraEnabled
        public String label { get; set; }
        @AuraEnabled
        public String description { get; set; }
        @AuraEnabled
        public String iconName { get; set; }
        @AuraEnabled
        public String buttonLabel { get; set; }
        @AuraEnabled
        public String componentType { get; set; }
        @AuraEnabled
        public String componentName { get; set; }
    }

    /** Everything saveTab may change on a tab; a blank id creates one. */
    // Transport properties named after the fields they carry; per-property
    // ApexDoc would only restate each name. AvoidBooleanMethodParameters
    // fires on the implicit setter of the `active` property, which is not the
    // control-flow flag that rule guards against -- a checkbox field cannot
    // cross the @AuraEnabled boundary without one.
    @SuppressWarnings('PMD.ApexDoc,PMD.AvoidBooleanMethodParameters')
    public class TabInput {
        @AuraEnabled
        public Id tabId { get; set; }
        @AuraEnabled
        public String developerName { get; set; }
        @AuraEnabled
        public String sObjectApiName { get; set; }
        @AuraEnabled
        public Decimal sequence { get; set; }
    }

    /** Everything createCard needs: the tab, the identity, and the properties. */
    // Transport properties named after the fields they carry; per-property
    // ApexDoc would only restate each name.
    @SuppressWarnings('PMD.ApexDoc')
    public class NewCardInput {
        @AuraEnabled
        public Id tabId { get; set; }
        @AuraEnabled
        public String developerName { get; set; }
        @AuraEnabled
        public String label { get; set; }
        @AuraEnabled
        public String description { get; set; }
        @AuraEnabled
        public String iconName { get; set; }
        @AuraEnabled
        public String buttonLabel { get; set; }
        @AuraEnabled
        public String componentType { get; set; }
        @AuraEnabled
        public String componentName { get; set; }
        @AuraEnabled
        public Decimal order { get; set; }
    }

    /** The console's root payload: the permission verdict and the tab graph. */
    public class AdminCatalog {
        @AuraEnabled
        public Boolean hasManagePermission;
        @AuraEnabled
        public List<AdminTab> tabs;
    }

    /** One Vista 360 tab with its cards, in display order. */
    public class AdminTab {
        @AuraEnabled
        public Id tabId;
        @AuraEnabled
        public String developerName;
        @AuraEnabled
        public String sObjectApiName;
        @AuraEnabled
        public Decimal sequence;
        @AuraEnabled
        public List<AdminCard> cards;
    }

    /** One card's presentation, binding, state, and rules. */
    public class AdminCard {
        @AuraEnabled
        public Id cardId;
        @AuraEnabled
        public String developerName;
        @AuraEnabled
        public String label;
        @AuraEnabled
        public String description;
        @AuraEnabled
        public String componentType;
        @AuraEnabled
        public String componentName;
        @AuraEnabled
        public String iconName;
        @AuraEnabled
        public String buttonLabel;
        @AuraEnabled
        public Decimal order;
        @AuraEnabled
        public Boolean active;
        @AuraEnabled
        public Boolean killSwitch;
        /** ALL or ANY — how this card's rules combine. Never null to the client. */
        @AuraEnabled
        public String ruleMatchLogic;
        @AuraEnabled
        public Integer ruleCount;
        @AuraEnabled
        public Integer activeRuleCount;
        @AuraEnabled
        public List<AdminRule> rules;
    }

    /** One visibility rule with its structured predicates. */
    public class AdminRule {
        @AuraEnabled
        public Id ruleId;
        @AuraEnabled
        public String developerName;
        @AuraEnabled
        public String description;
        @AuraEnabled
        public String formula;
        @AuraEnabled
        public Boolean active;
        @AuraEnabled
        public List<AdminPredicate> predicates;
    }

    /** One structured predicate of a rule (permission set or FLS check). */
    public class AdminPredicate {
        @AuraEnabled
        public Id predicateId;
        @AuraEnabled
        public String predicateType;
        @AuraEnabled
        public String targetApiName;
    }

    /** The verdict of a live formula validation. */
    public class FormulaValidation {
        @AuraEnabled
        public Boolean isValid;
        @AuraEnabled
        public String message;
    }
}
