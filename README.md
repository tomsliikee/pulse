<div align="center">
  <img src="readmestuff/app_icon_512.png" width="96" height="96" alt="Pulse logo" />
  <h1>Pulse</h1>
  <p><strong>A health app for Android in Material 3 Expressive. It reads your data from Health Connect, keeps up to ten years of it on the phone, and sends none of it anywhere.</strong></p>

  <p>
    <img src="https://img.shields.io/badge/Platform-Android%208.0+-neutral?style=flat-square" alt="Platform" />
    <img src="https://img.shields.io/badge/Engine-Flutter%203.47-neutral?style=flat-square" alt="Flutter Version" />
    <img src="https://img.shields.io/badge/Design-Material%203%20Expressive-neutral?style=flat-square" alt="Design Language" />
    <img src="https://img.shields.io/badge/Data-Health%20Connect-neutral?style=flat-square" alt="Data Source" />
    <img src="https://img.shields.io/badge/Storage-Local%20JSON-neutral?style=flat-square" alt="Storage" />
    <img src="https://img.shields.io/badge/Languages-de%20%7C%20en%20%7C%20pl-neutral?style=flat-square" alt="Languages" />
    <img src="https://img.shields.io/badge/Telemetry-None-neutral?style=flat-square" alt="No Telemetry" />
    <img src="https://img.shields.io/badge/License-MIT-neutral?style=flat-square" alt="License" />
  </p>
</div>

---

![Pulse: Today, Activity, Sleep and Heart](readmestuff/hero.png)

**Pulse** shows what your phone and watch already measure: steps, workouts, sleep, heart rate and the rest. It has one data source, **Health Connect**, so anything your phone, a **Fitbit** or another app writes there shows up without a second sign-in.

There is no account, no server and no analytics. The one thing Pulse asks the network for is the **weather** of the morning, and only once you set a place in the profile; your health data never leaves the phone.

The screenshots on this page show sample data.

---

## Features

- **Four Pages, One Scene Each:** **Today**, **Activity**, **Sleep** and **Heart** each open with an animated scene drawn by the app and the page's main number on a shape. The scene comes in when the page opens: the land rises, the sun or the moon climbs to its place and the figure appears.
- **Simple or Advanced:** The large cards show their few most important numbers, or all of them. A new installation starts simple.
- **Good Morning:** A few cards when you get up: last night, your recovery, the weather and your goals.
- **Weekly Report:** On Sunday evening, the week from Monday to Sunday against the weeks before, with a score of its own.
- **What Goes Together:** Connections found in your own numbers, such as how you sleep after a day with a workout.
- **Recovery, Day Score and Sleep Score:** Three scores from 0 to 100, each broken down into the parts it is made of.
- **Twelve Goals:** By day or by week, with streaks and a view per week, month and year.
- **Body Age:** Your real age plus or minus the years your last 30 days are worth.
- **Ten Years of History:** Every metric by day, week, month, year and in total.
- **Your Own Layout:** Remove, add, resize and reorder the tiles of every page.
- **Reload by a Button:** The arrow beside the edit pencil reads everything again. Pulling the page down does nothing, so a scroll never reloads by mistake.
- **Every Kind of Workout:** 56 kinds, from running to table tennis, each counted in the way that fits it.
- **Routes:** The way a workout took, drawn by its speed, with the time of each kilometre and the climb.
- **Entries:** Add **water**, **weight** and **meals**; they are written to Health Connect. A meal starts at the foods you logged before.
- **Colour Styles, Dark Theme and Liquid Glass:** The colours follow your wallpaper or one of seven styles of the app's own, and the bars can turn into refracting glass.
- **Three Languages:** **German**, **English** and **Polish**.
- **Private by Construction:** Everything stays in the app's own directory, with a backup file you save yourself.

---

## The Pages

### Simple and Advanced

The large cards of the four pages come in two modes, chosen at the top of the profile.

- **Simple:** Each card keeps its drawing and one to three numbers: recovery, steps and active calories on Today, the distance or the duration of the latest workout, the score and length of the night, the latest heart rate and the day's range. Sentences say how it went without a number.
- **Advanced:** The same cards with everything: goals, hours, times, pace, sleep stages and minutes per zone.
- **Nothing Is Lost:** Tiles and detail pages show all their numbers in both modes. Tap a large card to see everything behind it.

A new installation starts in simple mode. An installation that already has settings stays advanced.

