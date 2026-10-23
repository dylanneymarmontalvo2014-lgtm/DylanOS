# DylanOS Shell

The first-run Plasma desktop layout adds the DylanOS dashboard to each desktop using Plasma's positioned `Containment.addWidget` scripting API. It provides a live clock, a navigable month calendar, and local memory/uptime readings from `/proc`; it intentionally has no fabricated weather, events, reminders, or remote-service data. Like the rest of the initial layout, this applies to new profiles and does not replace an existing user's panels or desktop widgets.

The Control Center's Do Not Disturb toggle now uses Plasma's public `NotificationManager.Settings` API. A user-initiated toggle inhibits notifications for eight hours and can be cleared from the same control. An application-owned inhibition is shown as such and is not overridden. The notification list continues to display the real Plasma notification model, including while Do Not Disturb is active. The compact badge shows the number of current notifications, not an unread count. The secondary action opens KDE Connect by its proper name, not the unrelated AirDrop brand.

Konsole retains the DylanOS Crimson profile and current-session-directory behavior; its scrollback history is increased to 50,000 lines. No wallpaper configuration or image is changed by these shell enhancements. Fastfetch remains unchanged pending approval of its separate logo preview.
