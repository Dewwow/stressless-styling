# Stressless Styling - Object Model

## Overview
Data model for the Stressless Styling salon management app.

## Entity Relationship Diagram

```
                    ┌──────────────────┐
                    │Service_Category__c│
                    └────────┬─────────┘
                             │ 1:many
                             ▼
┌─────────────┐      ┌──────────────────┐      ┌──────────────────────┐
│  Stylist__c │◄────►│    Service__c    │◄────►│Appointment_Service__c│
└──────┬──────┘      └──────────────────┘      └──────────┬───────────┘
       │                     ▲                            │
       │                     │                            │
       ▼                     │                            ▼
┌─────────────────┐  ┌───────┴───────┐          ┌─────────────────┐
│Stylist_Service__c│  │               │          │  Appointment__c │
│   (junction)    │──┘               └──────────│                 │
└─────────────────┘                             └────────┬────────┘
       │                                                 │
       ▼                                                 │
┌─────────────────────┐                                 ▼
│Stylist_Availability__c│                        ┌───────────┐
└─────────────────────┘                          │  Contact  │
                                                 │(Customer) │
                                                 └─────┬─────┘
                                                       │
                                                       ▼
                                                ┌──────────────┐
                                                │Preferences__c│
                                                └──────────────┘
```

## Custom Objects

### Service_Category__c
Groups salon services into categories.

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| Name | Text | Yes | Category name (e.g., Hair, Nails, Makeup) |
| Description__c | Text Area | No | Description of this category |
| Sort_Order__c | Number | No | Display order (default: 100) |
| Active__c | Checkbox | No | Whether category is active (default: true) |

---

### Service__c
Individual services offered by the salon.

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| Name | Text | Yes | Service name (e.g., Haircut, Color, Styling) |
| Service_Category__c | Lookup | No | Category this service belongs to |
| Price__c | Currency | Yes | Base price for this service |
| Duration_Minutes__c | Number | Yes | Estimated time in minutes |
| Description__c | Long Text | No | Detailed description |
| Sort_Order__c | Number | No | Display order within category |
| Active__c | Checkbox | No | Whether service is active (default: true) |

---

### Stylist__c
Staff members who provide salon services.

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| Name | Text | Yes | Stylist's display name |
| Contact__c | Lookup(Contact) | No | Personal contact info |
| Bio__c | Long Text | No | Professional bio for customers |
| Photo_URL__c | URL | No | Profile photo URL |
| Title__c | Picklist | No | Level: Junior, Stylist, Senior, Master, Director |
| Hire_Date__c | Date | No | Employment start date |
| Commission_Rate__c | Percent | No | Commission percentage |
| Active__c | Checkbox | No | Whether stylist is active (default: true) |

---

### Stylist_Service__c (Junction)
Links stylists to services they can perform.

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| Name | Auto Number | Yes | SS-0001 format |
| Stylist__c | Master-Detail | Yes | The stylist |
| Service__c | Master-Detail | Yes | The service |
| Price_Override__c | Currency | No | Custom price (blank = use standard) |
| Duration_Override__c | Number | No | Custom duration (blank = use standard) |

---

### Stylist_Availability__c
Working hours for each stylist by day of week.

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| Name | Auto Number | Yes | AVL-0001 format |
| Stylist__c | Master-Detail | Yes | The stylist |
| Day_of_Week__c | Picklist | Yes | Sunday through Saturday |
| Start_Time__c | Time | Yes | Shift start time |
| End_Time__c | Time | Yes | Shift end time |
| Effective_Date__c | Date | No | When schedule starts |
| Active__c | Checkbox | No | Whether entry is active (default: true) |

---

### Appointment__c
Customer appointment bookings.

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| Name | Auto Number | Yes | APT-00001 format |
| Customer__c | Lookup(Contact) | Yes | Customer contact |
| Stylist__c | Lookup(Stylist) | Yes | Assigned stylist |
| Appointment_Date__c | Date | Yes | Date of appointment |
| Start_Time__c | Time | Yes | Start time |
| End_Time__c | Time | No | End time |
| Status__c | Picklist | Yes | Scheduled, Confirmed, Checked In, In Progress, Completed, Cancelled, No Show |
| Total_Price__c | Currency | No | Sum of all services |
| Total_Duration__c | Number | No | Total minutes |
| Notes__c | Long Text | No | Special requests |
| Booked_Online__c | Checkbox | No | Booked via Experience Site |
| Confirmation_Sent__c | Checkbox | No | Email/SMS sent |
| Reminder_Sent__c | Checkbox | No | Reminder sent |
| Cancellation_Reason__c | Picklist | No | Customer Request, Stylist Unavailable, etc. |

---

### Appointment_Service__c (Junction)
Services included in an appointment with pricing captured at booking.

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| Name | Auto Number | Yes | AS-0001 format |
| Appointment__c | Master-Detail | Yes | Parent appointment |
| Service__c | Lookup | Yes | The service |
| Price__c | Currency | Yes | Price at time of booking |
| Duration_Minutes__c | Number | Yes | Duration at time of booking |
| Stylist_Service__c | Lookup | No | Specific stylist-service record |
| Notes__c | Text Area | No | Service-specific notes |

---

### Preferences__c
Customer preferences for salon services (historical tracking).

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| Name | Auto Number | Yes | PREF-0001 format |
| Contact__c | Master-Detail | Yes | Customer contact |
| Preference_Date__c | Date | No | When captured |
| Preferred_Stylist__c | Lookup | No | Preferred stylist |
| Hair_Type__c | Picklist | No | Straight, Wavy, Curly, Coily |
| Hair_Texture__c | Picklist | No | Fine, Medium, Coarse |
| Hair_Length__c | Number | No | Hair length |
| Scalp_Sensitivity__c | Picklist | No | Normal, Sensitive, Very Sensitive |
| Chemical_Treated__c | Checkbox | No | Has chemically treated hair |
| Communication_Preference__c | Picklist | No | Email, SMS, Phone, No Contact |
| Allergies_Notes__c | Long Text | No | Allergies and special notes |

---

## Standard Objects Used

### Contact
- **Customers**: People who book appointments
- **Related to**: Appointment__c (Customer), Stylist__c (optional link)

---

## Permission Sets

### Stressless_Styling_Admin
Full access to all Stressless Styling objects and fields. Assign to salon managers and administrators.
