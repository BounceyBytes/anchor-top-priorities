# Anchor

Anchor is an iOS app (SwiftUI) for keeping your **top 3 priorities per day** front-and-center, with a lightweight backlog and optional Google Calendar scheduling.

## What the app currently does

- **Daily “Mission” (Top 3)**
  - Pick up to **3 priorities** for any day.
  - Swipe **right** to mark complete, swipe **left** to un-complete.
  - Drag **up/down** to reorder the day’s priorities.
  - “Punt to tomorrow”, rename, delete, or move a priority back to the backlog.
  - The app enforces the **3-per-day limit** (and will automatically recover if an invalid state is detected).

- **Backlog**
  - Keep unscheduled tasks in a backlog.
  - Compact backlog panel at the bottom, with a full-screen backlog for fast entry.
  - Move backlog items onto the currently selected day (respecting the 3-per-day limit).

- **Date navigation + history**
  - Swipe to move between days.
  - **Monthly view** shows day-level completion indicators and a **Top-1 streak** visualization.
  - Header includes a streak “circles” timeline you can tap to jump to a date.

- **Pomodoro**
  - Start a 25-minute focus timer for a selected priority.

- **Google Calendar (optional)**
  - Sign in/out via Google Sign-In.
  - “Schedule” a priority: see today’s calendar events and place a task block on a draggable timeline.
  - Detects conflicts before scheduling.
  - Creates an event in the user’s **primary** calendar and stores the resulting event ID on the priority item.

## Data model

The app persists data using **SwiftData** with a single model:

- `PriorityItem`
  - `dateAssigned == nil` → backlog item
  - `dateAssigned != nil` → assigned to that day (ordered by `orderIndex`)

## Running the app

- Open `Anchor.xcodeproj` in Xcode
- Select an iOS Simulator (or device) and Run

## Google Calendar setup notes

Google Calendar features use the client ID in:

- `Anchor/Utilities/GoogleCalendarManager.swift`

If you change the Google OAuth client ID:

- Update the **URL scheme** in `AnchorApp-Info.plist` to the reversed client ID
- There’s also a helper build script: `Anchor/add_url_scheme.sh`

## Project layout (high level)

- `Anchor/Views/`: SwiftUI screens (daily priorities, backlog, monthly view, scheduling sheet, pomodoro)
- `Anchor/ViewModels/`: app logic (`PriorityManager`, `PomodoroTimer`)
- `Anchor/Utilities/`: design system, confetti/tick-rain effect, Google Calendar integration