![Today in advanced and in simple mode, then Activity and Sleep in simple mode](readmestuff/simple.png)

### Today

- **The Day as a Scene:** The sky follows the time of day, with the sun or the moon where the hour puts it. By day the figure walks, livelier in an hour with many steps, past three rows of hills and swaying grass; at night it stands and breathes.
- **Recovery:** How rested the day began, from 0 to 100 %, in red, yellow or green. From nine in the evening the **day score** joins it.
- **Two Rings:** **Steps** outside and **active calories** inside, each against its goal, around the **body age**. A ring that reaches its goal turns into a travelling wave.
- **The Hours So Far:** Small bars from midnight to now beside each ring, and one sentence that sets your steps against yesterday at the same time.
- **Hints:** Up to three, from fixed rules over your own numbers.
- **A Page per Day:** The scores with their parts, the day in numbers with marks for a **personal best**, the night before and the workouts of that day.

![Goals and tiles on Today, the page about one day, and the list of all days](readmestuff/today.png)

### Good Morning

Like the morning brief of a watch, on the phone: the first time you open Pulse within **three hours** of getting up, a few cards to swipe through appear by themselves. They begin with a **sunrise**, behind which Pulse reads what your watch wrote since, so the night is there when the cards come. Around the time you usually get up, an alarm of the app sends a **notification**; where the hourly refresh found the night before that, it tells of it.

- **Greeting:** A morning scene whose sky shows the weather, your name, and one sentence on how hard the day should be: **easy**, **normal** or **demanding**.
- **Last Night:** Sleep score, time asleep and the stages. While the watch has not synced, the card says so.
- **Recovery:** The score with its parts, and the readings of the night that **stand out** against your last 30 days: heart rate variability, resting heart rate, respiratory rate, oxygen saturation and skin temperature.
- **Weather:** Now, highest, lowest, the chance of rain and the day in two-hour steps, for the place you set in the profile. Without a place there is no weather card and no network access.
- **Goals:** Where each goal stands and its streak, and yesterday in numbers.
- **Tonight:** When to go to bed.

For the rest of the morning the **Good morning** tile on Today opens the cards again; when the three hours are over it leaves the page until the next day. One switch in the profile turns all of it off; a second one keeps the tile on Today all day.

![The greeting, last night, the recovery and the weather](readmestuff/morning.png)

### Activity

- **The Latest Workout as a Scene:** A figure does what the workout was, where it takes place: on the road, in a hall with wall bars, on a field with a goal, a net or a basket, in falling snow, on a rock face, on the water or under it. 22 figures cover the 56 kinds; related kinds share one and differ in what they hold. Strength changes from squats to presses to lifts from the floor, yoga flows from one posture into the next, a ball is struck and comes back.
- **The Number a Kind Is About:** A run, a ride or a swim opens with its **distance** and compares pace or speed. Strength, studio, ball and winter sports open with their **duration**, then calories, intensity and heart rate; the few hundred metres walked between the machines stand last and are neither judged nor a personal best. Calm kinds such as yoga show duration and heart rate.
- **Intensity:** The average heart rate of a workout against the highest for your age (220 less the age, from the date of birth in the profile), as a word from **Easy** to **All out** and a percentage. A rule of thumb by the app, not a measurement.
- **A Page per Workout:** Every number against the workout before and the average of the last ones, a chart of the last twelve of its kind, and marks for personal bests.
- **The Route:** Where a workout has one, its line tinted from slow to fast, the time of each kilometre as bars with the fastest marked (a speed for rides, stretches of five or ten kilometres for long ways), and the altitude as a profile with the metres climbed and descended. Rows and the latest workout show the line small. Three switches in the profile take the kilometres, the climb and the small lines away.
- **Allowing Routes:** Health Connect hands out the routes other apps recorded only with your consent. While it holds them back, a workout's page and the profile show a button that opens Health Connect's own dialog; choose **Allow all routes** there. The line is kept as at most 200 points in the app's own directory; no map is loaded.
- **Kinds of Workout:** Each kind Health Connect tells apart has its own name and icon. The fine values count endurance and ball sports by heart rate, walking and hiking by steps, and calm or static kinds such as strength, yoga or golf at a fixed rate; a minute without a heart rate counts at the rate of its kind.
- **All Activities:** Month by month, with a filter for the kind.
- **Steps by Week and Month:** The average per day stands large above the chart.
- **Removing a Workout:** The **bin** on a workout's page takes it out of Pulse together with the steps, distance and calories counted while it ran, with an **undo**. Later, the button at the top of the list of all activities shows the removed ones and brings one back. A workout deleted in the app that recorded it disappears on its own.

