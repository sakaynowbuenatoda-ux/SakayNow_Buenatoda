# CHAPTER 3

# TECHNICAL BACKGROUND

This chapter presents the technologies and components used in developing **SakayNow Buenatoda**, a mobile transportation booking system for tricycles in Buenavista, Bohol. The system uses a Flutter mobile frontend, Firebase cloud services, Google Maps platform services, device location capabilities, and local preference storage to support real-time ride booking, role-based access, driver availability, passenger trip management, admin monitoring, verification workflows, and live ride tracking.

SakayNow Buenatoda is designed as a cross-platform application with a modular Flutter architecture. The application separates user interface pages, reusable widgets, controllers, services, models, configuration files, and session utilities. Firebase Authentication manages account access, Cloud Firestore stores user, booking, driver location, and review records, Firebase Storage stores verification documents and profile images, and Google Maps-related APIs support map display, place search, routing, distance estimation, and geofencing behavior.

## 1. Hardware

Hardware refers to the physical devices and computing resources required to build, test, deploy, and use SakayNow Buenatoda. These devices support mobile access, development, cloud storage, location-based booking, and system testing.

### 1.1 Mobile Devices

Mobile devices serve as the primary platform for passengers and drivers. Passengers use smartphones to register, log in, search or pin pickup and drop-off points, book rides, monitor active trips, manage saved destinations, and view trip history. Drivers use smartphones to manage availability, receive ride requests, accept bookings, publish live location updates, update trip status, and review recent trips.

For smooth operation, Android and iOS devices should support modern Flutter applications, internet connectivity, location services, and enough storage for the installed application and cached preferences. Since the system uses live location and map features, devices should have GPS support and stable mobile data or Wi-Fi access.

### 1.2 Development Computer

A development computer is required during system analysis, design, programming, debugging, testing, and deployment preparation. The development machine runs the Flutter SDK, Dart tooling, Firebase CLI, Android Studio or Visual Studio Code, device emulators, and source control tools. Recommended specifications include at least an Intel Core i5, Ryzen 5, or equivalent processor, 8 GB of RAM, and SSD storage to support Flutter builds, emulator testing, dependency installation, and Firebase configuration.

### 1.3 Firebase Cloud Infrastructure

Firebase provides the cloud backend resources used by SakayNow Buenatoda. Instead of maintaining a separate custom server, the application communicates directly with Firebase services. Firebase Authentication handles secure account registration and login, Cloud Firestore stores structured application records, and Firebase Storage stores uploaded verification images such as student IDs, driver licenses, NBI clearances, and selfies.

### 1.4 Device Location Hardware

The system relies on mobile GPS and location hardware for booking and tracking features. Passengers use location services to set pickup points and view route information, while drivers use location streaming to update their current position during availability and active rides. These location values are used with geofencing logic to estimate distances, determine arrival proximity, and improve trip monitoring.

## 2. Software

Software includes the frameworks, programming languages, libraries, platforms, and development tools used to build and operate SakayNow Buenatoda. These technologies were selected to support cross-platform development, real-time database updates, map-based booking, role-based navigation, and maintainable application architecture.

### 2.1 Flutter Framework

Flutter is the main framework used to develop the SakayNow Buenatoda application. It enables a single codebase to support Android, iOS, web, and desktop targets while maintaining a consistent user interface. The project uses Material Design 3, custom themes, reusable widgets, and responsive layouts for passenger, driver, admin, authentication, profile, settings, and ride monitoring screens.

The Flutter source code is organized under the `lib` directory. Major folders include `pages` for role-based screens, `widgets` for reusable interface components, `controllers` for state and interaction logic, `services` for Firebase and external API communication, `models` for structured data objects, `core` for authentication/session and preferences, and `config` for environment, assets, and map constants. This modular structure improves readability and maintainability.

### 2.2 Dart Programming Language

Dart is the primary programming language used in the SakayNow Buenatoda frontend. It is used to define UI components, data models, controllers, service classes, validation logic, Firebase operations, asynchronous streams, and local preferences. Dart null safety helps reduce runtime errors by making nullable values explicit, especially in user profiles, locations, ride records, and optional document URLs.

