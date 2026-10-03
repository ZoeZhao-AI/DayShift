# DayShift Prototype — Interaction Spec (machine-readable)

<!--
Purpose: complete description of the DayShift clickable prototype
(Design/DayShift_Prototype.html, 34 artboards) for review and for building the app.
Conventions:
- SCREEN_ID = artboard file name without ".dc.html".
- "→ X" = tapping navigates to screen X.
- "[state]" = local interaction on the same screen only.
- "[none]" = looks tappable but has no effect in the prototype.
- "[external]" = opens a URL outside the prototype.
- State never carries between screens; each screen is a fixed snapshot.
- The prototype shows the full product vision. The build scope is defined in
  DEVELOPMENT_SPEC.md Section 7; screens outside that scope are reference only.
-->

## 1. Global context

```yaml
app: DayShift
platform: iOS 17, iPhone 15 frame (393 x 852 pt), mid-fidelity
user_persona: Lin, 31, freelance UI/UX designer, inner-west Sydney, home has no air conditioning
sample_day: Thursday
current_time: "6:40 am"          # all daily-flow screens show "Checked 6:40 am"
plans:
  - {id: run,     time: "7:00–7:45 am",  title: Run,         place: Enmore Park,        mode: in person, status: needs_attention, reason: "Smoke until 10 am. Air quality Poor, above your limit (Fair).", leave_by: "6:55 am"}
  - {id: call,    time: "11:00–11:30 am",title: Client call, place: Online,             mode: online,    status: looks_good}
  - {id: focus,   time: "1:00–5:00 pm",  title: Focus work,  place: Home,               mode: in person, status: needs_attention, reason: "It reaches 33°C outside this afternoon. You've said your room gets too hot above 30°C."}
  - {id: grocery, time: "5:30–6:00 pm",  title: Grocery run, place: Marrickville Metro, mode: in person, status: looks_good, crowd: "Usually busy (estimate)", leave_by: "5:20 pm", travel: "8 min walk"}
workplace_recommendation: "Work today at Newtown Library · Air-conditioned · Usually quiet until 3 pm · Open until 6 pm · 12 min by bus · Home gets too hot after 1 pm"
user_limits: {feels_like_max: "32°C", air_quality_worst: Fair, uv_max: 8, wind_gust_max: "40 km/h", rain_chance_max: "40%", home_too_hot_above: "30°C"}
day_settings: {planning_hours: "6:00 am–9:00 pm", buffer: "15 min", travel: Public transport, leave_reminder: "10 min before"}
my_activities_ordered: [Run, Focus work, Client meeting, Walk, Coffee with a friend, Outdoor sketching, Indoor swim, Gallery visit, Grocery run]
my_places: [Home (Inner West, indoor, no AC), Newtown Library (Newtown, indoor, AC), Enmore Park (Enmore, outdoor), Marrickville Metro (Marrickville, indoor), Bondi Beach (Bondi, outdoor)]
place_kinds: [Home, Library, Café, Coworking space, Office, Park, Beach, Gym, Pool, Sports court, Gallery or museum, Shopping centre, Other]
```

### Design rules
- Status is always icon + words: `✓ Looks good` (grey) or `⚠ Needs attention` (amber). Amber is used only for Needs attention.
- Teal is the only accent: primary buttons, selected states, toggles on.
- Never show "No data", "Unknown" or blank areas.
- Vocabulary: **Activity** = a type (Run). **Plan** = one scheduled activity on a day. Entry action is "Plan an activity".
- Options always keep the plan's original duration.
- Short time outside on the way that exceeds a limit is shown as a **Tip**, never as a problem or a reason to rule out an option.
- Crowd levels are always labelled as estimates.

### Tab bar (shared)
Present on: Today, TodayUpdated, TodayFocusMoved, TodayEmpty, TodayBanners, MyPlaces, MyActivities, Settings.
`Today → Today` · `My Places → MyPlaces` · `My Activities → MyActivities` · `Settings → Settings`

---

## 2. Screen inventory

