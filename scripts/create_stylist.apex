// Find or create Contact for ejbantz@gmail.com
Contact c;
List<Contact> existingContacts = [SELECT Id, FirstName, LastName, Email FROM Contact WHERE Email = 'ejbantz@gmail.com' LIMIT 1];

if (existingContacts.isEmpty()) {
    // Need an Account first
    Account acc;
    List<Account> accounts = [SELECT Id FROM Account LIMIT 1];
    if (accounts.isEmpty()) {
        acc = new Account(Name = 'Stressless Styling Customers');
        insert acc;
    } else {
        acc = accounts[0];
    }

    c = new Contact(
        FirstName = 'EJ',
        LastName = 'Bantz',
        Email = 'ejbantz@gmail.com',
        AccountId = acc.Id
    );
    insert c;
    System.debug('Created new Contact: ' + c.Id);
} else {
    c = existingContacts[0];
    System.debug('Found existing Contact: ' + c.Id);
}

// Check if Stylist already exists for this contact
List<Stylist__c> existingStylists = [SELECT Id FROM Stylist__c WHERE Contact__c = :c.Id LIMIT 1];

if (existingStylists.isEmpty()) {
    Stylist__c stylist = new Stylist__c(
        Name = 'EJ Bantz',
        Contact__c = c.Id,
        Title__c = 'Master Stylist',
        Bio__c = 'With years of experience in hair styling, EJ specializes in modern cuts and color techniques.',
        Active__c = true
    );
    insert stylist;
    System.debug('Created new Stylist: ' + stylist.Id);
} else {
    System.debug('Stylist already exists: ' + existingStylists[0].Id);
}

System.debug('Setup complete! ejbantz@gmail.com is now configured as a stylist.');
