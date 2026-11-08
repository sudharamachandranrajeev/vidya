# Vidya — feature plan from competitor review mining

Source: `replica/fixes.md` (kept local, not in git): 1,745 real, linked reviews
of eight popular flashcard, language-learning, online-course and note-taking
apps, from app stores, review sites and developer forums. Every item below
traces to a numbered theme there with its review/source count — check that
file before changing scope.

Phases are priority order, not calendar weeks. Vidya already ships SM-2
scheduling, achievements, skills tracking, portfolio+Markdown export,
progress charts, notes, focus mode, starter curricula, local-first storage —
none of that is re-listed.

## P1 — cheap, high-signal fixes

### T1. Lenient typed-answer grading
- Size: S
- Evidence: content-quality theme, 26 reviews, 11 sources (exact-match
  grading complaints about an online-course app; "garbage in, garbage out"
  on question wording in a flashcard app)
- Any typed-answer review mode should default to case/whitespace/synonym-
  tolerant matching, not exact string match.

### T2. Dismissible, non-punitive streaks
- Size: S
- Evidence: gamification theme, 88 reviews, 14 sources — the single biggest
  "stop gamifying me" signal in the sample ("Stop the gamification",
  "Streak Freeze Inflation")
- Settings toggle to fully disable streak-style pressure; achievements
  system stays, streak mechanic becomes opt-in.

### T3. Local, user-capped review reminders
- Size: S
- Evidence: notification/spam theme, 21 reviews, 8 sources
- On-device scheduled notifications tied to due cards, frequency cap set
  once by the user — no server-driven push campaign.

## P2 — medium builds, broad evidence

### T4. Media flashcards (image, audio, cloze deletion)
- Size: M
- Evidence: table stakes for flashcard apps; `Flashcard`/`review.dart` was
  text-only
- Build this before T7 (deck import) — importing real decks from other apps
  needs media fields to round-trip without losing cards.

### T5. Deck/content export, one-way share file
- Size: M
- Evidence: teams/sharing theme, 69 reviews, 13 sources ("no way to send
  decks to individuals without going on desktop" — a mobile flashcard app)
- Plain exported file, not live collaboration — stays consistent with
  Vidya's local-first, no-network-by-default model.

### T6. Transparent, simplified SRS presets
- Size: M
- Evidence: SRS/algorithm theme, 165 reviews, 11 sources — two opposite
  complaints (too complex in one flashcard app; arbitrary or punitive in
  others) that triangulate the same unmet need
- Plain-language "why this card is due now" view, with 2–3 named presets
  (light/standard/intensive) layered on the existing scheduler — no raw
  ease/interval knobs exposed by default.

## P3 — larger builds

### T7. Deck import (deck packages, CSV, tab-separated exports)
- Size: L
- Evidence: integrations/import theme, 48 reviews, 7 sources — direct quote
  "I wanted to upload my pre-existing flashcard lists but there's no way to
  do this, in any format" (a mobile flashcard app)
- Depends on T4 shipping first (media fields) to avoid lossy imports.
  Removes the #1 switching blocker for anyone moving from another
  flashcard app.

### T8. iOS/macOS build targets
- Size: L
- Evidence: platforms theme, 99 reviews, 11 sources — the largest single
  "what's missing" theme in the whole sample
- Repo currently ships `android/`, `windows/`, `linux/` only. Mostly
  packaging/signing work in Flutter; sized L for App Store review and
  Apple dev account lead time, not code complexity.

## Status (2026-11-08)
T1–T7 shipped. T8 deferred: needs a Mac and an Apple developer account.

## Not building
- Price/paywall, billing/refund, ads, login/account friction — real, large
  themes but platform-operations problems of the competitors, not a Vidya
  feature gap; Vidya's local-first/no-ads model already avoids most of this
  structurally.
- Parent/mentor visibility into someone else's progress — thin (1 review)
  and a different user than Vidya currently targets.

## Positioning (for later, not store copy yet)
"For learners who juggle one app for flashcards, another for notes and a
spreadsheet for progress, and hate that none of them talk to each other,
Vidya keeps programs, courses, flashcards, skills and portfolio in one
local-first app with no forced streaks, no paywalled core features, and no
sync bugs that eat a study session."
