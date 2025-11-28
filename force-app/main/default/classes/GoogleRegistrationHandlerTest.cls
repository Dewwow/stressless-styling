/**
 * Test class for GoogleRegistrationHandler.
 * Tests user creation for both new customers and existing stylists.
 */
@isTest
private class GoogleRegistrationHandlerTest {

    @TestSetup
    static void setupTestData() {
        // Create a Contact that will be a Stylist
        Contact stylistContact = new Contact(
            FirstName = 'Maria',
            LastName = 'Santos',
            Email = 'maria.santos@example.com'
        );
        insert stylistContact;

        // Create the Stylist record
        Stylist__c stylist = new Stylist__c(
            Name = 'Maria Santos',
            Contact__c = stylistContact.Id,
            Active__c = true,
            Title__c = 'Senior Stylist'
        );
        insert stylist;

        // Create a Contact that is just a Customer (no Stylist record)
        Contact customerContact = new Contact(
            FirstName = 'Sarah',
            LastName = 'Johnson',
            Email = 'sarah.johnson@example.com'
        );
        insert customerContact;
    }

    @isTest
    static void testCreateUser_NewCustomer() {
        // Test creating a user for someone who doesn't have a Contact yet
        GoogleRegistrationHandler handler = new GoogleRegistrationHandler();

        Auth.UserData userData = new Auth.UserData(
            'google-id-123',           // identifier
            'John',                     // firstName
            'Doe',                      // lastName
            'John Doe',                 // fullName
            'john.doe@example.com',     // email
            null,                       // link
            null,                       // username
            null,                       // locale
            'Google',                   // provider
            null,                       // siteLoginUrl
            new Map<String, String>()   // attributeMap
        );

        Test.startTest();
        User newUser = handler.createUser(null, userData);
        Test.stopTest();

        System.assertNotEquals(null, newUser, 'User should be created');
        System.assertEquals('john.doe@example.com', newUser.Email, 'Email should match');
        System.assertEquals('John', newUser.FirstName, 'First name should match');
        System.assertEquals('Doe', newUser.LastName, 'Last name should match');
        System.assertNotEquals(null, newUser.ContactId, 'User should be linked to a Contact');

        // Verify Contact was created
        Contact createdContact = [SELECT Id, Email FROM Contact WHERE Email = 'john.doe@example.com'];
        System.assertNotEquals(null, createdContact, 'Contact should be created');
    }

    @isTest
    static void testCreateUser_ExistingCustomer() {
        // Test creating a user for an existing Customer Contact
        GoogleRegistrationHandler handler = new GoogleRegistrationHandler();

        Auth.UserData userData = new Auth.UserData(
            'google-id-456',
            'Sarah',
            'Johnson',
            'Sarah Johnson',
            'sarah.johnson@example.com',
            null,
            null,
            null,
            'Google',
            null,
            new Map<String, String>()
        );

        Test.startTest();
        User newUser = handler.createUser(null, userData);
        Test.stopTest();

        System.assertNotEquals(null, newUser, 'User should be created');
        System.assertEquals('sarah.johnson@example.com', newUser.Email, 'Email should match');

        // Verify it linked to existing Contact (not created a new one)
        List<Contact> contacts = [SELECT Id FROM Contact WHERE Email = 'sarah.johnson@example.com'];
        System.assertEquals(1, contacts.size(), 'Should use existing Contact, not create new one');
    }

    @isTest
    static void testCreateUser_ExistingStylist() {
        // Test creating a user for an existing Stylist Contact
        GoogleRegistrationHandler handler = new GoogleRegistrationHandler();

        Auth.UserData userData = new Auth.UserData(
            'google-id-789',
            'Maria',
            'Santos',
            'Maria Santos',
            'maria.santos@example.com',
            null,
            null,
            null,
            'Google',
            null,
            new Map<String, String>()
        );

        Test.startTest();
        User newUser = handler.createUser(null, userData);
        Test.stopTest();

        System.assertNotEquals(null, newUser, 'User should be created');
        System.assertEquals('maria.santos@example.com', newUser.Email, 'Email should match');

        // Verify it linked to existing Contact
        Contact existingContact = [SELECT Id FROM Contact WHERE Email = 'maria.santos@example.com'];
        System.assertEquals(existingContact.Id, newUser.ContactId, 'Should link to existing Stylist Contact');
    }

    @isTest
    static void testCreateUser_NullEmail() {
        // Test that null email throws an exception
        GoogleRegistrationHandler handler = new GoogleRegistrationHandler();

        Auth.UserData userData = new Auth.UserData(
            'google-id-000',
            'Test',
            'User',
            'Test User',
            null,  // null email
            null,
            null,
            null,
            'Google',
            null,
            new Map<String, String>()
        );

        Test.startTest();
        try {
            User newUser = handler.createUser(null, userData);
            System.assert(false, 'Should have thrown exception for null email');
        } catch (Auth.AuthProviderPluginException e) {
            System.assert(e.getMessage().contains('Email is required'), 'Should throw email required error');
        }
        Test.stopTest();
    }

    @isTest
    static void testUpdateUser() {
        // Test the updateUser method (called on subsequent logins)
        GoogleRegistrationHandler handler = new GoogleRegistrationHandler();

        // First create a user
        Auth.UserData userData = new Auth.UserData(
            'google-id-update',
            'Update',
            'Test',
            'Update Test',
            'update.test@example.com',
            null,
            null,
            null,
            'Google',
            null,
            new Map<String, String>()
        );

        Test.startTest();
        // This just tests that updateUser doesn't throw an error
        // In a real scenario, we'd need a valid user ID
        handler.updateUser(null, null, userData);
        Test.stopTest();

        // If we get here without exception, the test passes
        System.assert(true, 'updateUser should complete without error for null userId');
    }
}
