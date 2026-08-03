/**
 * The thin @AuraEnabled boundary for the Vista 360 admin console. It
 * reports whether the running user holds the manage permission and, when
 * they do, returns the configuration graph (tabs, their cards, and each
 * card's rule count) for the console to browse.
 *
 * All reads run in user mode: the admin console is a real-access surface
 * for users granted the V360_Admin permission set, never a trusted
 * mediator like the end-user visibility read path.
 */
public with sharing class V360AdminController {

    private static final String MANAGE_PERMISSION = 'V360_ManageVisibilityRules';

    @AuraEnabled
    public static AdminCatalog getCatalog() {
        try {
            AdminCatalog catalog = new AdminCatalog();
            catalog.hasManagePermission = FeatureManagement.checkPermission(MANAGE_PERMISSION);
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
                    Active__c,
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
                            KillSwitch__c
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
     */
    @AuraEnabled
    public static void saveCardProperties(
        Id cardId,
        String label,
        String buttonLabel,
        String componentType,
        String componentName
    ) {
        try {
            V360AdminService.saveCards(
                new List<V360_Card__c>{
                    new V360_Card__c(
                        Id = cardId,
                        Label__c = label,
                        ButtonLabel__c = buttonLabel,
                        ComponentType__c = componentType,
                        ComponentName__c = componentName
                    )
                }
            );
        } catch (V360AdminService.V360AdminServiceException adminError) {
            throw new AuraHandledException(adminError.getMessage());
        } catch (Exception unexpected) {
            throw new AuraHandledException('Unable to save the card.');
        }
    }

    /** Activates or deactivates (drafts) a card; inactive cards are hidden from end users before any rule runs. */
    @AuraEnabled
    public static void setCardActive(Id cardId, Boolean isActive) {
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

    /** Live formula validation for the rule editor; never saves anything. */
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
                (SELECT PredicateType__c, TargetApiName__c FROM V360_Rule_Predicates__r ORDER BY PredicateType__c)
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
        adminTab.active = tab.Active__c;
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
        List<AdminRule> rules = rulesByCardId.get(card.Id);
        adminCard.rules = rules == null ? new List<AdminRule>() : rules;
        adminCard.ruleCount = adminCard.rules.size();
        return adminCard;
    }

    public class AdminCatalog {
        @AuraEnabled
        public Boolean hasManagePermission;
        @AuraEnabled
        public List<AdminTab> tabs;
    }

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
        public Boolean active;
        @AuraEnabled
        public List<AdminCard> cards;
    }

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
        @AuraEnabled
        public Integer ruleCount;
        @AuraEnabled
        public List<AdminRule> rules;
    }

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

    public class AdminPredicate {
        @AuraEnabled
        public String predicateType;
        @AuraEnabled
        public String targetApiName;
    }

    public class FormulaValidation {
        @AuraEnabled
        public Boolean isValid;
        @AuraEnabled
        public String message;
    }
}
