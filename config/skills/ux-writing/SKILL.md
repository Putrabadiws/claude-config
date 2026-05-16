---
name: ux-writing
description: UX writing guide for UI copy - buttons, labels, errors, tooltips, notifications, onboarding text. Use when writing or reviewing any user-facing text in apps.
argument-hint: [component or context]
---

# UX Writing Guide

Apply these rules when writing any user-facing text: buttons, labels, error messages, tooltips, empty states, notifications, onboarding, modals, banners, etc.

Works for any language. Match the target language's natural tone.

## Core Principles

1. **Short** — Cut every word that doesn't help the user act
2. **Clear** — One reading = one meaning. No ambiguity
3. **Useful** — Every text should help the user do something or understand something
4. **Human** — Write like talking to a coworker, not a robot or a lawyer

## Word Choice

- Use simple, everyday words. If a simpler word exists, use it
- Avoid jargon unless the user definitely knows it
- Don't use fancy/formal words when plain ones work

| Avoid | Use instead |
|-------|-------------|
| utilize | use |
| commence | start |
| terminate | end, stop |
| subsequent | next |
| prior to | before |
| in order to | to |
| at this time | now |
| insufficient | not enough |
| functionality | feature |
| encountered an issue | something went wrong |

## Buttons & Actions

- Start with a verb: **Save**, **Delete**, **Send**, **Create**
- Be specific: **Save changes** > **Submit**, **Delete account** > **Confirm**
- Primary action = what the user wants. Secondary = escape route
- Destructive actions: say what will happen — **Delete project** not just **Delete**

| Bad | Good |
|-----|------|
| Submit | Save changes |
| OK | Got it |
| Cancel | Go back |
| Yes / No | Delete / Keep |
| Click here | View details |
| Proceed | Continue |

## Error Messages

Structure: **What happened** + **What to do**

```
What happened: We couldn't save your changes.
What to do:    Check your connection and try again.
```

Rules:
- Don't blame the user
- Don't use technical codes unless the user needs them for support
- Always give a next step when possible
- Be specific — "Password must be at least 8 characters" not "Invalid input"

| Bad | Good |
|-----|------|
| Error 500 | Something went wrong. Try again in a few minutes. |
| Invalid input | Enter a valid email address (e.g. name@example.com) |
| Operation failed | We couldn't delete this file. It may be in use. |
| Authentication error | Wrong email or password. Try again or reset your password. |
| Forbidden | You don't have access to this page. Contact your admin. |

## Empty States

Don't just say "nothing here." Tell the user:
1. What this place is for
2. How to get started

```
No alerts yet.
Alerts will show up here when your system detects a threat.
```

```
No reports.
Create your first report to start tracking activity.
[Create report]
```

## Confirmation Dialogs

- Title: what's about to happen
- Body: consequences (if any)
- Primary button: the action (not "Yes")
- Secondary button: the way out (not "No")

```
Title:   Delete this project?
Body:    This will permanently delete "My Project" and all its data.
         This action cannot be undone.
Buttons: [Cancel] [Delete project]
```

## Notifications & Toasts

- Keep under 2 lines
- Lead with the outcome, not the process
- Skip "Successfully" — if it worked, just say what happened

| Bad | Good |
|-----|------|
| Successfully saved | Changes saved |
| Your request has been submitted successfully | Request submitted |
| The item has been successfully deleted | Item deleted |
| Operation completed successfully | Done |

## Form Labels & Helpers

- Labels: short noun or noun phrase — **Email**, **Company name**, **Start date**
- Placeholders: example values, not instructions — `e.g. name@company.com`
- Helper text: constraints or context — "Must be at least 8 characters"
- Don't repeat the label in the placeholder

## Tooltips

- Answer "what is this?" or "why is this here?"
- Max 1-2 sentences
- Don't put critical info only in tooltips

## Loading & Progress

- Tell the user what's happening, not that something is happening
- **Loading alerts...** > **Loading...**
- **Saving your changes...** > **Please wait...**
- For long operations: show progress or estimate

## Capitalization & Punctuation

- Sentence case everywhere (headings, buttons, labels, menus)
- Title Case only for product names or proper nouns
- No period on single-sentence labels, buttons, or headings
- Use periods in multi-sentence body text
- No exclamation marks unless genuinely exciting (almost never in enterprise software)

## Numbers & Formatting

- Use digits for numbers: **3 alerts**, not **three alerts**
- Use relative time when useful: **2 minutes ago**, not **14:32:07**
- Large numbers: use separators — **1,234** not **1234**
- Dates: follow the app's locale. Default: **13 Feb 2026**

## Multilingual Notes

When writing copy for non-English languages:
- Don't translate English copy word-by-word. Rewrite naturally in the target language
- Match the formality level of the target culture (e.g. formal "vous" vs informal "tu" in French)
- Keep UI text short — some languages expand 30-40% vs English
- Test button text length — German and Portuguese tend to be longer
- Right-to-left languages (Arabic, Hebrew): ensure layout works

## Checklist

Before shipping any copy, check:
- [ ] Can a new user understand this without context?
- [ ] Is every word necessary?
- [ ] Does the user know what to do next?
- [ ] No jargon, no internal terms?
- [ ] Consistent with other text in the same screen?
- [ ] Works in the target language (not a literal translation)?
