/**
 * Test class for DashboardController.
 * Tests appointment queries and stylist retrieval for guest user access.
 */
@isTest
private class DashboardControllerTest {

    @TestSetup
    static void setupTestData() {
        // Create Service Category
        Service_Category__c category = new Service_Category__c(
            Name = 'Hair',
            Description__c = 'Hair services',
            Active__c = true
        );
        insert category;

        // Create Service
        Service__c service = new Service__c(
            Name = 'Haircut',
            Service_Category__c = category.Id,
            Price__c = 50,
            Duration_Minutes__c = 45,
            Active__c = true,
            Description__c = 'Standard haircut'
        );
        insert service;

        // Create Stylist Contact
        Contact stylistContact = new Contact(
            FirstName = 'Maria',
            LastName = 'Santos',
            Email = 'maria.santos@test.com'
        );
        insert stylistContact;

        // Create Stylist record
        Stylist__c stylist = new Stylist__c(
            Name = 'Maria Santos',
            Contact__c = stylistContact.Id,
            Title__c = 'Senior Stylist',
            Active__c = true,
            Bio__c = 'Expert colorist with 10 years experience'
        );
        insert stylist;

        // Create Stylist Service junction
        Stylist_Service__c stylistService = new Stylist_Service__c(
            Stylist__c = stylist.Id,
            Service__c = service.Id
        );
        insert stylistService;

        // Create Customer Contact
        Contact customerContact = new Contact(
            FirstName = 'Sarah',
            LastName = 'Johnson',
            Email = 'sarah.johnson@test.com',
            Phone = '555-1234'
        );
        insert customerContact;

        // Create upcoming Appointment
        Appointment__c upcomingApt = new Appointment__c(
            Customer__c = customerContact.Id,
            Stylist__c = stylist.Id,
            Appointment_Date__c = Date.today().addDays(7),
            Start_Time__c = Time.newInstance(10, 0, 0, 0),
            Status__c = 'Scheduled',
            Notes__c = 'Test appointment'
        );
        insert upcomingApt;

        // Create Appointment Service
        Appointment_Service__c aptService = new Appointment_Service__c(
            Appointment__c = upcomingApt.Id,
            Service__c = service.Id,
            Price__c = 50,
            Duration_Minutes__c = 45
        );
        insert aptService;

        // Create past Appointment
        Appointment__c pastApt = new Appointment__c(
            Customer__c = customerContact.Id,
            Stylist__c = stylist.Id,
            Appointment_Date__c = Date.today().addDays(-7),
            Start_Time__c = Time.newInstance(14, 0, 0, 0),
            Status__c = 'Completed'
        );
        insert pastApt;

        // Create past Appointment Service
        Appointment_Service__c pastAptService = new Appointment_Service__c(
            Appointment__c = pastApt.Id,
            Service__c = service.Id,
            Price__c = 50,
            Duration_Minutes__c = 45
        );
        insert pastAptService;
    }

    @isTest
    static void testGetCustomerAppointments() {
        Contact customer = [SELECT Id FROM Contact WHERE Email = 'sarah.johnson@test.com' LIMIT 1];

        Test.startTest();
        List<DashboardController.AppointmentWrapper> appointments =
            DashboardController.getCustomerAppointments(customer.Id);
        Test.stopTest();

        System.assertEquals(1, appointments.size(), 'Should return one upcoming appointment');
        System.assertEquals('Maria Santos', appointments[0].stylistName, 'Stylist name should be populated');
    }

    @isTest
    static void testGetCustomerAppointments_NullContactId() {
        Test.startTest();
        List<DashboardController.AppointmentWrapper> appointments =
            DashboardController.getCustomerAppointments(null);
        Test.stopTest();

        System.assertEquals(0, appointments.size(), 'Should return empty list for null contact');
    }

    @isTest
    static void testGetStylistAppointments() {
        Stylist__c stylist = [SELECT Id FROM Stylist__c WHERE Active__c = true LIMIT 1];

        Test.startTest();
        List<DashboardController.AppointmentWrapper> appointments =
            DashboardController.getStylistAppointments(stylist.Id);
        Test.stopTest();

        System.assertEquals(1, appointments.size(), 'Should return one upcoming appointment');
        System.assertEquals('Sarah Johnson', appointments[0].customerName, 'Customer name should be populated');
    }

