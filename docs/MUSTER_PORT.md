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
| 12 | Closeout and retention: the status clock (draft → published → live → closed → archived; closed locks the door and the settings), the closeout report PDF, retention forward only (report kept and delivered, then the scrub: phones, answers, delivery logs, phone check-in sessions, walk-up records; contacts archived for the club). Registrations stay with the guests' accounts | #21 | #10 |
| 13 | Delivery outcomes: the SES hook (SNS, signature-verified, plus a shared token) lands bounce/complaint/delivery/delay notices on the send and marks the address; bounced addresses skipped until corrected; the WhatsApp hook (Meta, signed); the provider registry behind each channel | #22 | #11 |

## In progress

| Slice | What | Notes |
| --- | --- | --- |
| 14 | **Club branding, contacts, event duplicate** | Brand colours on the club profile that designs and emails fall back to; the club's contact book (what retention kept, searchable, exported as CSV); duplicating an event's setup onto a new date. Web: moa_web#12; backend: `feat/club-branding`. |
| 15 | **Admission numbers** | A per-event format (prefix, digits, event code) and a sequential number per ticket, never rewritten; read at the gate like the scan code; on tickets, rows and find results. Web: moa_web#13; backend: `feat/admission-numbers`. |

## Next, in order

| Slice | What | Notes |
| --- | --- | --- |

## Operations: delivery notices

Outcomes (delivered, bounced, complained, not delivered) come from the providers themselves and land on the send they belong to, matched by the id the provider returned when it took the mail (`provider_id`). A hard bounce or a complaint marks the registration (`email_bounced_at`) so later sends skip the address with the reason "that address bounced — correct it to send again"; correcting the email on the attendees page clears it.

**Amazon SES → SNS → the API.** In SES, add an event destination (or a notification) for Bounce, Complaint, Delivery and DeliveryDelay to an SNS topic, and subscribe the topic over HTTPS to

```
https://api.myotherapp.in/api/v1/hooks/ses?token=<SES_WEBHOOK_TOKEN>
```

The API confirms the subscription itself (it fetches the `SubscribeURL`, on an Amazon host only). Every call must carry Amazon's signature, verified against the certificate SNS hosts; the `token` is a second check and is set in the backend's environment as `SES_WEBHOOK_TOKEN`. A call that fails either is answered 202 with `ok: false` and logged, so Amazon does not retry it for hours.

**WhatsApp (Meta Cloud API).** Not wired to a provider yet: the delivery summary says so, and sends on that channel are recorded as skipped with the reason. When one is, set `WHATSAPP_ACCESS_TOKEN` and `WHATSAPP_PHONE_NUMBER_ID`, point Meta's webhook at `https://api.myotherapp.in/api/v1/hooks/whatsapp` with `WHATSAPP_VERIFY_TOKEN` and `WHATSAPP_APP_SECRET` set, and statuses (delivered, read, failed with Meta's codes) land the same way.

Left out on purpose: face matching at the gate, inbound email (needs an SES receiving domain), and ticket types as a separate concept (our roles and registration fields cover it).
