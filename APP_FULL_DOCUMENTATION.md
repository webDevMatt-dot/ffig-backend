# FFIG App: Full Documentation and System Report

Generated on: 2026-04-09
Repository root: `/Users/matt/ffig-mobile-app`

## 1. Executive Summary

This repository contains a full product stack for **Female Founders Initiative Global (FFIG)**:

- A **Flutter mobile app** (`mobile_app`) for members and admins.
- A **Django + DRF backend** (repo root apps) that powers auth, profiles, events, chat, resources, payments, admin workflows, and community modules.

At a product level, the app provides:

- User onboarding (register, OTP verify, login, password reset)
- Role/tier access (Free, Standard, Premium, Admin)
- Event discovery, RSVP/ticket purchase, and ticket verification
- Member directory + public profiles
- Direct messaging + community chat
- Story/reels/marketing-style content feed (VVIP area)
- Resource vault (magazines, masterclasses, newsletters, etc.)
- Full admin console for approvals, moderation, analytics, content, users, and tickets

## 2. What The App Does (Functional Report)

### 2.1 Primary User Experience

The app is a **membership-based community and content platform** for founders:

- Users discover and register for events.
- Members network through directory and chat.
- Premium users unlock direct messaging, marketing tools, and VVIP media/content surfaces.
- Users consume curated resources.
- Admins moderate content and manage platform operations.

### 2.2 Membership Tiers

Tier behavior is centralized in:

- `mobile_app/lib/core/services/membership_service.dart`

Core rules:

- `free`: baseline/public access
- `standard`: adds community-level access
- `premium`: unlocks inbox/direct messaging, business and marketing capabilities, premium content surfaces
- `admin` (`isAdmin`): override access to all admin tooling

### 2.3 Operational/Admin Experience

Admins can:

- Manage homepage modules (hero, founder spotlight, alerts, ticker, business-of-month)
- Manage events (including speaker/agenda/FAQ/ticket tiers)
- Review approvals (business profiles and marketing content)
- Moderate reports and apply actions
- Manage users and login logs
- Manage resources and media attachments
- View analytics and ticket purchase logs
- Scan/verify event ticket QR payloads
- Manage community polls/quizzes

## 3. High-Level Architecture

## 3.1 Monorepo Layout

Top-level split:

- `mobile_app/` -> Flutter app (UI + app-side services)
- `authentication/`, `members/`, `events/`, `chat/`, `community/`, `home/`, `resources/`, `payments/` -> Django domain apps
- `ffig_backend/` -> Django project settings and URL routing
- `core/` -> backend middleware and permissions

### 3.2 Runtime Request Flow

1. Flutter screen triggers action.
2. Action usually calls direct `http` request or `AdminApiService`/other service.
3. URL is composed from `baseUrl` in `mobile_app/lib/core/api/constants.dart`.
4. Django route resolves via `ffig_backend/urls.py` and included app URL configs.
5. DRF views/serializers/models process request and return JSON.
6. Flutter updates UI state.

### 3.3 Environments and Base URL

Frontend base URL logic:

- File: `mobile_app/lib/core/api/constants.dart`
- Release/Web: `https://ffig-backend-ti5w.onrender.com/api/`
- Debug Android emulator: `http://10.0.2.2:8000/api/`
- Debug iOS/local: `http://localhost:8000/api/`

## 4. Frontend Documentation (Flutter)

Root app:

- Entry: `mobile_app/lib/main.dart`
- Feature code: `mobile_app/lib/features/**`
- Shared services: `mobile_app/lib/core/services/**`

### 4.1 Startup and Bootstrapping

File:

- `mobile_app/lib/main.dart`

Startup responsibilities:

- Loads `.env` with `flutter_dotenv`
- Sets Stripe publishable key
- Initializes Firebase (non-web)
- Registers FCM background handler
- Initializes local notifications (`NotificationService`)
- Initializes IAP stream listener (`IAPService`)
- Launches splash then routes into `DashboardScreen` (token and guest both currently flow to dashboard)

### 4.2 Main Navigation

Primary navigation hub:

- `mobile_app/lib/features/home/dashboard_screen.dart`

