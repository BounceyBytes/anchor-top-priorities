# Anchor

Anchor is a SwiftUI iOS app for planning each day around your top three priorities, while keeping everything else in a backlog.

## Features

- Daily mission (top 3)
  - Assign up to 3 priorities to any day.
  - Reorder priorities with drag and drop.
  - Mark complete/incomplete with swipe gestures.
  - Punt to tomorrow, rename, delete, or move items to backlog.
  - Automatic guardrails enforce the 3-per-day limit.

- Backlog workflow
  - Keep unscheduled work in a backlog (compact + full-screen entry flows).
  - Move backlog items into a selected day while respecting limits.
  - Incomplete past-day priorities can be copied into backlog without duplicates.

- Navigation and streaks
  - Swipe horizontally between days.
  - Monthly view includes day completion indicators.
  - Top-1 streak visualization is shown in both monthly view and header circles.

- Focus timer
  - Built-in 25-minute Pomodoro timer per priority.

- Optional Google Calendar scheduling
  - Google Sign-In support.
  - Visual scheduling sheet with existing day events.
  - Conflict detection before creating calendar events.
  - Stores created event linkage on the corresponding priority item.

## Data model

Data is persisted with SwiftData using `PriorityItem`:

- `dateAssigned == nil`: backlog item
- `dateAssigned != nil`: day-assigned item (ordered by `orderIndex`)
- Optional fields support notes, backlog-copy lineage, and calendar linkage.

## Requirements

- Xcode 16+
- iOS 18+ simulator or device

## Run locally

1. Open `Anchor.xcodeproj` in Xcode.
2. Select the `Anchor` scheme.
3. Run on an iOS simulator or connected device.

## Google Calendar configuration

Google Calendar integration is implemented in:

- `Anchor/Utilities/GoogleCalendarManager.swift`

If you rotate or replace OAuth credentials:

1. Update the client ID used by `GoogleCalendarManager`.
2. Update the reversed-client-ID URL scheme in `AnchorApp-Info.plist`.
3. If needed, run `Anchor/add_url_scheme.sh` to help apply URL scheme updates.

## Project structure

- `Anchor/Views/`: SwiftUI screens and feature views.
- `Anchor/ViewModels/`: state and business logic (`PriorityManager`, `PomodoroTimer`).
- `Anchor/Models/`: SwiftData models (`PriorityItem`).
- `Anchor/Utilities/`: design system and platform integrations.

