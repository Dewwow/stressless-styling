// Set the Google Client ID in Custom Settings
// Run this after creating a scratch org: cci task run execute_anon --path scripts/set_google_client_id.apex --org dev
// Replace YOUR_GOOGLE_CLIENT_ID with your actual Google OAuth Client ID

String clientId = 'YOUR_GOOGLE_CLIENT_ID';

Google_Auth_Settings__c settings = Google_Auth_Settings__c.getOrgDefaults();
if (settings.Id == null) {
    settings = new Google_Auth_Settings__c();
}
settings.Client_ID__c = clientId;
upsert settings;

System.debug('Google Client ID has been set in Custom Settings');