| SCREEN_ID | Group | Title on canvas |
|---|---|---|
| Main | Onboarding | 1 · Welcome (entry point) |
| ChooseActivities | Onboarding | 2 · Choose your activities |
| AlertsPermission | Onboarding | 3 · Alerts explainer |
| Today | Daily flow | 4 · Today (hub) |
| TodayEmpty | Daily flow | 4b · Today: empty state |
| TodayBanners | Daily flow | 4c · Today with banners |
| PlanDetailFocus | Daily flow | 5 · Plan Detail: Focus work |
| PlanDetailRun | Daily flow | 5a · Plan Detail: Run |
| PlanDetailGrocery | Daily flow | 5b · Plan Detail: Grocery run (looks good) |
| PlanDetailCall | Daily flow | 5c · Plan Detail: Client call (online) |
| OptionsRun | Daily flow | 6 · Options for your run |
| TodayUpdated | Daily flow | 6b · Today after accepting (toast) |
| OptionsFocus | Daily flow | 6c · Options for focus work |
| TodayFocusMoved | Daily flow | 6d · Today, Focus work moved (toast) |
| OptionsGrocery | Daily flow | 6e · Options for a plan that looks good |
| OptionsNone | Daily flow | 6f · Options: no result |
| PlanEditor | Daily flow | 7 · Plan Editor (sheet) |
| PlanEditorError | Daily flow | 7b · Plan Editor: overlap error |
| History | Daily flow | 11 · History |
| HistoryEmpty | Daily flow | 11b · History: empty state |
| MyPlaces | Management | 8 · My Places (tab 2) |
| AddPlace | Management | 8c · Add a place: search |
| PlaceEditorNew | Management | 8d · New place, pre-filled |
| PlaceEditor | Management | 8b · Place Editor: Home |
| MyActivities | Management | 9 · My Activities (tab 3) |
| CreateActivity | Management | 9b · Create your own activity |
| Settings | Management | 10 · Settings (tab 4) |
| HomeWidgets | Widgets | W1 · Home Screen widgets |
| LockWidget | Widgets | W2 · Lock Screen widget (after Focus work moved) |
| LockNotifsAM | Notifications | N1a · Lock Screen 6:40 am (notification B) |
| AffectedExpanded | Notifications | N3 · Plan affected, expanded |
| AffectedDone | Notifications | N4 · Plan affected, done |
| LockNotifsPM | Notifications | N1b · Lock Screen 12:25 pm (notification A) |
| LeaveExpanded | Notifications | N2 · Leave reminder, expanded |

---

## 3. Screens

### Main (Welcome)
- Title "Plan your day around Sydney's weather"; paragraph "DayShift checks your plans against heat, smoke, UV, wind and rain, and helps you find a better time or place."; example card "7:00 am Run · Smoke until 10 am · ⚠ Needs attention" → "DayShift suggests" → "5:30 pm Run · Air quality Good, UV low · ✓ Looks good".
- "Get started" → ChooseActivities

### ChooseActivities
- Title "What do you usually do?"; caption "Pick the activities you plan most. DayShift only suggests from these, and you can change them later."
- Chips by purpose: Exercise (Run, Walk, Cycling, Ocean swim, Indoor swim, Gym session, Yoga class), Work (Focus work, Client meeting, Networking event), Socialising (Coffee with a friend, Picnic, Dinner out), Relaxation & creative (Outdoor sketching, Photography walk, Gallery visit, Cinema), Errands (Grocery run, Market visit).
- Initial selection = my_activities_ordered; counter "9 activities selected".
- "Back" → Main · chips [state] · "Continue" → AlertsPermission

### AlertsPermission
- "Stay a step ahead"; "Allow alerts so DayShift can remind you when to leave and tell you when a plan is affected."; rows "Leave reminders — 10 minutes before you need to go, with conditions on the way." and "When a plan is affected — Smoke, heat, UV, wind or rain, with a better option ready."
- "Back" → ChooseActivities · "Allow alerts" → Today · "Not now" → Today

### Today (hub)
- Large title "Today", subtitle "Thursday"; workplace card with "Move Focus work here"; section "Your plans" (4 plans: time, icon, title, place, leave-by, status, short reason); footer "Checked 6:40 am".
- "History" → History · "+" → PlanEditor · "Move Focus work here" → OptionsFocus
- Run row → PlanDetailRun · Client call row → PlanDetailCall · Focus work row → PlanDetailFocus · Grocery run row → PlanDetailGrocery

### TodayEmpty
- "Your day is clear." / "Plan something and DayShift will keep an eye on it." + "Plan an activity"; Ideas for today: "Good time for a run: 5:00 to 7:00 pm · Cool, air quality Good, low UV" + "Plan a run"; "UV is very high from 11 am to 3 pm · Above your limit of 8. Plan outdoor time outside these hours."; footer "Checked 6:40 am".
- "History" → HistoryEmpty · "+", "Plan an activity", "Plan a run" → PlanEditor

