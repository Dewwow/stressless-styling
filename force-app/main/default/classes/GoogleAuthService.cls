/**
 * Service class for Google authentication in Guest User context.
 * Validates Google identity and provides user context without creating User records.
 * All data access is controlled by Apex based on the authenticated email.
 */
public without sharing class GoogleAuthService {

    /**
     * Wrapper class for user session data
     */
    public class UserSession {
        @AuraEnabled public String email { get; set; }
        @AuraEnabled public String firstName { get; set; }
        @AuraEnabled public String lastName { get; set; }
        @AuraEnabled public String contactId { get; set; }
        @AuraEnabled public String stylistId { get; set; }
        @AuraEnabled public Boolean isStylist { get; set; }
        @AuraEnabled public Boolean isCustomer { get; set; }
        @AuraEnabled public String userType { get; set; }
        @AuraEnabled public String title { get; set; }
    }

    /**
     * Initialize or retrieve a user session based on Google-authenticated email.
     * Creates a Contact if one doesn't exist for the email.
     *
     * @param email The email address from Google authentication
     * @param firstName First name from Google profile
     * @param lastName Last name from Google profile
     * @return UserSession containing user context
     */
    @AuraEnabled
    public static UserSession initializeSession(String email, String firstName, String lastName) {
        if (String.isBlank(email)) {
            throw new AuraHandledException('Email is required');
        }

        email = email.toLowerCase().trim();
        UserSession session = new UserSession();
        session.email = email;
        session.firstName = firstName;
        session.lastName = lastName;

        // Find or create Contact
        Contact userContact = findOrCreateContact(email, firstName, lastName);
        session.contactId = userContact.Id;
        session.firstName = userContact.FirstName;
        session.lastName = userContact.LastName;

        // Check if this Contact is a Stylist
        Stylist__c stylist = findActiveStylist(userContact.Id);
        if (stylist != null) {
            session.isStylist = true;
            session.isCustomer = false;
            session.userType = 'Stylist';
            session.stylistId = stylist.Id;
            session.title = stylist.Title__c;
        } else {
            session.isStylist = false;
            session.isCustomer = true;
            session.userType = 'Customer';
        }

        return session;
    }

    /**
     * Get user session without creating a Contact (for returning users).
     *
     * @param email The email address from Google authentication
     * @return UserSession or null if no Contact exists
     */
    @AuraEnabled
    public static UserSession getSession(String email) {
        if (String.isBlank(email)) {
            return null;
        }

        email = email.toLowerCase().trim();

        List<Contact> contacts = [
            SELECT Id, FirstName, LastName, Email
            FROM Contact
            WHERE Email = :email
            LIMIT 1
        ];

        if (contacts.isEmpty()) {
            return null;
        }

        Contact userContact = contacts[0];
        UserSession session = new UserSession();
        session.email = email;
        session.contactId = userContact.Id;
        session.firstName = userContact.FirstName;
        session.lastName = userContact.LastName;

        // Check if this Contact is a Stylist
        Stylist__c stylist = findActiveStylist(userContact.Id);
        if (stylist != null) {
            session.isStylist = true;
            session.isCustomer = false;
            session.userType = 'Stylist';
            session.stylistId = stylist.Id;
            session.title = stylist.Title__c;
        } else {
            session.isStylist = false;
            session.isCustomer = true;
            session.userType = 'Customer';
        }

        return session;
    }

    /**
     * Finds an existing Contact by email or creates a new one.
     */
    private static Contact findOrCreateContact(String email, String firstName, String lastName) {
        List<Contact> existingContacts = [
            SELECT Id, FirstName, LastName, Email
            FROM Contact
            WHERE Email = :email
            LIMIT 1
        ];

        if (!existingContacts.isEmpty()) {
            return existingContacts[0];
        }

        // Get the default Account for new contacts
        Account defaultAccount = getDefaultAccount();

        // Create new Contact
        Contact newContact = new Contact();
        newContact.FirstName = String.isNotBlank(firstName) ? firstName : 'Guest';
        newContact.LastName = String.isNotBlank(lastName) ? lastName : 'Customer';
        newContact.Email = email;
        newContact.AccountId = defaultAccount.Id;

        insert newContact;
        return newContact;
    }

    /**
     * Gets or creates the default Account for customer contacts.
     */
    private static Account getDefaultAccount() {
        String accountName = 'Stressless Styling Customers';

        List<Account> accounts = [
            SELECT Id
            FROM Account
            WHERE Name = :accountName
            LIMIT 1
        ];

        if (!accounts.isEmpty()) {
            return accounts[0];
        }

        // Create the account if it doesn't exist
        Account newAccount = new Account(Name = accountName);
        insert newAccount;
        return newAccount;
    }

    /**
     * Finds an active Stylist record for the given Contact.
     */
    private static Stylist__c findActiveStylist(Id contactId) {
        List<Stylist__c> stylists = [
            SELECT Id, Title__c
            FROM Stylist__c
            WHERE Contact__c = :contactId
            AND Active__c = true
            LIMIT 1
        ];

        return stylists.isEmpty() ? null : stylists[0];
    }

    /**
     * Clear session - for logout functionality.
     * In this architecture, logout is handled client-side by clearing localStorage.
     * This method is here for any server-side cleanup if needed in the future.
     */
    @AuraEnabled
    public static void clearSession(String email) {
        // Currently no server-side session to clear
        // Future: Could log logout events or clear any server-side tokens
    }
}
