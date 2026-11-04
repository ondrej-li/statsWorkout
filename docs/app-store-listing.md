# App Store listing — 1.0.0

Copy ready to paste into App Store Connect. Character counts are Apple's limits, measured on the
exact strings below (verified with `python3` — see the end of this file).

## App information

| Field | Value | Length |
| --- | --- | --- |
| App name | `StatsWorkout` | 12 / 30 |
| Subtitle | `Health stats for every period` | 29 / 30 |
| Bundle ID | `com.defik74.statsWorkout` | — |
| SKU | `statsworkout-001` | — |
| Version | `1.0.0` | — |
| Primary language | English (U.S.) | — |
| Primary category | Health & Fitness | — |
| Secondary category | — | — |
| Age rating | 4+ | — |
| Price | Free | — |
| Copyright | `2026 Ondřej Linek` | — |

## URLs

| Field | URL |
| --- | --- |
| Privacy Policy URL | https://stats-workout.ondralinek.cz/privacy.html |
| Support URL | https://stats-workout.ondralinek.cz/support.html |
| Marketing URL | https://stats-workout.ondralinek.cz/ |

## Promotional text — English (163 / 170)

```
All-day steps, workout distance, elevation and exercise time — for 24 hours, a day, a week, a month or a year. Zoom the charts, tap a bar and read the exact value.
```

## Description — English (1817 / 4000)

```
StatsWorkout turns the activity already stored in Apple Health into statistics you can actually read.

Pick a period — the last 24 hours, a single day, a calendar week, a month, a quarter, a year or any custom range — and see:
• steps for the whole period
• distance covered
• elevation gained
• time spent exercising
• number of activities

Every period comes with a total, an average, the best bucket and a comparison against the previous period or the same period last year. A month that is still running is compared with the same elapsed days of the previous one, so the numbers never flatter you.

ALL DATA OR JUST WORKOUTS
Switch between "All data" — everything Apple Health monitors continuously, including the walk to the shop — and "Activities", which counts only what was recorded inside a workout. Same charts, same periods, one tap apart.

CHARTS BUILT FOR FINGERS
Pinch to zoom into a shorter stretch, drag sideways to pan, and tap a bar or the progress line to read the exact value for that hour, day, week or month. The progress chart shows your running total against the previous period, so you can see at a glance whether you are ahead.

THE DETAILS
• units follow your preference — kilometres or miles, metres or feet
• calendar-aware weeks, months, quarters and years, including daylight-saving days
• hourly resolution for day and 24-hour views
• dark and light mode, Dynamic Type, VoiceOver labels on every chart
• no account, no sign-up, no subscription

PRIVACY
StatsWorkout asks Apple Health for read-only access to steps, distances, flights climbed, active energy and workouts. Every calculation happens on your device. There is no account, no analytics, no advertising, no third-party SDK and no server of ours that ever receives your health data.

Requires iOS 26 or later. iPhone and iPad.
```

## Description — Czech (1748 / 4000)

