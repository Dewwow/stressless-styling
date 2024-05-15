from cumulusci.tasks.salesforce import BaseSalesforceApiTask
from cumulusci.core.exceptions import TaskOptionsError

class UpdateUserDebugMode(BaseSalesforceApiTask):
    def _run_task(self):
        # Query for the user with the alias 'UUser'
        query = "SELECT Id FROM User WHERE Alias = 'UUser' LIMIT 1"
        result = self.sf.query(query)
        
        if not result['records']:
            raise TaskOptionsError("No user found with alias 'UUser'")
        
        user_id = result['records'][0]['Id']
        self.logger.info(f"Updating debug mode for user {user_id}")
        
        # Update the UserPreferencesUserDebugModePref field to True
        update_result = self.sf.User.update(user_id, {
            'UserPreferencesUserDebugModePref': True
        })
        
        self.logger.info(f"Update result: {update_result}")