### 2.3 Firebase Authentication

Firebase Authentication manages user account creation, login, logout, authentication state changes, and email verification. The application listens to authentication state through an authentication gate. When a user is signed in, the system loads the user's Firestore profile and redirects the user to the correct interface based on role: passenger, driver, or admin.

### 2.4 Cloud Firestore

Cloud Firestore is the main database of SakayNow Buenatoda. It stores structured records such as users, bookings, driver locations, and reviews. Firestore's real-time snapshot streams allow passenger ride status, driver queues, admin dashboards, active bookings, and live driver locations to update without manual refreshing.

Important collections used by the project include:

- `users` for account profiles, roles, verification status, uploaded document URLs, activity state, passenger type, and ratings.
- `bookings` for ride requests, pickup and drop-off locations, route estimates, driver assignment, payment method, timestamps, ETA data, and status history.
- `driver_locations` for driver GPS coordinates, availability state, active booking reference, heading, speed, and accuracy.
- `reviews` for driver-passenger review records and rating aggregation.

### 2.5 Firebase Storage

Firebase Storage stores image and document uploads submitted during registration and verification. Passenger registration uploads an ID image and selfie. Driver registration uploads an NBI clearance, driver's license, and selfie. The uploaded file URLs are then saved in Firestore user records for admin review.

### 2.6 Firestore and Storage Security Rules

The project includes security rules for Firestore and Firebase Storage. Firestore rules restrict account creation to valid signup data, allow users to read their own profiles, allow admins to manage users, and allow only verified drivers to go active or accept bookings. Storage rules restrict user document access and limit upload size. These rules help protect sensitive user information and prevent unauthorized updates.

### 2.7 Google Maps Platform

Google Maps platform services support the map-based booking workflow. The project uses Google Maps Flutter for map rendering, Places API for autocomplete and place details, Geocoding API for pinned locations, Directions API for route generation, and Distance Matrix API for travel distance and ETA estimates. The application reads the Google services API key from environment configuration using `.env` or Dart defines.

### 2.8 Geolocator and Geofencing

The `geolocator` package is used to request location permission, get the current device position, and listen to driver location changes. The geofencing service calculates distances between coordinates and checks whether a driver is near the pickup point, near the destination, or whether the passenger is within the allowed pickup radius. These calculations support real-time ride tracking and arrival-related logic.

### 2.9 Ride Tracking and Booking Services

The ride tracking service is responsible for creating bookings, watching active passenger rides, watching open driver queues, accepting bookings, updating ride statuses, updating driver locations, and saving reviews. It uses Firestore transactions and batched writes for operations that must remain consistent, such as assigning a driver to a booking and marking that driver unavailable.

Ride statuses are represented through a structured enum with valid transitions. A ride can move from searching, accepted, driver arriving, arrived, in progress, and then completed or cancelled. This approach helps prevent invalid trip state changes.

### 2.10 Controllers and State Management

The project uses controller classes based on `ChangeNotifier` to separate business logic from UI screens. The booking map controller manages pickup and drop-off search, selected map pins, route loading, distance estimates, driver selection, and booking creation. The ride tracking controller watches an active ride, publishes driver location, updates ETA, and handles status changes. The quick destinations controller manages saved passenger destinations using both local and remote storage.

This controller-based approach keeps screen files focused on presentation while services and controllers handle data operations and application logic.

### 2.11 Shared Preferences

Shared Preferences is used for local storage of user session details, app preferences, text scaling, theme mode, and passenger quick destinations. It also acts as an offline-friendly fallback for saved destinations when Firestore is temporarily unavailable. Session data such as user ID, name, email, role, and passenger type is cached locally after the Firestore user profile is loaded.

### 2.12 User Interface Components

The application uses reusable widgets for consistent UI presentation. These include shared app bars, bottom navigation, passenger dashboard sections, map search fields, route summary cards, Firebase storage images, profile cards, admin app bars, settings cards, and time-ago text. The theme uses local Google Font assets and disables runtime font fetching for consistent appearance and better reliability.