```
StatsWorkout mění aktivitu uloženou v Apple Health na statistiky, které se dají opravdu číst.

Vyberte období — posledních 24 hodin, jeden den, kalendářní týden, měsíc, čtvrtletí, rok nebo vlastní rozsah — a uvidíte:
• kroky za celé období
• ujetou a ušlou vzdálenost
• nastoupané převýšení
• čas strávený cvičením
• počet aktivit

Každé období má součet, průměr, nejlepší úsek a srovnání s předchozím obdobím nebo se stejným obdobím loňského roku. Rozběhnutý měsíc se porovnává jen se stejně dlouhou částí toho předchozího, takže čísla nikoho nešidí.

VŠECHNA DATA, NEBO JEN TRÉNINKY
Přepínejte mezi „Všechna data" — vším, co Apple Health sleduje průběžně, včetně cesty do obchodu — a „Aktivity", které počítají jen to, co bylo zaznamenáno uvnitř tréninku. Stejné grafy, stejná období, jeden dotek.

GRAFY NA DOTEK
Přibližte pinch gestem, posouvejte do stran a klepnutím na sloupec nebo čáru si přečtěte přesnou hodnotu pro danou hodinu, den, týden či měsíc. Graf průběhu ukazuje průběžný součet proti předchozímu období, takže na první pohled vidíte, zda jste napřed.

PODROBNOSTI
• jednotky podle vašeho nastavení — kilometry nebo míle, metry nebo stopy
• kalendářní týdny, měsíce, čtvrtletí a roky včetně dnů se změnou času
• hodinové rozlišení pro denní a 24hodinový pohled
• tmavý i světlý režim, Dynamic Type, popisky pro VoiceOver u každého grafu
• žádný účet, žádná registrace, žádné předplatné

SOUKROMÍ
StatsWorkout žádá Apple Health o přístup pouze pro čtení ke krokům, vzdálenostem, zdolaným patrům, aktivní energii a tréninkům. Všechny výpočty probíhají ve vašem zařízení. Neexistuje účet, analytika, reklama, SDK třetích stran ani náš server, který by se k vašim zdravotním datům dostal.

Vyžaduje iOS 26 nebo novější. iPhone a iPad.
```

## Keywords — English (91 / 100)

```
steps,workout,activity,training,distance,elevation,walking,running,cycling,hiking,pedometer
```

Apple indexes the app name and subtitle too, so "stats", "health" and "period" are deliberately not
repeated here. Keywords are per-locale: the Czech listing can use its own set, for example
`kroky,trénink,aktivita,vzdálenost,převýšení,chůze,běh,kolo,turistika,fitness`.

## What's new — next version (unreleased)

```
• Workout detail: route map, splits and full statistics for every activity
• Workouts are named after when and where they happened — "Your morning walk around Brtnice"
• Statistics stay up to date in the background, with an on-device cache
```

## What's new — 1.0.0

```
First release.
• Statistics for 24 hours, a day, week, month, quarter, year or a custom range
• Steps, distance, elevation, exercise time and activity count
• All data and workout-only views
• Zoomable, pannable charts with tap-to-read values
• Fair comparisons against the previous period or last year
```

## Review notes (927 / 4000)

```
StatsWorkout reads steps and workouts from Apple Health. There is no login and no account, so a
reviewer needs nothing but the demo data:

1. Launch the app. On first launch it asks for Health access; the sheet is the standard iOS one.
   Access can be declined — the dashboard then explains how to enable it in iOS Settings.
2. To see the interface with no Health data at all, open Settings → Data source → Use demo data.
   Demo activity is generated on the device from a fixed seed and is labelled in the UI.
3. Tap the period chips (24h, Day, Week, Month, Quarter, Year) and the All data / Activities switch
   above the charts to see how the numbers are derived.
4. Pinch a chart to zoom, then tap a bar to read that bucket's exact value.

No health data leaves the device: there is no server component, no analytics and no third-party SDK.
The privacy policy and support pages are at https://stats-workout.ondralinek.cz/.
```

## App Privacy answers

| Question | Answer |
| --- | --- |
| Do you or your third-party partners collect data from this app? | **No** — "Data Not Collected" |
| Tracking | No |
| Health & Fitness data | Read from HealthKit on device only; used for app functionality; never transmitted |
| Third-party SDKs | None |

## Screenshots

Upload from [screenshots/](../screenshots): `iphone/01-dashboard` … `06-settings` (1206 × 2622) and
`ipad/01-dashboard` … `04-activity-log` (2064 × 2752). Regenerate with `make shots`.

## Export compliance

`ITSAppUsesNonExemptEncryption` is already `false` in `Supporting/Info.plist`, so App Store Connect
does not ask.

## Verifying the limits

```sh
python3 - <<'PY'
import re, pathlib
text = pathlib.Path("docs/app-store-listing.md").read_text()
blocks = re.findall(r"```\n(.*?)\n```", text, re.S)
for block in blocks:
    print(len(block), block.splitlines()[0][:60])
PY
```
