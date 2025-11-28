Google_Auth_Settings__c settings = Google_Auth_Settings__c.getOrgDefaults();
System.debug('Client ID: ' + settings?.Client_ID__c);
System.debug('Settings ID: ' + settings?.Id);
