# Fedora reminder service

`fedora-reminder` creates persistent systemd user timers and delivers expiry
through `notify-send` in the graphical user session. Reminder state is private
to the user under `${XDG_STATE_HOME:-$HOME/.local/state}/fedora-reminders`.

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
