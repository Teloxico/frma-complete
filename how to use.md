### How to Use the Health Assistant App

This guide explains the various features of the Health Assistant app and how to use them.

**1. Getting Started & Home Page**

* **Initial Launch:** When you first open the app, you'll land on the Home Page.
* **Greeting:** The header greets you based on the time of day and your profile name (if set).
* **Navigation Drawer:** Swipe from the left edge or tap the menu icon (☰) in the top-left corner to open the navigation drawer. This provides access to all app sections.
* **Daily Wellness Tip:** A card on the home page displays a rotating health tip.
* **Emergency Button:** A prominent red button provides quick access to the Emergency Care section.
* **Feature Grid:** Tiles provide quick access to key features like Health Chat, Health Metrics, Medications, Appointments, Profile, and Settings.
* **Water Tracker:**
    * Track your daily water intake.
    * Tap **"Add Glass"** to log a predefined amount (default 200ml, adjustable in settings).
    * Tap **"Custom"** to enter a specific amount in ml.
    * View your progress towards your daily goal (automatically set based on profile gender, or customizable).
    * Tap the goal/glass size text to set custom values.
    * Enable/disable hourly hydration reminders using the toggle switch. A notification appears briefly at the top when a reminder triggers.
    * Tap **"Reset for today"** to clear the day's water intake.

**2. Health Chat** (`/chat`)

* **Access:** Via the drawer menu or home page tile.
* **Functionality:** Ask general health-related questions to the AI assistant.
* **Sending Messages:** Type your question in the input field at the bottom and tap the send icon (▶️).
* **AI Response:** The assistant's reply will appear after a brief "typing" indicator.
* **Profile Context:** Your profile information (age, conditions, etc.) is considered by the AI for potentially more relevant answers.
* **History:** Conversations can be saved locally (toggle this in Settings). Tap the `🗑️` icon in the app bar to clear the current chat history.
* **API Configuration:**
    * If the server isn't configured, a warning bar appears.
    * Tap the Settings icon (⚙️) in the app bar to expand the inline API configuration section.
    * Select "Local Server" or "RunPod", enter the required details (URL or Endpoint ID), test the connection, and save. *Note: The RunPod API Key must be set via the main Settings page.*

**3. My Profile** (`/profile`)

* **Access:** Via the drawer menu or home page tile.
* **Functionality:** View and manage your personal health profile.
* **Viewing:** Displays your name, age, BMI (if height/weight are entered), gender, height, weight, blood type, selected medical conditions, allergies, medications, and emergency contacts.
* **Editing:**
    * Tap the "Edit Profile" button (floating action button or app bar icon).
    * **Password Protection:** The first time you edit, you'll be asked to set a password. Subsequent edits require entering this password.
    * Fill in or modify fields like Name, Date of Birth (via date picker), Gender, Height, Weight, and Blood Type.
    * Manage lists (Medical Conditions, Allergies, Medications, Emergency Contacts) by tapping the `+` icon next to the section header to add items via dialogs, or tapping existing items (for Medications/Contacts) to edit them. Items in editable lists can often be removed via icons within the list.
    * Tap the Save icon (✔️) in the app bar to save changes and exit edit mode. Tap the Cancel icon (❌) to discard changes.
* **Clearing Data:** In view mode, tap the `🗑️` icon in the app bar to permanently clear all profile data and the profile password.

**4. Health Metrics** (`/health_metrics`)

* **Access:** Via the drawer menu or home page tile.
* **Functionality:** Provides a consolidated view of key metrics derived from your profile.
* **Displays:** Profile header (Name, Age, Gender), Key Metrics (Weight, Height, Blood Type), BMI calculation and category visualization (if applicable), and lists of your selected Medical Conditions, Allergies, and Medications.
* **Interaction:** This page is read-only. To change metrics, edit your profile.

**5. Medications** (`/medications`)

