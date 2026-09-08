# Bundled Feed report

Generate with `scripts/generate-report.py`; use the bundled template unchanged.
This describes the design's behavior, not instructions to build a UI.

- Desktop Feed with the blue accent, selected `r/` logo, and GitHub syntax colors.
- Full-width “What changed” recap, pinned scope, and explicit reviewer completion
  and failures. Coverage, checks, and limits remain available with zero findings.
- Continuous findings sorted by severity × likelihood, unknown likelihood last.
  Reviewer counts and provider logos accompany the top tags.
- Equal-width finding/source columns. Code starts with the first finding, sticks
  to the viewport, and follows the last title to pass the screen midpoint.
- Compact file tabs with the all-comments icon and Before/After switch on their
  right. Full files always display, with cited ranges highlighted and review
  annotations inline. Filename/revision sit in the bottom status bar.
- Multiple files/ranges, independent Before/After paths for renames, explicit
  absent/unavailable states, and file browsing without findings.
- Expanded reproduction and confidence/limits; distinct colors for expected and
  actual/predicted outcomes. Preserve source, document, external, and check evidence.
- Decision notes outside code. Done and Discarded findings move to separate
  collapsed sections. Reopening, undo, browser persistence, and complete copying.
- Standalone HTML with embedded assets and no automatic network requests.

Assets/scripts are independent copies, not links to skill 2. Vendored assets:
highlight.js 11.11.1 (BSD-3-Clause), DM Sans (OFL), Simple Icons OpenAI 11.15.0 and
Claude 14.15.0 (CC0; marks belong to their owners). Font and highlighter licenses
are bundled and embedded in generated reports.