    @isTest
    static void testGetStylistAppointments_NullStylistId() {
        Test.startTest();
        List<DashboardController.AppointmentWrapper> appointments =
            DashboardController.getStylistAppointments(null);
        Test.stopTest();

        System.assertEquals(0, appointments.size(), 'Should return empty list for null stylist');
    }

    @isTest
    static void testGetCustomerPastAppointments() {
        Contact customer = [SELECT Id FROM Contact WHERE Email = 'sarah.johnson@test.com' LIMIT 1];

        Test.startTest();
        List<DashboardController.AppointmentWrapper> appointments =
            DashboardController.getCustomerPastAppointments(customer.Id);
        Test.stopTest();

        System.assertEquals(1, appointments.size(), 'Should return one past appointment');
    }

    @isTest
    static void testGetCustomerPastAppointments_NullContactId() {
        Test.startTest();
        List<DashboardController.AppointmentWrapper> appointments =
            DashboardController.getCustomerPastAppointments(null);
        Test.stopTest();

        System.assertEquals(0, appointments.size(), 'Should return empty list for null contact');
    }

    @isTest
    static void testGetStylistPastAppointments() {
        Stylist__c stylist = [SELECT Id FROM Stylist__c WHERE Active__c = true LIMIT 1];

        Test.startTest();
        List<DashboardController.AppointmentWrapper> appointments =
            DashboardController.getStylistPastAppointments(stylist.Id);
        Test.stopTest();

        System.assertEquals(1, appointments.size(), 'Should return one past appointment');
        System.assertEquals('Sarah Johnson', appointments[0].customerName, 'Customer name should be populated');
    }

    @isTest
    static void testGetStylistPastAppointments_NullStylistId() {
        Test.startTest();
        List<DashboardController.AppointmentWrapper> appointments =
            DashboardController.getStylistPastAppointments(null);
        Test.stopTest();

        System.assertEquals(0, appointments.size(), 'Should return empty list for null stylist');
    }

    @isTest
    static void testGetAvailableStylists() {
        Test.startTest();
        List<DashboardController.StylistWrapper> stylists =
            DashboardController.getAvailableStylists();
        Test.stopTest();

        System.assertEquals(1, stylists.size(), 'Should return one active stylist');
        System.assertEquals('Maria Santos', stylists[0].name, 'Stylist name should match');
        System.assertEquals('Senior Stylist', stylists[0].title, 'Stylist title should match');
        System.assert(stylists[0].services.size() > 0, 'Stylist should have services');
    }

    @isTest
    static void testGetServiceCategories() {
        Test.startTest();
        List<DashboardController.ServiceCategoryWrapper> categories =
            DashboardController.getServiceCategories();
        Test.stopTest();

        System.assertEquals(1, categories.size(), 'Should return one active category');
        System.assertEquals('Hair', categories[0].name, 'Category name should match');
        System.assertEquals(1, categories[0].services.size(), 'Category should have one service');
        System.assertEquals('Haircut', categories[0].services[0].name, 'Service name should match');
    }

    @isTest
    static void testAppointmentWrapper_CustomerView() {
        Appointment__c apt = [
            SELECT Id, Name, Appointment_Date__c, Start_Time__c, Status__c, Notes__c,
                   Stylist__r.Name, Stylist__r.Title__c,
                   (SELECT Service__r.Name, Price__c, Duration_Minutes__c FROM Appointment_Services__r)
            FROM Appointment__c
            WHERE Status__c = 'Scheduled'
            LIMIT 1
        ];

        Test.startTest();
        DashboardController.AppointmentWrapper wrapper =
            new DashboardController.AppointmentWrapper(apt, 'Customer');
        Test.stopTest();

        System.assertEquals(apt.Id, wrapper.appointmentId, 'Appointment ID should match');
        System.assertEquals('Maria Santos', wrapper.stylistName, 'Stylist name should be populated');
        System.assertEquals(null, wrapper.customerName, 'Customer name should not be populated in customer view');
        System.assertEquals(50, wrapper.totalPrice, 'Total price should be calculated');
        System.assertEquals(45, wrapper.totalDuration, 'Total duration should be calculated');
    }