### TodayBanners
- Same as Today plus banners: "Alerts are off. Turn them on in Settings to get leave reminders." with "Open Settings" → Settings; "Weather and air quality aren't available right now. Your plans are still saved."
- Footer: "Statuses from the last check at 6:10 am. DayShift will check again automatically."

### PlanDetailRun
- "Run", "7:00 to 7:45 am · Enmore Park"; ⚠ Needs attention.
- Conditions ⚠ "Smoke until 10 am. Air quality Poor, above your limit (Fair)." + air-quality chart 6 am–12 pm, dashed limit at Fair, "Now · Poor" marker, caption "Air quality at Enmore Park · shaded where it's worse than your limit".
- Travel ✓ "5 min walk · Leave by 6:55 am" · Opening hours ✓ "Open 24 hours." · Crowds ✓ "Usually quiet · estimate".
- Back → Today · "See better options" → OptionsRun · "Edit plan" → PlanEditor · "Delete plan" → Today

### PlanDetailFocus
- "Focus work", "1:00 to 5:00 pm · Home"; ⚠ Needs attention.
- Conditions ⚠ 33°C message + outside temperature chart 12–6 pm, dashed limit 30°C, area above limit shaded.
- Travel ✓ "You're already here." · Opening hours ✓ "Always available." · Crowds ✓ "Usually quiet · estimate".
- Back → Today · "See better options" → OptionsFocus · "Edit plan" → PlanEditor · "Delete plan" → Today

### PlanDetailGrocery
- "Grocery run", "5:30 to 6:00 pm · Marrickville Metro"; ✓ Looks good.
- Conditions "Indoors. On the walk: 31°C feels like, air quality Good, UV low." · Travel "8 min walk · Leave by 5:20 pm" · Opening hours "Open until 9 pm." · Crowds "Usually busy · estimate".
- Back → Today · "Find other options" → OptionsGrocery · "Edit plan" → PlanEditor · "Delete plan" → Today

### PlanDetailCall
- "Client call", "11:00 to 11:30 am · Online"; ✓ Looks good.
- Conditions "Online, so the weather doesn't affect this plan." · Travel "No travel needed." · Opening hours "Always available." · Crowds "Online, so crowds don't apply."
- No options button (the plan is fixed).
- Back → Today · "Edit plan" → PlanEditor · "Delete plan" → Today

### OptionsRun
- Current plan "7:00 am · Enmore Park · ⚠ Smoke, air quality Poor"; "2 better options":
  1. [Recommended] "Move to 5:30 pm · Enmore Park" — "Air quality returns to Good and UV is low." — "Grocery run moves from 5:30 to 6:30 pm. Your 11 am call is not affected."
  2. "Switch to Indoor swim · Ian Thorpe Aquatic Centre, Ultimo · 7:30 am" — "Indoors, so smoke doesn't matter. 25 min by bus." — "Opening hours not confirmed." + "Check hours in Maps" [external] — "Back home by 9:15 am. Your 11 am call is not affected."
- Back → PlanDetailRun · Option 1 "Use this plan" → TodayUpdated · Option 2 "Use this plan" [none] · "Keep my plan" → PlanDetailRun

### TodayUpdated
- Plans: Client call ✓ · Focus work ⚠ · Run 5:30–6:15 pm, "Moved", Leave by 5:25 pm, ✓ · Grocery run 6:30–7:00 pm, "Moved", Leave by 6:20 pm, ✓.
- Toast "Your run is now at 5:30 pm." + "Undo" → Today
- History → History · "+" → PlanEditor · "Move Focus work here" → OptionsFocus · Client call row → PlanDetailCall · Focus work row → PlanDetailFocus

### OptionsFocus
- Current plan "1:00 to 5:00 pm · Home · ⚠ 33°C outside, above your 30°C limit"; "1 better option":
  [Recommended] "Move to Newtown Library · 1:00 to 5:00 pm" — "Air-conditioned and usually quiet until 3 pm. Open until 6 pm, 12 min by bus." — "Leave by 12:35 pm. Your 5:30 pm grocery run still fits."
- Note: "No other 4-hour slot fits around your run, your 11 am call and your grocery run today."
- Back → PlanDetailFocus · "Use this plan" → TodayFocusMoved · "Keep my plan" → PlanDetailFocus

