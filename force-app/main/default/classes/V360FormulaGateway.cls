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
            throw new V360FormulaGatewayException(readable(buildException.getMessage()), buildException);
        }
    }

    /**
     * The platform's build error is written for the Setup UI, not for an API
     * caller: it carries an anchor tag whose href is a javascript: call into
     * Setup's own popup helper. Rendered anywhere else that markup is either
     * escaped into a wall of text or, worse, live. Tags are stripped, the
     * now-orphaned "Tell me more" goes with them, and the whitespace the tag
     * left behind is collapsed, so what reaches an admin is the sentence that
     * actually says what is wrong.
     *
     * @param platformMessage the raw message from the formula engine
     * @return the same message with the Setup-only markup removed
     */
    private static String readable(String platformMessage) {
        if (String.isBlank(platformMessage)) {
            return 'Formula failed to build.';
        }
        String stripped = platformMessage.replaceAll('<[^>]*>', ' ');
        stripped = stripped.replaceAll('(?i)\\s*Tell me more\\s*$', '');
        stripped = stripped.replaceAll('\\s+', ' ').trim();
        return String.isBlank(stripped) ? 'Formula failed to build.' : stripped;
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