Main tabs/page order:

1. Home
2. Events
3. Network (members directory)
4. VVIP (Premium/Standard/Locked surface based on tier)
5. Admin (visible when `is_staff`)

Bottom nav component:

- `mobile_app/lib/shared_widgets/glass_nav_bar.dart`

### 4.3 Notification Routing (Deep-link Logic)

Notification service:

- `mobile_app/lib/core/services/notification_service.dart`

Notification type routing:

- `chat_message` -> `ChatScreen`
- `community_chat` -> `CommunityChatScreen`
- `admin_alert`, `admin_business_alert` -> `AdminApprovalsScreen`
- `admin_purchase_alert` -> `AdminTicketsScreen`
- `new_story` -> `VVIPReelsScreen`
- `new_resource` -> `ResourcesScreen`
- content updates (`new_post`, `hero_announcement`, `flash_alert`, `founder_spotlight`, `business_spotlight`) -> `DashboardScreen`

### 4.4 Screen Index (Where Screens Live)

### 4.4.1 Auth

- `mobile_app/lib/features/auth/login_screen.dart` -> login, token persistence, moderation checks.
- `mobile_app/lib/features/auth/signup_screen.dart` -> registration form + OTP flow start.
- `mobile_app/lib/features/auth/email_verification_screen.dart` -> signup OTP verification + resend.
- `mobile_app/lib/features/auth/forgot_password_screen.dart` -> request reset OTP.
- `mobile_app/lib/features/auth/verify_otp_screen.dart` -> confirm OTP + set new password.
- `mobile_app/lib/features/auth/auth_screen.dart` -> placeholder/stub screen.

### 4.4.2 Home and Dashboard

- `mobile_app/lib/features/home/dashboard_screen.dart` -> central app shell, tabs, role checks, unread polling, creation entry points.
- `mobile_app/lib/features/home/business_detail_screen.dart` -> business spotlight detail.

Home models:

- `mobile_app/lib/features/home/models/hero_item.dart`
- `mobile_app/lib/features/home/models/founder_profile.dart`
- `mobile_app/lib/features/home/models/business_profile.dart`
- `mobile_app/lib/features/home/models/flash_alert.dart`

Home widgets:

- `mobile_app/lib/features/home/widgets/hero_carousel.dart`
- `mobile_app/lib/features/home/widgets/hero_banner.dart`
- `mobile_app/lib/features/home/widgets/news_ticker.dart`
- `mobile_app/lib/features/home/widgets/founder_card.dart`
- `mobile_app/lib/features/home/widgets/founder_spotlight_card.dart`
- `mobile_app/lib/features/home/widgets/business_card.dart`
- `mobile_app/lib/features/home/widgets/flash_alert_banner.dart`
- `mobile_app/lib/features/home/widgets/bento_tile.dart`

### 4.4.3 Events and Tickets

- `mobile_app/lib/features/events/events_screen.dart` -> upcoming/past event lists + search.
- `mobile_app/lib/features/events/event_detail_screen.dart` -> event detail tabs, RSVP flow, ticket launch.
- `mobile_app/lib/features/events/ticket_flow/ticket_selection_screen.dart` -> choose ticket tier/quantity.
- `mobile_app/lib/features/events/ticket_flow/checkout_screen.dart` -> Stripe/free registration checkout.
- `mobile_app/lib/features/events/ticket_flow/ticket_confirmation_screen.dart` -> confirmation display screen.
- `mobile_app/lib/features/tickets/my_tickets_screen.dart` -> user’s tickets with QR display.

### 4.4.4 Community and Profiles

- `mobile_app/lib/features/community/member_list_screen.dart` -> directory + filters + admin long-press actions + polls/quizzes mode.
- `mobile_app/lib/features/community/public_profile_screen.dart` -> public member profile + DM entry gating.
- `mobile_app/lib/features/community/profile_screen.dart` -> self profile + business profile access.
- `mobile_app/lib/features/community/community_screen.dart` -> placeholder/stub screen.
- `mobile_app/lib/features/community/widgets/filter_bottom_sheet.dart` -> filter UI for directory.

### 4.4.5 Chat

