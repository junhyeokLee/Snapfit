# Selected UX Improvements Implementation Plan

> **For agentic workers:** Use superpowers:executing-plans to implement the approved changes inline.

**Goal:** Apply only review items 2, 3 and 4 selected by the user.
**Architecture:** Reuse the store filter anchor and existing moment compose/recap actions. Keep the current navigation and data flows.
**Tech Stack:** Flutter, Riverpod; no dependency changes.
**Spec:** ../../verification/design-next-priorities-2026-11-15/다음_디자인_개선사항.md (items 2–4 only).

## Constraints and review focus

- Keep bottom navigation source unchanged; retain initial store recommendations and filters.
- Preserve existing dirty workspace changes. Use per-file before snapshots rather than isolate stale HEAD.
- No app build, preview server, deployment, production mutation or commit.
- Cover same-day vs other-day records, month boundaries, 320px/large text, recap account safety and hidden store resume.

## Tasks

- [x] Store: expect category selection to reveal result controls and the active subject; use the existing filter-anchor reveal instead of returning to the recommendations.
- [x] Copy: expect `오늘 기록하기` before a daily record and `오늘 한 장 더` after one, in home and journal; retain new-record composition.
- [x] Recap: expect a visible `이번 주 돌아보기` button below the calendar, with 44px touch target; retain existing week/role/account checks.
- [x] Run changed regression tests before implementation (RED), then focused related suites (GREEN), inspect current rendered screenshots, run scoped analysis and whitespace checks.
- [x] Independently review the scoped before/after diff and record outcomes.

## Progress

Ruling: User selected concrete items from the saved review; implementation proceeds with that approval. Recap moves below the calendar to leave room for the month title on compact/large-text screens.

Completed: 76 related checks passed, 1 web-only test skipped; 8-file analysis passed. Independent review found no blockers. See docs/verification/selected-ux-improvements-2026-11-15/README.md.
Ruling: reuse the filter anchor for all category selections by removing the existing native top override; no new navigation state or branch is needed.
