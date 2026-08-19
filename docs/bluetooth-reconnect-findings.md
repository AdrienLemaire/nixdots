# BLE keyboard reconnect latency — measured findings

Hardware: Dell XPS 13 9320, Intel AX211 (`hci0` A0:02:A5:03:92:B4), Logitech
MX Keys Mini (`D3:46:9C:DC:46:1B`, daily driver) and Pebble K380s.
Measured 2026-08-18/19 on kernel 6.18.35 / bluez 5.86.

Tools in this directory: `bt-reconnect-measure.sh` (latency), `bt-trace.sh` (HCI trace).

## Symptom

~3.5 s from the keyboard's BLE link coming up to it actually being usable.

| phase | at 30–50 ms interval | at 7.5–15 ms interval |
|---|---|---|
| LE link established | ~0.5 s | ~0.2 s |
| link → ServicesResolved | 1.9–2.4 s | 1.71–1.73 s |
| ServicesResolved → `uhid` device | 1.440 s | 1.440 / 1.439 / 1.462 s |

For comparison the Pebble M350s mouse goes link → usable in **0.01 s**.

## Root cause

Enumeration is ATT round-trip bound. From the HCI trace, one reconnect is
**184 ATT PDUs**: 35 Read Request, 24 Read Blob Request (the HID report map),
9 Write Request (CCCD enables), plus responses and notifications.

Measured ATT round trip: **median 44 ms** (min 35, max 46) = 2 × the connection
interval. 68 request/response round trips × 44 ms ≈ **3.0 s**. That is the delay.

Two firmware limits on the keyboard make this unavoidable at a given interval:

- **ATT MTU is 23**, the spec minimum (`Exchange MTU Response: Server RX MTU: 23`)
  even though bluez asks for 517. The report map therefore needs 24 blob reads.
- Service *discovery* is NOT the problem — only 3 `Read By Group Type` and 1
  `Read By Type` appear, so bluez's GATT cache is working. It is the
  characteristic *value* reads (report map, report references, DIS strings)
  that bluez repeats on every single connection.

## The connection interval is not ours to set

`hardware.bluetooth.settings.LE` only governs the **initial** connection:

```
LE Enhanced Connection Complete: interval 15.00 msec, latency 0, supervision 6000 msec
```

165 ms later the keyboard sends an L2CAP Connection Parameter Update Request
(min 20 ms, max 25 ms, **peripheral latency 20**, timeout 2100 ms). bluez
accepts unconditionally — the kernel only sanity-checks against spec ranges,
there is no policy hook — and 285 ms after that:

```
LE Connection Update Complete: interval 22.50 msec, latency 20, supervision 2100 msec
```

So only the first ~450 ms of enumeration runs at our interval; the remaining
~3 s runs at the keyboard's 22.5 ms. Measured gain from 30–50 ms → 7.5–15 ms
was **0.35 s** of ~3.5 s, which matches.

## Correction to the K380s regression notes

The supervision-timeout workaround (`ConnectionSupervisionTimeout = 600`) is
**defeated in practice**: the keyboard pulls it straight back down to 2100 ms,
the exact value blamed for the `Reason 0x08 Connection Timeout` drops.

The premise that renegotiation silently fails on this host (kernel bug
`91b5a598b5`) is **not what this trace shows** — the update completes
successfully, status 0x00. Whatever causes the drops, "the initial params
stick" is not the mechanism here.

Corollary: the fast initial interval is nearly free, since the keyboard
renegotiates away from it within 450 ms regardless.

## Where the remaining headroom is

Ranked by payoff:

1. **Stop the link dropping at all.** The user only waits because the link
   drops when they step away. Supervision timeout ends up at 2100 ms with
   peripheral latency 20 (≈470 ms of tolerated silence). `hcitool lecup
   <handle> --latency 20 --timeout 600` after connect would restore a 6 s
   timeout while keeping the keyboard's preferred interval and latency, so
   there is no battery cost. Needs a hook on connect; bluez has no knob.
2. **Force a faster interval during enumeration** via the same `lecup` path.
   68 round trips at 15 ms instead of 44 ms ≈ 1 s instead of 3 s. Races with
   enumeration, which starts ~150 ms after connect.
3. Nothing can be done about MTU 23 or the repeated value reads without
   patching bluez.

---

# Update 2026-08-19 — `hid-vivaldi` is the largest single cost

Correction to the analysis above: the 24 `Read Blob Request`s are **not** the HID
report map. They are **12 separate 48-byte value reads** (each 22+22+4 bytes),
and the trace timestamps for the 12 group-terminating reads are:

```
269.007 269.548 269.998 270.177 270.402 270.582
270.762 270.942 271.077 271.212 271.347 271.482
```