- `mobile_app/lib/features/chat/inbox_screen.dart` -> conversation list, filters, global search, community tile.
- `mobile_app/lib/features/chat/chat_screen.dart` -> direct chat, replies, search, block/report/favorite/mute/clear.
- `mobile_app/lib/features/chat/community_chat_screen.dart` -> shared community channel.
- `mobile_app/lib/features/chat/widgets/instagram_message_input.dart` -> message input UI component.

### 4.4.6 Resources

- `mobile_app/lib/features/resources/resources_screen.dart` -> categorized resource feed + search + mark viewed.
- `mobile_app/lib/features/resources/pdf_viewer_screen.dart` -> in-app PDF rendering.

### 4.4.7 Marketing and Business

- `mobile_app/lib/features/marketing/marketing_requests_screen.dart` -> list user marketing submissions.
- `mobile_app/lib/features/marketing/create_marketing_request_screen.dart` -> create marketing content request.
- `mobile_app/lib/features/marketing/preview_marketing_post_screen.dart` -> pre-submit review and final upload.
- `mobile_app/lib/features/marketing/edit_marketing_request_screen.dart` -> edit/update existing request.
- `mobile_app/lib/features/marketing/business_profile_editor_screen.dart` -> create/edit business profile for approval.

### 4.4.8 Premium/VVIP

- `mobile_app/lib/features/premium/premium_screen.dart` -> premium tab shell hosting VVIP feed.
- `mobile_app/lib/features/premium/standard_screen.dart` -> standard member lounge + upsell.
- `mobile_app/lib/features/premium/locked_screen.dart` -> upgrade/paywall (IAP with Stripe fallback).
- `mobile_app/lib/features/premium/vvip_reels_screen.dart` -> vertical reels-style premium feed.
- `mobile_app/lib/features/premium/create_story_screen.dart` -> story creation and upload.
- `mobile_app/lib/features/premium/share_to_chat_sheet.dart` -> share premium content into chat.
- `mobile_app/lib/features/premium/vip_screen.dart` -> alternate/legacy VIP tabbed resource screen.
- `mobile_app/lib/features/premium/logic/story_logic.dart` -> story logic helpers.

Premium widgets:

- `mobile_app/lib/features/premium/widgets/vvip_feed.dart`
- `mobile_app/lib/features/premium/widgets/stories_bar.dart`
- `mobile_app/lib/features/premium/widgets/story_viewer.dart`
- `mobile_app/lib/features/premium/widgets/story_bubbles.dart`
- `mobile_app/lib/features/premium/widgets/full_screen_media_viewer.dart`

### 4.4.9 Settings

- `mobile_app/lib/features/settings/settings_screen.dart` -> account overview, logout/delete, password change, read receipt updates.
- `mobile_app/lib/features/settings/edit_profile_screen.dart` -> editable profile form + avatar update.
- `mobile_app/lib/features/settings/account_settings_screen.dart` -> account-level options.
- `mobile_app/lib/features/settings/blocked_users_screen.dart` -> list and unblock users.

### 4.4.10 Admin

Top-level admin hub:

- `mobile_app/lib/features/admin/admin_dashboard_screen.dart`

Admin areas:

- `mobile_app/lib/features/admin/user_management_screen.dart`
- `mobile_app/lib/features/admin/edit_user_screen.dart`
- `mobile_app/lib/features/admin/resource_management_screen.dart`
- `mobile_app/lib/features/admin/admin_logs_screen.dart`
- `mobile_app/lib/features/admin/ticket_scanner_screen.dart`
- `mobile_app/lib/features/admin/tickets/admin_tickets_screen.dart`
- `mobile_app/lib/features/admin/analytics/admin_analytics_screen.dart`
- `mobile_app/lib/features/admin/analytics/event_revenue_screen.dart`
- `mobile_app/lib/features/admin/approvals/admin_approvals_screen.dart`
- `mobile_app/lib/features/admin/moderation/admin_reports_screen.dart`
- `mobile_app/lib/features/admin/moderation/report_detail_screen.dart`
- `mobile_app/lib/features/admin/events_management/manage_events_screen.dart`
- `mobile_app/lib/features/admin/events_management/edit_event_screen.dart`
- `mobile_app/lib/features/admin/home_management/manage_hero_screen.dart`
- `mobile_app/lib/features/admin/home_management/manage_founder_screen.dart`
- `mobile_app/lib/features/admin/home_management/manage_alerts_screen.dart`
- `mobile_app/lib/features/admin/home_management/manage_ticker_screen.dart`
- `mobile_app/lib/features/admin/home_management/manage_business_screen.dart`
- `mobile_app/lib/features/admin/community_management/manage_community_screen.dart`
- `mobile_app/lib/features/admin/community_management/manage_polls_screen.dart`
- `mobile_app/lib/features/admin/community_management/poll_form_screen.dart`
- `mobile_app/lib/features/admin/community_management/manage_quizzes_screen.dart`
- `mobile_app/lib/features/admin/community_management/quiz_form_screen.dart`

