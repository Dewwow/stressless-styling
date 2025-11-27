# Stressless Styling - Object Model

## Overview
Data model for the Stressless Styling salon management app.

## Custom Objects

### Preferences__c
Stores customer preferences for salon services.

| Field | Type | Description |
|-------|------|-------------|
| Contact__c | Lookup(Contact) | Link to customer contact record |
| Hair_Length__c | Picklist | Customer's hair length preference |

## Standard Objects Used

### Contact
Represents customers and employees (stylists).

### Account
Represents salon locations (if multi-location support needed).

## Relationships Diagram

```
Contact (Customer)
    └── Preferences__c (1:many)
```

---
*More objects to be added as development progresses.*
