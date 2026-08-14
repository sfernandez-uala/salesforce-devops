import { LightningElement, api, wire } from 'lwc';
import { getObjectInfo } from 'lightning/uiObjectInfoApi';
import getFormulaVocabulary from '@salesforce/apex/V360RuleVocabulary.getFormulaVocabulary';

const MAX_FORMULA_LENGTH = 3900;

/**
 * Operators the formula engine accepts, labelled the way the platform's own
 * editor labels them -- the symbol is not the part an admin is unsure about.
 */
const OPERATORS = [
    { label: '= Equal', insertText: ' = ' },
    { label: '<> Not equal', insertText: ' <> ' },
    { label: '< Less than', insertText: ' < ' },
    { label: '<= Less or equal', insertText: ' <= ' },
    { label: '> Greater than', insertText: ' > ' },
    { label: '>= Greater or equal', insertText: ' >= ' },
    { label: '&& And', insertText: ' && ' },
    { label: '|| Or', insertText: ' || ' },
    { label: '( Open parenthesis', insertText: '(' },
    { label: ') Close parenthesis', insertText: ')' },
    { label: '& Concatenate', insertText: ' & ' }
];

/**
 * A curated set, not every formula function the platform has. Two reasons.
 *
 * Functions that only exist in a validation-rule or workflow context --
 * ISCHANGED, PRIORVALUE, ISNEW -- are invalid in a dynamically built formula
 * and offering them would offer something the engine rejects. And a visibility
 * rule answers "who sees this card", so the list stays close to that question
 * rather than becoming a scroll through trigonometry.
 */
const FUNCTIONS = [
    { label: 'AND', signature: 'AND(logical1, logical2, ...)', description: 'True when every argument is true.' },
    { label: 'OR', signature: 'OR(logical1, logical2, ...)', description: 'True when any argument is true.' },
    { label: 'NOT', signature: 'NOT(logical)', description: 'Reverses the argument.' },
    { label: 'IF', signature: 'IF(logical, value_if_true, value_if_false)', description: 'Picks one of two values.' },
    { label: 'ISBLANK', signature: 'ISBLANK(expression)', description: 'True when the value is blank. Prefer it over ISNULL for text.' },
    { label: 'ISNULL', signature: 'ISNULL(expression)', description: 'True when the value is null. Text fields are never null, only blank.' },
    { label: 'CONTAINS', signature: 'CONTAINS(text, compare_text)', description: 'True when text contains compare_text. Case sensitive.' },
    { label: 'BEGINS', signature: 'BEGINS(text, compare_text)', description: 'True when text starts with compare_text.' },
    { label: 'INCLUDES', signature: 'INCLUDES(multiselect_picklist, text_literal)', description: 'True when a multi-select picklist includes the value.' },
    { label: 'ISPICKVAL', signature: 'ISPICKVAL(picklist, text_literal)', description: 'True when a picklist equals the value. Compare picklists with this, not with =.' },
    { label: 'TEXT', signature: 'TEXT(value)', description: 'Converts a picklist, number or date to text.' },
    { label: 'VALUE', signature: 'VALUE(text)', description: 'Converts text to a number.' },
    { label: 'LEN', signature: 'LEN(text)', description: 'The number of characters in text.' },
    { label: 'UPPER', signature: 'UPPER(text)', description: 'Text in upper case.' },
    { label: 'LOWER', signature: 'LOWER(text)', description: 'Text in lower case.' },
    { label: 'TRIM', signature: 'TRIM(text)', description: 'Text without leading or trailing spaces.' },
    { label: 'TODAY', signature: 'TODAY()', description: 'The current date.' },
    { label: 'NOW', signature: 'NOW()', description: 'The current date and time.' },
    { label: 'CASE', signature: 'CASE(expression, value1, result1, ..., else_result)', description: 'Compares an expression against a series of values.' },
    { label: 'ABS', signature: 'ABS(number)', description: 'The number without its sign.' },
    { label: 'ROUND', signature: 'ROUND(number, num_digits)', description: 'The number rounded to the given digits.' },
    { label: 'MAX', signature: 'MAX(number, number, ...)', description: 'The largest argument.' },
    { label: 'MIN', signature: 'MIN(number, number, ...)', description: 'The smallest argument.' }
];

