/**
 * Controller for the Dashboard LWC component.
 * Provides appointment data based on Contact/Stylist context.
 * Works with Guest User access - data filtering is controlled by Apex.
 */
public without sharing class DashboardController {

    /**
     * Gets upcoming appointments for a given contact (as customer).
     * @param contactId The Contact Id to get appointments for
     * @return List of AppointmentWrapper objects
     */
    @AuraEnabled
    public static List<AppointmentWrapper> getCustomerAppointments(Id contactId) {
        List<AppointmentWrapper> appointments = new List<AppointmentWrapper>();

        if (contactId == null) {
            return appointments;
        }

        for (Appointment__c apt : [
            SELECT Id, Name, Appointment_Date__c, Start_Time__c, Status__c, Notes__c,
                   Stylist__r.Name, Stylist__r.Title__c,
                   (SELECT Service__r.Name, Price__c, Duration_Minutes__c FROM Appointment_Services__r)
            FROM Appointment__c
            WHERE Customer__c = :contactId
            AND Appointment_Date__c >= TODAY
            AND Status__c != 'Cancelled'
            ORDER BY Appointment_Date__c, Start_Time__c
            LIMIT 10
        ]) {
            appointments.add(new AppointmentWrapper(apt, 'Customer'));
        }

        return appointments;
    }

    /**
     * Gets upcoming appointments for a given stylist.
     * @param stylistId The Stylist Id to get appointments for
     * @return List of AppointmentWrapper objects
     */
    @AuraEnabled
    public static List<AppointmentWrapper> getStylistAppointments(Id stylistId) {
        List<AppointmentWrapper> appointments = new List<AppointmentWrapper>();

        if (stylistId == null) {
            return appointments;
        }

        for (Appointment__c apt : [
            SELECT Id, Name, Appointment_Date__c, Start_Time__c, Status__c, Notes__c,
                   Customer__r.Name, Customer__r.Email, Customer__r.Phone,
                   (SELECT Service__r.Name, Price__c, Duration_Minutes__c FROM Appointment_Services__r)
            FROM Appointment__c
            WHERE Stylist__c = :stylistId
            AND Appointment_Date__c >= TODAY
            AND Status__c != 'Cancelled'
            ORDER BY Appointment_Date__c, Start_Time__c
            LIMIT 20
        ]) {
            appointments.add(new AppointmentWrapper(apt, 'Stylist'));
        }

        return appointments;
    }

    /**
     * Gets past appointments for a given contact (as customer).
     * @param contactId The Contact Id to get appointments for
     * @return List of AppointmentWrapper objects
     */
    @AuraEnabled
    public static List<AppointmentWrapper> getCustomerPastAppointments(Id contactId) {
        List<AppointmentWrapper> appointments = new List<AppointmentWrapper>();

        if (contactId == null) {
            return appointments;
        }

        for (Appointment__c apt : [
            SELECT Id, Name, Appointment_Date__c, Start_Time__c, Status__c, Notes__c,
                   Stylist__r.Name, Stylist__r.Title__c,
                   (SELECT Service__r.Name, Price__c, Duration_Minutes__c FROM Appointment_Services__r)
            FROM Appointment__c
            WHERE Customer__c = :contactId
            AND Appointment_Date__c < TODAY
            ORDER BY Appointment_Date__c DESC, Start_Time__c DESC
            LIMIT 10
        ]) {
            appointments.add(new AppointmentWrapper(apt, 'Customer'));
        }

        return appointments;
    }

    /**
     * Gets past appointments for a given stylist.
     * @param stylistId The Stylist Id to get appointments for
     * @return List of AppointmentWrapper objects
     */
    @AuraEnabled
    public static List<AppointmentWrapper> getStylistPastAppointments(Id stylistId) {
        List<AppointmentWrapper> appointments = new List<AppointmentWrapper>();

        if (stylistId == null) {
            return appointments;
        }

        for (Appointment__c apt : [
            SELECT Id, Name, Appointment_Date__c, Start_Time__c, Status__c, Notes__c,
                   Customer__r.Name, Customer__r.Email, Customer__r.Phone,
                   (SELECT Service__r.Name, Price__c, Duration_Minutes__c FROM Appointment_Services__r)
            FROM Appointment__c
            WHERE Stylist__c = :stylistId
            AND Appointment_Date__c < TODAY
            ORDER BY Appointment_Date__c DESC, Start_Time__c DESC
            LIMIT 20
        ]) {
            appointments.add(new AppointmentWrapper(apt, 'Stylist'));
        }

        return appointments;
    }

    /**
     * Gets all active stylists for customer booking/viewing.
     * @return List of StylistWrapper objects
     */
    @AuraEnabled(cacheable=true)
    public static List<StylistWrapper> getAvailableStylists() {
        List<StylistWrapper> stylists = new List<StylistWrapper>();

        for (Stylist__c stylist : [
            SELECT Id, Name, Title__c, Bio__c, Photo_URL__c,
                   (SELECT Service__r.Name, Service__r.Price__c FROM Stylist_Services__r)
            FROM Stylist__c
            WHERE Active__c = true
            ORDER BY Name
        ]) {
            stylists.add(new StylistWrapper(stylist));
        }

        return stylists;
    }

    /**
     * Gets all active services for booking.
     * @return List of ServiceCategoryWrapper objects
     */
    @AuraEnabled(cacheable=true)
    public static List<ServiceCategoryWrapper> getServiceCategories() {
        List<ServiceCategoryWrapper> categories = new List<ServiceCategoryWrapper>();

        for (Service_Category__c cat : [
            SELECT Id, Name, Description__c,
                   (SELECT Id, Name, Description__c, Price__c, Duration_Minutes__c
                    FROM Services__r
                    WHERE Active__c = true
                    ORDER BY Name)
            FROM Service_Category__c
            WHERE Active__c = true
            ORDER BY Name
        ]) {
            categories.add(new ServiceCategoryWrapper(cat));
        }

        return categories;
    }

    // Wrapper Classes

    public class AppointmentWrapper {
        @AuraEnabled public Id appointmentId;
        @AuraEnabled public String name;
        @AuraEnabled public Date appointmentDate;
        @AuraEnabled public Time startTime;
        @AuraEnabled public String status;
        @AuraEnabled public String notes;
        @AuraEnabled public String stylistName;
        @AuraEnabled public String stylistTitle;
        @AuraEnabled public String customerName;
        @AuraEnabled public String customerEmail;
        @AuraEnabled public String customerPhone;
        @AuraEnabled public List<ServiceWrapper> services;
        @AuraEnabled public Decimal totalPrice;
        @AuraEnabled public Integer totalDuration;

        public AppointmentWrapper(Appointment__c apt, String viewType) {
            this.appointmentId = apt.Id;
            this.name = apt.Name;
            this.appointmentDate = apt.Appointment_Date__c;
            this.startTime = apt.Start_Time__c;
            this.status = apt.Status__c;
            this.notes = apt.Notes__c;

            if (viewType == 'Customer') {
                this.stylistName = apt.Stylist__r?.Name;
                this.stylistTitle = apt.Stylist__r?.Title__c;
            } else if (viewType == 'Stylist') {
                this.customerName = apt.Customer__r?.Name;
                this.customerEmail = apt.Customer__r?.Email;
                this.customerPhone = apt.Customer__r?.Phone;
            }

            this.services = new List<ServiceWrapper>();
            this.totalPrice = 0;
            this.totalDuration = 0;

            if (apt.Appointment_Services__r != null) {
                for (Appointment_Service__c svc : apt.Appointment_Services__r) {
                    ServiceWrapper sw = new ServiceWrapper();
                    sw.serviceName = svc.Service__r?.Name;
                    sw.price = svc.Price__c;
                    sw.duration = Integer.valueOf(svc.Duration_Minutes__c);
                    this.services.add(sw);

                    if (svc.Price__c != null) {
                        this.totalPrice += svc.Price__c;
                    }
                    if (svc.Duration_Minutes__c != null) {
                        this.totalDuration += Integer.valueOf(svc.Duration_Minutes__c);
                    }
                }
            }
        }
    }

    public class ServiceWrapper {
        @AuraEnabled public String serviceName;
        @AuraEnabled public Decimal price;
        @AuraEnabled public Integer duration;
    }

    public class StylistWrapper {
        @AuraEnabled public Id stylistId;
        @AuraEnabled public String name;
        @AuraEnabled public String title;
        @AuraEnabled public String bio;
        @AuraEnabled public String photoUrl;
        @AuraEnabled public List<String> services;

        public StylistWrapper(Stylist__c stylist) {
            this.stylistId = stylist.Id;
            this.name = stylist.Name;
            this.title = stylist.Title__c;
            this.bio = stylist.Bio__c;
            this.photoUrl = stylist.Photo_URL__c;
            this.services = new List<String>();

            if (stylist.Stylist_Services__r != null) {
                for (Stylist_Service__c ss : stylist.Stylist_Services__r) {
                    if (ss.Service__r?.Name != null) {
                        this.services.add(ss.Service__r.Name);
                    }
                }
            }
        }
    }

    public class ServiceCategoryWrapper {
        @AuraEnabled public Id categoryId;
        @AuraEnabled public String name;
        @AuraEnabled public String description;
        @AuraEnabled public List<ServiceItemWrapper> services;

        public ServiceCategoryWrapper(Service_Category__c cat) {
            this.categoryId = cat.Id;
            this.name = cat.Name;
            this.description = cat.Description__c;
            this.services = new List<ServiceItemWrapper>();

            if (cat.Services__r != null) {
                for (Service__c svc : cat.Services__r) {
                    this.services.add(new ServiceItemWrapper(svc));
                }
            }
        }
    }

    public class ServiceItemWrapper {
        @AuraEnabled public Id serviceId;
        @AuraEnabled public String name;
        @AuraEnabled public String description;
        @AuraEnabled public Decimal price;
        @AuraEnabled public Integer duration;

        public ServiceItemWrapper(Service__c svc) {
            this.serviceId = svc.Id;
            this.name = svc.Name;
            this.description = svc.Description__c;
            this.price = svc.Price__c;
            this.duration = svc.Duration_Minutes__c != null ? Integer.valueOf(svc.Duration_Minutes__c) : 0;
        }
    }
}
