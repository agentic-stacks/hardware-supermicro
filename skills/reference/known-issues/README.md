# Known Issues

Check this reference before performing firmware updates or when encountering unexpected behavior. Each entry documents the symptom, root cause, workaround, affected versions, and current status.

## How to Use

1. Identify your platform generation (X11, X12, X13) and current BMC firmware version
2. Review the issues below before firmware updates or when debugging unexplained behavior
3. Each entry follows: **Symptom / Cause / Workaround / Affected versions / Status**

> **Note:** Supermicro releases firmware per-motherboard model, not per-platform. Always verify these issues against your specific motherboard model and firmware version.

---

## X13 Platform Known Issues

### BMC Web UI Session Timeout After Firmware Update

**Symptom:** After BMC firmware update, web UI sessions expire immediately upon login.
**Cause:** Session cookie format changed between firmware versions; old cookies are rejected by the new firmware.
**Workaround:** Clear browser cookies for the BMC IP address, or open the web UI in a private/incognito window.
**Affected versions:** BMC firmware 01.00.xx through 01.02.xx
**Status:** Fixed in 01.03.xx

---

### Redfish BIOS Attributes Return Empty After Reboot

**Symptom:** `GET /redfish/v1/Systems/1/Bios` returns an empty `Attributes` object immediately after host reboot.
**Cause:** The BMC requires time to read and cache BIOS configuration after the host powers on. The Redfish endpoint responds before the data is ready.
**Workaround:** Wait 60–90 seconds after reboot before querying BIOS attributes via Redfish.
**Affected versions:** X12 and X13 with BMC firmware < 01.04.xx
**Status:** Improved in later firmware (wait time reduced to approximately 30 seconds)

---

### ipmitool sol activate Drops Connection Intermittently

**Symptom:** Serial Over LAN session established with `ipmitool sol activate` disconnects after a few minutes of use.
**Cause:** BMC SOL buffer overflows under high serial console output, causing the session to drop.
**Workaround:** Reduce serial console verbosity (e.g., lower kernel log level), or use the HTML5 KVM console instead of SOL.
**Affected versions:** Various X11 and X12 BMC firmware versions
**Status:** Partially addressed in newer firmware; SOL remains less reliable than KVM for high-output sessions
