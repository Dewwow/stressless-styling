// Verify the stylist setup
List<Contact> contacts = [SELECT Id, FirstName, LastName, Email FROM Contact WHERE Email = 'ejbantz@gmail.com'];
System.debug('Contact: ' + contacts);

List<Stylist__c> stylists = [SELECT Id, Name, Contact__c, Contact__r.Email, Title__c, Active__c FROM Stylist__c WHERE Contact__r.Email = 'ejbantz@gmail.com'];
System.debug('Stylist: ' + stylists);
