# DayShift — Development Specification

Version: 1.0 (scope reduced for a 4-day build, due Wed 7 Oct 2026)

## How to use this spec (for Claude Code)

- Work through Section 9 one step at a time. After each small task, STOP and wait
  for review before continuing.
- Implement only what this spec describes. Anything listed in 0.5 "Out of scope"
  must not be added, even if it seems helpful.
- Names in this spec (types, methods, UI text) are intentional domain vocabulary.
  Use them exactly.
- The prototype in /Design shows the full product vision. It contains screens and
  features beyond this build. Follow Section 7 for what to build; use the
  prototype only for layout and wording of those screens.

---

## 0. Project Overview

### 0.1 Purpose
DayShift helps knowledge-work freelancers in Sydney keep their daily plans on
track when conditions change. It checks each plan against heat, air quality
(smoke), UV, wind and rain at that place and time, plus travel time and opening
hours. When a plan needs attention, it suggests up to three options (a different
time or a different place) that still fit around the rest of the day.

### 0.2 Primary Stakeholder
Lin, 31, freelance UI/UX designer in Sydney. Rents in the inner west with no air
conditioning. Works from home, a library or a café, meets clients online most
days, runs in the park and does a weekly grocery run.

### 0.3 Primary Use Case
Suggest and accept an alternative for a plan that needs attention.

### 0.4 In Scope
- Plans are created inside the app.
- Weather and air quality come from the Open-Meteo API, per place coordinates.
- Travel time is estimated from straight-line distance.
- Place coordinates come from an address via CLGeocoder.
- Options are produced by transparent rules, not an AI model.
- Core Data store in an App Group shared container.
- Two extensions: WidgetKit widget, Notification Content Extension.

### 0.5 Out of Scope (do NOT implement)
- EventKit / system calendar import
- MapKit routing (MKDirections) and MapKit place search
- CloudKit, user accounts, login
- Background refresh (BGAppRefreshTask); checks run when the app becomes active
- Undo, History screen, onboarding, My Activities management, custom activities
- Switching to a different activity or to online as an option
- Workplace recommendation, best-time suggestions, Lock Screen widget
- Accepting an option inside the notification extension (it opens the app instead)
- Third-party Swift packages