    @isTest
    static void testAppointmentWrapper_StylistView() {
        Appointment__c apt = [
            SELECT Id, Name, Appointment_Date__c, Start_Time__c, Status__c, Notes__c,
                   Customer__r.Name, Customer__r.Email, Customer__r.Phone,
                   (SELECT Service__r.Name, Price__c, Duration_Minutes__c FROM Appointment_Services__r)
            FROM Appointment__c
            WHERE Status__c = 'Scheduled'
            LIMIT 1
        ];

        Test.startTest();
        DashboardController.AppointmentWrapper wrapper =
            new DashboardController.AppointmentWrapper(apt, 'Stylist');
        Test.stopTest();

        System.assertEquals(apt.Id, wrapper.appointmentId, 'Appointment ID should match');
        System.assertEquals('Sarah Johnson', wrapper.customerName, 'Customer name should be populated');
        System.assertEquals(null, wrapper.stylistName, 'Stylist name should not be populated in stylist view');
    }

    @isTest
    static void testStylistWrapper() {
        Stylist__c stylist = [
            SELECT Id, Name, Title__c, Bio__c, Photo_URL__c,
                   (SELECT Service__r.Name, Service__r.Price__c FROM Stylist_Services__r)
            FROM Stylist__c
            WHERE Active__c = true
            LIMIT 1
        ];

        Test.startTest();
        DashboardController.StylistWrapper wrapper =
            new DashboardController.StylistWrapper(stylist);
        Test.stopTest();

        System.assertEquals(stylist.Id, wrapper.stylistId, 'Stylist ID should match');
        System.assertEquals('Maria Santos', wrapper.name, 'Name should match');
        System.assertEquals('Senior Stylist', wrapper.title, 'Title should match');
        System.assert(wrapper.services.size() > 0, 'Should have services listed');
    }

    @isTest
    static void testServiceCategoryWrapper() {
        Service_Category__c cat = [
            SELECT Id, Name, Description__c,
                   (SELECT Id, Name, Description__c, Price__c, Duration_Minutes__c
                    FROM Services__r WHERE Active__c = true)
            FROM Service_Category__c
            WHERE Active__c = true
            LIMIT 1
        ];

        Test.startTest();
        DashboardController.ServiceCategoryWrapper wrapper =
            new DashboardController.ServiceCategoryWrapper(cat);
        Test.stopTest();

        System.assertEquals(cat.Id, wrapper.categoryId, 'Category ID should match');
        System.assertEquals('Hair', wrapper.name, 'Name should match');
        System.assertEquals(1, wrapper.services.size(), 'Should have one service');
    }

    @isTest
    static void testServiceItemWrapper() {
        Service__c svc = [
            SELECT Id, Name, Description__c, Price__c, Duration_Minutes__c
            FROM Service__c
            WHERE Active__c = true
            LIMIT 1
        ];

        Test.startTest();
        DashboardController.ServiceItemWrapper wrapper =
            new DashboardController.ServiceItemWrapper(svc);
        Test.stopTest();

        System.assertEquals(svc.Id, wrapper.serviceId, 'Service ID should match');
        System.assertEquals('Haircut', wrapper.name, 'Name should match');
        System.assertEquals(50, wrapper.price, 'Price should match');
        System.assertEquals(45, wrapper.duration, 'Duration should match');
    }

    @isTest
    static void testServiceWrapper() {
        DashboardController.ServiceWrapper wrapper = new DashboardController.ServiceWrapper();
        wrapper.serviceName = 'Haircut';
        wrapper.price = 50;
        wrapper.duration = 45;

        System.assertEquals('Haircut', wrapper.serviceName, 'Service name should be set');
        System.assertEquals(50, wrapper.price, 'Price should be set');
        System.assertEquals(45, wrapper.duration, 'Duration should be set');
    }
}
