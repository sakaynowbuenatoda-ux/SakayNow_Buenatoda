SakayNow Buenatoda is a Flutter and Firebase mobile transportation booking
system for tricycles in Buenavista, Bohol.

It supports four roles:

- Passenger: book rides, manage trips, save locations, and pay by cash or Xendit checkout.
- Driver: accept bookings, manage availability, monitor trips, and receive cashless-ready rides when payout details are configured.
- Admin: monitor users, trips, reports, verification, and system records.
- Super Admin: perform all admin work and create, deactivate, or restore regular admin accounts.

## Objectives of the Study

The main objective of this study is to design and develop SakayNow Buenatoda, a
geofencing-based mobile application for efficient, safe, and transparent
tricycle booking.

Specifically, this study aims to:

1. Develop a mobile booking system that enables ride requests, driver acceptance, saved locations, and driver availability control.
2. Implement location-based features including geofencing and real-time tracking for accurate driver-passenger matching and trip monitoring.
3. Ensure fare efficiency and payment convenience through LGU-based fare transparency, student discounts, cash payments, and Xendit online checkout for GCash, Maya, and card payments.
4. Incorporate evaluation and feedback mechanisms such as driver rating, review, ranking, and reporting systems.
5. Establish security and verification processes for students and drivers through ID validation and admin approval.
6. Develop an admin dashboard for monitoring users, trips, reports, verification status, and overall system performance.

## Scope

SakayNow Buenatoda includes:

- Ride booking with passenger pickup/drop-off, driver queue acceptance, and active ride monitoring.
- Geofencing-based driver matching and live ride tracking.
- Fare estimates, fare records, student discount handling, and cash collection status.
- Xendit online checkout for supported cashless methods.
- Passenger and driver reviews, reports, and rankings.
- Driver availability, payout account readiness, and trip summaries.
- Admin monitoring for accounts, trips, reports, and verification.

## Xendit Configuration

Online checkout is handled through Xendit only.

Required Firebase Functions secrets:

```sh
firebase functions:secrets:set XENDIT_SECRET_KEY
firebase functions:secrets:set XENDIT_WEBHOOK_TOKEN
```

Optional redirect environment variables for deployed functions:

```sh
XENDIT_SUCCESS_URL=https://sakaynow-buenatoda.web.app/payment/success
XENDIT_FAILURE_URL=https://sakaynow-buenatoda.web.app/payment/cancelled
```

Xendit webhook callback URL:

```text
https://asia-southeast1-sakaynow-buenatoda.cloudfunctions.net/xenditWebhook
```

In the Xendit dashboard, configure the callback token to match the
`XENDIT_WEBHOOK_TOKEN` Firebase secret. The webhook updates booking payment
records from `checkout_pending` to `paid` or `checkout_failed`.

## Super Admin Migration

Deploy a client that recognizes `super_admin` together with the updated
Functions, Firestore rules, and Storage rules before changing the live user
record. The migration uses Application Default Credentials with access to the
target Firebase project.

```sh
firebase deploy --only functions,firestore:rules,storage,hosting
cd functions
npm run migrate:super-admin
```

The migration promotes the single active regular admin whose first name is
`admin`, canonicalizes existing admin-direct conversations, and writes an
idempotent audit record. It stops without overwriting data if the promotion
candidate or conversation state is ambiguous.

Run the executable authorization suite from the repository root with:

```sh
firebase emulators:exec --project sakaynow-super-admin-rules-test --only firestore,storage "npm --prefix functions run test:rules"
```
