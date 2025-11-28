/**
 * Controller for appointment booking functionality.
 * Handles availability checking and appointment creation for Guest users.
 */
public without sharing class BookingController {

    /**
     * Get available time slots for a stylist on a specific date.
     * @param stylistId The stylist to check availability for
     * @param selectedDate The date to check
     * @param durationMinutes Total duration of services being booked
     * @return List of available time slots
     */
    @AuraEnabled
    public static List<TimeSlot> getAvailableSlots(Id stylistId, Date selectedDate, Integer durationMinutes) {
        List<TimeSlot> slots = new List<TimeSlot>();

        if (stylistId == null || selectedDate == null || durationMinutes == null) {
            return slots;
        }

        // Get the day of week for the selected date
        String dayOfWeek = getDayOfWeek(selectedDate);

        // Get stylist's availability for this day
        List<Stylist_Availability__c> availabilities = [
            SELECT Start_Time__c, End_Time__c
            FROM Stylist_Availability__c
            WHERE Stylist__c = :stylistId
            AND Day_of_Week__c = :dayOfWeek
            AND Active__c = true
            AND (Effective_Date__c = null OR Effective_Date__c <= :selectedDate)
            ORDER BY Start_Time__c
        ];

        if (availabilities.isEmpty()) {
            return slots;
        }

        // Get existing appointments for this stylist on this date
        List<Appointment__c> existingAppointments = [
            SELECT Start_Time__c, End_Time__c
            FROM Appointment__c
            WHERE Stylist__c = :stylistId
            AND Appointment_Date__c = :selectedDate
            AND Status__c NOT IN ('Cancelled', 'No Show')
            ORDER BY Start_Time__c
        ];

        // Generate available slots (30-minute intervals)
        Integer slotInterval = 30; // minutes

        for (Stylist_Availability__c avail : availabilities) {
            Time currentTime = avail.Start_Time__c;
            Time endTime = avail.End_Time__c;

            while (addMinutesToTime(currentTime, durationMinutes) <= endTime) {
                Time slotEnd = addMinutesToTime(currentTime, durationMinutes);

                // Check if this slot conflicts with existing appointments
                Boolean isAvailable = true;
                for (Appointment__c apt : existingAppointments) {
                    if (timesOverlap(currentTime, slotEnd, apt.Start_Time__c, apt.End_Time__c)) {
                        isAvailable = false;
                        break;
                    }
                }

                if (isAvailable) {
                    TimeSlot slot = new TimeSlot();
                    slot.startTime = currentTime;
                    slot.endTime = slotEnd;
                    slot.displayTime = formatTime(currentTime);
                    slot.value = String.valueOf(timeToMilliseconds(currentTime));
                    slots.add(slot);
                }

                currentTime = addMinutesToTime(currentTime, slotInterval);
            }
        }

        return slots;
    }

    /**
     * Create a new appointment with services.
     * @param customerId The Contact Id of the customer
     * @param stylistId The Stylist Id
     * @param appointmentDate The date of the appointment
     * @param startTimeMs Start time in milliseconds from midnight
     * @param serviceIds List of Service Ids to book
     * @param notes Optional notes for the appointment
     * @return The created Appointment Id
     */
    @AuraEnabled
    public static Id createAppointment(Id customerId, Id stylistId, Date appointmentDate,
                                       Long startTimeMs, List<Id> serviceIds, String notes) {

        if (customerId == null || stylistId == null || appointmentDate == null ||
            startTimeMs == null || serviceIds == null || serviceIds.isEmpty()) {
            throw new AuraHandledException('Missing required booking information');
        }

        // Get service details for duration calculation
        List<Service__c> services = [
            SELECT Id, Price__c, Duration_Minutes__c
            FROM Service__c
            WHERE Id IN :serviceIds
        ];

        // Calculate total duration
        Integer totalDuration = 0;
        for (Service__c svc : services) {
            totalDuration += svc.Duration_Minutes__c != null ? Integer.valueOf(svc.Duration_Minutes__c) : 0;
        }

        // Convert milliseconds to Time
        Time startTime = millisecondsToTime(startTimeMs);
        Time endTime = addMinutesToTime(startTime, totalDuration);

        // Verify the slot is still available
        List<TimeSlot> availableSlots = getAvailableSlots(stylistId, appointmentDate, totalDuration);
        Boolean slotStillAvailable = false;
        for (TimeSlot slot : availableSlots) {
            if (slot.startTime == startTime) {
                slotStillAvailable = true;
                break;
            }
        }

        if (!slotStillAvailable) {
            throw new AuraHandledException('This time slot is no longer available. Please select another time.');
        }

        // Create the appointment
        Appointment__c apt = new Appointment__c();
        apt.Customer__c = customerId;
        apt.Stylist__c = stylistId;
        apt.Appointment_Date__c = appointmentDate;
        apt.Start_Time__c = startTime;
        apt.End_Time__c = endTime;
        apt.Status__c = 'Scheduled';
        apt.Notes__c = notes;
        apt.Booked_Online__c = true;
        insert apt;

        // Create appointment services
        List<Appointment_Service__c> aptServices = new List<Appointment_Service__c>();
        for (Service__c svc : services) {
            Appointment_Service__c aptSvc = new Appointment_Service__c();
            aptSvc.Appointment__c = apt.Id;
            aptSvc.Service__c = svc.Id;
            aptSvc.Price__c = svc.Price__c;
            aptSvc.Duration_Minutes__c = svc.Duration_Minutes__c;
            aptServices.add(aptSvc);
        }
        insert aptServices;

        return apt.Id;
    }

    /**
     * Cancel an appointment.
     * @param appointmentId The appointment to cancel
     * @param reason Optional cancellation reason
     */
    @AuraEnabled
    public static void cancelAppointment(Id appointmentId, String reason) {
        if (appointmentId == null) {
            throw new AuraHandledException('Appointment ID is required');
        }

        List<Appointment__c> appointments = [
            SELECT Id, Status__c, Appointment_Date__c
            FROM Appointment__c
            WHERE Id = :appointmentId
            LIMIT 1
        ];

        if (appointments.isEmpty()) {
            throw new AuraHandledException('Appointment not found');
        }

        Appointment__c apt = appointments[0];

        // Check if appointment can be cancelled (not already cancelled or completed)
        if (apt.Status__c == 'Cancelled') {
            throw new AuraHandledException('This appointment is already cancelled');
        }
        if (apt.Status__c == 'Completed') {
            throw new AuraHandledException('Cannot cancel a completed appointment');
        }

        // Update the appointment
        apt.Status__c = 'Cancelled';
        apt.Cancellation_Reason__c = String.isNotBlank(reason) ? reason : 'Cancelled by customer';
        update apt;
    }

    // Helper methods

    private static String getDayOfWeek(Date d) {
        Datetime dt = Datetime.newInstance(d, Time.newInstance(12, 0, 0, 0));
        return dt.format('EEEE');
    }

    private static Time addMinutesToTime(Time t, Integer minutes) {
        Integer totalMinutes = t.hour() * 60 + t.minute() + minutes;
        Integer newHour = Math.mod(totalMinutes / 60, 24);
        Integer newMinute = Math.mod(totalMinutes, 60);
        return Time.newInstance(newHour, newMinute, 0, 0);
    }

    private static Boolean timesOverlap(Time start1, Time end1, Time start2, Time end2) {
        return start1 < end2 && end1 > start2;
    }

    private static String formatTime(Time t) {
        Integer hour = t.hour();
        Integer minute = t.minute();
        String ampm = hour >= 12 ? 'PM' : 'AM';
        Integer displayHour = Math.mod(hour, 12);
        if (displayHour == 0) displayHour = 12;
        return displayHour + ':' + String.valueOf(minute).leftPad(2, '0') + ' ' + ampm;
    }

    private static Long timeToMilliseconds(Time t) {
        return (Long)t.hour() * 3600000 + (Long)t.minute() * 60000 + (Long)t.second() * 1000;
    }

    private static Time millisecondsToTime(Long ms) {
        Integer hours = Integer.valueOf(ms / 3600000);
        Integer minutes = Integer.valueOf(Math.mod(ms, 3600000) / 60000);
        return Time.newInstance(hours, minutes, 0, 0);
    }

    // Wrapper class for time slots
    public class TimeSlot {
        @AuraEnabled public Time startTime;
        @AuraEnabled public Time endTime;
        @AuraEnabled public String displayTime;
        @AuraEnabled public String value;
    }
}