### TodayFocusMoved
- Workplace card "You're working at Newtown Library today · … · Leave by 12:35 pm".
- Plans: Run ⚠ · Client call ✓ · Focus work at Newtown Library, "Moved", Leave by 12:35 pm, ✓ · Grocery run "Leave the library by 5:10 pm · 15 min by bus", ✓.
- Toast "Focus work is now at Newtown Library." + "Undo" → Today

### OptionsGrocery
- Current plan card "✓ Looks good · 5:30 pm · Marrickville Metro · Usually busy · estimate. You don't need to change anything." + "Keep my plan" → PlanDetailGrocery.
- "Other good options": "Move to 7:15 pm · Usually quiet after 7 pm (estimate). Cooler walk, open until 9 pm. Nothing else moves." · "Move to 8:00 pm · Usually quiet (estimate). Finishes by 8:40 pm, within your planning hours. Nothing else moves."
- Footnote: "Earlier times overlap Focus work (1:00 to 5:00 pm)."
- Both "Use this plan" [none]

### OptionsNone (standalone example)
- "Options for outdoor sketching"; current plan "6:15 pm · Enmore Park · ⚠ Wind gusts 55 km/h, above your 40 km/h limit".
- **"No time or place today keeps this activity within your limits."** / "Try another day, or adjust your limits in Settings."
- "What DayShift checked": other times today, other places, other activities.
- "Try another day" → PlanEditor · "Adjust limits in Settings" → Settings · "Keep my plan" / back → Today

### PlanEditor (sheet)
- "Plan an activity". Activity chips (My Activities) + "Browse all activities"; Place list (filtered by activity) + "Search for a place"; note "Only outdoor places are shown for Walk. Online isn't offered for this activity."; When (Date, Start time, Duration); Best times today (3 cards, selectable); Flexibility ("Can move between [5:00 pm] and [8:00 pm]", "Can change place", "Can switch to another activity") + "DayShift only suggests changes you allow here."
- "Cancel" / "Save plan" → Today · "Browse all activities" → ChooseActivities · "Search for a place" → AddPlace · best-time cards [state] · toggles [state]

### PlanEditorError (standalone state)
- Client meeting, Online, 10:45 am, 45 min; inline error **"This plan overlaps with Client call at 11:00 am."** / "Choose another time, or shorten one of the plans."; "Save plan" disabled.

### History / HistoryEmpty
- History: "Changes you made with DayShift's options." Today: "Run moved from 7:00 am to 5:30 pm · Smoke · Today". Earlier this week: "Focus work moved from Home to Newtown Library · Heat · Tuesday". Back → Today.
- HistoryEmpty: "No changes yet." / "When you use an option, it appears here." Back → TodayEmpty.

### MyPlaces
- Caption "Where you usually go. DayShift uses these details to check your plans."; five places; "Add a place" → AddPlace; Home row → PlaceEditor.

### AddPlace
- Search "Marrickville"; "Results from Apple Maps": Marrickville Library (Library) → PlaceEditorNew; Marrickville Park; Annette Kellerman Aquatic Centre (Swimming pool); Marrickville Metro ("Saved"). "Cancel" → MyPlaces.

### PlaceEditorNew
- Name "Marrickville Library", Kind "Library", Area "Marrickville"; note "Name, area and kind filled in from Apple Maps. Check the details, then save."
- Indoor on, Air-conditioned on, note "Air-conditioned places stay comfortable, so DayShift won't warn you about heat here."
- Opening hours "Typical for libraries: 10 am to 8 pm" / "Check and edit if different."; Usual busy times "Quiet mornings · estimate".
- Back → AddPlace · "Save" / "Save place" → MyPlaces
- Rule: the "It gets too hot here when it's above [30]°C outside" row appears only when Air-conditioned is off.

### PlaceEditor (Home)
- Name "Home", Kind "Home", Area "Inner West"; Indoor on, Air-conditioned off; "It gets too hot here when it's above [30]°C outside" with − / + (20–45); "Used to warn you before working here on hot days."; Opening hours "Always available"; Usual busy times "Quiet all day".
- Back / "Done" → MyPlaces

### MyActivities
- "Your favourites first. DayShift only suggests activities from this list."; numbered list with drag handles; "Add from catalogue" → ChooseActivities; "Create your own" → CreateActivity.

### CreateActivity
- Name "Tennis"; Purpose (Exercise selected); What affects it: Heat, Smoke, UV, Wind, Rain; Suitable kinds of places (13 place_kinds); "Can be done online" toggle.
- "Cancel" / "Save activity" → MyActivities

