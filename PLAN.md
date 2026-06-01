# Descent Mk3i Tactical — Watch Face Build Plan

## What We're Building

A custom Garmin watch face for the **Descent Mk3i 51mm** (454×454 AMOLED). Tactical aesthetic inspired by Black Grid and Big Easy, but cleaner — fewer data slots, bold readability, and a No Flight Time arc on the outer ring aligned to the physical 24h bezel.

---

## Layout

```
         [NFT arc — outer ring, ~215px radius, cyan]

              SUN 31                   ← date, top center
        72F   NW 12mph   5280ft        ← weather / wind / altitude
    [════════════════════] 82%          ← battery progress bar

           23:45  :58 [B][!]           ← large time + seconds + BT + notifications

      88    72    1842    67           ← Body Battery | Stress | Calories | HR
      BB    ST    CAL     HR
```

### Zone Details

| Zone | Content | Position (y) |
|---|---|---|
| Outer arc | NFT countdown (cyan, 4px); 24h = full circle | radius 215 |
| Date | "SUN 31" cyan-green text | y ≈ 65 |
| Info row | Temp \| Wind+dir \| Altitude | y ≈ 108 |
| Battery bar | Horizontal bar (green/yellow/red) + % label | y ≈ 149 |
| Time | Large HH:MM (NUMBER_HOT font) | y ≈ 200–270 |
| Seconds | Small ":SS" bottom-right of time | y ≈ 258 |
| Icons | BT (blue=connected, dim=off) + notification dot | x ≈ 355, y ≈ 262 |
| Bottom row | Body Battery, Stress, Calories, HR — 4 cols | y ≈ 350/378 |

---

## Color Palette

| Element | Hex |
|---|---|
| Background | `#000000` |
| Primary text / time | `#FFFFFF` |
| Accent (date, labels) | `#00FFBF` tactical cyan-green |
| Muted labels | `#777777` |
| NFT arc | `#00CFFF` cyan |
| Battery (high >30%) | `#00AA44` green |
| Battery (mid 15-30%) | `#FFAA00` yellow |
| Battery (low <15%) | `#FF3300` red |
| BT connected | `#00AAFF` blue |
| Seconds | `#AAAAAA` gray |

---

## Data Sources

| Field | API |
|---|---|
| Time + Date | `System.getClockTime()`, `Gregorian.info()` |
| Temperature (°F) | `Weather.getCurrentConditions().temperature` (C→F) |
| Wind (mph + compass dir) | `Weather.getCurrentConditions().windSpeed/windBearing` |
| Altitude (ft) | `Activity.getActivityInfo().altitude` (m→ft) |
| Battery % | `System.getSystemStats().battery` |
| Heart Rate | `Complications.COMPLICATION_TYPE_HEART_RATE` |
| Calories | `Complications.COMPLICATION_TYPE_CALORIES` |
| Body Battery | `Complications.COMPLICATION_TYPE_BODY_BATTERY` |
| Stress | `Complications.COMPLICATION_TYPE_STRESS` |
| No Flight Time | `Complications.COMPLICATION_TYPE_NO_FLY_TIME` (dive devices) |
| Bluetooth | `System.getDeviceSettings().phoneConnected` |
| Notifications | `System.getDeviceSettings().notificationCount` |

> **NFT fallback**: If `COMPLICATION_TYPE_NO_FLY_TIME` is not supported at runtime, the outer arc shows a 24-hour time-of-day arc instead.

---

## File Structure

```
garmin-watchface-custom/
  manifest.xml           # app config, permissions, device targets
  monkey.jungle          # build config
  PLAN.md                # this file
  source/
    WatchFaceApp.mc      # AppBase entry point
    WatchFaceView.mc     # all drawing + complication logic
  resources/
    strings/
      strings.xml        # app name string
    drawables/
      drawables.xml      # launcher icon reference (placeholder)
```

---

## Permissions (manifest.xml)

```xml
<iq:uses-permission id="SensorHistory"/>   <!-- weather data -->
<iq:uses-permission id="ActivityHistory"/> <!-- altitude -->
<iq:uses-permission id="Complications"/>   <!-- HR, BB, stress, NFT, calories -->
```

---

## Build & Test

1. **Install**: Garmin Connect IQ SDK + VS Code with Monkey C extension
2. **Simulate**: `Ctrl+Shift+P` → "Run Connect IQ Simulation" → choose `descent_mk3i`
3. **Sideload**: Connect IQ app on phone → My Device Apps → install from dev mode
4. **NFT test**: Use the dive simulator in Garmin Connect IQ to inject a dive and check NFT arc

---

## Implementation Order

- [x] Project scaffold (manifest, jungle, directories)
- [x] WatchFaceApp.mc — entry point
- [x] WatchFaceView.mc — full drawing implementation
- [ ] Test in simulator (time, battery bar, bottom row)
- [ ] Verify weather + altitude data fields
- [ ] Verify complications (HR, calories, body battery, stress)
- [ ] Test NFT arc after a simulated dive
- [ ] Polish: spacing, font sizing, edge case null handling
- [ ] Sideload to physical device
