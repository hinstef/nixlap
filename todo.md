# TODO

## nixadmin — Phase 2: pi.dev extensions for NixOS tools

Write TypeScript extensions for pi.dev that give it NixOS-specific tools:
- Read/edit files in the config repo
- Trigger nixos-rebuild via the Phase 3 helper socket
- Read systemd journal logs

See `docs/nixadmin-v2-spec.md` sections 7 and 9 for the tool set design.

---

## nixadmin — Phase 3: Privileged Helper Daemon

Replace the current NOPASSWD sudoers rules for `nixos-rebuild` with a proper
scoped Unix socket helper. See `docs/nixadmin-v2-spec.md` section 6 for the
full design.

- Small daemon listening on `/run/nixadmin-helper.sock`
- Accepts only `test | switch | revert` commands (no arbitrary shell)
- Runs `nixos-rebuild` as root, streams output back over the socket
- pi.dev extension calls the socket instead of invoking sudo directly
- Remove NOPASSWD sudoers rules from `nixadmin.nix` once done

---

# Hibernation Fix TODO

## Problem
`suspend-then-hibernate` not kicking in after 45min when lid is closed.

---

## Likely Causes

### 1. Spurious wakeups (most likely)
`suspend-then-hibernate` sets an RTC alarm to wake after 45min and then hibernate.
If something (USB, network, bluetooth) wakes the system before the RTC fires, it just stays awake.

```bash
# Check wake events from previous boot
journalctl -b -1 | grep -E "Wake|wake|PM:|suspend|hibernate"

# See which devices can wake the system
cat /proc/acpi/wakeup
```

### 2. `SuspendEstimationSec` too high
Current config:
```nix
HibernateDelaySec = "45min";
SuspendEstimationSec = "60min";  # if battery < 60min remaining, skip suspend -> hibernate immediately
```
The 60min threshold may interfere with battery-based logic. Try lowering:
```nix
SuspendEstimationSec = "45min";
```

### 3. `settings.hibernate` not `true`
The entire sleep config block is gated on `lib.mkIf settings.hibernate` — confirm the flag is set.

---

## Debugging Commands

```bash
# Check sleep events from last boot
journalctl -b -1 | grep -iE "sleep|suspend|hibernate|rtc|wake"

# Check RTC alarm was set (run immediately after lid close, before sleep)
cat /sys/class/rtc/rtc0/wakealarm

# Verify sleep config is applied
cat /etc/systemd/sleep.conf.d/*.conf
systemctl cat systemd-suspend-then-hibernate.service
```
