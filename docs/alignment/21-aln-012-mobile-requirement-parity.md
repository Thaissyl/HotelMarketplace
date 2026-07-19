# ALN-012 Mobile Requirement Parity

## Scope

ALN-012 closes GAP-019, GAP-021, GAP-022, GAP-026, and GAP-028. It aligns
public browsing, property onboarding and setup, account self-service, platform
commission management, and production network configuration with the canonical
requirements. Payment remains the approved demo flow.

## Public Marketplace

- Unauthenticated users land on marketplace search and can open hotel detail.
- Login and registration remain public; account, booking, operations, and
  platform routes remain protected.
- Reserving a room still requires an authenticated Customer.
- Guest navigation shows Sign in instead of a nonfunctional Sign out action.

## Property Setup

- A Property Owner without a hotel receives a first-property onboarding form.
- Registration creates a PendingReview hotel and selects it using current
  database-backed access without requiring a new JWT.
- Owner and assigned Hotel Manager can manage hotel profile, gallery, amenities,
  cancellation policy, room types, and physical rooms through HotelScoped
  operations endpoints.
- Room-type deactivation and physical-room setup updates retain existing domain
  lifecycle and future-booking safeguards.
- Platform Administrator receives no hotel operations role or implicit mutation
  access.

## Account Self-Service

The account profile boundary now requires authentication rather than the
Customer role. Customer, Owner, hotel staff, and Platform Administrator can
update only their own name and phone number and can change their own password.
Operations and Platform Admin workspaces expose a direct Account settings route.

## Platform Commission

Platform Administrator can list all hotels, search and paginate the list, view
the current default commission, and set a value from zero through thirty
percent. The backend endpoint remains platform-role-only and writes through the
existing transactional commission mutation and audit path.

## Network Security

- Android main/release manifest no longer permits cleartext traffic.
- Local HTTP remains available only in debug and profile manifest overlays.
- Production environment startup rejects a non-HTTPS API base URL.
- Development retains Android Emulator access through `10.0.2.2`.

## Verification

- API integration covers role protection for the global hotel list, Manager
  profile/content/inventory CRUD, and non-Customer own-profile access.
- Mobile contract tests cover hotel registration and complete content payloads.
- Environment tests reject production HTTP and normalize development URLs.
- Backend build/tests, Flutter analysis/tests, and Android APK build are required
  acceptance gates for this increment.
