/**
 * Wraps the platform's FormulaEval engine behind the IFormulaEngine seam.
 * Builds a boolean formula against an anchor SObject type with the four
 * identity-condition global variables (Custom Permission, Profile, User,
 * User Role) available to the formula, then evaluates it against a record
 * of that type.
 *
 * One instance builds one formula at a time: build() replaces whatever was
 * previously built. Callers decide what a build() failure means for them —
 * this class only reports it by throwing.
 */
public with sharing class V360FormulaGateway implements IFormulaEngine {

    /**
     * The platform's hard cap on formula length for a dynamically built and
     * evaluated formula. Enforced here as defense in depth on top of the
     * platform's own rejection, and ahead of it so the failure message is
     * the same regardless of which layer catches it first.
     */
    public static final Integer MAX_FORMULA_LENGTH = 3900;

    private static final List<FormulaEval.FormulaGlobal> IDENTITY_GLOBALS = new List<FormulaEval.FormulaGlobal>{
        FormulaEval.FormulaGlobal.PERMISSION,
        FormulaEval.FormulaGlobal.PROFILE,
        FormulaEval.FormulaGlobal.USER,
        FormulaEval.FormulaGlobal.USER_ROLE
    };

    private FormulaEval.FormulaInstance builtFormula;

    public void build(String formulaText, Schema.SObjectType sObjectType) {
        if (sObjectType == null) {
            throw new V360FormulaGatewayException('An anchor SObject type is required to build a formula.');
        }
        if (String.isBlank(formulaText)) {
            throw new V360FormulaGatewayException('Formula text cannot be blank.');
        }
        if (formulaText.length() > MAX_FORMULA_LENGTH) {
            throw new V360FormulaGatewayException(
                'Formula is ' + formulaText.length() + ' characters long; the maximum is ' + MAX_FORMULA_LENGTH + '.'
            );
        }

        try {
            this.builtFormula = Formula.builder()
                .withType(sObjectType)
                .withReturnType(FormulaEval.FormulaReturnType.BOOLEAN)
                .withGlobalVariables(IDENTITY_GLOBALS)
                .withFormula(formulaText)
                .build();
        } catch (Exception buildException) {
            this.builtFormula = null;
            throw new V360FormulaGatewayException('Formula failed to build: ' + buildException.getMessage(), buildException);
        }
    }

    public Boolean evaluate(SObject record) {
        requireBuiltFormula();
        try {
            Object result = this.builtFormula.evaluate(record);
            return result == null ? false : (Boolean) result;
        } catch (Exception evaluateException) {
            throw new V360FormulaGatewayException(
                'Formula failed to evaluate: ' + evaluateException.getMessage(),
                evaluateException
            );
        }
    }

    public Set<String> getReferencedFields() {
        requireBuiltFormula();
        return this.builtFormula.getReferencedFields();
    }

    private void requireBuiltFormula() {
        if (this.builtFormula == null) {
            throw new V360FormulaGatewayException('build() must succeed before this call.');
        }
    }

    public class V360FormulaGatewayException extends Exception {
    }
}
