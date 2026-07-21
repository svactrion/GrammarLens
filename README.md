# GrammarLens

**An AI-powered grammar coach for people who learned English by speaking it — not by studying it.**

> 🚧 Active development — personal product case study, built in public.
> Currently in: **Phase 1 — Discovery & Definition**

## The Problem

Many English learners (including me) became fluent through conversation:
foreign friends, games, series. We can speak — but our grammar knowledge
is implicit. Ask us *why* it's "have been" and not "was", and we freeze.

Exams like IELTS demand explicit grammar accuracy. Existing apps don't
serve this segment: beginner apps (Duolingo etc.) start too low and move
too slowly; grammar books are dry and not personalized.

## The Idea

A mobile app (Flutter) that teaches grammar from **your own sentences**:

1. Short daily writing prompts (IELTS-style micro tasks)
2. LLM analyzes your sentences → detects mistakes
3. For each mistake: what went wrong → which rule → corrected version → 2-3 targeted mini exercises
4. **Error-pattern memory:** the app tracks your recurring mistake types and personalizes practice around *your* weak spots

AI is not a feature here — it's the foundation. A static rules-and-quizzes
app can't build a personalized curriculum from your own writing.

## Product Process

This project follows a structured product process, documented as it happens:

- [ ] User research (interviews with IELTS candidates)
- [ ] Competitor analysis
- [x] PRD → [`/docs/prd.md`](docs/prd.md)
- [ ] MVP prototype (Flutter + LLM API)
- [ ] User testing (5+ testers)
- [ ] Iteration based on feedback

## Scope Decisions (what's deliberately NOT in the MVP)

- No speech/audio features
- No gamification, streaks, levels
- No placement test
- Single language pair (TR → EN) to start

Why: documented in the PRD.

## Stack

Flutter · LLM API (structured JSON feedback) · AI-assisted development (Claude Code)

## Dev Notes

- Run the web build with a fixed port, e.g.
  `flutter run -d chrome --web-port=5555 --dart-define=ANTHROPIC_API_KEY=...`.
  The local error profile is stored in the browser's IndexedDB, which is
  scoped per-origin *including port* — a random port each run means a fresh,
  empty database every time.

## About

Built by [Ahmet Emin Tayfur](https://www.linkedin.com/in/ahmettayfur) — statistics graduate moving
into product management. This repo doubles as my learning-in-public log;
process write-up coming on [Medium](https://medium.com/@ahmet-tayfur).