### Settings
- Your limits (32°C, Fair, 8, 40 km/h, 40%) + "DayShift flags a plan when the forecast goes past any of these."; Your day (6:00 am to 9:00 pm, 15 min, Public transport, 10 min before); Alerts "✓ Allowed", "Open iOS Settings", "Leave reminders and plan alerts are on."; History → History.

### HomeWidgets
- Small: "Next · 11:00 am" / "Client call" / "Online" / "✓ Looks good".
- Medium, two tap areas:
  - Top "Work today at Newtown Library · Air-conditioned · Usually quiet · Open until 6 pm · Home gets too hot after 1 pm" → OptionsFocus
  - Bottom "Next · 11:00 am · Client call · Online · ✓ Looks good" → PlanDetailCall

### LockWidget (static)
- After Focus work moved; 12:20. "Leave 12:35" / "Newtown Library" / "UV 9".

### LockNotifsAM (6:40 am)
- Notification B "Your 7:00 am run is affected" / "Smoke until 10 am. Press and hold to see a better option." → AffectedExpanded

### AffectedExpanded
- "Your 7:00 am run is affected" ⚠ "Smoke until 10 am."; air-quality chart with limit; Recommended "Move to 5:30 pm · Enmore Park" + schedule note.
- "Use this plan" → AffectedDone · "Keep my plan" → LockNotifsAM

### AffectedDone
- ✓ "Done. Your run is now at 5:30 pm." / "Enmore Park · Air quality Good, UV low." / "Grocery run moved to 6:30 pm. Your 11 am call is not affected."
- "Undo" → AffectedExpanded · "Open DayShift" → TodayUpdated

### LockNotifsPM (12:25 pm)
- Notification A "Leave in 10 min for Focus work" / "Newtown Library · 12 min by bus. Press and hold for details." → LeaveExpanded

### LeaveExpanded
- "Leave in 10 min for Focus work"; "Newtown Library · 12 min by bus · arrive 12:47 pm".
- On the way: 31°C feels like (your limit 32°C) · "UV 9 · 4 min outside, wear sunscreen" marked **Tip** · 10% chance of rain (your limit 40%) · Air quality Good (your limit Fair).
- At Newtown Library: "Indoors, air-conditioned" · "Open until 6 pm" · "Usually quiet · estimate".
- "✓ Your plan looks good." · "Got it" → LockNotifsPM

---

## 4. Key user journeys

```yaml
J1_onboarding: [Main, ChooseActivities, AlertsPermission, Today]
J2_fix_run_in_app: [Today, PlanDetailRun, OptionsRun, "Use this plan", TodayUpdated]
J3_fix_focus_work: [Today, PlanDetailFocus, OptionsFocus, "Use this plan", TodayFocusMoved]
J4_review_good_plan: [Today, PlanDetailGrocery, OptionsGrocery, "Keep my plan", PlanDetailGrocery]
J5_new_plan: [Today, "+", PlanEditor, "pick a best time", "Save plan", Today]
J6_fix_run_from_notification: [LockNotifsAM, AffectedExpanded, "Use this plan", AffectedDone, "Open DayShift", TodayUpdated]
J7_leave_reminder: [LockNotifsPM, LeaveExpanded, "Got it", LockNotifsPM]
J8_add_place: [MyPlaces, AddPlace, PlaceEditorNew, "Save place", MyPlaces]
J9_create_activity: [MyActivities, CreateActivity, "Save activity", MyActivities]
J10_widget_entry: [HomeWidgets, "tap top half", OptionsFocus]
J11_widget_next_plan: [HomeWidgets, "tap bottom half", PlanDetailCall]
```

---

## 5. Known limitations of the prototype

- Orphan screens (open directly on the canvas): TodayEmpty, TodayBanners, PlanEditorError, OptionsNone, HomeWidgets, LockWidget, LockNotifsAM, LockNotifsPM.
- No shared state between screens; the Today tab always opens the original Today.
- Dead buttons: OptionsRun Option 2 "Use this plan"; both OptionsGrocery "Use this plan"; Settings rows and "Open iOS Settings"; PlanEditor activity chips and place rows; MyPlaces rows other than Home; AddPlace results other than Marrickville Library; drag handles.
- Timing differs by surface: daily flow 6:40 am; HomeWidgets between the run and 11 am; LockWidget and notification A around 12:20–12:25 pm after Focus work was moved; notification B 6:40 am.