Admin widgets:

- `mobile_app/lib/features/admin/widgets/admin_dark_list_item.dart`
- `mobile_app/lib/features/admin/widgets/user_picker_dialog.dart`

### 4.5 Frontend Service Layer (Where Logic Lives)

### 4.5.1 API and Core Services

- `mobile_app/lib/core/api/constants.dart` -> base URL/environment routing.
- `mobile_app/lib/core/api/admin_service.dart` -> admin reset password endpoint helper.
- `mobile_app/lib/core/api/django_api_client.dart` -> placeholder client.
- `mobile_app/lib/core/services/admin_api_service.dart` -> large orchestration service for home/events/admin/marketing/resources/community admin calls.
- `mobile_app/lib/core/services/membership_service.dart` -> local RBAC gate checks and upgrade prompt.
- `mobile_app/lib/core/services/notification_service.dart` -> FCM/local notifications and deep-link navigation.
- `mobile_app/lib/core/services/stripe_service.dart` -> Stripe payment intents, membership purchases, connect flows.
- `mobile_app/lib/core/services/iap_service.dart` -> platform in-app purchases and backend receipt verification.
- `mobile_app/lib/core/services/ticket_service.dart` -> ticket helper service (legacy purchase path + ticket fetch).
- `mobile_app/lib/core/services/version_service.dart` -> app update check via `/home/version/`.

### 4.5.2 Shared UI Utilities

- `mobile_app/lib/shared_widgets/upgrade_modal.dart` -> upgrade CTA modal.
- `mobile_app/lib/shared_widgets/moderation_dialog.dart` -> blocked/suspended account messaging.
- `mobile_app/lib/shared_widgets/user_avatar.dart` -> avatar fallback/display logic.
- `mobile_app/lib/core/utils/dialog_utils.dart` -> common dialog wrappers.
- `mobile_app/lib/core/utils/url_utils.dart` -> URL helpers.

## 5. API Map (Frontend to Backend)

Below is the practical API map used by the Flutter app.

### 5.1 Auth

- `auth/login/`
- `auth/refresh/`
- `auth/register/`
- `auth/register/verify-otp/`
- `auth/register/resend-otp/`
- `auth/password/reset/request-otp/`
- `auth/password/reset/confirm-otp/`
- `auth/password/change/`
- `auth/delete/`

### 5.2 Member/Profile/Network

- `members/`
- `members/me/`
- `members/unique-locations/`
- `members/me/business/`
- `members/block/<user_id>/`
- `members/blocked/`
- `members/report/`
- `members/favorites/toggle/<user_id>/`

### 5.3 Stories and Marketing

- `members/stories/`
- `members/stories/<id>/`
- `members/stories/<id>/seen/`
- `members/stories/<id>/views/`
- `members/stories/<id>/reply/`
- `members/me/marketing/`
- `members/me/marketing/list/`
- `members/me/marketing/<id>/`
- `members/marketing/feed/`
- `members/marketing/<id>/like/`
- `members/marketing/<id>/comments/`

### 5.4 Events and Tickets

- `events/`
- `events/<id>/`
- `events/<id>/delete/`
- `events/featured/`
- `events/my-tickets/`
- `events/tiers/`
- `events/tiers/<id>/`
- `events/speakers/`
- `events/speakers/<id>/`
- `events/agenda/`
- `events/agenda/<id>/`
- `events/faqs/`
- `events/faqs/<id>/`

