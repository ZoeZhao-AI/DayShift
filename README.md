# DayShift

DayShift helps knowledge-work freelancers in Sydney keep their daily plans on track when heat, smoke, UV, wind or rain change during the day.

UTS iOS Software Development, Assessment Task 3.

## App Group

`group.com.utsstudent.zhaoziying.dayshift`

## Status

In development. Full setup instructions, architecture and feature guide will be added before submission.

## Notes

### Seeing a plan-affected notification on the Simulator

`Design/SimulatorPayloads/plan-affected-run.apns` is a sample "Your 7:00 am run is
affected" alert, with the air-quality chart and the recommended option, as in the
prototype's AffectedExpanded screen. It is kept outside the app bundle.

1. Run DayShift on the Simulator once and allow alerts.
2. Go to the Home Screen (or lock the Simulator), so the alert isn't shown inside the app.
3. Drag `plan-affected-run.apns` onto the Simulator window, or run
   `xcrun simctl push booted com.utsstudent.zhaoziying.DayShift Design/SimulatorPayloads/plan-affected-run.apns`.
4. Press and hold the notification to see the expanded view.

The sample's plan isn't saved in the app, so "See options" and tapping the alert open
Today with "This plan no longer exists." Real alerts open the plan.
