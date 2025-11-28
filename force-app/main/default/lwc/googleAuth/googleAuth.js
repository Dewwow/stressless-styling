import { LightningElement, api, track } from 'lwc';
import initializeSession from '@salesforce/apex/GoogleAuthService.initializeSession';
import getSession from '@salesforce/apex/GoogleAuthService.getSession';

const SESSION_KEY = 'stressless_user_session';
const USE_LOCAL_STORAGE = true; // Use localStorage for persistence across refreshes

// Module-level flag to prevent multiple session checks across component remounts
let sessionAlreadyChecked = false;
let signInEventDispatched = false;

function getStorage() {
    return USE_LOCAL_STORAGE ? localStorage : sessionStorage;
}

export default class GoogleAuth extends LightningElement {
    @api googleClientId;

    @track isLoading = true;
    @track isSignedIn = false;
    @track error = '';
    @track userName = '';
    @track userPicture = '';

    _googleInitialized = false;
    _userSession = null;

    connectedCallback() {
        this.checkExistingSession();
    }

    renderedCallback() {
        if (!this._googleInitialized && !this.isSignedIn && !this.isLoading) {
            this.initializeGoogleSignIn();
        }
    }

    /**
     * Check if user has an existing session in storage
     */
    async checkExistingSession() {
        // Prevent duplicate checks across component remounts
        if (sessionAlreadyChecked) {
            console.log('GoogleAuth: Session already checked globally, restoring state');
            // Just restore the UI state from storage without making API calls
            const storedSession = getStorage().getItem(SESSION_KEY);
            if (storedSession) {
                const sessionData = JSON.parse(storedSession);
                this._userSession = sessionData;
                this.userName = `${sessionData.firstName} ${sessionData.lastName}`;
                this.isSignedIn = true;
            }
            this.isLoading = false;
            return;
        }
        sessionAlreadyChecked = true;

        console.log('GoogleAuth: Checking for existing session...');
        try {
            const storedSession = getStorage().getItem(SESSION_KEY);
            console.log('GoogleAuth: Stored session found:', !!storedSession);
            if (storedSession) {
                const sessionData = JSON.parse(storedSession);
                console.log('GoogleAuth: Session data email:', sessionData.email);

                // Verify session is still valid by checking with server
                const serverSession = await getSession({ email: sessionData.email });
                console.log('GoogleAuth: Server session response:', serverSession);
                if (serverSession) {
                    this._userSession = serverSession;
                    this.userName = `${serverSession.firstName} ${serverSession.lastName}`;
                    this.isSignedIn = true;
                    console.log('GoogleAuth: Session restored, isSignedIn:', this.isSignedIn);
                    // Dispatch event only once
                    if (!signInEventDispatched) {
                        signInEventDispatched = true;
                        this.dispatchSignInEvent(serverSession);
                    }
                } else {
                    // Session invalid, clear it
                    console.log('GoogleAuth: Server session invalid, clearing');
                    getStorage().removeItem(SESSION_KEY);
                }
            }
        } catch (err) {
            console.error('GoogleAuth: Error checking session:', err);
            getStorage().removeItem(SESSION_KEY);
        } finally {
            this.isLoading = false;
        }
    }

    /**
     * Load Google Identity Services script dynamically
     */
    loadGoogleScript() {
        // Check if script is already being loaded or exists
        if (document.querySelector('script[src*="accounts.google.com/gsi/client"]')) {
            console.log('GoogleAuth: Script tag exists, waiting for it to load...');
            // eslint-disable-next-line @lwc/lwc/no-async-operation
            setTimeout(() => {
                this.initializeGoogleSignIn();
            }, 200);
            return;
        }

        console.log('GoogleAuth: Creating script tag for Google Identity Services...');
        const script = document.createElement('script');
        script.src = 'https://accounts.google.com/gsi/client';
        script.async = true;
        script.defer = true;
        script.onload = () => {
            console.log('GoogleAuth: Google script loaded successfully');
            this.initializeGoogleSignIn();
        };
        script.onerror = (err) => {
            console.error('GoogleAuth: Failed to load Google script', err);
            this.error = 'Unable to load Google Sign-In. Please check your network connection.';
        };
        document.head.appendChild(script);
    }

    /**
     * Initialize Google Sign-In button
     */
    initializeGoogleSignIn() {
        if (this._googleInitialized) return;

        if (!this.googleClientId) {
            console.warn('GoogleAuth: Client ID not configured');
            this.error = 'Google Client ID not configured';
            return;
        }

        // Check if Google script is loaded
        if (!window.google || !window.google.accounts) {
            console.log('GoogleAuth: Google script not found, attempting to load...');
            this.loadGoogleScript();
            return;
        }

        try {
            console.log('GoogleAuth: Initializing with client ID:', this.googleClientId.substring(0, 20) + '...');
            window.google.accounts.id.initialize({
                client_id: this.googleClientId,
                callback: this.handleCredentialResponse.bind(this),
                auto_select: false,
                cancel_on_tap_outside: true
            });

            this._googleInitialized = true;
            console.log('GoogleAuth: Google Sign-In initialized successfully');
        } catch (err) {
            console.error('Error initializing Google Sign-In:', err);
            this.error = 'Unable to initialize Google Sign-In';
        }
    }

