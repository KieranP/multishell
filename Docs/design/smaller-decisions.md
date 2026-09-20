# Smaller decisions

What has no other file to go in. Newest at the bottom.

- **Install Command Line Tool is the one thing run as root.** The two paths go
  in as Apple event parameters to a handler in a constant script, never
  interpolated into it, and the script quotes them with AppleScript's own form.
- **Interpolating and escaping by hand escaped for the shell, not for
  AppleScript**, so a quote in the home path ended the literal and ran the rest
  as root. Costs: four-char codes Swift does not import, and main-actor-only
  components.
