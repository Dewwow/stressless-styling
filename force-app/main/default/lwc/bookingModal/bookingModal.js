import { LightningElement, api, track } from 'lwc';
import getAvailableStylists from '@salesforce/apex/DashboardController.getAvailableStylists';
import getServiceCategories from '@salesforce/apex/DashboardController.getServiceCategories';
import getAvailableSlots from '@salesforce/apex/BookingController.getAvailableSlots';
import createAppointment from '@salesforce/apex/BookingController.createAppointment';

export default class BookingModal extends LightningElement {
    @api contactId;

    @track isOpen = false;
    @track currentStep = 1;
    @track isLoading = false;
    @track error = '';

    // Data
    @track _stylists = [];
    @track serviceCategories = [];
    @track availableSlots = [];

    // Computed stylists with selection state
    get stylists() {
        return this._stylists.map(s => ({
            ...s,
            isSelected: s.stylistId === this.selectedStylistId,
            cardClass: s.stylistId === this.selectedStylistId ? 'slds-card stylist-card selected' : 'slds-card stylist-card'
        }));
    }

    // Selections
    @track selectedStylistId = null;
    @track selectedStylist = null;
    @track selectedServices = [];
    @track selectedDate = null;
    @track selectedSlot = null;
    @track notes = '';

    // Computed properties
    get stepTitle() {
        const titles = {
            1: 'Select a Stylist',
            2: 'Choose Services',
            3: 'Pick Date & Time',
            4: 'Confirm Booking'
        };
        return titles[this.currentStep];
    }

    get isStep1() { return this.currentStep === 1; }
    get isStep2() { return this.currentStep === 2; }
    get isStep3() { return this.currentStep === 3; }
    get isStep4() { return this.currentStep === 4; }

    get canGoBack() { return this.currentStep > 1; }
    get canGoNext() {
        if (this.currentStep === 1) return this.selectedStylistId !== null;
        if (this.currentStep === 2) return this.selectedServices.length > 0;
        if (this.currentStep === 3) return this.selectedSlot !== null;
        return false;
    }

    get disableNext() {
        return !this.canGoNext;
    }

    get nextButtonLabel() {
        return this.currentStep === 3 ? 'Review Booking' : 'Next';
    }

    get totalDuration() {
        return this.selectedServices.reduce((sum, svc) => sum + (svc.duration || 0), 0);
    }

    get totalPrice() {
        return this.selectedServices.reduce((sum, svc) => sum + (svc.price || 0), 0);
    }

    get formattedTotalPrice() {
        return '$' + this.totalPrice.toFixed(2);
    }

    get formattedTotalDuration() {
        return this.totalDuration + ' min';
    }

    get selectedServiceNames() {
        return this.selectedServices.map(s => s.name).join(', ');
    }

    get minDate() {
        const tomorrow = new Date();
        tomorrow.setDate(tomorrow.getDate() + 1);
        return tomorrow.toISOString().split('T')[0];
    }

    get maxDate() {
        const maxDate = new Date();
        maxDate.setDate(maxDate.getDate() + 60);
        return maxDate.toISOString().split('T')[0];
    }

    get formattedSelectedDate() {
        if (!this.selectedDate) return '';
        const date = new Date(this.selectedDate + 'T12:00:00');
        return date.toLocaleDateString('en-US', {
            weekday: 'long',
            month: 'long',
            day: 'numeric',
            year: 'numeric'
        });
    }

    get selectedSlotDisplay() {
        if (!this.selectedSlot) return '';
        const slot = this.availableSlots.find(s => s.value === this.selectedSlot);
        return slot ? slot.displayTime : '';
    }

    // Public methods
    @api
    open() {
        this.isOpen = true;
        this.resetBooking();
        this.loadStylists();
    }

    @api
    close() {
        this.isOpen = false;
        this.resetBooking();
    }

    // Data loading
    async loadStylists() {
        this.isLoading = true;
        try {
            this._stylists = await getAvailableStylists();
        } catch (err) {
            this.error = 'Error loading stylists';
            console.error(err);
        } finally {
            this.isLoading = false;
        }
    }

    async loadServices() {
        this.isLoading = true;
        try {
            this.serviceCategories = await getServiceCategories();
        } catch (err) {
            this.error = 'Error loading services';
            console.error(err);
        } finally {
            this.isLoading = false;
        }
    }

    async loadTimeSlots() {
        if (!this.selectedStylistId || !this.selectedDate || this.totalDuration === 0) {
            this.availableSlots = [];
            return;
        }

        this.isLoading = true;
        try {
            this.availableSlots = await getAvailableSlots({
                stylistId: this.selectedStylistId,
                selectedDate: this.selectedDate,
                durationMinutes: this.totalDuration
            });
        } catch (err) {
            this.error = 'Error loading available times';
            console.error(err);
        } finally {
            this.isLoading = false;
        }
    }

    // Event handlers
    handleClose() {
        this.close();
    }

    handleStylistSelect(event) {
        const stylistId = event.currentTarget.dataset.id;
        this.selectedStylistId = stylistId;
        this.selectedStylist = this.stylists.find(s => s.stylistId === stylistId);
    }

    handleServiceToggle(event) {
        const serviceId = event.currentTarget.dataset.id;
        const isChecked = event.target.checked;

        if (isChecked) {
            // Find the service in categories
            for (const cat of this.serviceCategories) {
                const service = cat.services.find(s => s.serviceId === serviceId);
                if (service) {
                    this.selectedServices = [...this.selectedServices, service];
                    break;
                }
            }
        } else {
            this.selectedServices = this.selectedServices.filter(s => s.serviceId !== serviceId);
        }
    }

    handleDateChange(event) {
        this.selectedDate = event.target.value;
        this.selectedSlot = null;
        this.loadTimeSlots();
    }

    handleSlotSelect(event) {
        this.selectedSlot = event.currentTarget.dataset.value;
    }

    handleNotesChange(event) {
        this.notes = event.target.value;
    }

    handleBack() {
        if (this.currentStep > 1) {
            this.currentStep--;
        }
    }

    handleNext() {
        if (this.currentStep < 4 && this.canGoNext) {
            this.currentStep++;
            if (this.currentStep === 2) {
                this.loadServices();
            }
        }
    }

    async handleConfirmBooking() {
        if (!this.contactId) {
            this.error = 'Please sign in to book an appointment';
            return;
        }

        this.isLoading = true;
        this.error = '';

        try {
            const serviceIds = this.selectedServices.map(s => s.serviceId);

            await createAppointment({
                customerId: this.contactId,
                stylistId: this.selectedStylistId,
                appointmentDate: this.selectedDate,
                startTimeMs: parseInt(this.selectedSlot, 10),
                serviceIds: serviceIds,
                notes: this.notes
            });

            // Dispatch success event
            this.dispatchEvent(new CustomEvent('bookingsuccess'));
            this.close();

        } catch (err) {
            console.error('Booking error:', err);
            this.error = err.body?.message || 'Error creating appointment. Please try again.';
        } finally {
            this.isLoading = false;
        }
    }

    resetBooking() {
        this.currentStep = 1;
        this.selectedStylistId = null;
        this.selectedStylist = null;
        this.selectedServices = [];
        this.selectedDate = null;
        this.selectedSlot = null;
        this.notes = '';
        this.error = '';
        this.availableSlots = [];
    }

    // Helper to check if service is selected
    isServiceSelected(serviceId) {
        return this.selectedServices.some(s => s.serviceId === serviceId);
    }
}
