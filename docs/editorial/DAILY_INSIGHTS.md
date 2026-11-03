# Daily insights — editorial guide

**Source of truth for the wording:** `Packages/RetrogradeKit/Sources/Editorial/DailyInsightCopy.swift` (approved direction, 2026-11-03). Edit copy there; the tests in `EditorialTests/DailyInsightCopyTests.swift` enforce the rules below.

## How a day's detail is built
1. **Level + summary** — one line from the level's pool; specific pools when the day's strongest event is a Mercury turning point (Intense), Mercury retrograde (Elevated), a shadow or a Moon phase (Mild).
2. **What's shaping the day** — one row per scored event, strongest first: title, tag, one-line note. A quiet day shows "Nothing notable in the sky today. Enjoy the quiet."
3. **Good habit for this day** — from the level's pool of 8 (2 each: communication, technology, planning, reflection), interleaved so neighbouring days rotate topics.

Selection is deterministic from the date (days since 2000-01-01), so a day always reads the same and consecutive days differ.

## Tags
RETROGRADE · TURNING POINT · NEAR STATION · SHADOW · MOON PHASE · SIGN CHANGE

## Voice rules (tested)
- Reflection prompts, never predictions. Banned: "will", "won't", "expect", "guarantee", "going to", "bad luck", "disaster", "beware", "warning", "doomed", "inevitable", "lag".
- Intense days stay gentle and reassuring: the level reflects overlapping sky events under our method, not disruption.
- Playful, slightly cheeky Retrograde voice; plain language; no jargon without a gloss ("Astrologers link it to…").
- Planet meanings are attributed to astrology, not stated as fact.