Steady-state spacing settles at ~0.14 s = 3 ATT round trips × 44 ms.

Twelve reads, and the keyboard has exactly twelve function-row keys:

```
/sys/bus/hid/devices/0005:046D:B369.0045/function_row_physmap
= C0000 C0000 C0000 C0000 C0000 C0000 C0000 C0000 C0000 C0000 C0000 C0000
```

`vivaldi_feature_mapping()` (`drivers/hid/hid-vivaldi-common.c`) issues a
**synchronous blocking** `hid_hw_raw_request(HID_FEATURE_REPORT, HID_REQ_GET_REPORT)`
**once per function-row key usage**, during driver probe — i.e. after bluez has
created the uhid device but before the input device is registered. Each one is a
GATT round trip back out over the air.

All twelve returned values are identical (`0x000C0000` = HID_UP_CONSUMER), which
is degenerate — the remapping data this buys is useless.

Cost: ~12 × 0.14 s ≈ **1.7 s** of the ~3.2 s, and it explains the previously
mysterious invariant 1.44 s tail between `ServicesResolved` and the `uhid`
device appearing. It did not shrink with the connection interval because it is
round trips, and by then the keyboard had already renegotiated to 22.5 ms.

Device/driver binding on this host:

| device | HID id | driver | link → usable |
|---|---|---|---|
| Pebble M350s mouse | `046D:B036` | `hid-generic` | ~0.0 s |
| MX Keys Mini | `046D:B369` | `hid-vivaldi` | 3.0–3.9 s |
| Pebble K380s | `046D:B377` | `hid-vivaldi` | slow |

The journal also carries 20 `hid-vivaldi ... failed to fetch feature 9` warnings
in 8 days, in bursts — the same signature reported at
https://sleeplessbeastie.eu/2025/09/23/how-to-solve-logitech-mx-keys-s-connection-issue/
where blacklisting `hid-vivaldi` resolved a 56 s attach.

**`hid-vivaldi` cannot cause a disconnect** — on failure it does `dev_warn` and
`goto out`; probe never fails and the link is untouched. It explains delay only.

Note: `boot.blacklistedKernelModules = [ "hid_vivaldi" ]` appears in
`k380s-bt-regression.md` under "tried and proven ineffective" — but that was
evaluated against the *disconnect* regression, not against reconnect latency.
It was never measured for this.

Live test without a rebuild:

```
sudo rmmod hid_vivaldi hid_vivaldi_common
./docs/bt-reconnect-measure.sh          # expect hid= to drop by ~1.5-2 s
```

Caveat: the function row may behave differently under `hid-generic`, though the
physmap being 12× identical suggests nothing real is lost.

## Result (measured 2026-08-19)

`sudo rmmod hid_vivaldi hid_vivaldi_common`, then re-measured:

```
before   link=0.20s  hid=3.19s  total=3.39s
after    link=0.27s  hid=0.11s  total=0.38s
```

**hid 3.17 s -> 0.11 s, a 29x improvement.** Larger than the ~1.7 s predicted
from the 12 blob-read groups alone, so hid-vivaldi accounts for essentially the
whole enumeration cost, not just the reads that were separable in the trace.

Made permanent as `boot.blacklistedKernelModules = [ "hid_vivaldi" ]` in
`host/config.nix`. The keyboard now falls back to `hid-generic`, matching the
mouse.

For the record, the LE connection-interval change earlier in this document is
worth 0.35 s and is now largely moot -- enumeration is no longer the bottleneck.
It costs nothing (the keyboard renegotiates away from it within 450 ms), so it
is being left in place, but it is not what fixed this.

## Side effect: device names change under hid-generic

Blacklisting `hid-vivaldi` changes how the keyboard enumerates. Under
`hid-vivaldi` it was a single input device `MX Keys Mini`; under `hid-generic`
it becomes three, and the one carrying the alphanumeric keys is named
**`MX Keys Mini Keyboard`** -> hyprland device `mx-keys-mini-keyboard`.

That silently broke the per-device layout: `device { name = mx-keys-mini }` no
longer matched, so the keyboard fell back to the global `us_qwerty-fr` instead
of `jp_qwerty-fr`. Verified with `hyprctl devices`.

Fixed by keeping rules under **both** names in `modules/hm/default.nix` and
`modules/hm/home/hypr/userprefs.conf` (hyprland ignores rules for absent
devices, so carrying both is harmless and survives a driver change either way).
The K380s is also a vivaldi device and gets the same treatment.

To check after any driver change:

```
hyprctl devices | awk '/Keyboard at/,/Tablets:/' | grep -A4 -i mx-keys
```

Look at `active keymap`. Expected: `Japanese (JIS) with french symbols`.