/**
 * The editor for one visibility formula: a plain text area, with every value
 * it can reference offered from real metadata instead of typed from memory.
 *
 * It deliberately offers only what c/V360FormulaGateway enables -- fields of
 * the anchor SObject, and the four identity globals ($Permission for a Custom
 * Permission, $Profile, $User, $UserRole). Permission set membership is not
 * expressible in a formula at all; that is the PERMISSION_SET predicate's job,
 * so no permission set appears here.
 *
 * The component holds no server calls of its own beyond reading that
 * vocabulary: validating and saving belong to whoever owns the rule, and are
 * requested through events.
 */
export default class V360FormulaEditor extends LightningElement {
    /** API name of the SObject the formula is built against. */
    @api anchorSObject;

    /** Verdict text from the last server-side check, if any. */
    @api feedbackMessage;

    /** Whether that verdict was a pass. */
    @api feedbackValid = false;

    /** Disables every control while the owner has a call in flight. */
    @api busy = false;

    draft = '';
    vocabulary = { customPermissions: [], profiles: [] };
    pendingCaret;

    @api
    get formula() {
        return this.draft;
    }
    set formula(value) {
        this.draft = value ?? '';
    }

    /** The current text, for an owner that would rather pull than listen. */
    @api
    get value() {
        return this.draft;
    }

    @wire(getFormulaVocabulary)
    wiredVocabulary({ data }) {
        if (data) {
            this.vocabulary = data;
        }
    }

    @wire(getObjectInfo, { objectApiName: '$anchorSObject' })
    anchorInfo;

    @wire(getObjectInfo, { objectApiName: 'User' })
    userInfo;

    // ---- the text area ----------------------------------------------------

    handleInput(event) {
        this.draft = event.target.value;
        this.dispatchEvent(new CustomEvent('formulachange', { detail: { value: this.draft } }));
    }

    get characterCount() {
        return `${this.draft.length} / ${MAX_FORMULA_LENGTH}`;
    }

    /** The platform rejects a longer formula, so warn before the round trip. */
    get isOverLength() {
        return this.draft.length > MAX_FORMULA_LENGTH;
    }

    /**
     * The count never wraps: it shares a flex row with helper copy that grew
     * long enough to squeeze "28 / 3900" onto two lines. The classes belong
     * here rather than beside class={countClass} in the template, because a
     * static class next to a bound one is discarded.
     */
    get countClass() {
        const base = 'slds-text-body_small slds-shrink-none slds-m-left_x-small';
        return this.isOverLength ? `${base} slds-text-color_error` : `${base} slds-text-color_weak`;
    }

    get feedbackClass() {
        return this.feedbackValid
            ? 'slds-text-body_small slds-text-color_success slds-m-top_x-small'
            : 'slds-text-body_small slds-text-color_error slds-m-top_x-small';
    }

    /**
     * Drops text where the caret is rather than appending, because a formula is
     * built in the middle of itself far more often than at the end. The caret
     * lands after the inserted text so typing continues naturally.
     */
    insertAtCursor(text) {
        const area = this.template.querySelector('[data-id="formula"]');
        const start = area?.selectionStart ?? this.draft.length;
        const end = area?.selectionEnd ?? this.draft.length;
        this.draft = `${this.draft.slice(0, start)}${text}${this.draft.slice(end)}`;
        this.pendingCaret = start + text.length;
        this.dispatchEvent(new CustomEvent('formulachange', { detail: { value: this.draft } }));
    }

