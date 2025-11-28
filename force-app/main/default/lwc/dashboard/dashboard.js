import { LightningElement, wire, track } from 'lwc';
import getCustomerAppointments from '@salesforce/apex/DashboardController.getCustomerAppointments';
import getStylistAppointments from '@salesforce/apex/DashboardController.getStylistAppointments';
import getCustomerPastAppointments from '@salesforce/apex/DashboardController.getCustomerPastAppointments';
import getStylistPastAppointments from '@salesforce/apex/DashboardController.getStylistPastAppointments';
import getAvailableStylists from '@salesforce/apex/DashboardController.getAvailableStylists';
import cancelAppointment from '@salesforce/apex/BookingController.cancelAppointment';

const SESSION_KEY = 'stressless_user_session';

export default class Dashboard extends LightningElement {
    @track userSession = null;
    @track upcomingAppointments = [];
    @track pastAppointments = [];
    @track stylists = [];
    @track isLoading = true;
    @track error;
    @track showAppointmentDetail = false;
    @track selectedAppointment = null;

    // Computed properties
    get isSignedIn() {
        return this.userSession !== null;
    }

    get isCustomer() {
        return this.userSession?.isCustomer === true;
    }

    get isStylist() {
        return this.userSession?.isStylist === true;
    }

    get userName() {
        if (this.userSession) {
            return `${this.userSession.firstName || ''} ${this.userSession.lastName || ''}`.trim() || 'Guest';
        }
        return 'Guest';
    }

    get userTitle() {
        if (this.isStylist && this.userSession.title) {
            return this.userSession.title;
        }
        return this.isCustomer ? 'Customer' : '';
    }

    get hasUpcomingAppointments() {
        return this.upcomingAppointments && this.upcomingAppointments.length > 0;
    }

    get hasPastAppointments() {
        return this.pastAppointments && this.pastAppointments.length > 0;
    }

    // Lifecycle hooks
    connectedCallback() {
        this.checkStoredSession();
        this.loadStylists();
    }

    /**
     * Check for existing session in storage
     */
    checkStoredSession() {
        try {
            // Check localStorage (matches googleAuth component)
            const storedSession = localStorage.getItem(SESSION_KEY);
            if (storedSession) {
                this.userSession = JSON.parse(storedSession);
                this.loadAppointments();
            }
        } catch (err) {
            console.error('Error checking stored session:', err);
        }
        this.isLoading = false;
    }

    /**
     * Handle sign-in event from googleAuth component
     */
    handleSignIn(event) {
        this.userSession = event.detail;
        this.loadAppointments();
    }

    /**
     * Handle sign-out event from googleAuth component
     */
    handleSignOut() {
        this.userSession = null;
        this.upcomingAppointments = [];
        this.pastAppointments = [];
    }

    /**
     * Load appointments based on user type
     */
    async loadAppointments() {
        if (!this.userSession) return;

        this.isLoading = true;
        try {
            if (this.userSession.isStylist && this.userSession.stylistId) {
                await this.loadStylistAppointments();
            } else if (this.userSession.contactId) {
                await this.loadCustomerAppointments();
            }
        } catch (err) {
            console.error('Error loading appointments:', err);
            this.error = err.body?.message || 'Error loading appointments';
        } finally {
            this.isLoading = false;
        }
    }

    /**
     * Load customer appointments
     */
    async loadCustomerAppointments() {
        const [upcoming, past] = await Promise.all([
            getCustomerAppointments({ contactId: this.userSession.contactId }),
            getCustomerPastAppointments({ contactId: this.userSession.contactId })
        ]);

        this.upcomingAppointments = upcoming.map(apt => this.formatAppointment(apt));
        this.pastAppointments = past.map(apt => this.formatAppointment(apt));
    }

    /**
     * Load stylist appointments
     */
    async loadStylistAppointments() {
        const [upcoming, past] = await Promise.all([
            getStylistAppointments({ stylistId: this.userSession.stylistId }),
            getStylistPastAppointments({ stylistId: this.userSession.stylistId })
        ]);

        this.upcomingAppointments = upcoming.map(apt => this.formatAppointment(apt));
        this.pastAppointments = past.map(apt => this.formatAppointment(apt));
    }

