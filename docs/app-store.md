# App Store submission notes

Everything App Store Connect needs for a first submission, in the order the form asks for it.
The public pages live at [stats-workout.ondralinek.cz](https://stats-workout.ondralinek.cz/).

## App information

| Field | Value |
| --- | --- |
| Name (30) | `StatsWorkout` |
| Subtitle (30) | `Apple Health stats, any period` |
| Bundle ID | `com.defik74.statsWorkout` |
| SKU | `statsworkout-001` |
| Primary language | English (U.S.) |
| Primary category | Health & Fitness |
| Secondary category | — |
| Age rating | 4+ (no user content, no ads, no web browsing) |
| Copyright | `2026 Ondřej Linek` |
| Price | Free |

## URLs

| Field | URL |
| --- | --- |
| Privacy Policy URL | https://stats-workout.ondralinek.cz/privacy.html |
| Support URL | https://stats-workout.ondralinek.cz/support.html |
| Marketing URL (optional) | https://stats-workout.ondralinek.cz/ |

Czech versions: `/cs/privacy.html`, `/cs/support.html`, `/cs/`.

## Promotional text (170)

> Steps, distance, elevation, exercise time and workouts — summarised for any period, with charts you can zoom into and read with a finger.

## Description (en-US)

```
StatsWorkout turns the activity already stored in Apple Health into statistics that are actually readable.

Pick a period — the last 24 hours, a single day, a calendar week, a month, a quarter, a year or any custom range — and see:
• steps for the whole period
• distance covered in workouts
• elevation gained
• time spent exercising
• number of activities

Every period comes with a total, an average, the best bucket and a comparison against the previous period or the same period last year. A month in progress is only compared with the same elapsed days, so the numbers stay honest.

The charts are built for fingers: pinch to zoom into a shorter stretch, drag to pan, and tap a bar or the progress line to read the exact value for that hour, day, week or month. The progress chart shows your running total against the previous period, so you can see at a glance whether you are ahead.

Details:
• units follow your preference — kilometres or miles, metres or feet
• distance, elevation and exercise time come from workouts; steps are counted all day long
• calendar-aware weeks, months, quarters and years, including daylight-saving days
• dark and light mode, Dynamic Type, VoiceOver labels on every chart

Privacy:
StatsWorkout asks Apple Health for read-only access to steps, distances, flights climbed, active energy and workouts. All calculations happen on your device. There is no account, no analytics, no advertising, no third-party SDK and no server of ours that ever receives your health data.

Requires iOS 26 or later.
```

## Description (cs)

```
StatsWorkout mění aktivitu uloženou v Apple Health na statistiky, které se dají opravdu číst.

Vyberte období — posledních 24 hodin, jeden den, kalendářní týden, měsíc, čtvrtletí, rok nebo vlastní rozsah — a uvidíte:
• kroky za celé období
• vzdálenost z tréninků
• nastoupané převýšení
• čas strávený cvičením
• počet aktivit

Ke každému období patří součet, průměr, nejlepší úsek a srovnání s předchozím obdobím nebo se stejným obdobím loňského roku. Rozběhnutý měsíc se porovnává jen se stejně dlouhou částí toho předchozího, takže čísla zůstávají poctivá.

Grafy jsou stavěné na prsty: přiblížíte pinch gestem, posouváte tažením a klepnutím na sloupec nebo čáru si přečtete přesnou hodnotu pro danou hodinu, den, týden či měsíc. Graf průběhu ukazuje průběžný součet proti předchozímu období, takže na první pohled vidíte, zda jste napřed.

Podrobnosti:
• jednotky podle vašeho nastavení — kilometry nebo míle, metry nebo stopy
• vzdálenost, převýšení a čas cvičení pocházejí z tréninků; kroky se počítají za celý den
• kalendářní týdny, měsíce, čtvrtletí a roky včetně dnů se změnou času
• tmavý i světlý režim, Dynamic Type, popisky pro VoiceOver u každého grafu

Soukromí:
StatsWorkout žádá Apple Health o přístup pouze pro čtení ke krokům, vzdálenostem, zdolaným patrům, aktivní energii a tréninkům. Všechny výpočty probíhají ve vašem zařízení. Neexistuje účet, analytika, reklama, SDK třetích stran ani náš server, který by se k vašim zdravotním datům dostal.

Vyžaduje iOS 26 nebo novější.
```

## Keywords (100, comma separated)

```
steps,workout,activity,health,statistics,training,distance,elevation,walking,running,cycling
```

## App Privacy

- **Data collection:** *Data Not Collected.* HealthKit data never leaves the device and the app has
  no backend, no analytics and no crash reporting.
- **Health & Fitness data:** used only for app functionality, on device, not linked to identity —
  and not collected in the App Privacy sense.
- **Tracking:** No.

## Export compliance

`ITSAppUsesNonExemptEncryption = false` is already set in `Supporting/Info.plist`, so App Store
Connect does not ask.

## Review notes

```
StatsWorkout reads steps and workouts from Apple Health; there is no login and no account.
On first launch the app shows the Health permission sheet. If access is declined, the dashboard
explains how to enable it in iOS Settings → Privacy & Security → Health → StatsWorkout.

No Health data leaves the device: there is no server component, no analytics and no third-party SDK.

To see the interface without any Health data, open Settings → Data source → Use demo data. The
sample activity is generated locally on the device and clearly labelled in the UI.
```

## Screenshots

Required sizes (Apple, 2026): 6.9" iPhone and 13" iPad, portrait. Capture with demo data so every
chart is populated:

1. Dashboard, month period — hero total, metric tiles, bars.
2. Dashboard, day period — hourly bars with a selected bar showing its value.
3. Progress over time chart vs previous period.
4. Activities list.
5. Settings — units and comparison options.
6. (Czech) Dashboard, month period.

## Localisation

The app is English-only for now; the website and the App Store listing ship English (primary) and
Czech. If the app is localised later, add `cs` to `project.yml` and a string catalog.