    /**
     * A native textarea has no value content attribute -- its text is a child
     * node and `value` exists only as a property -- so the template cannot
     * bind it and the property has to be written here. Guarded on a real
     * difference: assigning during typing would move the caret to the end on
     * every keystroke.
     *
     * The caret restore runs after, because an insert replaces the whole value
     * and the browser drops the selection when it does.
     */
    renderedCallback() {
        const area = this.template.querySelector('[data-id="formula"]');
        if (!area) {
            return;
        }
        if (area.value !== this.draft) {
            area.value = this.draft;
        }
        if (this.pendingCaret !== undefined) {
            area.focus();
            area.setSelectionRange(this.pendingCaret, this.pendingCaret);
            this.pendingCaret = undefined;
        }
    }

    /** Every helper reports the same way: one chosen value, dropped at the caret. */
    handleInsertSelection(event) {
        this.insertAtCursor(event.detail.value);
    }

    // ---- what each helper offers -----------------------------------------

    /**
     * Fields of the anchor object. The formula reads the record, so the API
     * name is what gets inserted while the label is what gets searched -- an
     * admin knows the field as "Annual Revenue", not AnnualRevenue.
     */
    get fieldOptions() {
        const fields = this.anchorInfo?.data?.fields ?? {};
        return (
            this.formulaSafe(Object.values(fields)).map((field) => ({
                key: field.apiName,
                label: field.label,
                detail: `${field.apiName} · ${field.dataType}`,
                insertText: field.apiName
            }))
        );
    }

    /**
     * getObjectInfo describes every field the user can read, which is not the
     * same set a formula can reference. Two families are dropped because the
     * engine rejects them and offering them would send an admin to Check
     * Syntax to find out:
     *
     *   - Compound fields (a Name or an Address) have no scalar value; their
     *     components are separate fields and those stay on the list.
     *   - The UserPreferences* family is not exposed to formulas at all,
     *     despite existing on the record.
     *
     * Custom fields are always kept: a custom field on any object, User
     * included, is formula-accessible.
     *
     * This narrows the list, it does not guarantee it. There is no
     * formula-availability flag in getObjectInfo, so Check Syntax stays the
     * authority -- this only stops the menu from proposing what is already
     * known to fail.
     */
    formulaSafe(fields) {
        return fields.filter(
            (field) => !field.compound && (field.custom || !field.apiName.startsWith('UserPreferences'))
        );
    }

    /**
     * The four identity globals, in the order an admin reaches for them: a
     * custom permission is the usual answer, a profile the blunt one.
     */
    get identityOptions() {
        const userFields = this.formulaSafe(Object.values(this.userInfo?.data?.fields ?? {})).map((field) => ({
            key: `user-${field.apiName}`,
            label: `$User.${field.apiName}`,
            detail: field.label,
            insertText: `$User.${field.apiName}`
        }));
        const permissions = (this.vocabulary.customPermissions ?? []).map((entry) => ({
            key: `perm-${entry.apiName}`,
            label: entry.label,
            detail: entry.insertText,
            insertText: entry.insertText
        }));
        const profiles = (this.vocabulary.profiles ?? []).map((entry) => ({
            key: `profile-${entry.apiName}`,
            label: entry.label,
            detail: entry.insertText,
            insertText: entry.insertText
        }));
        return ([...permissions, ...profiles, ...userFields]);
    }

    get functionOptions() {
        return (
            FUNCTIONS.map((fn) => ({
                key: fn.label,
                label: fn.signature,
                detail: fn.description,
                // The caret would sit after the closing bracket; leaving the
                // call open is what an admin does next anyway.
                insertText: `${fn.label}(`
            }))
        );
    }

    get operatorOptions() {
        return (
            OPERATORS.map((operator) => ({
                key: operator.label,
                label: operator.label,
                detail: '',
                insertText: operator.insertText
            }))
        );
    }


    get anchorLabel() {
        return this.anchorInfo?.data?.label ?? this.anchorSObject;
    }

    // ---- handing back to the owner ---------------------------------------

    handleValidate() {
        this.dispatchEvent(new CustomEvent('validate', { detail: { value: this.draft } }));
    }

    handleSave() {
        this.dispatchEvent(new CustomEvent('save', { detail: { value: this.draft } }));
    }
}