    /**
     * Load available stylists for display
     */
    async loadStylists() {
        try {
            this.stylists = await getAvailableStylists();
        } catch (err) {
            console.error('Error loading stylists:', err);
            this.stylists = [];
        }
    }

    formatAppointment(apt) {
        // Format date for display
        let formattedDate = '';
        if (apt.appointmentDate) {
            const date = new Date(apt.appointmentDate);
            formattedDate = date.toLocaleDateString('en-US', {
                weekday: 'short',
                month: 'short',
                day: 'numeric'
            });
        }

        // Format time for display
        let formattedTime = '';
        if (apt.startTime) {
            // startTime comes as milliseconds from midnight
            const hours = Math.floor(apt.startTime / 3600000);
            const minutes = Math.floor((apt.startTime % 3600000) / 60000);
            const ampm = hours >= 12 ? 'PM' : 'AM';
            const displayHours = hours % 12 || 12;
            formattedTime = `${displayHours}:${minutes.toString().padStart(2, '0')} ${ampm}`;
        }

        // Get service names as comma-separated string
        const serviceNames = apt.services?.map(s => s.serviceName).join(', ') || '';

        // Appointment can be cancelled if it's Scheduled or Confirmed
        const canCancel = ['Scheduled', 'Confirmed'].includes(apt.status);

        return {
            ...apt,
            formattedDate,
            formattedTime,
            formattedDateTime: `${formattedDate} at ${formattedTime}`,
            serviceNames,
            formattedPrice: apt.totalPrice ? `$${apt.totalPrice.toFixed(2)}` : '',
            formattedDuration: apt.totalDuration ? `${apt.totalDuration} min` : '',
            statusClass: this.getStatusClass(apt.status),
            canCancel
        };
    }

    getStatusClass(status) {
        const statusMap = {
            'Scheduled': 'slds-badge slds-badge_lightest',
            'Confirmed': 'slds-badge slds-theme_success',
            'Completed': 'slds-badge slds-theme_info',
            'Cancelled': 'slds-badge slds-theme_error',
            'No Show': 'slds-badge slds-theme_warning'
        };
        return statusMap[status] || 'slds-badge';
    }

    handleBookAppointment() {
        const modal = this.template.querySelector('c-booking-modal');
        if (modal) {
            modal.open();
        }
    }

    handleBookingSuccess() {
        // Reload appointments to show the new booking
        this.loadAppointments();
    }

    handleViewSchedule() {
        // Navigate to full schedule view
        console.log('View schedule clicked');
    }

    handleViewAppointment(event) {
        const appointmentId = event.currentTarget.dataset.id;
        // Find the appointment in upcoming or past lists
        let apt = this.upcomingAppointments.find(a => a.appointmentId === appointmentId);
        if (!apt) {
            apt = this.pastAppointments.find(a => a.appointmentId === appointmentId);
        }
        if (apt) {
            // Add clickable links for email and phone
            this.selectedAppointment = {
                ...apt,
                emailLink: apt.customerEmail ? `mailto:${apt.customerEmail}` : null,
                phoneLink: apt.customerPhone ? `tel:${apt.customerPhone}` : null
            };
            this.showAppointmentDetail = true;
        }
    }

    handleCloseDetail() {
        this.showAppointmentDetail = false;
        this.selectedAppointment = null;
    }

    async handleCancelAppointment(event) {
        const appointmentId = event.target.dataset.id;
        const appointmentName = event.target.dataset.name || 'this appointment';

        // Confirm cancellation
        if (!confirm(`Are you sure you want to cancel ${appointmentName}?`)) {
            return;
        }

        this.isLoading = true;
        try {
            await cancelAppointment({
                appointmentId: appointmentId,
                reason: 'Cancelled by customer online'
            });

            // Reload appointments to reflect the change
            await this.loadAppointments();
        } catch (err) {
            console.error('Error cancelling appointment:', err);
            this.error = err.body?.message || 'Error cancelling appointment';
        } finally {
            this.isLoading = false;
        }
    }
}
