/**
 * Seeds one Vista 360 tab -> card -> rule -> predicate end-to-end for the
 * Account record page. Everything below goes through V360AdminService --
 * the same CRUD/FLS-enforced write path an admin UI would use -- so this
 * script doubles as executable documentation of that path until a
 * dedicated admin Lightning surface ships.
 *
 * Idempotent and safe to re-run any number of times in the same org: every
 * record is looked up by its own natural identity first and updated in
 * place, rather than inserted a second time.
 *   - V360_Tab__c / V360_Card__c / V360_CardRule__c: looked up by their own
 *     DeveloperName__c (unique, ExternalId).
 *   - V360_RulePredicate__c has no DeveloperName__c field (by design -- see
 *     the frozen schema), so it is looked up by its natural composite key:
 *     parent rule + predicate type + target field.
 * V360AdminService.saveXxx() only upserts by Id (not by an external id
 * field), so this script resolves the Id itself before calling it.
 *
 * What it seeds:
 *   - One V360_Tab__c anchored on Account.
 *   - One V360_Card__c bound to the v360AccountSnapshot LWC (registered in
 *     v360CardRegistry.js).
 *   - One V360_CardRule__c on that card, with a formula condition on a
 *     picklist field. Picklist fields need ISPICKVAL() in FormulaEval -- a
 *     bare `Field = 'value'` comparison fails to build().
 *   - One V360_RulePredicate__c on that rule (FLS_READ), demonstrating the
 *     fail-closed structured-predicate path: a user without read access to
 *     the target field never sees the card, regardless of the formula.
 *
 * To adapt this for your own org's rule: change the *_DEVELOPER_NAME values
 * below, VISIBILITY_FORMULA, and FLS_PREDICATE_TARGET_FIELD to real
 * business logic. Requires the V360_ManageVisibilityRules custom
 * permission (granted by V360_Admin).
 *
 * Run: sf apex run --file scripts/apex/v360-seed-vertical-slice.apex --target-org <alias>
 */

// ---- Configuration: edit these for your own org's rule --------------------
String tabDeveloperName = 'AccountOverview';
String anchorSObjectApiName = 'Account';
String cardDeveloperName = 'V360AccountSnapshot';
String cardComponentName = 'v360AccountSnapshot';
String ruleDeveloperName = 'V360AccountSnapshotVisibility';
String visibilityFormula = 'ISPICKVAL(Industry, \'Banking\')';
// A custom field is used here (rather than a standard one like AnnualRevenue)
// because custom-field FLS is off by default for every profile except System
// Administrator, which makes the fail-closed FLS_READ path easy to
// demonstrate with an ordinary low-privilege test user and no extra FLS setup.
String flsPredicateTargetField = 'CPCurrentDueAmount__c';

// ---- 1. Tab ----------------------------------------------------------------
List<V360_Tab__c> existingTabs = [
    SELECT Id
    FROM V360_Tab__c
    WHERE DeveloperName__c = :tabDeveloperName
    LIMIT 1
];
V360_Tab__c tab = existingTabs.isEmpty() ? new V360_Tab__c() : existingTabs[0];
tab.DeveloperName__c = tabDeveloperName;
tab.Name = tabDeveloperName;
tab.AnchorSObject__c = anchorSObjectApiName;
tab.Sequence__c = 1;

Database.UpsertResult tabResult = V360AdminService.saveTabs(new List<V360_Tab__c>{ tab })[0];
if (!tabResult.isSuccess()) {
    for (Database.Error tabError : tabResult.getErrors()) {
        System.debug(LoggingLevel.ERROR, 'V360_Tab__c seed failed: ' + tabError.getMessage());
    }
    throw new DmlException('Failed to seed V360_Tab__c -- see debug log for details.');
}
Id tabId = tabResult.getId();
System.debug('Seeded V360_Tab__c: ' + tabId);

// ---- 2. Card ----------------------------------------------------------------
List<V360_Card__c> existingCards = [
    SELECT Id
    FROM V360_Card__c
    WHERE DeveloperName__c = :cardDeveloperName
    LIMIT 1
];
V360_Card__c card = existingCards.isEmpty() ? new V360_Card__c() : existingCards[0];
card.DeveloperName__c = cardDeveloperName;
card.Name = cardDeveloperName;
card.Tab__c = tabId;
card.ComponentType__c = 'LWC';
card.ComponentName__c = cardComponentName;
card.Label__c = 'Account Snapshot';
card.Description__c = 'Vertical-slice proof card: shows a couple of Account fields via the UI API record wire.';
card.ButtonLabel__c = 'Snapshot';
card.IconName__c = 'standard:account';
card.Order__c = 1;
card.KillSwitch__c = false;
card.Active__c = true;

