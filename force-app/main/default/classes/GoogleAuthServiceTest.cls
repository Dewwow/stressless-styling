@isTest
private class GoogleAuthServiceTest {

    @TestSetup
    static void makeData() {
        // Create test Account
        Account testAccount = new Account(Name = 'Stressless Styling Customers');
        insert testAccount;

        // Create test Contact
        Contact testContact = new Contact(
            FirstName = 'Test',
            LastName = 'Customer',
            Email = 'test@example.com',
            AccountId = testAccount.Id
        );
        insert testContact;

        // Create test Stylist Contact
        Contact stylistContact = new Contact(
            FirstName = 'Test',
            LastName = 'Stylist',
            Email = 'stylist@example.com',
            AccountId = testAccount.Id
        );
        insert stylistContact;

        // Create Stylist record
        Stylist__c testStylist = new Stylist__c(
            Contact__c = stylistContact.Id,
            Title__c = 'Senior Stylist',
            Active__c = true
        );
        insert testStylist;
    }

    @isTest
    static void testInitializeSession_NewCustomer() {
        Test.startTest();
        GoogleAuthService.UserSession session = GoogleAuthService.initializeSession(
            'newcustomer@example.com',
            'New',
            'Customer'
        );
        Test.stopTest();

        System.assertNotEquals(null, session, 'Session should not be null');
        System.assertEquals('newcustomer@example.com', session.email, 'Email should match');
        System.assertEquals('New', session.firstName, 'First name should match');
        System.assertEquals('Customer', session.lastName, 'Last name should match');
        System.assertNotEquals(null, session.contactId, 'Contact ID should be created');
        System.assertEquals(true, session.isCustomer, 'Should be identified as customer');
        System.assertEquals(false, session.isStylist, 'Should not be identified as stylist');
        System.assertEquals('Customer', session.userType, 'User type should be Customer');
    }

    @isTest
    static void testInitializeSession_ExistingCustomer() {
        Test.startTest();
        GoogleAuthService.UserSession session = GoogleAuthService.initializeSession(
            'test@example.com',
            'Test',
            'Customer'
        );
        Test.stopTest();

        System.assertNotEquals(null, session, 'Session should not be null');
        System.assertEquals('test@example.com', session.email, 'Email should match');
        System.assertEquals('Test', session.firstName, 'First name should match existing contact');
        System.assertEquals('Customer', session.lastName, 'Last name should match existing contact');
        System.assertEquals(true, session.isCustomer, 'Should be identified as customer');
        System.assertEquals(false, session.isStylist, 'Should not be identified as stylist');
    }

    @isTest
    static void testInitializeSession_Stylist() {
        Test.startTest();
        GoogleAuthService.UserSession session = GoogleAuthService.initializeSession(
            'stylist@example.com',
            'Test',
            'Stylist'
        );
        Test.stopTest();

        System.assertNotEquals(null, session, 'Session should not be null');
        System.assertEquals('stylist@example.com', session.email, 'Email should match');
        System.assertEquals(false, session.isCustomer, 'Should not be identified as customer');
        System.assertEquals(true, session.isStylist, 'Should be identified as stylist');
        System.assertEquals('Stylist', session.userType, 'User type should be Stylist');
        System.assertNotEquals(null, session.stylistId, 'Stylist ID should be set');
        System.assertEquals('Senior Stylist', session.title, 'Title should match');
    }

    @isTest
    static void testInitializeSession_BlankEmail() {
        Test.startTest();
        try {
            GoogleAuthService.initializeSession('', 'Test', 'User');
            System.assert(false, 'Should have thrown exception');
        } catch (AuraHandledException e) {
            System.assert(e.getMessage().contains('Email is required') || e.getMessage().contains('Script-thrown exception'), 'Error should be thrown for blank email');
        }
        Test.stopTest();
    }

    @isTest
    static void testInitializeSession_NullEmail() {
        Test.startTest();
        try {
            GoogleAuthService.initializeSession(null, 'Test', 'User');
            System.assert(false, 'Should have thrown exception');
        } catch (AuraHandledException e) {
            System.assert(e.getMessage().contains('Email is required') || e.getMessage().contains('Script-thrown exception'), 'Error should be thrown for null email');
        }
        Test.stopTest();
    }

    @isTest
    static void testGetSession_ExistingContact() {
        Test.startTest();
        GoogleAuthService.UserSession session = GoogleAuthService.getSession('test@example.com');
        Test.stopTest();

        System.assertNotEquals(null, session, 'Session should not be null');
        System.assertEquals('test@example.com', session.email, 'Email should match');
        System.assertEquals(true, session.isCustomer, 'Should be identified as customer');
    }

    @isTest
    static void testGetSession_NonExistentContact() {
        Test.startTest();
        GoogleAuthService.UserSession session = GoogleAuthService.getSession('nonexistent@example.com');
        Test.stopTest();

        System.assertEquals(null, session, 'Session should be null for non-existent contact');
    }

    @isTest
    static void testGetSession_BlankEmail() {
        Test.startTest();
        GoogleAuthService.UserSession session = GoogleAuthService.getSession('');
        Test.stopTest();

        System.assertEquals(null, session, 'Session should be null for blank email');
    }

    @isTest
    static void testClearSession() {
        Test.startTest();
        // Just verify it doesn't throw an error
        GoogleAuthService.clearSession('test@example.com');
        Test.stopTest();

        // No assertions needed - method is placeholder for future functionality
        System.assert(true, 'Clear session should complete without error');
    }

    @isTest
    static void testInitializeSession_CreatesAccountIfNeeded() {
        // Delete the test account to test auto-creation
        delete [SELECT Id FROM Account WHERE Name = 'Stressless Styling Customers'];

        Test.startTest();
        GoogleAuthService.UserSession session = GoogleAuthService.initializeSession(
            'newuser@example.com',
            'New',
            'User'
        );
        Test.stopTest();

        // Verify account was created
        List<Account> accounts = [SELECT Id FROM Account WHERE Name = 'Stressless Styling Customers'];
        System.assertEquals(1, accounts.size(), 'Account should be auto-created');
        System.assertNotEquals(null, session.contactId, 'Contact should be created');
    }

    @isTest
    static void testInitializeSession_CaseInsensitiveEmail() {
        Test.startTest();
        GoogleAuthService.UserSession session = GoogleAuthService.initializeSession(
            'TEST@EXAMPLE.COM',
            'Test',
            'User'
        );
        Test.stopTest();

        System.assertEquals('test@example.com', session.email, 'Email should be lowercased');
        // Should find existing contact, not create new one
        List<Contact> contacts = [SELECT Id FROM Contact WHERE Email = 'test@example.com'];
        System.assertEquals(1, contacts.size(), 'Should not create duplicate contact');
    }
}
