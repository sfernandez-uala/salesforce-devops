import { LightningElement } from 'lwc';

/**
 * CSS-only shared module for Vista 360's chrome: no template, no logic, and
 * never rendered as a component in its own right. It exists purely so
 * custom CSS shared across Vista 360 components has exactly one home.
 * Consumers pull it into their own stylesheet with `@import 'c/v360Styles';`
 * rather than duplicating rules or reaching for inline styles.
 */
export default class V360Styles extends LightningElement {}
