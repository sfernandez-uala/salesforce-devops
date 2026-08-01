/**
 * In-memory stub implementations of the Vista 360 decision-core seams, shared
 * across the pure-unit test classes so each of them can inject exactly the
 * catalog/rule/user/formula state a scenario needs without any DML or a
 * connected org's data.
 */
@IsTest
public class V360TestStubs {

    /**
     * Builds a syntactically valid fake Id for the given SObject type, so
     * in-memory DTOs can carry a real, correctly-prefixed Id without inserting
     * anything.
     */
    public static Id fakeId(Schema.SObjectType sObjType, Integer sequence) {
        String keyPrefix = sObjType.getDescribe().getKeyPrefix();
        String paddedSequence = String.valueOf(sequence).leftPad(12, '0');
        return (Id) (keyPrefix + paddedSequence);
    }

    public class StubUserContext implements IUserContext {
        public Set<String> assignedPermissionSets = new Set<String>();
        public Set<String> heldCustomPermissions = new Set<String>();
        public String profileName;
        public Set<String> readableFields = new Set<String>();

        public Boolean hasPermissionSet(String apiName) {
            return assignedPermissionSets.contains(apiName);
        }

        public Boolean hasCustomPermission(String apiName) {
            return heldCustomPermissions.contains(apiName);
        }

        public Boolean hasProfile(String profileNameToCheck) {
            return profileName == profileNameToCheck;
        }

        public Boolean isFieldReadable(String sObjectApiName, String fieldApiName) {
            return readableFields.contains(sObjectApiName + '.' + fieldApiName);
        }
    }

    public class StubFormulaEngine implements IFormulaEngine {
        public Map<String, Boolean> resultByFormula = new Map<String, Boolean>();
        public Map<String, Set<String>> referencedFieldsByFormula = new Map<String, Set<String>>();
        public Set<String> formulasThatFailToBuild = new Set<String>();
        public Set<String> formulasThatFailToEvaluate = new Set<String>();

        private String currentFormula;

        public void build(String formulaText, Schema.SObjectType anchorType) {
            if (formulasThatFailToBuild.contains(formulaText)) {
                this.currentFormula = null;
                throw new StubFormulaEngineException('Stub build failure for: ' + formulaText);
            }
            this.currentFormula = formulaText;
        }

        public Boolean evaluate(SObject anchorRecord) {
            requireBuilt();
            if (formulasThatFailToEvaluate.contains(currentFormula)) {
                throw new StubFormulaEngineException('Stub evaluate failure for: ' + currentFormula);
            }
            if (!resultByFormula.containsKey(currentFormula)) {
                throw new StubFormulaEngineException('No stub result configured for: ' + currentFormula);
            }
            return resultByFormula.get(currentFormula);
        }

        public Set<String> getReferencedFields() {
            requireBuilt();
            return referencedFieldsByFormula.containsKey(currentFormula)
                ? referencedFieldsByFormula.get(currentFormula)
                : new Set<String>();
        }

        private void requireBuilt() {
            if (currentFormula == null) {
                throw new StubFormulaEngineException('build() must succeed before this call.');
            }
        }
    }

    public class StubFormulaEngineException extends Exception {
    }

    public class StubCardCatalogSource implements ICardCatalogSource {
        public Map<String, List<V360CardCatalogDTO>> cardsByTabApiName = new Map<String, List<V360CardCatalogDTO>>();

        public List<V360CardCatalogDTO> getCardsForTab(String tabApiName) {
            return cardsByTabApiName.containsKey(tabApiName)
                ? cardsByTabApiName.get(tabApiName)
                : new List<V360CardCatalogDTO>();
        }
    }

    public class StubCardRuleSource implements ICardRuleSource {
        public Map<Id, V360RuleGraph> ruleGraphByCardId = new Map<Id, V360RuleGraph>();

        public Map<Id, V360RuleGraph> getRulesForCards(Set<Id> cardIds) {
            Map<Id, V360RuleGraph> result = new Map<Id, V360RuleGraph>();
            for (Id cardId : cardIds) {
                if (ruleGraphByCardId.containsKey(cardId)) {
                    result.put(cardId, ruleGraphByCardId.get(cardId));
                }
            }
            return result;
        }
    }
}