![Activity with a run as the latest workout, the page about that run, the page about a strength session, and Activity with a yoga session](readmestuff/activities.png)

![All activities with their routes, a run's route tinted by speed, its kilometres and elevation, and a new meal starting at the foods logged before](readmestuff/routes_foods.png)

### Sleep

- **The Night Played Back:** The latest night runs in twelve seconds. The sky follows the stages, and the figure snores in deep sleep, dreams in REM and sits up when you were awake. The blanket rises with each breath, the moon has a light around it, and now and then a star falls.
- **Tonight:** A bedtime counted back from your usual time of getting up, a little earlier while the week is in debt.
- **A Page per Night:** The score in its four parts, the stages as blocks and against a guide range, bedtime and waking of the last 30 nights, and the sleep debt of seven.
- **Observations:** How your nights after a workout, or after a day above the step goal, differ from the others, by the rule of [What Goes Together](#what-goes-together).

![The bedtime for tonight and the stages, the page about one night, the night in numbers, and the stages against their guide ranges](readmestuff/sleep.png)

### Heart

- **A Heart That Beats at Your Rate:** A bright dot draws a monitor line behind the figure, one spike in the time of one beat at the last measured rate, and the line fades behind it. With every spike the heart swells and a ring leaves it.
- **Over the Day:** The day's heart rate as a curve from the first measurement to the last, true to time. Tap it and a bar stays at that measurement, with a pill that says the rate and the time; hold and drag, and the bar follows your finger. Each step is felt, fainter for a low rate and firmer for a high one.
- **The Day in Detail:** Tap the top of the page for the day's own page: lowest, average and highest with their times, the zones, the parts of the day, each number against the days before, hints from your own numbers, and the day hour by hour. A bar at the bottom leads to the other days that have a curve.
- **The Days Before and the Week:** Earlier days as cards to swipe and the week's averages as bars; each opens its day.
- **Vitals:** Resting heart rate, variability, blood pressure, oxygen saturation, respiratory rate and skin temperature, where your devices record them.
- **Time in Zones:** Rest, light, cardio and peak, each as its share of the measured time.

![The day's curve with its bar, vitals and time in zones, the page of the day, and its zones and parts](readmestuff/heart.png)

---

## Weekly Report and What Goes Together

### Weekly Report

From **Sunday at 19:00** until Monday ends, a tile on **Today** says that the week is ready, and an alarm of the app sends a **notification** around that time. The report stays reachable all week from the page of connections, and a bar at its foot pages back through earlier weeks.

- **Week Score:** The mean of the day scores from Monday to Sunday, above a scene of seven hills, one per day and as high as its score. The best day carries a flag.
- **Against the Weeks Before:** Steps, active calories, sleep, sleep score, recovery and resting heart rate, each against the week before and the mean of the four before.
- **The Best of the Week:** The best day, the best night, and every day that was the highest ever for steps, active calories or distance.
- **Goals:** A dot per day for each goal, and its streak.
- **Activities and Sleep:** The workouts of the week with their sum, the sleep debt, and the mean bedtime and time of getting up with their spread.

### What Goes Together

Pulse sets your days, nights and weeks against each other and shows what differs: one sentence, and two bars for the two sides with the number of days behind each. The strongest connection stands on a tile on **Today**, the strongest three in the weekly report.

| Kind | Split By | What Is Compared | Looks Back |
| :--- | :--- | :--- | :--- |
| **A day and the night after** | Workout, steps, active calories, active minutes, water, calories eaten | Sleep duration, sleep score, deep sleep, bedtime | 90 days |
| **A night and the day after** | Sleep duration, bedtime, sleep score | Recovery, resting heart rate, heart rate variability, steps | 90 days |
| **Days of the week** | Each day against the other six | Steps, sleep duration, bedtime | 90 days |
| **Over weeks** | Weeks with more steps or more workouts | Resting heart rate, heart rate variability, weight | 52 weeks |

A day is put on a side at your **goal** where there is one and both sides then hold enough days, otherwise at your own **median**. A connection is shown only when all of this holds:

- **Enough on Both Sides:** At least **10** days or nights, or **8** weeks.
- **A Clear Difference:** At least half a standard deviation, and at least an amount worth saying: 10 minutes, 3 points, 2 bpm, 3 ms, 500 steps or 0.5 kg.
- **More Than Chance:** A Welch's t of at least **2.8**. About sixty comparisons are made, and at the usual 2 a few would pass by chance.

So the page can be empty, and it says how many nights are still missing. What goes together need not be the cause.

![The tile on Today, the weekly report with its score and comparison, and the connections with their two sides](readmestuff/week.png)

---

## Goals and Body Age

Twelve goals in four groups, each switched on and off on its own and each with its own target.

| Group | Goals | Counted Over |
| :--- | :--- | :--- |
| **Movement** | Steps, active calories, active minutes, distance, floors | A day |
| **Sleep and water** | Sleep duration, sleep score, water | A day |
| **Training** | Workouts, training time | A week from Monday |
| **Nutrition** | Calories eaten (a limit to stay under), protein | A day |

The goals page shows **today** as wavy lines, the **week** and the **month** as marks per day, and the **year** as twelve bars. A streak of two or more days or weeks is named on the goal's card.

The **body age** needs your date of birth. Its page lists every factor with your value, the value it is judged against and the years it adds or takes: steps, intensity minutes, strength training, sleep duration and rhythm, resting heart rate, heart rate variability, blood pressure, and body fat or body mass index.

![The goals of today, a week of goals, the body age, and the factors that go into it](readmestuff/goals_age.png)

---

## Look and Feel

- **Material 3 Expressive:** Few containers, heavy free-standing type, shapes that mean something, and motion on springs. Numbers count up, rings and bars fill, tiles come in one after the other.
- **One Accent per Page:** Each of the four pages has its own tone, and its sub pages keep it.
- **Navigation You Can Drag:** Drag the selected pill of the floating bar to another page. The period tabs work the same way.
- **Predictive Back:** A page shrinks under your finger and shows what is beneath before you let go.
- **Light, Dark or System:** Every colour style has both.

![The four main pages in the dark theme](readmestuff/dark.png)

The colours are chosen from a row of dots in the profile:

| Style | Effect |
| :--- | :--- |
| **Wallpaper** | The palette Android derives from your wallpaper (Material You). The default where the system has one |
| **Blue**, **Violet**, **Green**, **Orange**, **Pink** | One family of colours around the chosen one; only Heart stays red. **Blue** is the default without a wallpaper palette |
| **Colourful pages** | Every page in its own colour, ground and bar included: Today blue, Activity green, Sleep violet, Heart red |
| **Mixed colours** | The same four colours on every page, one per kind of element |

![Today in green and in pink, Activity in mixed colours, and the row of styles in the profile](readmestuff/colours.png)

Three switches in the profile change the look further, all **off by default**:

| Switch | Effect |
| :--- | :--- |
| **Liquid Glass** | The navigation bar, the period tabs, the add button with its menu and the floating buttons become clear glass that bends the page beneath; tiles become translucent |
| **Edge-to-edge scene** | The scene of each main page runs from the top of the screen behind the title |
| **Flex font** | Large numbers and titles use the width and weight axes of **Google Sans Flex** |

![The four main pages with Liquid Glass switched on](readmestuff/glass.png)

---

## Your Data

- **Entries:** **Water**, **weight** and **meals** from the **+** button, written to Health Connect. The water tile adds a glass of **250 ml** with one tap. Your own entries can be edited and deleted.
- **Foods:** A new meal starts at the five foods eaten most often in the last 90 days; a tap fills the form with the name and values of the last time. **More** opens every food ever logged, including those other apps wrote, to search, sort (latest, most often, A–Z, calories) and filter (time of day, high in protein, calories, only from Pulse). A swipe takes a food out of the lists until it is eaten again.
- **Tiles:** In edit mode every tile has a **minus**; a list below offers what you removed and every measurement with data. Hold a tile to drag it. A measurement tile is **small** or **large**.
- **History:** One value per day and metric for up to **ten years**. Data already in Health Connect is loaded once on first start.
- **Background Refresh:** About once an hour, so no day is lost when the app stays closed.
- **Backup:** **Profile → Backup** writes history, nights, workouts and settings into one JSON file at a place you choose, and reads such a file again without overwriting what is already there.
- **Languages:** Numbers, dates and plurals follow the language (**7.432** / **7,432** / **7 432**). On **Android 13** and newer the choice is Android's own per-app language.

---

## Getting Started

### Download

Signed APKs are on the [**Releases**](https://github.com/tomsliikee/pulse/releases) page. Pulse is in **beta**: download the latest `pulse-v….apk`, open it on the phone and allow your browser or file manager to install apps once. You need **Android 8.0** or newer and **Health Connect**.

An APK you built yourself is signed with another key, so Android will not update it with a release. Save a backup in **Profile → Backup**, uninstall, install the release and read the backup again.

### Build from Source

You need the **Flutter SDK** 3.47 or newer, the **Android SDK** with platform tools, and a phone with **Health Connect** (built into **Android 14** and newer, an app from the Play Store before that).

**1. Clone and fetch dependencies:**
```bash
git clone https://github.com/tomsliikee/pulse.git
cd pulse
flutter pub get
```

**2. Run on a connected phone:**
```bash
flutter run -d android
```

**3. Or build and install an APK:**
```bash
flutter build apk --release
adb install -r build/app/outputs/flutter-apk/app-release.apk
```

Without `android/key.properties` the release build is signed with the debug key; [`docs/releasing.md`](docs/releasing.md) describes the release key and how a release is made.

On first start the app asks for access to Health Connect, then once for older data. Both dialogs belong to the system, and the app works with whatever you allow.

**Run the checks:**
```bash
flutter analyze
flutter test
```

### Permissions

| Permission | Why |
| :--- | :--- |
| **26 `READ_*`** health permissions | One per data type the app shows |
| **`WRITE_HYDRATION`**, **`WRITE_WEIGHT`**, **`WRITE_NUTRITION`** | The three kinds of entries you can add |
| **`READ_EXERCISE_ROUTES`** | The routes of workouts other apps recorded. Asked for through Health Connect's own dialog; if declined, workouts have no line |
| **`READ_HEALTH_DATA_HISTORY`** | Loading data older than 30 days once. If declined, history grows from today |
| **`READ_HEALTH_DATA_IN_BACKGROUND`** | The hourly refresh. If declined, data is refreshed when the app is opened |
| **`POST_NOTIFICATIONS`** | The notification that says good morning. Asked for after the cards first opened by themselves; if declined, they still open in the app |
| **`RECEIVE_BOOT_COMPLETED`** | Sets the alarm for that notification again after the phone restarted |
| **`INTERNET`** | The weather and the search for a place, both from **Open-Meteo**. Not used until a place is set |

---

## How It Works

One file in the code base talks to the **`health`** plugin. Everything above it works on plain Dart values and is covered by **953** unit and widget tests that need no device.

```mermaid
flowchart TD
    subgraph UI ["Interface Layer"]
        Shell["App Shell<br/><b>Floating Navigation Bar & Add Menu</b>"]
        Boards["Tile Boards<br/><b>Today, Activity, Sleep, Heart</b>"]
        Detail["Sub Pages<br/><b>Day, Night, Workout, Metric, Goals, Body Age</b>"]
        Scenes["Scenes<br/><b>Day, Workout, Night, Heart</b>"]
    end

    subgraph State ["State Layer"]
        HealthCtrl["HealthController<br/><b>Access, Refresh, Backfill, Entries</b>"]
        SettingsCtrl["SettingsController<br/><b>Goals, Theme, Tiles, Look</b>"]
    end

    subgraph Data ["Data Layer (pure Dart)"]
        Builder["buildSnapshot<br/><b>Raw Readings to 30 Days</b>"]
        Insights["Insights<br/><b>Scores, Goals, Body Age, Hints</b>"]
        History["HistoryArchive<br/><b>One Value per Day, 10 Years</b>"]
        Archives["Night & Workout Archives<br/><b>Every Night, Every Workout</b>"]
        Store["FileJsonStore<br/><b>Private App Directory</b>"]
    end

    subgraph Device ["Android"]
        Repo["HealthConnectRepository<br/><b>the only user of the health plugin</b>"]
        HC["Health Connect<br/><b>Phone, Watch, Other Apps</b>"]
        Worker["WorkManager Task<br/><b>Hourly Background Refresh</b>"]
    end

    Shell --> Boards
    Boards --> Detail
    Boards --> Scenes
    Boards --> HealthCtrl
    Boards --> SettingsCtrl
    Detail --> Insights
    HealthCtrl --> Repo
    HealthCtrl --> History
    HealthCtrl --> Archives
    Repo --> Builder
    Repo --> HC
    Worker --> Repo
    Worker --> History
    Worker --> Archives
    Insights --> Archives
    Insights --> History
    History --> Store
    Archives --> Store
    SettingsCtrl --> Store
```

### Measurements

**32** metrics in five groups. A day's value is the **sum** of the day, the **average** of its readings, or the **last** reading.

| Group | Metrics | Day Rule |
| :--- | :--- | :--- |
| **Activity** | Steps, distance, floors, active calories, total calories, intensity minutes | **Sum** |
| **Activity** | Speed | **Average** |
| **Vitals** | Heart rate, heart rate variability, oxygen saturation, respiratory rate, blood glucose, body temperature, skin temperature | **Average** |
| **Vitals** | Resting heart rate, blood pressure | **Last** |
| **Body** | Weight, height, body mass index, body fat, lean mass, body water, basal metabolic rate | **Last** |
| **Sleep** | Sleep duration, with stages where the source records them | **Sum** |
| **Nutrition** | Water, calories eaten, carbohydrates, protein, fat, fibre, sugar | **Sum** |

**Workouts** are read as sessions with type and duration; their steps, distance and calories are Health Connect's own totals of that time. **Intensity minutes** are estimated from the heart rate when no source writes them: a minute in the moderate range counts once, a vigorous one twice.

#### Coarse and Fine Values

The profile has a switch **Coarse | Fine** for the three numbers that sources tend to count generously: active calories, total calories and intensity minutes. **Coarse**, the default, shows them as described above. **Fine** shows what Pulse works out itself, meant to be realistic as the day's real burn:

| Number | How the fine value is counted |
|---|---|
| **Active calories** | Workouts and steps, each **less what that time would have cost at rest** |
| **Running, cycling, swimming** | From the heart rate, minute by minute (Keytel et al., 2005, from heart rate, weight, age and sex) |
| **Strength, yoga, unnamed workouts** | A fixed rate per minute and kilogram from the Compendium of Physical Activities (3.5, 2.5 and 3.5 MET), because there the heart rate rises further than the energy spent |
| **Walking, hiking and the rest of the day** | From the **steps**: 0.5 kcal per kilogram and kilometre at a step of 0.414 times your height. At a walking pace the heart rate says far more than the legs spend. Each minute of a workout counted by heart rate or rate takes 100 steps out of its hour, so nothing is counted twice |
| **Total calories** | Your own base (Mifflin-St Jeor, from weight, height, age and sex) for the day so far, plus the fine active calories. A source's total is not built on: where two apps write it, it holds the base twice |
| **Intensity minutes** | Minutes at a moderate heart rate in a workout, or in a stretch of at least **10 minutes in a row** outside one, once; at a vigorous one twice. A single minute below does not end a stretch. Moderate begins at 40 %, vigorous at 60 % of the heart rate reserve; the maximum is **208 − 0.7 × age** |

Readings up to five minutes apart are joined by the heart rate on the way from one to the other, because a watch does not write every minute. A workout you removed from Pulse counts for nothing here either. The calories need a **date of birth**, the **sex** and a **weight**; the profile says what is missing.

In the fine mode the page of **active calories** lists what the day is made of (workouts, everyday steps), and the calories on Today carry the word **Fine**.

Both sets are stored side by side, so the switch takes effect at once. Fine values exist for the days read since they were introduced: the single heart beats are read for the last **8 days** only, so those are filled on the first start, and older days show no value in the fine mode rather than the coarse one.

#### What You Really Burn

No estimate from a wrist is exact. The page of **total calories** therefore works the burn out backwards, from the one thing that is measured: over the last **28 days**, the calories you ate less what your weight did (a line through the weigh-ins, at 7,700 kcal per kilogram). Beside it stand the source's total and the fine total with their distance from it. It needs calories eaten on at least 24 of the 28 days and at least 6 weigh-ins, one in the first and one in the last week; until then the page says what is missing. It assumes the weight changes through fat and not through water, and it changes none of the other numbers.

![Today with fine values, what a day's active calories are made of, the real burn from food and weight, and the switch in the profile](readmestuff/fine.png)

Every metric has the tabs **Today**, **Yesterday**, **Week**, **Month**, **Year** and **All**. An average counts only days with data; a day without a measurement is not a zero.

### The Scores

All three are the app's own estimates, since Health Connect stores none. A part that cannot be judged is left out and the rest scaled to a hundred.

| Score | Parts and Weights | Judged Against |
| :--- | :--- | :--- |
| **Recovery** | Heart rate variability **50**, resting heart rate **20**, sleep **20**, respiratory rate **10** | Your own average of the 30 days before, and the sleep goal |
| **Day score** | Movement **40**, sleep **35**, resting heart rate **15**, water **10** | Your goals, last night's sleep score and your usual resting heart rate |
| **Sleep score** | Time asleep **40**, deep and REM **25**, efficiency **20**, bedtime **15** | The sleep goal, typical stage shares and your bedtime of the week before |

Two smaller rules belong to the morning. A reading of the night **stands out** when it lies more than **1.5 standard deviations** from your average of the 30 days before. The **effort** of the day is easy on a red recovery, or on a yellow one after two days of training in a row; demanding on a green one unless you trained on each of the last three days; and normal otherwise.

### Data Storage & Disk Paths

Everything is kept in the app's private directory, **`/data/data/at.haiden.pulse/files/`**. Uninstalling the app deletes it, which is what the backup file is for.

| File | Purpose |
| :--- | :--- |
| **`snapshot.json`** | The last 30 days in full: daily values, sleep stages, heart samples, workouts, entries |
| **`history-YYYY.json`** | One value per day and metric for that calendar year, for ten years |
| **`nights-YYYY.json`** | Every night that ended in that year: its times and the minutes in each stage |
| **`workouts.json`** | Every workout the app has seen, and the ones removed by hand |
| **`routes-YYYY.json`** | The route of each workout of that year that has one, as at most 200 points, with the time of each kilometre and the climb |
| **`foods.json`** | Every named meal the app has seen, as the foods they were: the values of the last time and when each was eaten |
| **`settings.json`** | Goals, profile, theme, look switches, tile order and sizes |
| **`sync.json`** | When the last background refresh ran and how long it took |
| **`weather.json`** | The last forecast of today, so the service is asked at most once an hour |
| **`morning.json`** | The day the morning's notification was last sent |

---

## Platform Support Matrix

| Platform | Runner | Status |
| :--- | :--- | :--- |
| **Android 8.0+** (API 26) | **`android/`** | ***Tested*** on a **Pixel 10 Pro** with real Health Connect data and on an **Android 17** emulator |
| **Linux** | **GTK3** (`linux/`) | ***Built.*** For development only; it has no health data source and shows a notice |
| **iOS, macOS, Windows, Web** | none | Not supported. Health Connect exists only on Android |

---

## Good to Know

- **Not Medical Advice:** The scores, the body age and the hints are estimates from fixed rules. The weights are constants of this app and are not validated.
- **Other Apps' Records:** Pulse can edit and delete only its own entries; Health Connect does not let an app change another app's records.
- **Heart Rate Samples:** Single samples are kept for the last **8 days**; older days keep their resting heart rate and daily values.
- **Not Read:** Elevation gained, power, **VO2 max**, bone mass and mindfulness sessions, because the **`health`** plugin cannot read them on Android. Cycle tracking and medical records are deliberately not requested.
- **Weather:** Forecast and place search come from [Open-Meteo](https://open-meteo.com). A request carries the coordinates of the place you picked and nothing else; the place is one you type, not your location.
- **Orientation:** Portrait only.

---

## Dependencies

| Package | Used For |
| :--- | :--- |
| **`material_ui`** | The Material widget library |
| **`m3e_core`** | Material 3 Expressive components: floating toolbar, FAB menu, shapes, wavy progress |
| **`motor`** | Spring motion |
| **`health`** | Health Connect |
| **`workmanager`** | Background refresh |
| **`dynamic_color`** | The system colour palette |
| **`liquid_glass_renderer`** | The refracting glass of the Liquid Glass switch |
| **`path_provider`** | The private directory |
| **`flutter_localizations`**, **`intl`** | Translations from **`lib/l10n/app_*.arb`**, numbers and dates per language |

The bundled typeface is **Google Sans Flex**, under the **SIL Open Font License** (see [`assets/fonts/OFL.txt`](assets/fonts/OFL.txt)).

---

## License

Released under the **MIT License**, see [`LICENSE`](LICENSE).