### 5.5 Chat

- `chat/conversations/`
- `chat/conversations/<id>/messages/`
- `chat/messages/send/`
- `chat/unread-count/`
- `chat/conversations/<id>/mute/`
- `chat/conversations/<id>/clear/`
- `chat/community/`
- `chat/community/unread-count/`
- `chat/community/mark-read/`
- `chat/search/`

### 5.6 Resources

- `resources/`
- `resources/unseen-count/`
- `resources/<id>/view/`

### 5.7 Home Content

- `home/hero/`
- `home/founder/`
- `home/alerts/`
- `home/ticker/`
- `home/business/`
- `home/version/`
- `home/download-apk/`

### 5.8 Payments

- `payments/connect/create-account/`
- `payments/connect/status/`
- `payments/create-payment-intent/`
- `payments/create-membership-payment-intent/`
- `payments/free-registration/`
- `payments/verify-ticket/`
- `payments/verify-subscription/`
- `payments/webhook/` (backend/webhook endpoint)

### 5.9 Community Polls/Quizzes

- `community/polls/`
- `community/polls/<id>/vote/`
- `community/quizzes/`
- `community/quizzes/<id>/submit/`

### 5.10 Admin

- `admin/resources/`
- `admin/resources/<id>/`
- `admin/resources/images/`
- `admin/resources/images/<id>/`
- `admin/analytics/`
- `admin/tickets/`
- `admin/approvals/business/`
- `admin/approvals/business/<id>/`
- `admin/approvals/marketing/`
- `admin/approvals/marketing/<id>/`
- `admin/moderation/reports/`
- `admin/moderation/reports/<id>/`
- `admin/moderation/actions/`
- `admin/users/`
- `admin/users/<id>/`
- `admin/reset-password/`
- `admin/logs/logins/`

## 6. Backend Documentation (Django)

Project config:

- `ffig_backend/settings.py`
- `ffig_backend/urls.py`

### 6.1 Backend App Responsibilities

### Authentication app (`authentication/`)

Purpose:

- Login/JWT issuance
- Registration
- OTP verification for signup
- OTP password reset
- Password change and user delete
- Admin password reset and admin user list/detail endpoints

Core files:

- `authentication/views.py`
- `authentication/serializers.py`
- `authentication/models.py`
- `authentication/urls.py`

### Members app (`members/`)

Purpose:

- Member profile data and profile edits
- Business profiles and marketing submissions
- Stories and story views
- Notifications
- Favorites/block/report
- Admin approvals, moderation actions, analytics views, login logs, and ticket list

Core files:

- `members/views.py`
- `members/serializers.py`
- `members/models.py`

### Events app (`events/`)

Purpose:

- Event CRUD + featured events
- Event sub-entities (speakers, agenda, FAQs, tiers)
- User ticket list and ticket artifacts

Core files:

- `events/views.py`
- `events/serializers.py`
- `events/models.py`

### Chat app (`chat/`)

Purpose:

- Conversation listing
- Message fetch/send
- Unread counters
- Community chat
- Search
- Mute and clear actions

Core files:

- `chat/views.py`
- `chat/serializers.py`
- `chat/models.py`

### Community app (`community/`)

Purpose:

- Poll and quiz modules via DRF ViewSets

Core files:

- `community/views.py`
- `community/serializers.py`
- `community/models.py`
- `community/urls.py`

### Home app (`home/`)

Purpose:

- Homepage content entities (hero, founder, alerts, ticker, business)
- App version metadata
- APK download endpoint

Core files:

- `home/views.py`
- `home/serializers.py`
- `home/models.py`
- `home/urls.py`

### Resources app (`resources/`)

Purpose:

- Resource catalog listing
- Resource seen/view tracking
- Admin CRUD for resources and gallery images

Core files:

- `resources/views.py`
- `resources/serializers.py`
- `resources/models.py`

### Payments app (`payments/`)

Purpose:

- Stripe payment and membership intent creation
- Free registration endpoint
- Connect onboarding/status
- Ticket and subscription verification
- Stripe webhook processing

