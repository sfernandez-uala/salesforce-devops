@IsTest
private class V360UserContextTest {

    private static final String TEST_PROFILE = 'Standard User';

    @IsTest
    static void hasPermissionSetReturnsTrueWhenUserHasAssignedPermissionSet() {
        // Given
        User grantedUser = V360TestDataFactory.insertUserWithAccess(TEST_PROFILE, new List<String>{ 'V360_Admin' });
        V360UserContext userContext = new V360UserContext();

        // When / Then
        System.runAs(grantedUser) {
            Test.startTest();
            Boolean result = userContext.hasPermissionSet('V360_Admin');
            Test.stopTest();
            Assert.isTrue(result, 'A user assigned the permission set should resolve true');
        }
    }

    @IsTest
    static void hasPermissionSetReturnsFalseWhenUserHasNoAssignedPermissionSet() {
        // Given
        User plainUser = V360TestDataFactory.insertUserWithAccess(TEST_PROFILE, null);
        V360UserContext userContext = new V360UserContext();

        // When / Then
        System.runAs(plainUser) {
            Test.startTest();
            Boolean result = userContext.hasPermissionSet('V360_Admin');
            Test.stopTest();
            Assert.isFalse(result, 'A user with no such assignment should resolve false');
        }
    }

    @IsTest
    static void hasPermissionSetReturnsFalseWhenApiNameIsBlank() {
        // Given
        V360UserContext userContext = new V360UserContext();

        // When
        Test.startTest();
        Boolean result = userContext.hasPermissionSet('');
        Test.stopTest();

        // Then
        Assert.isFalse(result, 'A blank API name must never resolve true');
    }

    @IsTest
    static void hasCustomPermissionReturnsTrueWhenUserHoldsGrantedCustomPermission() {
        // Given
        User grantedUser = V360TestDataFactory.insertUserWithAccess(TEST_PROFILE, new List<String>{ 'V360_Admin' });
        V360UserContext userContext = new V360UserContext();

        // When / Then
        System.runAs(grantedUser) {
            Test.startTest();
            Boolean result = userContext.hasCustomPermission('V360_ManageVisibilityRules');
            Test.stopTest();
            Assert.isTrue(result, 'A user assigned V360_Admin should hold its bundled custom permission');
        }
    }

    @IsTest
    static void hasCustomPermissionReturnsFalseWhenUserLacksCustomPermission() {
        // Given
        User plainUser = V360TestDataFactory.insertUserWithAccess(TEST_PROFILE, null);
        V360UserContext userContext = new V360UserContext();

        // When / Then
        System.runAs(plainUser) {
            Test.startTest();
            Boolean result = userContext.hasCustomPermission('V360_ManageVisibilityRules');
            Test.stopTest();
            Assert.isFalse(result, 'A user with no grant should not hold the custom permission');
        }
    }

    @IsTest
    static void hasProfileReturnsTrueWhenProfileNameMatches() {
        // Given
        User plainUser = V360TestDataFactory.insertUserWithAccess(TEST_PROFILE, null);
        V360UserContext userContext = new V360UserContext();

        // When / Then
        System.runAs(plainUser) {
            Test.startTest();
            Boolean result = userContext.hasProfile(TEST_PROFILE);
            Test.stopTest();
            Assert.isTrue(result, 'The user\'s own profile name should match');
        }
    }

    @IsTest
    static void hasProfileReturnsFalseWhenProfileNameDoesNotMatch() {
        // Given
        User plainUser = V360TestDataFactory.insertUserWithAccess(TEST_PROFILE, null);
        V360UserContext userContext = new V360UserContext();

        // When / Then
        System.runAs(plainUser) {
            Test.startTest();
            Boolean result = userContext.hasProfile('System Administrator');
            Test.stopTest();
            Assert.isFalse(result, 'A different profile name should not match');
        }
    }

    @IsTest
    static void isFieldReadableReturnsTrueWhenDirectFieldIsReadable() {
        // Given
        V360UserContext userContext = new V360UserContext();

        // When
        Test.startTest();
        Boolean result = userContext.isFieldReadable('Account', 'Name');
        Test.stopTest();

        // Then
        Assert.isTrue(result, 'Account.Name is readable to any authenticated user by default');
    }

    @IsTest
    static void isFieldReadableReturnsTrueWhenOneLevelParentFieldIsReadable() {
        // Given
        V360UserContext userContext = new V360UserContext();

        // When
        Test.startTest();
        Boolean result = userContext.isFieldReadable('Account', 'Parent.Name');
        Test.stopTest();

        // Then
        Assert.isTrue(result, 'A one-level parent traversal (Parent.Name) should resolve and be readable');
    }

    @IsTest
    static void isFieldReadableReturnsFalseWhenFieldDoesNotExist() {
        // Given
        V360UserContext userContext = new V360UserContext();

        // When
        Test.startTest();
        Boolean result = userContext.isFieldReadable('Account', 'Nonexistent_Field__c');
        Test.stopTest();

        // Then
        Assert.isFalse(result, 'An unknown field must fail closed as not readable');
    }

    @IsTest
    static void isFieldReadableReturnsFalseWhenSObjectApiNameIsBlank() {
        // Given
        V360UserContext userContext = new V360UserContext();

        // When
        Test.startTest();
        Boolean result = userContext.isFieldReadable('', 'Name');
        Test.stopTest();

        // Then
        Assert.isFalse(result, 'A blank SObject API name must fail closed as not readable');
    }
}
