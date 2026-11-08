# Changelog

## 0.3.0 (2026-11-08)

- Learn: import a whole study plan. Copy the in-app prompt into any AI chat, paste the reply (or
  open a `.json` plan), check the summary and import. Courses arrive with due dates, topics with
  minutes, topic details and resources as one study-guide note per course, plus skills,
  flashcards linked to their course, and notes. Plans merge by title, so a second import or the
  next part of a long plan adds only what is new. Example: `docs/examples/` holds a plan for NYC
  Transit's Car Inspector exam 7612.
- "Make it with AI" writes the plan in the app, through the AI chosen for Ask AI. Type the goal
  and, if you like, the syllabus, level, weekly hours and deadline; a long plan arrives part
  after part. A chat website cannot answer in the app, so then it copies the filled-in prompt.
  Several parts pasted one after another import together, and the summary names missing parts.
- A short welcome on first start asks where your data lives: on this device only, or synced
  through a home or cloud server, with guided steps. Vidya says when a newer release is out.
- App lock: a PIN or the device's own unlock over the app.
- Ask AI for help on any screen, and Report a problem or suggest a feature from the app.
- Review pace in Settings: Light (longer gaps, fewer reviews), Standard or Intensive (shorter
  gaps before an exam). The buttons show the next gap for the pace you chose. During a review,
  "Why now?" explains in plain words why a card is due.
- Review: typed answers are graded leniently. Case, spacing, punctuation, a leading article and
  bracketed text do not matter, and any synonym listed on the back ("car / automobile") counts.
- Day streaks are hidden until switched on in Settings. Achievements are unchanged.
- Optional review reminders on Android for days with cards due, at a time and weekly limit you
  set. No server involved.
- Flashcards can carry an image and audio, and cloze cards hide `{{c1::…}}` spans.
- Export cards to a share file; import cards from CSV, tab-separated text or a Vidya file.
- The database moves to version 3 (card image and audio); existing data is kept.

## 0.2.1 (2026-10-25)

- Phones get new navigation: a floating dock that scrolls through every screen (the "More"
  sheet is gone) and a side panel listing them all with what each is for. Swipe right on any
  page, or tap the dock's menu button, to open it; Back closes it.

## 0.2.0 (2026-10-24)

- Review: flashcards in decks with spaced repetition, a due queue, a week-ahead forecast and
  retention. A daily quest to clear the queue, experience for cards and reviews, and six new
  achievements (Deep focus, Memory seeds, First recall, A hundred recalls, Still water, Long memory).
- Focus timer from Home or a course; logs the session when it ends.
- Portfolio: copy skills, work and finished courses as Markdown.
- Progress: retention and longest focus.
- Quest experience labels now use the app font.
- The database moves to version 2; existing data is kept.

## 0.1.1 (2026-10-24)

- Sync setup and pairing links (vidya://) now open and work in Vidya.

## 0.1.0 (2026-10-24)

First release.

- Programs, courses and topics with templates; study log; tests.
- Skills with levels and targets; portfolio with a strength score; tagged notes.
- Progress metrics and charts; experience, levels, streak, daily quests, 28 achievements.
- Zen light and dark theme. Encrypted local database, optional end-to-end encrypted sync.
