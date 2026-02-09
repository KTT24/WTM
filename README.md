# WTM (What's The Move)

WTM is an iOS nightlife social app built with SwiftUI + Supabase.  
Users can discover nearby bars, post events, join event chats, and view weekly/monthly leaderboards.

## Features

- Auth onboarding with `email/password` or `phone OTP`
- Nearby bar discovery using Apple Maps + Core Location
- Event feed with live/upcoming sections
- "I'm Going" event tracking with chat reminders
- Weekly and monthly leaderboard cards
- In-app chat UI for event/bar threads
- Notification controls for:
  - weekend prompts
  - new events
  - event chat updates
- Optional "Nearby Parties" prediction system (Bluetooth presence + suggestion polling)

## Tech Stack

- SwiftUI
- Supabase Swift SDK (`supabase-swift`)
- MapKit + CoreLocation
- UserNotifications
- Supabase Edge Function (`update_user_bars`)

## Project Structure

- `WTM/Views/` - App screens and UI components
- `WTM/Backend/` - Data models, store, services, notifications
- `WTM/Event Prediction/` - Presence detection + party suggestion flow
- `supabase/functions/update_user_bars/` - Edge Function for profile bar updates

## Requirements

- Xcode (full app install, not only Command Line Tools)
- iOS Simulator or physical iPhone
- Supabase project with required tables/functions

Note: the project currently has `IPHONEOS_DEPLOYMENT_TARGET = 26.2` in `WTM.xcodeproj/project.pbxproj`.  
If your environment does not support that target, lower it in Xcode Build Settings.

## Run Locally

1. Open the project:

```bash
open WTM.xcodeproj
```

2. In Xcode:
- Select scheme `WTM`
- Pick an iOS simulator/device
- Build and Run

## Supabase Setup

WTM expects the following backend resources.

### Required tables

1. `profiles`
- `id uuid` (same as `auth.users.id`)
- `visited_bars jsonb`
- `nearby_bars jsonb`

2. `events`
- `id int`
- `name text`
- `date text` (`yyyy-MM-dd`)
- `start_time text` (`HH:mm:ss`, optional)
- `end_time text` (`HH:mm:ss`, optional)
- `location text`
- `description text`

3. `leaderboard_week`
- `username text`
- `rank int`
- `num_of_bars int`

4. `leaderboard_month`
- `username text`
- `rank int`
- `num_of_bars int`

5. Event prediction tables (if using Nearby Parties):
- `presence_tokens`
- `presence_sightings`
- `party_suggestions`

### Required Edge Function

- Function name: `update_user_bars`
- Source file: `supabase/functions/update_user_bars/index.ts`

Deploy (example):

```bash
supabase functions deploy update_user_bars
```

This function:
- authenticates the caller
- reads the current user row in `profiles`
- upserts `visited_bars` or `nearby_bars`

## Leaderboard Behavior

- The app reads leaderboard data directly from:
  - `leaderboard_week`
  - `leaderboard_month`
- Display fields are:
  - `username`
  - `rank`
  - `num_of_bars`

If leaderboard cards are empty, verify those tables contain rows and your RLS policies allow reads for authenticated users.

## Configuration Notes

- Supabase client is configured in `WTM/Backend/SupabaseManager.swift`.
- The project currently includes a publishable key in source for development.
- For production, move sensitive config to secure environment handling.

## Troubleshooting

- Build error about `xcodebuild` / developer directory:
  - Install full Xcode and switch toolchain:
  - `sudo xcode-select -s /Applications/Xcode.app/Contents/Developer`

- No nearby bars shown:
  - Ensure Location permission is granted
  - Use Settings debug location override if testing on simulator

- Notifications not delivered:
  - Enable notifications in iOS Settings
  - Check toggles in in-app Settings