Core files:

- `payments/views.py`
- `payments/urls.py`

### Core backend utilities (`core/`)

- `core/middleware.py` -> user last-seen tracking and membership-expiry request gating.
- `core/permissions.py` -> tier-based DRF permission helpers.

### 6.2 Backend Model Map

### Authentication models

- `PasswordResetOTP`
- `SignupOTP`

### Members models

- `Profile`
- `BusinessProfile`
- `MarketingRequest`
- `ContentReport`
- `Notification`
- `MarketingLike`
- `MarketingComment`
- `Story`
- `StoryView`
- `Conversation`
- `Message`
- `LoginLog`

### Events models

- `Event`
- `StripeConnectAccount`
- `EventSpeaker`
- `AgendaItem`
- `EventFAQ`
- `TicketTier`
- `Ticket`

### Chat models

- `Conversation`
- `ConversationClearStatus`
- `ConversationMuteStatus`
- `Message`

### Community models

- `Poll`
- `PollOption`
- `PollVote`
- `QuizQuestion`
- `QuizSubmission`

### Home models

- `HeroItem`
- `FounderProfile`
- `FlashAlert`
- `NewsTickerItem`
- `AppVersion`
- `BusinessOfMonth`

### Resources models

- `Resource`
- `ResourceImage`
- `ResourceView`

### 6.3 Middleware and Platform Rules

Defined in `core/middleware.py`:

- `UpdateLastSeenMiddleware`
  - updates profile last seen
  - creates daily login activity records
- `RequireActiveMembershipMiddleware`
  - blocks protected API calls for expired memberships
  - leaves auth/payments/profile and key renewal paths open

Key backend settings in `ffig_backend/settings.py`:

- Django 4.2 + DRF + SimpleJWT
- JWT auth default
- Throttles (`anon`, `user`)
- CORS/CSRF env-driven config
- Whitenoise static handling
- S3 storage when AWS vars exist; local file fallback otherwise
- Stripe + email configuration via environment variables

## 7. Admin Subsystem Map (Frontend + Backend)

### Admin Screens (Frontend)

Entry:

- `mobile_app/lib/features/admin/admin_dashboard_screen.dart`

Subareas:

- User management: `user_management_screen.dart`, `edit_user_screen.dart`
- Content approvals: `approvals/admin_approvals_screen.dart`
- Moderation: `moderation/admin_reports_screen.dart`, `moderation/report_detail_screen.dart`
- Home content CMS: files under `home_management/`
- Events CMS: files under `events_management/`
- Community CMS: files under `community_management/`
- Resources CMS: `resource_management_screen.dart`
- Analytics: `analytics/admin_analytics_screen.dart`, `analytics/event_revenue_screen.dart`
- Tickets: `tickets/admin_tickets_screen.dart`, `ticket_scanner_screen.dart`

### Admin Endpoints (Backend)

- `/api/admin/analytics/`
- `/api/admin/tickets/`
- `/api/admin/users/` and `/api/admin/users/<id>/`
- `/api/admin/reset-password/`
- `/api/admin/logs/logins/`
- `/api/admin/approvals/business/` and `/<id>/`
- `/api/admin/approvals/marketing/` and `/<id>/`
- `/api/admin/moderation/reports/` and `/<id>/`
- `/api/admin/moderation/actions/`
- `/api/admin/resources/`, `/<id>/`, `/images/`, `/images/<id>/`

## 8. Where To Find What (Quick Developer Guide)

If you need to change something, start here:

- App startup/init sequence:
  - `mobile_app/lib/main.dart`

- Base API URL/environment switch:
  - `mobile_app/lib/core/api/constants.dart`

- Tab routing and what appears on each tab:
  - `mobile_app/lib/features/home/dashboard_screen.dart`
  - `mobile_app/lib/shared_widgets/glass_nav_bar.dart`

- Tier gating and upgrade prompts:
  - `mobile_app/lib/core/services/membership_service.dart`
  - `mobile_app/lib/features/premium/locked_screen.dart`

