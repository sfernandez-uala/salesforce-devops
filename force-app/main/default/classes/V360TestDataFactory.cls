/**
 * Shared DML fixture builder for Vista 360 integration tests: tabs, cards,
 * rules, predicates, and the standalone test users/permission-set
 * assignments needed to exercise live grant resolution and the admin write
 * path with System.runAs.
 */
@IsTest
public class V360TestDataFactory {

    public static V360_Tab__c insertTab(String developerName, String anchorSObjectApiName) {
        V360_Tab__c tab = new V360_Tab__c(
            Name = developerName,
            DeveloperName__c = developerName,
            AnchorSObject__c = anchorSObjectApiName,
            Sequence__c = 1
        );
        insert tab;
        // Checkbox defaults on this org's V360 objects have proven unreliable when set at insert
        // time (observed empirically: Active__c silently stays false on insert despite an explicit
        // true value, but a follow-up update reliably persists it) — set booleans in a second DML.
        tab.Active__c = true;
        update tab;
        return tab;
    }

    /**
     * @param tabId the parent tab
     * @param developerName the card's stable identity
     * @param binding a card carrying at least ComponentType__c/ComponentName__c; any other field
     *        already set on it (e.g. AnchorSObject__c, KillSwitch__c) is preserved as given
     * @return the inserted card, with Tab__c/DeveloperName__c/Name and sensible defaults applied
     */
    public static V360_Card__c insertCard(Id tabId, String developerName, V360_Card__c binding) {
        V360_Card__c card = binding == null ? new V360_Card__c() : binding;
        card.Tab__c = tabId;
        card.DeveloperName__c = developerName;
        card.Name = String.isBlank(card.Name) ? developerName : card.Name;
        card.Label__c = String.isBlank(card.Label__c) ? developerName : card.Label__c;
        card.Order__c = card.Order__c == null ? 1 : card.Order__c;
        Boolean wantsActive = card.Active__c == null ? true : card.Active__c;
        Boolean wantsKillSwitch = card.KillSwitch__c == null ? false : card.KillSwitch__c;
        insert card;
        // See insertTab(): Checkbox fields on this org's V360 objects have proven unreliable when
        // set at insert time — set them in a second DML, which reliably persists the value.
        card.Active__c = wantsActive;
        card.KillSwitch__c = wantsKillSwitch;
        update card;
        return card;
    }

    public static V360_CardRule__c insertCardRule(Id cardId, String developerName, String visibilityFormula) {
        V360_CardRule__c rule = new V360_CardRule__c(
            Card__c = cardId,
            DeveloperName__c = developerName,
            VisibilityFormula__c = visibilityFormula
        );
        insert rule;
        // See insertTab()/insertCard(): set the checkbox in a second DML so it reliably persists.
        rule.Active__c = true;
        update rule;
        return rule;
    }

    public static V360_RulePredicate__c insertRulePredicate(Id cardRuleId, String predicateType, String targetApiName) {
        V360_RulePredicate__c predicate = new V360_RulePredicate__c(
            CardRule__c = cardRuleId,
            PredicateType__c = predicateType,
            TargetApiName__c = targetApiName
        );
        insert predicate;
        return predicate;
    }

    /**
     * Creates a standalone test User with the given profile and permission
     * sets already assigned, ready for System.runAs(). The User and
     * PermissionSetAssignment inserts run inside their own System.runAs
     * block so callers can freely mix this with prior non-setup-object DML
     * in the same transaction without a MIXED_DML_OPERATION error.
     */
    public static User insertUserWithAccess(String profileName, List<String> permissionSetNames) {
        Profile targetProfile = [SELECT Id FROM Profile WHERE Name = :profileName LIMIT 1];
        String uniqueSuffix = String.valueOf(DateTime.now().getTime())
            + String.valueOf(Math.abs(Crypto.getRandomInteger())).right(4);

        User testUser = new User(
            FirstName = 'V360',
            LastName = 'Test' + uniqueSuffix,
            Alias = 'v' + uniqueSuffix.right(7),
            Email = 'v360.test' + uniqueSuffix + '@example.invalid',
            Username = 'v360.test' + uniqueSuffix + '@' + UserInfo.getOrganizationId() + '.invalid',
            ProfileId = targetProfile.Id,
            TimeZoneSidKey = 'America/Sao_Paulo',
            LocaleSidKey = 'en_US',
            EmailEncodingKey = 'UTF-8',
            LanguageLocaleKey = 'en_US'
        );

        System.runAs(new User(Id = UserInfo.getUserId())) {
            insert testUser;
            assignPermissionSets(testUser.Id, permissionSetNames);
        }
        return testUser;
    }

    private static void assignPermissionSets(Id userId, List<String> permissionSetNames) {
        if (permissionSetNames == null || permissionSetNames.isEmpty()) {
            return;
        }
        Map<String, Id> permissionSetIdByName = new Map<String, Id>();
        for (PermissionSet permissionSet : [SELECT Id, Name FROM PermissionSet WHERE Name IN :permissionSetNames]) {
            permissionSetIdByName.put(permissionSet.Name, permissionSet.Id);
        }
        List<PermissionSetAssignment> assignments = new List<PermissionSetAssignment>();
        for (String permissionSetName : permissionSetNames) {
            Id permissionSetId = permissionSetIdByName.get(permissionSetName);
            if (permissionSetId == null) {
                throw new V360TestDataFactoryException('No PermissionSet named ' + permissionSetName + ' exists in this org.');
            }
            assignments.add(new PermissionSetAssignment(AssigneeId = userId, PermissionSetId = permissionSetId));
        }
        insert assignments;
    }

    public class V360TestDataFactoryException extends Exception {
    }
}
