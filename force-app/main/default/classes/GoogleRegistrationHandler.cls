/**
 * Registration handler for Google SSO authentication.
 * Creates or updates community users based on Google profile data.
 * Links users to Contact records and determines if user is a Stylist or Customer.
 */
global class GoogleRegistrationHandler implements Auth.RegistrationHandler {

    private static final String CUSTOMER_PROFILE_NAME = 'Customer Community Login User';
    private static final String STYLIST_PROFILE_NAME = 'Customer Community Login User';
    private static final String CUSTOMER_PERMISSION_SET = 'Stressless_Customer';
    private static final String STYLIST_PERMISSION_SET = 'Stressless_Stylist';

    /**
     * Creates a new community user when someone signs in via Google for the first time.
     */
    global User createUser(Id portalId, Auth.UserData data) {
        if (data == null || String.isBlank(data.email)) {
            throw new Auth.AuthProviderPluginException('Email is required for registration');
        }

        String email = data.email.toLowerCase().trim();

        // Find or create Contact
        Contact userContact = findOrCreateContact(data);

        // Determine if this Contact is a Stylist
        Boolean isStylist = checkIfStylist(userContact.Id);

        // Get the appropriate profile
        String profileName = isStylist ? STYLIST_PROFILE_NAME : CUSTOMER_PROFILE_NAME;
        Profile userProfile = [SELECT Id FROM Profile WHERE Name = :profileName LIMIT 1];

        // Create the User
        User newUser = new User();
        newUser.ProfileId = userProfile.Id;
        newUser.ContactId = userContact.Id;
        newUser.Email = email;
        newUser.Username = email + '.stressless';
        newUser.FirstName = data.firstName;
        newUser.LastName = data.lastName;
        newUser.Alias = generateAlias(data.firstName, data.lastName);
        newUser.EmailEncodingKey = 'UTF-8';
        newUser.LanguageLocaleKey = 'en_US';
        newUser.LocaleSidKey = 'en_US';
        newUser.TimeZoneSidKey = 'America/Los_Angeles';
        newUser.IsActive = true;

        return newUser;
    }

    /**
     * Updates an existing user when they sign in again via Google.
     */
    global void updateUser(Id userId, Id portalId, Auth.UserData data) {
        if (data == null || String.isBlank(data.email)) {
            return;
        }

        User existingUser = [SELECT Id, ContactId, ProfileId FROM User WHERE Id = :userId LIMIT 1];

        // Check if user type has changed (e.g., Customer became a Stylist)
        if (existingUser.ContactId != null) {
            Boolean isStylist = checkIfStylist(existingUser.ContactId);
            String expectedProfileName = isStylist ? STYLIST_PROFILE_NAME : CUSTOMER_PROFILE_NAME;
            Profile expectedProfile = [SELECT Id FROM Profile WHERE Name = :expectedProfileName LIMIT 1];

            if (existingUser.ProfileId != expectedProfile.Id) {
                existingUser.ProfileId = expectedProfile.Id;
                update existingUser;
            }
        }
    }

    /**
     * Finds an existing Contact by email or creates a new one.
     */
    private Contact findOrCreateContact(Auth.UserData data) {
        String email = data.email.toLowerCase().trim();

        List<Contact> existingContacts = [
            SELECT Id, FirstName, LastName, Email
            FROM Contact
            WHERE Email = :email
            LIMIT 1
        ];

        if (!existingContacts.isEmpty()) {
            return existingContacts[0];
        }

        // Create new Contact for this customer
        Contact newContact = new Contact();
        newContact.FirstName = String.isNotBlank(data.firstName) ? data.firstName : 'Unknown';
        newContact.LastName = String.isNotBlank(data.lastName) ? data.lastName : 'Customer';
        newContact.Email = email;

        insert newContact;
        return newContact;
    }

    /**
     * Checks if the Contact has an active Stylist record.
     */
    private Boolean checkIfStylist(Id contactId) {
        List<Stylist__c> stylists = [
            SELECT Id
            FROM Stylist__c
            WHERE Contact__c = :contactId
            AND Active__c = true
            LIMIT 1
        ];

        return !stylists.isEmpty();
    }

    /**
     * Generates a valid alias from first and last name.
     */
    private String generateAlias(String firstName, String lastName) {
        String alias = '';

        if (String.isNotBlank(firstName)) {
            alias += firstName.left(1);
        }
        if (String.isNotBlank(lastName)) {
            alias += lastName.left(4);
        }

        if (String.isBlank(alias)) {
            alias = 'user';
        }

        return alias.toLowerCase();
    }
}