### 0.6 Technical Baseline
- iOS 17.0+, SwiftUI, Observation (`@Observable`) for ViewModels
- Core Data (not SwiftData, not SQLite directly)
- Swift Testing for unit tests
- App Group ID: `group.com.utsstudent.zhaoziying.dayshift`
  (adjust to the signing team's prefix if needed, and update README)

---

## 1. Project Structure

### 1.1 Targets
| Target | Type | Purpose |
|---|---|---|
| DayShift | iOS App | SwiftUI views, ViewModels, app services |
| DayShiftWidget | Widget Extension | Next plan status on the Home Screen |
| DayShiftNotificationContent | Notification Content Extension | Custom view for the `upcomingPlan` category |
| DayShiftKit | Local Swift Package | Shared domain, use cases, repositories, Core Data |
| DayShiftKitTests | Test target in DayShiftKit | Unit tests with mocks |

All three app/extension targets enable the App Group capability with the same ID.

### 1.2 Folder Layout
```
DayShift/
├── DayShift/                      main app
│   ├── App/                       DayShiftApp.swift, AppDependencies.swift
│   ├── Views/                     one folder per screen
│   ├── ViewModels/
│   └── Services/                  WidgetCenterRefresher, LocalNotificationScheduler,
│                                  CLGeocoderPlaceGeocoder
├── DayShiftWidget/
├── DayShiftNotificationContent/
├── Design/                        prototype HTML + interaction spec (reference only)
└── Packages/DayShiftKit/
    ├── Sources/DayShiftKit/
    │   ├── Domain/
    │   ├── UseCases/
    │   ├── Repositories/          protocols only
    │   ├── Persistence/           .xcdatamodeld, CoreDataStack, repository implementations,
    │   │                          ActivityQuery
    │   ├── Conditions/            ConditionsService protocol, OpenMeteoConditionsService
    │   ├── Travel/                TravelTimeService protocol, StraightLineTravelTimeService
    │   ├── Services/              WidgetRefreshing, NotificationScheduling, PlaceGeocoding protocols
    │   └── Shared/                AppGroup.swift, Clock helpers
    └── Tests/DayShiftKitTests/
        ├── Mocks/
        ├── Fixtures/              LinsThursday.swift
        ├── DomainTests/
        ├── UseCaseTests/
        └── QueryTests/
```

### 1.3 Dependency Rules
- Domain imports Foundation only.
- Use cases depend on Domain and on PROTOCOLS only.
- Persistence, Conditions, Travel and app Services implement those protocols.
- ViewModels: all writes and all business rules go through use cases.
  Read-only data may come from a repository or service protocol directly
  (e.g. My Places from PlaceRepository, the Plan Detail chart from ConditionsService).
  ViewModels never import CoreData.
- Views depend on ViewModels only.
- WidgetKit and UserNotifications are imported only in app Services and
  extension targets.

---

## 2. Domain Models
Value types in `DayShiftKit/Domain`. Invariants are enforced in throwing or
failable initialisers. Rules that depend on other data belong to use cases.

### 2.1 Place
- `id: UUID`, `name: String`, `kind: PlaceKind`, `address: String`
- `latitude: Double`, `longitude: Double`, `suburb: String?`
- `isIndoor: Bool`, `isCooled: Bool`
- `uncooledHeatLimitC: Double?` — only for indoor places without AC.
  Meaning: "when it is hotter than this outside, this place is too hot". Default 30.
- `isAlwaysOpen: Bool`, `openingHours: OpeningHours?`
  (`isAlwaysOpen == false && openingHours == nil` means hours unknown)
Invariants: name not empty after trimming; outdoor place cannot be cooled;
uncooledHeatLimitC between 20 and 45 when set.

`PlaceKind` (13): home, library, cafe, coworkingSpace, office, park, beach, gym,
pool, sportsCourt, galleryOrMuseum, shoppingCentre, other.
Each kind provides defaults: `defaultIsIndoor`, `defaultIsCooled`,
`typicalCrowd(at: Date) -> CrowdLevel` (estimate, e.g. café busy weekdays
12–2 pm, shopping centre busy 5–7 pm and Saturday mornings, home always quiet).

### 2.2 OpeningHours
- `opensAt: Int`, `closesAt: Int` (minutes after midnight), `closedWeekdays: Set<Int>`
- Invariant: `closesAt > opensAt`
- `isOpen(throughout interval: DateInterval, calendar: Calendar) -> Bool`

### 2.3 ActivityType (static catalogue, not stored in Core Data)
- `id: String` (e.g. "run"), `name`, `symbolName`, `purpose: ActivityPurpose`
- `sensitivities: Set<ConditionSensitivity>` (heat, poorAirQuality, uv, wind, rain)
- `suitablePlaceKinds: Set<PlaceKind>`, `canBeOnline: Bool`
- `ActivityCatalogue.all` contains: Run, Walk, Cycling, Indoor swim, Gym session,
  Focus work, Client meeting, Coffee with a friend, Picnic, Outdoor sketching,
  Gallery visit, Grocery run.

### 2.4 PlannedActivity (a "plan")
- `id: UUID`, `typeID: String`, `title: String`
- `start: Date`, `durationMinutes: Int`, computed `end`, `interval`
- `place: Place?` (nil only when `mode == .online`)
- `mode: ActivityMode` (.inPerson, .online)
- `flexibility: ActivityFlexibility`
- `status: PlanStatus` (.planned, .adjusted, .cancelled)
Invariants: title not empty; duration 5–720 minutes; online ⇔ place == nil.

### 2.5 ActivityFlexibility
- `movableWindow: DateInterval?` (nil = fixed time)
- `allowsPlaceChange: Bool`
- Invariant: window duration ≥ plan duration.
- `allowsAnyChange: Bool` = movableWindow != nil || allowsPlaceChange

### 2.6 Conditions
- `HourlyConditions`: `time`, `temperatureC`, `apparentTemperatureC`,
  `precipitationProbability` (0–100), `uvIndex`, `windGustsKmh`, `pm25`
- `AirQualityCategory`: good, fair, poor, veryPoor, extremelyPoor, from hourly PM2.5.
  Thresholds (µg/m³): good < 25, fair < 50, poor < 100, veryPoor < 300, else extremelyPoor.
  TODO (developer): confirm these against the NSW Air Quality Categories before
  submission and cite the source in README.
- `ConditionsForecast`: `latitude`, `longitude`, `fetchedAt`, `hours`;
  `conditions(during: DateInterval) -> [HourlyConditions]`

### 2.7 ComfortPreferences
| Field | Default | Valid range |
|---|---|---|
| maxApparentTemperatureC | 32 | 20–45 |
| worstAcceptableAirQuality | .fair | good…poor |
| maxUVIndex | 8 | 1–15 |
| maxWindGustsKmh | 40 | 10–120 |
| maxRainProbability | 40 | 0–100 |
| earliestPlanTime / latestPlanTime | 06:00 / 21:00 | earliest < latest |
| minimumBufferMinutes | 15 | 0–120 |
| leaveReminderMinutes | 10 | 5–30 |
| travelMode | .publicTransport | walking, publicTransport, driving |

### 2.8 PlanCheck and PlanFinding
- `PlanCheck`: `planID`, `checkedAt`, `leaveBy: Date?`,
  `travel: TravelEstimate?`, `findings: [PlanFinding]`,
  `overallStatus` (.looksGood, .needsAttention — needsAttention if any finding is a problem)
- `PlanFinding`: `factor` (.conditions, .travel, .openingHours, .crowds),
  `severity` (.fine, .tip, .problem), `message: String` (plain language)
- Rules for messages:
  - Never claim an indoor temperature. Use: "It reaches 33°C outside this
    afternoon. You've said your room gets too hot above 30°C."
  - Online plans: "Online, so the weather doesn't affect this plan."
  - Crowds are always estimates: "Usually busy · estimate". Crowds are never a problem.
  - Time outside on the way under 10 minutes that exceeds a limit is a `.tip`,
    e.g. "UV 9 · 4 min outside, wear sunscreen".

### 2.9 DaySchedule
- `date`, `plans: [PlannedActivity]` (non-cancelled, sorted)
- `requiredGap(travelMinutes:buffer:) = max(buffer, travelMinutes)`
- `conflicts(for interval: DateInterval, travelBefore: Int, travelAfter: Int,
   excluding: Set<UUID>, buffer: Int) -> [ScheduleConflict]`
- `ScheduleConflict`: .overlaps(planID), .notEnoughGap(planID, available, required)
- Travel minutes are computed by the use case beforehand, so DaySchedule stays pure.

### 2.10 TravelEstimate
- `minutes: Int`, `mode: TravelMode`, `isEstimate: Bool` (always true in this build)

### 2.11 AlternativePlan
- `id`, `planID`
- `adjustment: Adjustment` — `.shiftTime(newStart: Date)` or `.changePlace(Place)`
- `knockOn: KnockOnChange?` — `planID`, `title`, `newStart` (at most one)
- `score: Int` (0–100)
- `explanation: String` — e.g. "Air quality returns to Good and UV is low."
- `scheduleNote: String` — e.g. "Grocery run moves from 5:30 to 6:30 pm.
  Your 11 am call is not affected."

### 2.12 AdjustmentRecord
- `id`, `planID`, `kind` (.shiftTime, .changePlace), `previousStart`, `newStart`,
  `previousPlaceName`, `newPlaceName`, `reason: String`, `acceptedAt`

---

## 3. Use Cases
Structs in `DayShiftKit/UseCases`. One `execute` method. Depend only on protocols.
Receive `now: Date`. Throw their own error enum conforming to `LocalizedError`
(`errorDescription` = what went wrong, `recoverySuggestion` = what to do next).

### 3.1 PlanActivityUseCase
Creates or edits a plan.
Rules:
- Cannot start in the past.
- Must be within planning hours.
- No conflicts with other plans that day (gap rule, using travel estimates).
- If the place has known opening hours, it must be open for the whole plan.
- In-person activity types only; online only if the type `canBeOnline`.
After saving: run the check for this plan (through the `PlanChecking` protocol,
which CheckUpcomingPlansUseCase provides), refresh the widget, schedule
(or reschedule) the leave reminder for in-person plans.
Errors (`PlanActivityError`):
- `startsInThePast` — "This plan starts in the past." / "Choose a start time later than now."
- `outsidePlanningHours` — "This plan is outside your planning hours (6:00 am to 9:00 pm)." /
  "Choose a time within these hours, or change your planning hours in Settings."
- `overlaps(title, time)` — "This plan overlaps with Client call at 11:00 am." /
  "Choose another time, or shorten one of the plans."
- `notEnoughTimeToGetThere(title, minutes)` — "You need 25 minutes to get here after Focus work." /
  "Start later, or choose a place closer to your previous plan."
- `notEnoughTimeForNextPlan(title, minutes)` — "You need 20 minutes to get to Grocery run after this plan." /
  "Start earlier, or choose a place closer to your next plan."
- `placeClosed(name)` — "Newtown Library is closed for part of this plan." /
  "Check the opening hours in My Places, or choose another place."
- `onlineNotAvailable(type)` — "Run can't be done online." / "Choose a place for this plan."

### 3.2 CheckUpcomingPlansUseCase
Checks today's plans that have not started and are not cancelled.
For each plan:
- Conditions: for in-person plans at outdoor places, compare each hour against
  the preferences for the type's sensitivities. For indoor uncooled places, once
  the day's outdoor temperature exceeds `uncooledHeatLimitC`, the place is too hot
  from that hour to the end of the day. Travel time outside: under 10 min → tip.
  On the way (indoor places only; outdoor plans are already checked hour by hour):
  compare the hours between leave-by and start against all of Lin's limits.
  Minutes outside: walking = the whole trip, public transport = 4 (to and from
  the stop), driving = 0.
  If no hourly conditions cover the plan (missing from the forecast), add a
  `.conditions` tip "Weather and air quality for this time aren't available."
  instead of treating the conditions as fine.
- Travel: estimate from the previous plan's place (or Home for the first plan);
  compute `leaveBy = start - travel minutes`. Not enough gap → problem.
- Opening hours: closed during the plan → problem; unknown → tip
  ("Opening hours not confirmed.").
- Crowds: `typicalCrowd` of the place kind, always fine or tip.
After checking: save each PlanCheck, refresh the widget, schedule a
plan-affected alert for each NEW problem (same plan + same reason only once),
and keep leave reminders in sync.
Errors (`CheckUpcomingPlansError`):
- `forecastUnavailable` — "Weather and air quality aren't available right now." /
  "Your plans are still saved. DayShift will check again when you next open the app."
  (The ViewModel then shows the last saved checks with "Checked <time>".)

### 3.3 SuggestAlternativesUseCase (primary use case)
Works for any plan whose flexibility allows at least one change.
Candidates:
1. Time shifts: every 30 minutes inside the movable window and planning hours,
   same place, same duration.
2. Place changes (if allowed): saved places whose kind suits the activity type,
   indoor when the problem is outdoor conditions, cooled when the problem is heat,
   open for the whole plan; same time, same duration.
3. Knock-on: if a time shift is blocked by exactly one flexible plan, try moving
   that plan inside its own window; the moved plan must also pass the check.
Each candidate must pass the same checks as 3.2 with no problems.
Scoring (0–100):
- Conditions margin 0–40: outdoor places use the activity's sensitivities;
  indoor places without AC use the outside temperature against the place's limit;
  indoor places with AC score the full 40. For each measure, take the worst hour
  during the plan: margin = (limit − worst) / limit, kept between 0 and 1. Air
  quality compares PM2.5 with the top of Lin's worst acceptable category (Fair → 50).
  Score = 40 × the smallest margin, rounded.
- Smallest change 0–30: a time shift scores 30 minus 1 per 30 minutes moved
  (not below 0); a place change at the same time scores 15.
- No knock-on: 20.
- Crowds 0–10: `typicalCrowd` of the place at the option's time: usually quiet 10,
  moderately busy 5, busy 0.
Return the best three by score.
- Plan needs attention: options must solve every problem (no problems in their check).
- Plan looks good ("Other good options"): return up to three valid options ranked by
  score, even if none beats the current plan, so "Find other options" always shows
  options for a flexible plan. Each explanation says what is different, e.g.
  "Usually quiet after 7 pm (estimate)."
Rules: never move fixed plans; never change duration; at most one knock-on.
Errors (`SuggestAlternativesError`):
- `planHasNoFlexibility` — "This plan is fixed, so DayShift can't suggest changes." /
  "Edit the plan to allow a different time or place."
- `noViableAlternative` — "No time or place today keeps this plan within your limits." /
  "Try another day, or adjust your limits in Settings."
  For a plan on another day, "today" becomes "tomorrow" or the day, e.g. "on Thursday 8 Oct".
- `forecastUnavailable` (same wording as 3.2)

### 3.4 AcceptAlternativeUseCase
Rules:
- Re-check the alternative with the latest forecast and schedule.
- The plan must not have started.
- Main change and knock-on change are saved in one transaction; if anything fails,
  nothing changes.
- One AdjustmentRecord per changed plan; changed plans get status `.adjusted`.
After saving: refresh the widget, remove pending alerts for changed plans,
reschedule their leave reminders, re-check the rest of the day.
Errors (`AcceptAlternativeError`):
- `noLongerAvailable(reason)` — "This option is no longer possible: Newtown Library closes at 5 pm." /
  "Go back to see updated options."
- `planAlreadyStarted` — "This plan has already started." / "Plan a new activity instead."
- `saveFailed` — "Your change couldn't be saved." / "Please try again. Your original plan hasn't changed."

### 3.5 UpdateComfortPreferencesUseCase
Rules: every value within the ranges in 2.7; earliest < latest.
After saving: refresh the widget; ViewModel then runs 3.2 again.
Errors (`UpdateComfortPreferencesError`):
- `valueOutOfRange(name, range)` — "Max feels-like temperature needs to be between 20°C and 45°C." /
  "Enter a value in this range."
- `planningHoursInvalid` — "Your earliest planning time needs to be before your latest." /
  "Adjust one of the times."

### 3.6 SavePlaceUseCase
Rules: unique name; address must resolve to coordinates (via PlaceGeocoding);
outdoor place cannot be cooled.
Errors (`SavePlaceError`):
- `duplicateName(name)` — "You already have a place called 'Home'." /
  "Use a different name, or edit the existing place."
- `addressNotFound` — "DayShift couldn't find that address." /
  "Check the spelling, or add the suburb and postcode."

---

## 4. Persistence

### 4.1 Core Data Model (`DayShift.xcdatamodeld` in DayShiftKit)
Enums stored as String raw values. Optional numbers use NSNumber.

**PlaceEntity**
- id UUID, name, kindRaw, address, suburb?, latitude Double, longitude Double
- isIndoor Bool, isCooled Bool, uncooledHeatLimitC NSNumber?
- isAlwaysOpen Bool, opensAt NSNumber?, closesAt NSNumber?, closedWeekdays String
- `activities` → ActivityEntity, to-many, inverse `place`, delete rule **Deny**

**ActivityEntity**
- id UUID, typeID, title, modeRaw, statusRaw
- start Date, end Date (stored for overlap queries), durationMinutes Int16
- movableWindowStart Date?, movableWindowEnd Date?, allowsPlaceChange Bool
- checkStatusRaw String? ("looksGood" / "needsAttention"; nil until first checked),
  checkSummary String?, checkedAt Date?, leaveBy Date?, travelMinutes NSNumber?,
  travelModeRaw String?,
  findingsData Binary? (JSON-encoded [PlanFinding])
- notifiedReasonKeys String? (e.g. "poorAirQuality,heat")
- `place` → PlaceEntity, to-one, delete rule Nullify
- `adjustments` → AdjustmentRecordEntity, to-many, delete rule **Cascade**

**AdjustmentRecordEntity**
- id, kindRaw, previousStart, newStart, previousPlaceName?, newPlaceName?,
  reason, acceptedAt
- `activity` → ActivityEntity, to-one, inverse `adjustments`, Nullify

**PreferencesEntity** (single row) — all fields of 2.7.

### 4.2 Domain Queries (`ActivityQuery`, pure functions returning NSPredicate)
- `plans(on day:)` — `start >= startOfDay AND start < startOfNextDay AND statusRaw != "cancelled"`
- `checkablePlans(on day:, now:)` — same day AND `start > now` AND
  `statusRaw IN {"planned","adjusted"}` → "today's plans that haven't started"
- `plans(overlapping interval:, excluding ids:)` — `start < %@ AND end > %@ AND
  NOT (id IN %@) AND statusRaw != "cancelled"`
- `plansNeedingAttention(on day:)` — same day AND `checkStatusRaw == "needsAttention"` AND
  `statusRaw != "cancelled"`

### 4.3 Repository Protocols (async throws, domain types only)
- `ActivityRepository`: `plans(on:)`, `checkablePlans(on:now:)`,
  `plans(overlapping:excluding:)`, `save(_:)`, `delete(id:)`,
  `saveCheck(_ check: PlanCheck)`, `check(for planID: UUID) -> PlanCheck?`,
  `markNotified(planID:reasonKeys:)`, `notifiedReasonKeys(planID: UUID) -> Set<String>`,
  `applyAdjustment(changedPlans: [PlannedActivity], records: [AdjustmentRecord])` (atomic)
- `PlaceRepository`: `allPlaces()`, `place(named:)`, `save(_:)`, `home()`
- `PreferencesRepository`: `load()` (defaults if none), `save(_:)`

### 4.4 Core Data Implementation
- `CoreDataStack` loads the model from `Bundle.module`; store URL from
  `FileManager.containerURL(forSecurityApplicationGroupIdentifier:)`.
  If unavailable, the app shows a domain error screen; extensions show their
  empty state. Never crash.
- Persistent history tracking enabled; the app re-fetches when it becomes active.
- Entities never leave the Persistence folder.

### 4.5 Default Content (no demo mode, no sample data)
- No plans today: Today shows "Your day is clear." and "Plan an activity".
- Conditions unavailable: show last saved checks with "Checked <time>";
  if never loaded, show the 3.2 error message as a banner.
- No screen or widget ever shows "No data" or "Unknown" alone.

---

## 5. External Data

### 5.1 ConditionsService
`forecast(for coordinates: [Coordinate], on day: Date) async throws -> [Coordinate: ConditionsForecast]`
`OpenMeteoConditionsService` (URLSession only):
- `https://api.open-meteo.com/v1/forecast` hourly: `temperature_2m,
  apparent_temperature, precipitation_probability, uv_index, wind_gusts_10m`
- `https://air-quality-api.open-meteo.com/v1/air-quality` hourly: `pm2_5`
- `timezone=Australia/Sydney`, `timeformat=unixtime`; multiple coordinates
  comma-separated in one request
- One coordinate returns a JSON object, several return a list. Open-Meteo returns
  grid-point coordinates, not the requested ones, so results are matched to the
  requested coordinates by order. Weather and air quality are joined by time; an
  hour with a missing or null value is left out.
- Coordinates rounded to 2 decimal places; responses cached for 1 hour;
  the last successful result is saved to the App Group container as JSON.
- Parameter names confirmed against the Open-Meteo docs and live responses (4 Oct 2026).

### 5.2 TravelTimeService
`travelEstimate(from: Coordinate, to: Coordinate, mode: TravelMode) -> TravelEstimate`
`StraightLineTravelTimeService`: haversine distance × 1.3 (road factor);
walking 4.5 km/h; public transport 20 km/h + 10 min waiting; driving 30 km/h.
Round up to whole minutes. Same place → 0. With public transport, a trip that takes
15 minutes or less on foot is walked instead (estimate mode `.walking`).

### 5.3 PlaceGeocoding
`coordinates(for address: String) async throws -> (latitude, longitude, suburb?)`
App implementation uses `CLGeocoder`.

---

## 6. Extensions

### 6.1 Shared Rules
- Extensions only display results saved by the main app. They read the Core Data
  store through DayShiftKit repositories and never call Core Data APIs directly.
- They never show "No data" or a blank view, and never crash if the store is missing.

### 6.2 Widget: NextPlanWidget
Families: `systemSmall`, `systemMedium`.
- Small: "Next · 11:00 am", plan title, place or "Online", status (icon + words),
  short reason or "Leave by 12:35 pm".
- Medium: next plan in detail (status, reason, leave-by) plus the following
  two plans in one line each.
- Empty: "Your day is clear." / "Plan an activity in DayShift."
  All done: "That's everything for today."
  Below either message, the next plan within the next 7 days, if any:
  "Coming up · Tomorrow" with "7:00 am Run · Enmore Park" (medium), or
  "Tomorrow 7:00 am · Run" (small). It shows no check status, since future
  plans aren't checked yet, and tapping it opens that plan. With nothing in
  the next 7 days, only the message.
- Timeline: an entry now and at each plan's start and end; policy `.atEnd`.
  After the last plan has ended, policy `.after` the start of tomorrow.
- Tap: `widgetURL` dayshift://plan/<id> (small); medium uses `Link` per row.
- Reload: `WidgetRefreshing.reload()` is called by use cases 3.1, 3.2, 3.4, 3.5 and
  after deleting a plan. App implementation calls `WidgetCenter.shared.reloadAllTimelines()`.

### 6.3 Notification Content Extension: `upcomingPlan` category
Scheduled by the app through `NotificationScheduling` (local notifications, time
interval or calendar triggers). Identifiers: `leave-<planID>`, `affected-<planID>`.

Situation A — Leave reminder (every in-person plan):
- Fires `leaveReminderMinutes` before `leaveBy`.
- Title "Leave in 10 min for Focus work"; body "Newtown Library · 12 min by bus.
  Press and hold for details."

Situation B — Plan affected (new problem found by 3.2):
- Only for plans starting more than 15 minutes from now; once per reason.
- Title "Your 7:00 am run is affected"; body "Smoke until 10 am. Press and hold to
  see a better option."

Payload (`userInfo`): planID, situation, findings, hourly values for the chart,
limit value, top option summary (if any). The extension needs no network.

Expanded view (SwiftUI):
- A: arrival time; "On the way" rows (feels-like, UV, rain, air quality, each with
  "your limit …"; tips marked "Tip"); destination rows (indoor/AC, opening hours,
  crowds estimate); verdict "Your plan looks good." or the problem.
- B: reason, Swift Charts line chart of the relevant condition with a dashed limit
  line, and the top option with its schedule note.

Actions:
- `seeOptions` "See options" (`.foreground`) → app opens dayshift://options/<planID>
- `keepPlan` "Keep my plan" → dismiss
- `gotIt` "Got it" (A only) → dismiss

App rules:
- `UNUserNotificationCenterDelegate.willPresent` returns `.banner, .sound` so
  alerts show while the app is open.
- When a plan is edited, deleted, adjusted or has started, its pending and
  delivered notifications are removed.
- Notification permission is requested the first time a plan is saved, after a
  short explanation sheet ("Allow alerts so DayShift can remind you when to leave
  and tell you when a plan is affected."). If declined, Today shows
  "Alerts are off. Turn them on in Settings to get leave reminders."

---

## 7. User Interface
Layout and wording follow `/Design/DayShift_Prototype.html` for these screens only.
Values come from real data, never hard-coded from the prototype.

### 7.1 Vocabulary
"Activity" = a type (Run). "Plan" = one scheduled activity. Status words:
"Looks good", "Needs attention", tag "Moved" for adjusted plans.

### 7.2 Navigation
Tab bar: Today | My Places | Settings.
Deep links: dayshift://today, dayshift://plan/<id>, dayshift://options/<id>.

### 7.3 Screens
| Prototype reference | View | Uses |
|---|---|---|
| Today, TodayEmpty, TodayBanners, TodayUpdated | TodayView (incl. "Coming up") | CheckUpcomingPlansUseCase; ActivityRepository (read: today and the next 7 days) |
| PlanDetailRun/Focus/Grocery/Call | PlanDetailView | saved PlanCheck; delete via ActivityRepository; chart from ConditionsService |
| OptionsRun/Focus/Grocery/None | OptionsView | SuggestAlternativesUseCase, AcceptAlternativeUseCase |
| PlanEditor, PlanEditorError | PlanEditorView | PlanActivityUseCase |
| MyPlaces | MyPlacesView | PlaceRepository (read) |
| PlaceEditor, PlaceEditorNew | PlaceEditorView | SavePlaceUseCase (address field replaces Apple Maps search) |
| Settings | SettingsView + simple editors | UpdateComfortPreferencesUseCase |
Not built: Welcome, ChooseActivities, AlertsPermission (replaced by the sheet in
6.3), History, AddPlace search, MyActivities, CreateActivity, Lock Screen widget,
workplace card, "Best times today".

### 7.4 Display Rules
- Status = icon + words. Amber only for "Needs attention"; teal for primary
  actions, selection, toggles.
- Plan Detail shows four check rows: Conditions (with chart for the problem
  condition), Travel, Opening hours, Crowds.
- "See better options" when needs attention; "Find other options" when it looks
  good; hidden when the plan is fixed.
- After accepting: return to Today with toast "Your run is now at 5:30 pm."
- Estimates labelled "estimate". Unknown hours: "Opening hours not confirmed."
- Errors: `errorDescription` bold, `recoverySuggestion` below. Form errors inline;
  "Save plan" disabled while an inline error is shown.
- Today has a "Coming up" section below "Your plans": plans for the next 7 days,
  grouped by day ("Tomorrow", "Tuesday 6 Oct"). Future plans are not checked
  (3.2 checks today only), so they show "Checked on the day" in grey. Tapping one
  opens Plan Detail, where it can be edited or deleted.
- Dynamic Type supported; icons have VoiceOver labels.

---

## 8. Testing
Swift Testing, in DayShiftKit, never using the Core Data stack. `now` is fixed.

### 8.1 Mocks
MockActivityRepository, MockPlaceRepository, MockPreferencesRepository,
MockConditionsService (scripted hours per place), MockTravelTimeService,
MockPlaceGeocoding, MockWidgetRefresher (counts reloads),
MockNotificationScheduler (records scheduled/removed IDs). Each can be set to throw.

### 8.2 Fixture: LinsThursday
now Thursday 6:40 am. Plans: Run 7:00–7:45 Enmore Park (window 6:00 am–9:00 pm);
Client call 11:00–11:30 Online (fixed); Focus work 1:00–5:00 pm Home (place change
allowed); Grocery run 5:30–6:00 pm Marrickville Metro (window 4:00–8:30 pm).
Places: Home (uncooled, 30°C), Newtown Library (cooled, 9 am–6 pm), Enmore Park,
Marrickville Metro (until 9 pm). Conditions: PM2.5 poor until 10 am; 33°C 2–4 pm;
UV 9 11 am–3 pm. Default preferences.

### 8.3 Required Tests (minimum set)
1. A valid run is saved, the widget refreshes and a leave reminder is scheduled
2. A plan overlapping the 11 am client call is rejected with "overlaps"
3. A run during smoke above Lin's limit needs attention
4. Focus work at home needs attention when it reaches 33°C outside
5. UV 9 on a 4-minute walk is a tip, not a problem (boundary: 10 minutes)
6. A smoky morning run moves to 5:30 pm and the grocery run follows
7. The fixed client call is never moved and every option keeps its duration
8. A fixed plan gives planHasNoFlexibility
9. Accepting the run option saves both plans together with two records and refreshes the widget
10. Accepting after the plan has started gives planAlreadyStarted
11. A temperature limit above 45°C is rejected
12. A second place called "Home" is rejected
13. Gap between plans is the larger of buffer and travel time (boundary: exactly 15 min is enough)
14. The checkable-plans predicate excludes started and cancelled plans (query layer)

Further tests if time allows: forecast unavailable, noViableAlternative, place
closed, save failure leaves plans unchanged, other good options for a plan that
looks good, notified only once per reason.

---

## 9. Development Plan (due Wed 7 Oct, 23:59 — submit Wednesday daytime)

### 9.1 Workflow
- One feature branch per step; merge to main by GitHub pull request only when
  it builds, tests pass and the check is done.
- Commits: `feat:`, `fix:`, `test:`, `docs:`. Example:
  `feat: add SuggestAlternativesUseCase with knock-on change`
- Claude Code does one small task, then stops for review.

### 9.1a Commit Policy
- Claude Code never commits. It stops after each task; the author reviews,
  runs the tests and commits.
- Each step follows this order where it applies:
  1. test: failing tests from Section 8 for the step
  2. feat: smallest implementation that makes them pass
  3. refactor: changes requested in the author's review (no behaviour change)
  4. fix: problems found when running on the Simulator or a device
  5. style: layout and wording aligned with the prototype
  6. docs: README, spec or decision log updates
- Small commits: one idea per commit. Never commit a whole step at once.
- All seven types must appear in the history, each for real work:

| Type | Used for | Expected in steps |
|---|---|---|
| build | Xcode project, targets, App Group entitlements, package wiring, schemes | 1, 2, 8, 9 |
| chore | .gitignore, folder organisation, /Design files, cleanup of unused files | 1, 11 |
| test | failing tests written before each use case; boundary and error tests | 3, 4, 6, 7, 10 |
| feat | domain models, repositories, use cases, screens, extensions | 2–10 |
| refactor | review findings: renaming to domain words, extracting helpers, splitting views | 3–10 |
| fix | problems found on the Simulator or a real iPhone | 2, 5–10 |
| style | layout, spacing and wording aligned with the prototype | 6–10 |
| docs | README sections, spec changes, decision log, AI assistance note | 1, 5, 9–11 |

### 9.1b Review Checklist (author, after every task)
- Names use domain vocabulary (no "data", "item", "manager")
- ViewModels never touch Core Data
- Every error says what went wrong and what to do next
- Nothing outside the scope in 0.5
- Test names read like Lin's situation
- Run it on the Simulator: does it match the prototype?
Findings become refactor, fix or style commits.

### 9.2 Steps
**Step 1:**
1. `feature/project-setup` — project, three targets, DayShiftKit, App Group on all
   targets, README skeleton, .gitignore. Check: everything builds.
2. `feature/shared-store-spike` — minimal model from Bundle.module in the App Group;
   app saves one plan, widget shows its title. Check on the Simulator (required).
   Try a real iPhone once; the author uses a free Apple account, so if signing
   blocks App Groups on the device, development and the demo use the Simulator
   (record this in the decision log). The App Group ID lives in ONE constant
   (`AppGroup.identifier`) so a marker can change it easily.

**Step 2:**
3. `feature/domain-models` — Section 2 + tests 5, 13.
4. `feature/repositories` — full model, repositories, ActivityQuery, mocks,
   fixture, test 14.
5. `feature/conditions` — Open-Meteo, straight-line travel, geocoding.
   Check: real forecast for two Sydney coordinates in a debug print.

**Step 3:**
6. `feature/plan-and-check` — 3.1, 3.2, tests 1–4; Today, Plan Editor, Plan Detail.
7. `feature/options` — 3.3, 3.4, tests 6–10; Options screen and toast.

**Step 4:**
8. `feature/widget` — small + medium, empty states, reloads.
9. `feature/notifications` — leave reminders, affected alerts, content extension,
   actions, foreground banners, cleanup. Check: plan an in-person activity
   ~30 minutes ahead in another suburb; reminder arrives; expanded view shows;
   "See options" opens the Options screen.
10. `feature/places-and-settings` — 3.5, 3.6, tests 11–12; My Places, Place Editor,
    Settings. → All assignment requirements met.

**Step 5:**
11. `docs/submission` — README complete, /Design files, final run-through on a
    real iPhone, PDF updated to match the build, zip and submit.

### 9.3 If behind schedule, cut in this order
1. Place-change options (keep time shift + knock-on)
2. Crowds row (show only Conditions, Travel, Opening hours)
3. Settings editors beyond temperature and air quality
4. Tests beyond the 14 required
Never cut: App Group store, widget (2 families + reload), notification content
extension, the primary use case, Repository protocols with mocks.

### 9.4 Decision Log
Record every change to this spec during development (commit as `docs:`).
| Date | Decision | Reason |
|---|---|---|
| 3 Oct 2026 | Scope reduced to 6 use cases for a 4-day build | Due Wed 7 Oct |
| 3 Oct 2026 | "Use this plan" from a notification opens the app instead of applying in the extension | Lower risk; extension stays display-only |
| 4 Oct 2026 | Added `ActivityRepository.check(for:)` to read a plan's saved PlanCheck | Plan Detail and Today (3.2, "Checked <time>") show saved checks, but 4.3 had no way to read them |
| 4 Oct 2026 | Added `ActivityRepository.notifiedReasonKeys(planID:)` | 3.2 alerts once per plan and reason, which needs the reasons already notified; 4.3 could only write them |
| 4 Oct 2026 | `ActivityEntity.checkStatusRaw` is optional (nil until the plan is first checked) | A new plan has no check yet; storing "looksGood" before checking would be wrong |
| 4 Oct 2026 | Added `ActivityEntity.travelModeRaw` (String?) | A saved PlanCheck's TravelEstimate needs its mode; reading it from current preferences would be wrong after Lin changes travel mode |
| 4 Oct 2026 | `plansNeedingAttention` excludes cancelled plans | A cancelled plan can keep an old "needsAttention" check status and would still appear in the widget |
| 4 Oct 2026 | Open-Meteo: request `timeformat=unixtime`, accept a list or an object, match results to requested coordinates by order (5.1) | Checked against live responses: they return grid-point coordinates, and unix times avoid parsing local times on daylight-saving days. Parameter names in 5.1 are current |
| 4 Oct 2026 | A plan with no hourly conditions gets a `.conditions` tip "Weather and air quality for this time aren't available." (3.2) | Hours with missing values are skipped when decoding; a plan without conditions must not look good without saying so |
| 4 Oct 2026 | With public transport, trips of 15 minutes or less on foot are walked (5.2) | The prototype shows "Marrickville Metro · 8 min walk" for Lin, who travels by public transport; nobody waits 10 minutes for a bus to go a few hundred metres |
| 4 Oct 2026 | Step 6 uses a placeholder `NotificationScheduling` in the app that schedules nothing; Step 9 replaces it with the UNUserNotificationCenter scheduler | Use cases 3.1 and 3.2 need the protocol now; notifications and the content extension are built in Step 9 (feature/notifications) |
| 4 Oct 2026 | Added the `PlanChecking` protocol (3.1) | PlanActivityUseCase runs the check after saving, but use cases may only depend on protocols (1.3) |
| 4 Oct 2026 | Added `PlanActivityError.notEnoughTimeForNextPlan` (3.1) | The gap rule also applies to the plan after; "You need … minutes to get here after …" only describes the plan before |
| 4 Oct 2026 | Time outside on the way: walking counts the whole trip, public transport a fixed 4 minutes, driving 0; the trip compares all of Lin's limits, for indoor places only (3.2) | The prototype shows "12 min by bus" with "UV 9 · 4 min outside"; outdoor plans are already checked over the plan itself |
| 4 Oct 2026 | Temporary "Add sample places" button on Today saves Lin's four places through PlaceRepository; Step 10 removes it | Plans need saved places before My Places and the Place Editor exist (Step 10) |
| 4 Oct 2026 | ViewModels may read data from service protocols as well as repository protocols (1.3) | The Plan Detail chart needs the forecast for the plan's place; reading it through ConditionsService (cached) is read-only and needs no business rule |
| 4 Oct 2026 | Today gets a "Coming up" section with plans for the next 7 days, shown as "Checked on the day" (7.3, 7.4) | Lin couldn't see plans saved for another day, so it looked as if nothing was saved; future plans aren't checked until their day |
| 5 Oct 2026 | Defined the 3.3 scoring: conditions margin 0–40, smallest change 0–30, no knock-on 20, crowds 0–10 | 3.3 named the parts but not how to score them; crowds are added so quieter times can be offered, as in the prototype's grocery options |
| 5 Oct 2026 | A plan that looks good gets up to three valid options even if none beats it (3.3) | With "only higher-scoring options", a plan that looks good would usually get none; "Find other options" must always show the primary use case for a flexible plan |
| 6 Oct 2026 | After the last plan of the day, the widget timeline reloads at the start of tomorrow instead of `.atEnd` (6.2) | With no plan left, the timeline has a single entry, and `.atEnd` would make WidgetKit ask again straight away, over and over; the app still reloads the widget whenever a plan changes |
| 6 Oct 2026 | The widget's empty and all-done states also show the next plan within 7 days (6.2) | As on Today's "Coming up", Lin can see her next plan from the Home Screen even when today has nothing left |

---

## 10. README Requirements
1. Project overview and the problem (one paragraph, links to the PDF).
2. Domain context: stakeholder (Lin), key vocabulary (Activity, Plan, Check, Option).
3. Architecture summary: layers, DayShiftKit, dependency rules, diagram image.
4. Extensions and why: widget scenario, notification scenario.
5. Database choice: Core Data, why not CloudKit, entities and relationships,
   the domain predicates.
6. **App Group identifier:** `group.com.utsstudent.zhaoziying.dayshift`
7. Setup: Xcode version, iOS 17+, run on the Simulator, run tests (`DayShiftKitTests`).
   If the marker builds with their own team: select their team on all three targets,
   change the App Group ID on all three targets AND in `AppGroup.identifier`
   to the same new value.
8. How to see every feature (for the marker):
   - Add My Places (e.g. Home with an address, a library), then plan activities.
   - Add the DayShift widget (small and medium) to the Home Screen.
   - Allow alerts. Plan an in-person activity starting in ~30 minutes in another
     suburb: a leave reminder arrives; press and hold to see the custom view.
   - Open any flexible plan and tap "Find other options", then "Use this plan":
     the widget updates.
   - On a mild day, lower limits in Settings (e.g. Max UV 3) to see plans that
     need attention.
9. Attributions: Open-Meteo (weather and air quality data, credit per its terms),
   NSW air quality category source, Apple documentation used.
10. AI assistance: Claude (research, planning, spec, finding bugs) and Claude Code
    (implementation step by step from this spec); every step reviewed and tested
    by the author. Also declared in the PDF.
11. Known limitations: estimated travel times, outdoor temperature as an indicator
    for uncooled rooms, crowd levels are estimates, checks run when the app is
    opened (no background refresh).
