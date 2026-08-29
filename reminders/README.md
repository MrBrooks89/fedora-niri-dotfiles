# Fedora reminder service

`fedora-reminder` creates persistent systemd user timers. At expiry it plays the
open-source Freedesktop `alarm-clock-elapsed` sound through
`canberra-gtk-play` and shows a `notify-send` popup in the graphical user
session. Reminder state is private to the user under
`${XDG_STATE_HOME:-$HOME/.local/state}/fedora-reminders`.

```text
fedora-reminder add 10m "Check the oven"
fedora-reminder list
fedora-reminder cancel REMINDER_ID
fedora-reminder clear
fedora-reminder --help
```

Durations accept a positive integer followed by `s`, `m`, `h`, or `d`, up to
365 days. Each reminder has its own persistent timer and is removed after a
successful notification. No root access is used.

Fedora dependencies are `libnotify`, `libcanberra-gtk3`, and
`sound-theme-freedesktop`. Sound playback is best-effort: a missing player,
missing sound event, or playback failure does not suppress the visual reminder
or prevent successful cleanup.
