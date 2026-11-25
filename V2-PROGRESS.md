# FareLookup V2

Branch: v2. Never merge or deploy production without user approval.

## Product intent
Today = is the work paying enough, what did I keep, what needs action? Quote = price a job before committing. Jobs = quote to completion/payment. Money = rental-period viability.

## Checkpoints
- [x] Isolate v2 from main; preserve the existing backend, community fares and calculator.
- [ ] Add Today dashboard using saved trip records and existing calculation functions. Show hourly vs target, take-home vs gross, period hours vs required hours, Trips/Expenses tabs; indicate estimates.
- [ ] Preview build and verify mobile layout and navigation.
- [ ] Improve quote and jobs workflows; distinguish earned, paid, and planned.
- [ ] Reconcile actual fuel purchases retroactively and protect historical rates; review data schema before changes.
- [ ] Money: rental-period recovery without double counting.

## Assumptions / boundaries
Existing saved trip dates are date-only, not timestamps. New defaults should use America/New_York; historical records must not be silently reassigned. Existing targetHours is monthly, so the first dashboard uses month hours / target rather than assuming a daily goal. Existing trip expenses are calculated, not necessarily actual purchases. Keep existing auth and storage unchanged during UI phase. Do not expose private records in a public preview; authenticated access remains governed by existing policies. No database migrations in phase one.
