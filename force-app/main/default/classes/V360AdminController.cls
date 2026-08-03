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
            Map<Id, Integer> ruleCountsByCardId = countRulesByCard();
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
                catalog.tabs.add(toAdminTab(tab, ruleCountsByCardId));
            }
            return catalog;
        } catch (Exception unexpected) {
            throw new AuraHandledException('Unable to load the Vista 360 configuration.');
        }
    }

    private static Map<Id, Integer> countRulesByCard() {
        Map<Id, Integer> ruleCountsByCardId = new Map<Id, Integer>();
        for (AggregateResult grouped : [
            SELECT Card__c cardId, COUNT(Id) ruleCount
            FROM V360_CardRule__c
            WITH USER_MODE
            GROUP BY Card__c
        ]) {
            ruleCountsByCardId.put((Id) grouped.get('cardId'), (Integer) grouped.get('ruleCount'));
        }
        return ruleCountsByCardId;
    }

    private static AdminTab toAdminTab(V360_Tab__c tab, Map<Id, Integer> ruleCountsByCardId) {
        AdminTab adminTab = new AdminTab();
        adminTab.tabId = tab.Id;
        adminTab.developerName = tab.DeveloperName__c;
        adminTab.sObjectApiName = tab.AnchorSObject__c;
        adminTab.sequence = tab.Sequence__c;
        adminTab.active = tab.Active__c;
        adminTab.cards = new List<AdminCard>();
        for (V360_Card__c card : tab.V360_Cards__r) {
            adminTab.cards.add(toAdminCard(card, ruleCountsByCardId));
        }
        return adminTab;
    }

    private static AdminCard toAdminCard(V360_Card__c card, Map<Id, Integer> ruleCountsByCardId) {
        AdminCard adminCard = new AdminCard();
        adminCard.cardId = card.Id;
        adminCard.developerName = card.DeveloperName__c;
        adminCard.label = card.Label__c;
        adminCard.description = card.Description__c;
        adminCard.componentType = card.ComponentType__c;
        adminCard.componentName = card.ComponentName__c;
        adminCard.iconName = card.IconName__c;
        adminCard.order = card.Order__c;
        adminCard.active = card.Active__c;
        adminCard.killSwitch = card.KillSwitch__c;
        Integer ruleCount = ruleCountsByCardId.get(card.Id);
        adminCard.ruleCount = ruleCount == null ? 0 : ruleCount;
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
        public Decimal order;
        @AuraEnabled
        public Boolean active;
        @AuraEnabled
        public Boolean killSwitch;
        @AuraEnabled
        public Integer ruleCount;
    }
}
