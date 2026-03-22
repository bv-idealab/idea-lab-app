# AICTE IDEA Lab Management System 🚀

A comprehensive, cross-platform Flutter application built to digitize and streamline the operations of the AICTE IDEA Lab at Bharati Vidyapeeth College of Engineering. 

This system features a **Mobile App for Students** to explore and book lab resources, and a **Web Dashboard for Administrators** to manage users, machines, and lab operations in real-time.

## ✨ Key Features

### 📱 Student Portal (Mobile)
* **Digital Entry Pass:** Auto-generated QR codes for secure lab entry based on approved profiles.
* **Live Machine Booking:** Real-time availability checking and time-slot booking for machines (3D Printers, Laser Cutters, CNC, etc.).
* **Project Management:** Create, track, and update academic projects, including adding faculty mentors and team members.
* **Gamified Learning (Achievements):** Earn "IDEA Points" and unlock badges for registering, booking machines, and completing projects.
* **Grievance Reporting:** Directly report machine faults or lab issues to admins and track resolution status.

### 💻 Admin Dashboard (Web/PC)
* **User Approvals:** Gatekeeper system to review and approve/reject new student registrations.
* **Live Machine Status:** Toggle machine availability (Available / Under Maintenance) which instantly updates on the student app.
* **Grievance Triage:** Review student-reported issues and update statuses (Pending ➔ Processing ➔ Completed).
* **Global Bookings & Projects:** Complete oversight of all lab activities, booked slots, and ongoing projects.
* **Live Leaderboard:** Ranks students globally based on their earned IDEA Points.

## 🛠️ Tech Stack
* **Frontend:** Flutter & Dart (Cross-platform compilation for iOS, Android, and Web).
* **Backend as a Service (BaaS):** Firebase
  * **Authentication:** Secure Email/Password login.
  * **Cloud Firestore:** Real-time NoSQL database for syncing bookings, points, and machine statuses instantly.
  * **Firebase Storage:** Cloud storage for profile pictures and project assets.

## 🚀 Getting Started

### Prerequisites
* Flutter SDK (v3.10+)
* A Firebase Project with Authentication, Firestore, and Storage enabled.

### Installation
1. Clone the repository:
   ```bash
   git clone [https://github.com/yourusername/idea_lab_app.git](https://github.com/yourusername/idea_lab_app.git)

2. Navigate to the directory:
   ```bash
   cd idea_lab_app

3. Install dependencies:
   ```bash
   flutter pub get

4. Firebase Setup:
   You will need to connect your own Firebase project.
   Run ```bash
       flutterfire configure
   to generate the firebase_options.dart file and add your google-services.json (Android) / GoogleService-Info.plist (iOS).