Database.UpsertResult cardResult = V360AdminService.saveCards(new List<V360_Card__c>{ card })[0];
if (!cardResult.isSuccess()) {
    for (Database.Error cardError : cardResult.getErrors()) {
        System.debug(LoggingLevel.ERROR, 'V360_Card__c seed failed: ' + cardError.getMessage());
    }
    throw new DmlException('Failed to seed V360_Card__c -- see debug log for details.');
}
Id cardId = cardResult.getId();
System.debug('Seeded V360_Card__c: ' + cardId);

// ---- 3. Card rule ------------------------------------------------------------
List<V360_CardRule__c> existingRules = [
    SELECT Id
    FROM V360_CardRule__c
    WHERE DeveloperName__c = :ruleDeveloperName
    LIMIT 1
];
V360_CardRule__c rule = existingRules.isEmpty() ? new V360_CardRule__c() : existingRules[0];
rule.DeveloperName__c = ruleDeveloperName;
rule.Card__c = cardId;
rule.VisibilityFormula__c = visibilityFormula;
rule.Description__c = 'Visible when the account\'s Industry is Banking.';
rule.Active__c = true;

Database.UpsertResult ruleResult = V360AdminService.saveCardRules(new List<V360_CardRule__c>{ rule })[0];
if (!ruleResult.isSuccess()) {
    for (Database.Error ruleError : ruleResult.getErrors()) {
        System.debug(LoggingLevel.ERROR, 'V360_CardRule__c seed failed: ' + ruleError.getMessage());
    }
    throw new DmlException('Failed to seed V360_CardRule__c -- see debug log for details.');
}
Id ruleId = ruleResult.getId();
System.debug('Seeded V360_CardRule__c: ' + ruleId);

// ---- 4. Rule predicate (FLS_READ) --------------------------------------------
List<V360_RulePredicate__c> existingPredicates = [
    SELECT Id
    FROM V360_RulePredicate__c
    WHERE CardRule__c = :ruleId
    AND PredicateType__c = 'FLS_READ'
    AND TargetApiName__c = :flsPredicateTargetField
    LIMIT 1
];
// CardRule__c (master-detail) is write-once: the platform never allows it to be
// updated after insert (re-parenting a master-detail child is not permitted), so it
// is only set on the new-record branch -- an existing predicate already has the
// correct parent and re-assigning it on update would throw "Field is not writeable".
V360_RulePredicate__c predicate = existingPredicates.isEmpty()
    ? new V360_RulePredicate__c(CardRule__c = ruleId)
    : existingPredicates[0];
predicate.PredicateType__c = 'FLS_READ';
predicate.TargetApiName__c = flsPredicateTargetField;

Database.UpsertResult predicateResult = V360AdminService.saveRulePredicates(new List<V360_RulePredicate__c>{ predicate })[0];
if (!predicateResult.isSuccess()) {
    for (Database.Error predicateError : predicateResult.getErrors()) {
        System.debug(LoggingLevel.ERROR, 'V360_RulePredicate__c seed failed: ' + predicateError.getMessage());
    }
    throw new DmlException('Failed to seed V360_RulePredicate__c -- see debug log for details.');
}
System.debug('Seeded V360_RulePredicate__c: ' + predicateResult.getId());

// ---- 5. Defensive re-check of the checkbox fields ----------------------------
// This org has an observed, unresolved anomaly where a Checkbox field on a V360
// object can fail to persist a value assigned inside @TestSetup (see
// V360TestDataFactory and apply-progress.md); direct DML like the writes above is
// the confirmed-reliable context. This script re-reads and corrects defensively
// anyway, since it is meant to be re-run safely and unattended.
List<V360_Card__c> confirmedCards = [SELECT Active__c, KillSwitch__c FROM V360_Card__c WHERE Id = :cardId];
List<V360_CardRule__c> confirmedRules = [SELECT Active__c FROM V360_CardRule__c WHERE Id = :ruleId];

if (!confirmedCards.isEmpty() && (confirmedCards[0].Active__c != true || confirmedCards[0].KillSwitch__c != false)) {
    System.debug(LoggingLevel.WARN, 'V360_Card__c checkbox fields did not persist as expected on first write -- correcting.');
    V360AdminService.saveCards(new List<V360_Card__c>{ new V360_Card__c(Id = cardId, Active__c = true, KillSwitch__c = false) });
}
if (!confirmedRules.isEmpty() && confirmedRules[0].Active__c != true) {
    System.debug(LoggingLevel.WARN, 'V360_CardRule__c.Active__c did not persist as true on first write -- correcting.');
    V360AdminService.saveCardRules(new List<V360_CardRule__c>{ new V360_CardRule__c(Id = ruleId, Active__c = true) });
}

System.debug('Vista 360 vertical-slice seed complete. Tab=' + tabId + ' Card=' + cardId + ' Rule=' + ruleId);
