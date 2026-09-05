# Report UI

Use an editorial layout with readable typography and clear hierarchy.

- Keep each finding's title, problematic location, severity, likelihood, reviewer count, and "What goes wrong" visible in the findings list. Selection reveals its full explanation, reproduction, and evidence limits.
- Show syntax-highlighted Before and After code in a right sidebar, alongside the finding. Allow opening the full file at each recorded revision with its recorded line range highlighted. Clearly label an absent side for added or deleted code.
- Give each finding an editable comment and an Open, Done, or Rejected status. Done and Rejected findings move to a separate list at the bottom; reopening returns them to the active list.
- Persist statuses and comments across reloads in the same browser, keyed by report and stable finding ID.
- Provide a copy action containing the complete finding: revision-specific paths and start/end lines, severity and likelihood with reasoning, Before/After code, explanation, reproduction, evidence limits, reviewer count, and the user's comment if present.
- Show reviewer completion status and coverage limits separately from findings. If none are supported, display "No supported findings identified" without implying failed or incomplete reviews succeeded.
