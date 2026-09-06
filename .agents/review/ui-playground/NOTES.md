# Throwaway review layout exploration

Question: which visual style best supports reading a behavior recap, reviewing continuous findings, and inspecting source code?

Current variants:
- 11 Feed: original full-width recap, then a 50/50 finding and sticky-code split.
- 17 Feed · Yellow: same Feed layout and GitHub syntax colors, with AI Hero yellow (#f7c64f) accents.
- 15 GitHub: repository context, compact review-thread boxes, outlined labels, green actions. Reference: https://primer.style/product/components/
- 16 AI Hero: DM Sans headings, monospace labels, yellow actions, gray surfaces and warm gradient accents. Reference: https://www.aihero.dev/

All start with `whatChanged`. Code begins at the findings, follows titles crossing the viewport midpoint, and shows complete files with highlighted ranges. Done and discarded findings move into separate collapsed groups. Undo and Reopen preserve notes. State is in memory.

Build: `PYTHONDONTWRITEBYTECODE=1 python3 .agents/review/ui-playground/build-designs.py`

Open `index.html`; use the bottom switcher or `?variant=11`, `?variant=17`, `?variant=15`, `?variant=16`.

DM Sans is embedded for offline use; its OFL license accompanies the font and is included in the generated HTML.

Decision: pending user iteration. No production skill changes, commits, or new tests.

App identity: the user selected recovered option 1, the original Inbox mark. `assets/review-logo.svg` uses a white lowercase `r/` on the original rounded navy (#2e3d69) square. It is embedded in every header and as the favicon, so the HTML remains standalone.