- Login/signup/password flows:
  - `mobile_app/lib/features/auth/*.dart`
  - `authentication/views.py`
  - `authentication/serializers.py`
  - `authentication/urls.py`

- Member profile and directory behavior:
  - `mobile_app/lib/features/community/member_list_screen.dart`
  - `mobile_app/lib/features/community/public_profile_screen.dart`
  - `mobile_app/lib/features/community/profile_screen.dart`
  - `members/views.py`
  - `members/serializers.py`
  - `members/models.py`

- Event list/detail and ticket UX:
  - `mobile_app/lib/features/events/*.dart`
  - `mobile_app/lib/features/tickets/my_tickets_screen.dart`
  - `events/views.py`
  - `events/models.py`
  - `payments/views.py`

- Payment behavior:
  - `mobile_app/lib/core/services/stripe_service.dart`
  - `mobile_app/lib/core/services/iap_service.dart`
  - `payments/views.py`
  - `payments/urls.py`

- Chat logic (DM + community):
  - `mobile_app/lib/features/chat/*.dart`
  - `chat/views.py`
  - `chat/models.py`

- Notification behavior and deep links:
  - `mobile_app/lib/core/services/notification_service.dart`

- Resource vault:
  - `mobile_app/lib/features/resources/*.dart`
  - `resources/views.py`
  - `resources/models.py`

- VVIP feed/stories:
  - `mobile_app/lib/features/premium/*.dart`
  - `mobile_app/lib/features/premium/widgets/*.dart`
  - `members/views.py` (stories + marketing feed endpoints)

- Admin workflows:
  - frontend: `mobile_app/lib/features/admin/**`
  - app-side API orchestration: `mobile_app/lib/core/services/admin_api_service.dart`
  - backend routes: `ffig_backend/urls.py`, `authentication/urls.py`

- Global backend routing:
  - `ffig_backend/urls.py`
  - included routes: `authentication/urls.py`, `home/urls.py`, `payments/urls.py`, `community/urls.py`

- Membership-expiry access rules:
  - `core/middleware.py`

## 9. Known Notes and Risks Observed

These are important for maintenance:

- Duplicate URL entries in `ffig_backend/urls.py` exist for some routes (for example moderation actions, report route, chat message/unread paths, and business profile route). Functionality may still work, but cleanup is recommended.
- `mobile_app/lib/core/api/django_api_client.dart` is currently a placeholder and not a real shared client.
- `mobile_app/lib/features/auth/auth_screen.dart` and `mobile_app/lib/features/community/community_screen.dart` are placeholders.
- `mobile_app/lib/features/premium/vip_screen.dart` appears to be an alternate/older VIP surface while current premium tab uses `PremiumScreen` + `VVIPFeed`.
- `mobile_app/lib/core/services/ticket_service.dart` references `events/<eventId>/purchase/`, which is not present in current `ffig_backend/urls.py`; confirm whether this path is legacy.
- `mobile_app/lib/features/settings/blocked_users_screen.dart` uses import paths with one extra `../` (`../../../core/...`) relative to its location; review this file if analyzer/build errors appear.

## 10. Version and Dependency Snapshot

Frontend:

- Flutter package version: `1.0.357+357` (`mobile_app/pubspec.yaml`)
- Key integrations: Firebase Messaging, Stripe, In-App Purchase, QR scanning, PDF viewing, video, share.

Backend:

- Django `4.2.x`, DRF, SimpleJWT, Stripe Python SDK, firebase-admin, AWS storage support.
- Dependencies in `requirements.txt`.

## 11. Final System Summary

The app is a **membership-driven founder network platform** with:

- Public and member-only content surfaces
- Event commerce and ticket verification
- Networking via profiles and chat
- Premium media/content channels
- Strong admin controls for moderation and operational publishing

From a code-organization perspective:

- **Screens** are in `mobile_app/lib/features/**`.
- **Frontend business logic** is split between feature screens and `mobile_app/lib/core/services/**`.
- **Backend business logic** is in app `views.py`, serialization in `serializers.py`, and persistence in `models.py`.
- **Global route wiring** is in `ffig_backend/urls.py`.

This file is intended to be the main map for onboarding, maintenance, and future refactoring.