    /**
     * Handle click on custom sign-in button - triggers Google One Tap
     */
    handleGoogleSignIn() {
        if (!this._googleInitialized) {
            this.error = 'Google Sign-In not ready. Please try again.';
            return;
        }

        // Show Google One Tap prompt
        window.google.accounts.id.prompt((notification) => {
            console.log('GoogleAuth: Prompt notification:', notification);
            if (notification.isNotDisplayed()) {
                console.log('GoogleAuth: One Tap not displayed, reason:', notification.getNotDisplayedReason());
                // Fall back to showing an error or alternative method
                this.error = 'Google Sign-In popup blocked. Please allow popups for this site.';
            } else if (notification.isSkippedMoment()) {
                console.log('GoogleAuth: One Tap skipped, reason:', notification.getSkippedReason());
            } else if (notification.isDismissedMoment()) {
                console.log('GoogleAuth: One Tap dismissed, reason:', notification.getDismissedReason());
            }
        });
    }

    /**
     * Handle Google credential response
     */
    async handleCredentialResponse(response) {
        console.log('GoogleAuth: handleCredentialResponse called');
        this.isLoading = true;
        this.error = '';

        try {
            // Decode the JWT to get user info
            const payload = this.decodeJwt(response.credential);
            console.log('GoogleAuth: JWT decoded, email:', payload.email);

            const email = payload.email;
            const firstName = payload.given_name || '';
            const lastName = payload.family_name || '';
            const picture = payload.picture || '';

            // Initialize session with Salesforce
            console.log('GoogleAuth: Calling initializeSession...');
            const session = await initializeSession({
                email: email,
                firstName: firstName,
                lastName: lastName
            });
            console.log('GoogleAuth: Session initialized:', session);

            // Store session in localStorage
            const sessionData = {
                email: email,
                firstName: session.firstName,
                lastName: session.lastName,
                contactId: session.contactId,
                stylistId: session.stylistId,
                isStylist: session.isStylist,
                isCustomer: session.isCustomer,
                userType: session.userType,
                title: session.title,
                picture: picture
            };
            getStorage().setItem(SESSION_KEY, JSON.stringify(sessionData));
            console.log('GoogleAuth: Session saved to storage');

            this._userSession = session;
            this.userName = `${session.firstName} ${session.lastName}`;
            this.userPicture = picture;
            this.isSignedIn = true;
            console.log('GoogleAuth: Sign-in complete, isSignedIn:', this.isSignedIn);

            this.dispatchSignInEvent(session);
        } catch (err) {
            console.error('GoogleAuth: Error processing sign-in:', err);
            this.error = err.body?.message || 'Sign-in failed. Please try again.';
        } finally {
            this.isLoading = false;
        }
    }

    /**
     * Decode JWT token (client-side only - for display purposes)
     */
    decodeJwt(token) {
        try {
            const base64Url = token.split('.')[1];
            const base64 = base64Url.replace(/-/g, '+').replace(/_/g, '/');
            const jsonPayload = decodeURIComponent(
                atob(base64)
                    .split('')
                    .map(c => '%' + ('00' + c.charCodeAt(0).toString(16)).slice(-2))
                    .join('')
            );
            return JSON.parse(jsonPayload);
        } catch (e) {
            console.error('Error decoding JWT:', e);
            return {};
        }
    }

    /**
     * Handle sign out
     */
    handleSignOut() {
        console.log('GoogleAuth: Signing out...');
        // Clear session storage
        getStorage().removeItem(SESSION_KEY);

        // Reset module-level flags
        sessionAlreadyChecked = false;
        signInEventDispatched = false;

        // Revoke Google session if available
        if (window.google && window.google.accounts) {
            window.google.accounts.id.disableAutoSelect();
        }

        this._userSession = null;
        this.userName = '';
        this.userPicture = '';
        this.isSignedIn = false;

        this.dispatchSignOutEvent();

        // Re-render the sign-in button
        this._googleInitialized = false;
    }

    /**
     * Dispatch sign-in event with user session
     */
    dispatchSignInEvent(session) {
        this.dispatchEvent(new CustomEvent('signin', {
            detail: {
                email: session.email || this._userSession?.email,
                firstName: session.firstName,
                lastName: session.lastName,
                contactId: session.contactId,
                stylistId: session.stylistId,
                isStylist: session.isStylist,
                isCustomer: session.isCustomer,
                userType: session.userType,
                title: session.title
            },
            bubbles: true,
            composed: true
        }));
    }

    /**
     * Dispatch sign-out event
     */
    dispatchSignOutEvent() {
        this.dispatchEvent(new CustomEvent('signout', {
            bubbles: true,
            composed: true
        }));
    }

    /**
     * Public method to get current session
     */
    @api
    getSession() {
        return this._userSession;
    }

    /**
     * Public method to check if signed in
     */
    @api
    checkSignedIn() {
        return this.isSignedIn;
    }
}