* **Access:** Via the drawer menu or home page tile.
* **Functionality:** Manage medication reminders. Reminders can be automatically populated from medications added in your profile.
* **Adding Reminders:** Tap the `+` floating action button. Select a medication (must be added to your profile first), set the dosage, time, and repeating days.
* **Viewing Reminders:**
    * Reminders are listed chronologically by time.
    * Use the tabs ("All", "Today", "Active", "Inactive") to filter the list.
    * Tap a reminder to view its details.
* **Managing Reminders:**
    * Toggle the switch on a reminder card to activate/deactivate it.
    * Swipe a reminder left to delete it (confirmation required).
    * Edit a reminder by tapping it to view details, then tapping "Edit".

**6. Appointments** (`/appointments`)

* **Access:** Via the drawer menu or home page tile.
* **Functionality:** Schedule and manage medical appointments.
* **Adding Appointments:** Tap the `+` floating action button. Enter Doctor Name, Specialty, Date, Time, Location, and optional Notes.
* **Viewing Appointments:**
    * Appointments are sorted by date.
    * Use the tabs ("Upcoming", "Completed", "All") to filter the list.
    * Upcoming appointments within 24 hours are highlighted. Past due appointments are indicated.
* **Managing Appointments:**
    * Tap the checkmark icon (✔️) on an appointment card to mark it as completed (or tap refresh (🔄) to mark as not completed).
    * Swipe an appointment left to delete it (confirmation required).

**7. Emergency Care** (`/emergency`)

* **Access:** Via the drawer menu or the prominent red button on the home page.
* **Functionality:** Provides quick access to emergency resources and guided first-aid assessments.
* **Emergency Call Bar:**
    * Displays the primary emergency number for your detected location (or a default). Tap the service name (e.g., "General") to select other available numbers (like Ambulance) if configured for your region.
    * Tap the large "CALL EMERGENCY SERVICES" button to initiate a call after confirmation.
    * Displays your current detected location. Tap the location to try opening it in a map app.
* **Emergency List:** Shows tiles for various emergency situations (e.g., Heart Attack, Stroke, Burns). Critical emergencies are listed first.
* **Starting Assessment:** Tap an emergency tile. A dialog asks if the assessment is for "Me" or "Someone Else". Selecting an option navigates to the Assessment Page.

**8. Emergency Assessment Page** (Navigated from Emergency Care)

* **Functionality:** Guides you through steps for a specific emergency.
* **Intro:** Displays Do's, Don'ts, and a description for the selected emergency. High-priority cases show direct call buttons. Tap "START ASSESSMENT" to proceed.
* **Patient Info (If "Someone Else"):** Asks for the patient's name (optional), age, gender, known conditions, allergies, and medications.
* **Assessment Questions:** Presents a series of questions specific to the emergency (e.g., Yes/No, Multiple Choice, Slider). Answer each question to proceed. You can usually go back to the previous question.
* **Results:** After answering questions, the app sends the information to the AI backend (if configured) and displays the generated first-aid instructions or an error message.
* **Actions:** From the results page, you can go back home, call emergency services again, or copy the assessment details and instructions to the clipboard.

**9. Settings** (`/settings`)

* **Access:** Via the drawer menu or home page tile.
* **API Configuration:**
    * Select API Mode (Local Server / RunPod).
    * Enter Local Server URL or RunPod Endpoint ID.
    * Set/Clear RunPod API Key (stored securely).
    * Test the connection to the configured backend.
    * Save API settings.
* **Appearance:**
    * Choose Theme Mode (System, Light, Dark).
    * Select the app's Primary Color using a color picker.
    * Adjust Font Size using a slider.
    * Toggle High Contrast mode (requires app restart).
* **Notifications:** Enable/Disable app notifications and sound effects.
* **Privacy & Data:**
    * Toggle saving of Health Chat conversation history locally.
    * Export profile and settings data to the clipboard as JSON.
    * Clear All App Data (including profile, settings, history - requires confirmation).
* **Reset:** Reset Appearance and Notification settings to their defaults using the refresh icon (🔄) in the app bar.