### 2.13 Development Tools

Visual Studio Code or Android Studio can be used as the main development environment. Flutter tooling supports running, debugging, analyzing, and building the application. Firebase CLI supports Firebase initialization, rules deployment, and hosting configuration where needed. Git is used for source control, backup, collaboration, and change tracking.

## 3. Peopleware

Peopleware refers to the individuals involved in developing, maintaining, evaluating, and using SakayNow Buenatoda. Their roles help ensure that the system is functional, secure, usable, and aligned with the transportation needs of the community.

### 3.1 Developers

Developers are responsible for system analysis, database design, interface design, Flutter development, Firebase configuration, map service integration, testing, debugging, and documentation. They maintain the modular architecture of the application and ensure that authentication, booking, tracking, and admin features work together properly.

### 3.2 Passengers

Passengers are end users who request tricycle rides through the application. They create accounts, submit verification requirements, choose pickup and drop-off locations, book rides, monitor active trips, manage quick destinations, view ride history, and provide feedback. Student passengers may also be identified separately through the passenger type field for verification and fare-related handling.

### 3.3 Drivers

Drivers are end users who provide transportation services through the application. They register with required verification documents, wait for admin approval, toggle availability, publish live location, accept open bookings, update ride status, and view recent trips. Only verified and non-banned drivers are allowed to go active or accept bookings.

### 3.4 System Administrator

The system administrator manages user verification, account approval, account restriction, user restoration, booking monitoring, review records, and operational dashboards. The admin role helps ensure that only valid passenger and driver accounts are allowed to participate in the booking system.

### 3.5 Academic Adviser or Evaluator

The academic adviser or evaluator reviews the project for correctness, usability, documentation quality, and alignment with the study objectives. This role may provide feedback on system scope, technical implementation, interface design, and whether the project addresses the transportation booking problem effectively.

### 3.6 Test Users

Test users help evaluate the application during development. They test signup, login, document upload, role-based navigation, map search, ride booking, driver queue behavior, live tracking, admin approval, and error handling. Their feedback supports improvements in reliability, clarity, and user experience.

## 4. Network

The network component describes how SakayNow Buenatoda communicates between the mobile application, Firebase services, Google Maps services, and user devices. Although some preferences and saved destinations can be stored locally, the main booking and tracking features rely on internet connectivity.

### 4.1 Internet Connectivity

Internet connectivity is required for login, signup, account verification, Firestore profile loading, booking creation, driver availability updates, ride monitoring, real-time driver location updates, review saving, and admin dashboard data. Users may connect through Wi-Fi or mobile data depending on availability.

### 4.2 Application-to-Firebase Communication

The Flutter application communicates directly with Firebase through official Firebase SDKs. Authentication requests are sent to Firebase Authentication. User, booking, driver location, and review records are read and written through Cloud Firestore. Verification images and profile images are uploaded to Firebase Storage. Firestore real-time listeners provide live updates for active rides, driver queues, admin user lists, and booking records.

### 4.3 Application-to-Google Maps Communication

The application communicates with Google Maps services over HTTPS. Places autocomplete and place details are used to search for pickup and destination points. Directions API provides route polylines, travel distance, duration, and map bounds. Distance Matrix API provides ETA estimates. Reverse geocoding and nearby search help convert pinned coordinates into readable locations.

### 4.4 Real-Time Ride Tracking Flow

During a ride, the driver device streams location updates using the Geolocator package. These updates are written to the `driver_locations` collection and, when the driver has an active ride, also copied into the related booking record. Passenger and driver screens listen to Firestore snapshots so trip information, location markers, ETA values, and ride status can update in near real time.

### 4.5 Local Cache and Offline-Friendly Behavior

SakayNow Buenatoda uses Shared Preferences for local session and preference data. Passenger quick destinations are saved locally first and synchronized with Firestore when possible. This allows selected user settings and saved places to remain available even when network access is unstable, while critical booking and tracking actions still require Firebase connectivity.
