# Bringing Muster's event operations into MOA

Muster (github.com/muhammedr7025/ticketing_muster) runs an agency's event floor:
guest lists, tickets, ID cards, the door, self check-in, broadcasts, closeout
and retention. This document is the running plan for porting it onto our stack
(FastAPI backend, Next clubs dashboard, Flutter app), feature by feature, each
as its own pull request pair (backend + web).

## Done

| Slice | What | Backend | Web |
| --- | --- | --- | --- |
| 1 | Layout contract and renderer (tickets, certificates) | #13 | #3 |
| 2 | Layer designer with uploads | #13 | #3 |
| 3 | Ticket lifecycle and the delivery log | #13 | #3 |
| 4 | Certificates: issue, send, verify, revoke | #13 | #3 |
| 5 | Attendees page: import, add, edit, remove, delivery bar | #13 | #3 |
| 6 | Mail module: journey emails, editor, broadcasts, library, timers | #13 | #3 |
| 6b | The invite is the ticket email at registration and payment; messages in the delivery log | #15 | #4 |
| 7 | Doors, recorded check-ins, the team's switches, gate links, the gate console, walk-ups, offline queue, check-in log | #16 | #5 |
| 8 | ID cards: badge designs per role with eight starters, card and batch PDFs, print jobs, reprint policy, pre-printed stock, print at check-in from the gate | #17 | #6 |
| 9 | Self check-in and kiosk: paired kiosk devices with shift tokens and a staff PIN, the `/kiosk` screen (front camera, typed code, auto-print, "this isn't me"), check-in from the guest's own phone via the kiosk's rotating QR at `/s/[token]` (name, or a code by email), print from the phone at the kiosk | #18 | #7 |
| 10 | Agenda: the run of show (blocks with time, speaker, room; parallel tracks; a heading per day), public on the event page (moa_events#1) and in the app (moa_mobileapp#30), the agenda layer in both layout engines with four starters and a parity test, the programme design kind, the A4 programme PDF, the kiosk playing what is still to come while a card prints | #19 | #8 |
| 11 | Merchandise: items with stock or sized variants, eligibility by role or guest field, what each guest is owed resolved from their own record, the handover at the gate (atomic stock decrement, size picked at the counter written to the record), the merch log with facets and analytics, the "Hands out merch" duty | #20 | #9 |

## In progress

| Slice | What | Notes |
| --- | --- | --- |
| 12 | **Closeout and retention** | The closeout report PDF (attendance, roles, ways in, merch, messages, certificates, ratings) kept and emailed to recipients; the status clock (draft → published → live → closed → archived; closed locks settings and the door); the retention job that scrubs the guest list after the report (phones, answers, delivery logs, walk-ups), archiving contacts for the club first. Registrations themselves stay: they belong to the guests' own accounts. |

## Next, in order

| Slice | What | Notes |
| --- | --- | --- |
| 13 | Delivery outcomes and channels | SES bounce / complaint / delivery webhook into the delivery log; bounced addresses skipped; WhatsApp provider abstraction with a "not configured" provider and the channel shown as such. |
| 14 | Club branding, contacts, event duplicate | Brand colours on the club profile feeding designs and emails; a club contact book across events; duplicate an event's setup. |
| 15 | Admission numbers | Per-event admission number format (prefix, digits, event code) alongside the scan code. |

Left out on purpose: face matching at the gate, inbound email (needs an SES receiving domain), and ticket types as a separate concept (our roles and registration fields cover it).
