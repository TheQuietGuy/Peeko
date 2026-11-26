# Changelog

Every release of Dynamic Ledge (called Dynamic Notch until 1.4.0), newest first. The format follows
[Keep a Changelog](https://keepachangelog.com/en/1.1.0/) and versions follow
[Semantic Versioning](https://semver.org/): new features bump the middle number, fixes bump the
last one.

## [2.6.0] - 2026-11-26

**Perch is now Peeko.** Another Mac notch app is already called Perch, so this one has a name
of its own: Pip still peeks out beside the camera. Settings, permissions and saved files carry
over (the app's identity underneath is unchanged).

### Added
- **Dot Matrix theme.** Inspired by LED displays: pure black with a faint grid of unlit
  dots once the notch opens, the music bars as columns of lit dots, big numbers (timers,
  temperature, days left) drawn in dots, open views scanning in from the left, and precise
  motion with only a hint of settle. At rest it's still just the notch.
- Between lyric lines (and before the first), the lyrics strip shows the song and artist.
- Home widgets can be reordered by dragging in Settings › Home Page.
- **Weather works like a weather app.** Click a day in the week to see its hours (every three
  hours) and its rain chance, UV and sunrise and sunset; today shows how it feels now, with
  humidity, wind and the UV index. The rain alert moved under the temperature, where it fits.

### Performance
- A long lyric line now glides once to show its end, instead of crawling for the whole line,
  which kept SwiftUI redrawing the notch every frame. While music played with lyrics the main
  thread went from about half busy to about a fifth.

### Changed
- **Brutal, reworked.** Graphic rather than loud: black and white like a printed poster, with a
  crisp white outline, a solid offset plate instead of the coral shadow, and black keys with
  white edges whose labels carry the action's colour. The song's colour still fills the plate.
- **Several tabs or apps playing.** When two play at once, macOS reports whichever spoke last,
  so the notch used to flip between them. A different source now waits a moment before taking
  over; if the one showing keeps playing, the other goes in the switcher (a second tab of the
  same browser is named by what it plays) instead of the view jumping.
- Keep Awake turns itself off when the battery runs low on its own power.
- On a screen without a notch, Perch now floats as a pill by default, instead of drawing a
  notch that isn't there.
- Updates are checked against Perch's own GitHub releases (TheQuietGuy/Perch), never the
  original app's, and open the release to download.

### Removed
- The anonymous daily usage signal, which had nowhere to go in Perch.

## [2.5.1] - 2026-11-25

### Fixed
- **Long lyric lines were cut off.** The lyrics strip is a little wider, and a line that still
  doesn't fit slides left while it's sung, finishing about a second before the next line, with
  soft edges instead of "…".
- **A pause when opening the notch.** Perch looked for a camera every time Home opened, which
  walks every capture device on the main thread. It now looks once, when Mirror first opens.
- The AI usage refresh timer can now be coalesced with others by macOS.

## [2.5.0] - 2026-11-23

### Added
- **Colour Picker** (⌃⌥X). Pick a colour from anything on screen with the system magnifier;
  its hex is copied straight away. Recent colours stay in a row, and each copies as HEX, RGB,
  HSL or SwiftUI code. No permission needed.
- **Countdowns** (⌃⌥Y). Days left to exams, deadlines and trips, soonest first, as cards that
  turn orange in the last three days.
- **Lyrics in the notch.** When a song has timed lyrics, the line being sung hangs under the
  compact music view, in time with the song. Turn it off with Lyrics in Settings.
- **The song colours the notch.** While music plays, Black glows in the album's colour, Glass
  is tinted by it (Liquid Glass on macOS 26) with its lit edge in that colour, and Brutal's
  hard shadow takes it on.

### Changed
- **Six music bars that follow the real sound, on by default.** The bars measure what your Mac
  is playing in six bands, sub-bass (kick) to air (hi-hats), with a finer analysis window that
  tells the kick from the bass line. They also adjust to each song's
  loudness, so a loud track pumps with the beat instead of sitting at the top. macOS asks once
  for System Audio Recording; if you refuse, the bars go back to their own motion.

### Animation and efficiency
- Springs retuned to about 0.2 bounce on open (lively, never wobbly), no bounce on close, and
  a small pulse on hover. Open content now follows the shape a beat later with a soft blur.
- The grid's tiles pop in one after another when it opens.
- Lyrics redraw only at the moment each line starts, instead of five times a second.
- Pip checks in every 3 seconds while asleep instead of twice a second.
- Shadows are drawn once per shape group, and Glass's song glow comes from a hairline edge so
  the glass itself carries no shadow.
- Stats reads the battery every 20 seconds instead of every 2.

### Removed
- Unused code: an unfinished per-app EQ engine and a handful of properties nothing called.

### Fixed
- **Dragging a window into Files after allowing permission.** Two causes: every local build was
  ad-hoc signed, so macOS treated each rebuild as a new app and quietly dropped the
  Accessibility and Automation permission you'd given (Settings still showed it on); and the
  first "Allow Perch to control…" prompt was cut off by the script's 5-second deadline. Builds
  are now signed with one local certificate (`Perch Local Signing`), and Perch asks macOS for
  Automation permission first and waits for your answer, with a clear message if it's off.

## [2.4.0]

### Added
- **A Pip menu bar icon**: a tiny notch with Pip's eyes, tinted for light and dark menu bars,
  instead of the generic eyes symbol.
- **More in the menu bar menu**: the weather at a glance (click for the full view), Stats,
  and Show Pip.
- **Pip says welcome back**: it smiles when you return after being away, and in the morning.
- **Keep Awake keeps Pip awake too**: no dozing off while your Mac is kept awake.

### Added
- **Weather can use your location.** "Use My Location" in the Weather view (or Settings ›
  Home & Widgets › Weather). macOS asks once; the location is only used to fetch the forecast,
  and a reading is reused for an hour. A filled arrow beside the place name means Weather is
  following you; click the name to switch to a city.

## [2.3.0]

### Added
- **Customise Home.** Settings › Home & Widgets › Home Page: switch widgets on or off and
  reorder them (Now Playing & Live, Today, Weather, Timer, Shortcuts, AI Agent Usage). Home
  shows the first three that have something to show; Timer and Shortcuts share a column
  before anything is left out.
- **Weather, its own view.** In the grid and on ⌃⌥H: now, feels-like, humidity, wind and
  sunset, the next hours with the chance of rain, a rain warning, and the week with each day's
  range, laid out like Apple's Weather. The first time, it asks for your city right in the
  notch. A Weather widget for Home shows now and the next four hours.

### Changed
- **The black Dynamic Island look is the default**, as Mac users expect. Brutal and Glass are
  in Settings › Appearance.
- The grid is seven across, so all thirteen features still fit on one page.

## [2.2.0]

### Changed
- **One navigation bar everywhere.** Home, your shortcuts and whatever's open sit in the same
  bar on every view; the current one is highlighted and named ("Home", "Files", "Stats"), and
  a view opened from the grid joins the bar while open, with its name on the right. The
  separate back-button header for panels is gone, so anything is one click away.
- **The grid fits on one page.** Six across, every feature visible; no hidden second page.
- **Home's Today card.** The calendar card now always shows today's date and the weather,
  then your next event, so Home is useful before the calendar is connected.
- **Brutal buttons on Home.** Quick actions (timer presets, Connect) are flat colour blocks
  that press onto a coral shadow. The Brutal chip shadow is coral too: black vanished on the
  black notch.
- **Hide in full screen is on by default.**

### Added
- **Escape closes the notch** while the pointer is on it (not in Notes or Clipboard search,
  where Escape belongs to the text field). It never takes Escape from other apps otherwise.
- **Alerts wait while you read them.** An alert doesn't disappear while the pointer is over it.
- **VoiceOver hears alerts** as they appear.
- **Pip's ears answer the pointer**, so hovering or clicking them opens the notch like the notch.

## [2.1.0]

### Added
- **Stats opens like Files.** It's a shortcut beside Home from the start (four shortcuts now
  fit), and opens its own tab instead of only switching the notch readout. The switch for
  memory and CPU beside the camera is at the top of the tab.
- **Much more in Stats**, in two rows: CPU with user/system split, a two-minute history and a
  bar per core; memory with an app/wired/compressed bar and swap; GPU use with history; network
  speed with history and your local IP; battery level, time left, health, cycle count, power
  draw, temperature and charger wattage; free disk; load average; the busiest apps; uptime and
  how warm the Mac is. Everything is read on this Mac, only while the tab is open.
- **Clipboard size.** Keep the last 20, 50 or 100 copies (Settings › Home & Widgets).

### Changed
- Pip's eyes are a little bigger, and they only move when the pointer really does, so a
  still Mac isn't woken twice a second.

## [2.0.0] - Perch

### Added
- **Pip.** The resting notch grows two small ears with eyes in them. Pip blinks, follows the
  pointer, widens its eyes on hover, smiles after something finishes, and sleeps at night or
  when you're away. Settings › Appearance › Pip on the notch.
- **New name and icon.** The app is now Perch, with its own bundle ID, so it runs beside
  Dynamic Ledge without sharing settings or sockets.

### Changed
- Brutal is the default theme.

### Added (fork, earlier)
- **Brutal theme.** Settings › Appearance: a neo-brutalist look. Once the notch opens it gets a
  thick lemon edge and a hard coral shadow, quick-action buttons press down onto their shadow
  like real keys, and it snaps open without wobbling. At rest it's still just the notch.
- **Hide when an app is full screen.** Settings › General › Privacy & Focus.
- **Hide from screenshots and screen sharing.** Settings › General › Privacy & Focus.
- **Headphone battery.** Settings › Activities & Alerts › Headphones: AirPods and other Bluetooth
  headphones connecting, with their battery level.
- **Weather.** Settings › Home & Widgets › Weather: the temperature and conditions for a city you
  type, at the top of Home, from Open-Meteo.

### Changed (fork)
- Update checks are off by default and anonymous usage counting is disabled, so this fork never
  replaces itself with the original app or counts towards its numbers.

## [1.5.0] - 2026-11-09

### Added
- **Stats and AI usage in Home.** While they're on, they join Home's live section with calls and
  music. Two share the section, half each, and clicking one opens it.
- **Switch between live activities.** With more than one going on, an opened activity shows the
  others as small circles beside the camera. Click one to go to it.
- **Close when answered in Claude Code.** A switch in Settings › General › Coding Assistants
  for the check that closes a request in the notch once it's answered in Claude Code's own
  window. It's on unless you switch it off; off, nothing is read from Claude Code's sessions.
- **Home from an approval.** The back button on a coding assistant's request opens Home and
  leaves the request waiting. It comes back when the notch closes, or goes away if you answer it
  in the assistant.
- **Pill for other screens.** Pick **Pill** in Settings › Appearance and external displays (and
  Macs without a notch) show a floating pill just below the top edge, like the Dynamic Island,
  instead of a notch. A MacBook's own notch always stays a notch.
- **AI Agent Usage.** See how much of Codex's and Antigravity's limits you've used and when they
  reset, in Home or its own panel. It's off until you turn it on in Settings ›
  General › Coding Assistants. While it's on, the lowest limit left shows beside the camera when
  nothing else is playing or running; click it for the details. Its launcher tile turns it off
  and on again, like Stats, and off it stops checking. Codex checks your limits with OpenAI using
  its own sign-in; Antigravity's are read on this Mac. Dynamic Ledge sends nothing itself and
  needs no API keys.
- **Choose where sound plays.** A button in the open music view switches between your Mac's
  speakers, AirPods and other headphones, and displays with speakers.
- **Convert images in the Tray.** Right-click an image and pick **Convert to** for a PNG, JPEG,
  HEIC, TIFF or GIF copy, saved next to the original and added to the Tray. The original isn't
  touched.
- **Zip and Merge PDF in the Tray.** Buttons beside the Tray put everything in it into one .zip,
  or its PDFs and images into one PDF, saved next to the first file and added to the Tray.
  Right-click a file to compress just that one.
- **"Done" alert for coding assistants.** When Claude Code, Codex or Cursor finishes, the notch
  says so, with the project's name. Turn it off in Settings › General › Coding Assistants, which
  also takes its hook back out of the tool's settings.
- **Install updates automatically.** An optional switch in Software Update installs a verified
  new version when the daily check finds one, then relaunches. Off by default. It waits while a
  timer or stopwatch runs, a call is on, or a coding assistant is waiting for your answer.
- **Text from images.** Copy a screenshot or picture and its text shows up in Clipboard, ready to
  paste. The text is read on your Mac and the image isn't kept. Turn it on in Settings › Home &
  Widgets › Text from images; it's off until you do.
- **Live music bars.** The bars beside the camera move with what's actually playing. Turn on Live
  music bars in Settings › General › Now Playing; macOS asks once to let Dynamic Ledge hear your
  Mac's sound. It's only measured to move the bars, never recorded or sent. Needs macOS 14.2.
- **Choose how the notch moves.** Settings › Appearance › Motion: Springy for more bounce,
  Calm for no bounce at all, or Standard as before.
- **Update count.** The anonymous daily count also says once when a Mac moves to a new version,
  and which version it came from, so I can see how many people update. It now also includes the
  kind of Mac (its model code, like "Mac14,2"), whether an update was installed automatically or
  clicked, which step failed if an update didn't install, and, once, if the app didn't quit
  properly last time. No crash logs or anything else is sent.

### Fixed
- An approval answered in Claude Code's own window now leaves the notch straight away, instead
  of staying there until it timed out. Claude's questions and plans, which have their own choices,
  stay in Claude Code instead of showing Allow and Deny in the notch.
- With nothing going on, the notch stays exactly the size of your Mac's notch at every size, even
  with Show when idle on or Settings › Appearance open. It no longer pokes out at the sides.
- Approvals from the notch keep working right after an update, without restarting Dynamic Ledge.
- Zip, Merge PDF and Convert to work for files in places that can't be written, like a mounted disk image: the result goes to Downloads.
- Clicking Zip or Merge PDF twice no longer makes two copies.
- Converted images are named like Finder copies ("Photo 2.jpg").
- AI Agent Usage stops checking when Dynamic Ledge stops its services.

### Changed
- **Moves like the Dynamic Island.** Opening springs out quickly with a small overshoot and the
  content grows and bounces with it; closing settles back without a bounce. Content swaps
  faster with a lighter blur, hovering lifts the notch and what's in it by 5 %, and open views
  have rounder, smoother corners. Glass now moves the same way and no longer stutters as it
  starts to open, closing draws the content back into the notch instead of blinking it out,
  and Springy bounces without wobbling.
- **Two activities at once.** The second one's bubble is as tall as the notch and hangs from
  the top edge with the same rounded corners (a circle beside the floating pill), and it slides
  out of the notch's side like the Dynamic Island's instead of popping out of its middle.
  Hovering it now opens that activity; before, it opened the first one.
- **Slimmer music.** While music plays, the artwork and bars sit closer to the camera, and the
  open player has the Dynamic Island's proportions.
- Coding-assistant requests show Allow and Deny as white and grey buttons stacked on the right,
  with the request beside them.
- AI Agent Usage covers Codex and Antigravity. Claude Code keeps its limits only on Anthropic's
  servers, which would mean using your Claude sign-in, so it isn't listed.
- **Settings looks like System Settings.** A sidebar with search, back and forward buttons, the
  page title in the toolbar, and coloured icons inside each page. Now Playing, Coding Assistants,
  About and Software Update open from General. The pictures in Appearance now show the real
  notch shape, and the Glass one shows its smoked, frosted look.
- Calendar has larger dates and a scrollable list of events. In the elongated Home, swipe the
  date strip to move through the month.
- The elongated Home fits your display's size and scaling, keeping controls readable.
- No scroll bars in the notch, even with a mouse connected. They covered the widgets and
  squeezed the timer's wheels. The elongated Home settles on a widget as you scroll and fades
  out at its edges instead of cutting widgets off.
- The elongated calendar and timer move like Apple's pickers: the day or number in the middle is
  largest and brightest, and the ones either side shrink and fade smoothly as you scroll. Scroll
  the days to choose one, or click a day to glide it to the middle.
- The installer disk is named after its version ("Dynamic Ledge 1.5.0 Installer"), so it isn't
  mistaken for the app in Finder's sidebar and two open disks don't end up with the same name.
- Opening the installer shows an arrow from Dynamic Ledge to Applications, with a line saying to
  drag it across.
- A shorter README, with step-by-step install, update and uninstall guides and a clear privacy
  and permissions section.

## [1.4.3] - 2026-11-02

### Fixed
- Dragging a file from the Tray into Finder keeps its name, and dropping it into apps like
  WhatsApp or Mail works.
- Right-click a Tray item and choose **Copy** to paste the file into another app, as with Finder's
  Copy.

## [1.4.2] - 2026-10-31

### Added
- **Glass theme.** Pick **Glass** in Settings › Appearance for a smoked-glass notch: black around
  the camera, easing into frosted glass along the bottom edge, which catches the light. It moves
  with softer, springier motion, and a slider sets how dark the glass stays. Black stays the
  default.
- **Download progress.** While Safari, Chrome or another browser downloads into your Downloads
  folder, the notch shows how far along it is. Open it to see the file, how much is left and
  roughly how long, with buttons to show it in Finder or stop it. Part of the Finished downloads
  setting.
- **Approve coding assistants from the notch.** Claude Code, Codex, Copilot CLI, Antigravity and
  Cursor each have a switch in Settings › Activities. When one wants to run a command or change a
  file, the notch shows what it wants to do, with Allow and Deny. Close it, or leave it for two
  minutes, and the assistant asks in its own window as usual. Claude Code, Codex and Copilot CLI
  only ask the notch when they would ask you anyway; Antigravity and Cursor ask before every
  terminal command. Switching one on adds a hook to its settings file, and switching it off takes
  it out again. Codex asks you to review new hooks once (/hooks). Long commands and file changes
  make the notch a little taller, and you can scroll through and select the whole request. The
  hook only trusts answers from the same copy of Dynamic Ledge, so right after an update,
  approvals go to the assistant's own window until Dynamic Ledge restarts.
- **Scrolling titles.** Long song and video titles scroll in the open music view while they play,
  so you can read the whole name. They stay still when paused or with Reduce Motion on.
- **Anonymous usage count.** Once a day the app sends TelemetryDeck a random, hashed ID with the
  app and macOS versions, so I can see how many Macs use it. Nothing about you or what you do is
  sent.

### Changed
- **Signed with Dynamic Ledge's own certificate.** macOS now keeps Accessibility, Camera, Calendar
  and other permissions when the app updates. Because of the switch, this one update may ask you
  to allow them once more.
- **The update button.** A new version shows as an **Update** pill when you open the notch, then
  shrinks to a round download button beside the grid. Point at it to see the label again.
- Smoother opening and closing: the notch's shape is now drawn by the graphics card instead of
  being redrawn on the CPU for every frame.

### Removed
- The "Connected" alert for AirPods and other headphones. macOS already shows it at the top of
  the screen, so the notch was repeating it.

### Fixed
- The notch no longer freezes while macOS asks for access to your Downloads folder.
- Turning on an assistant keeps its settings file as a link when it is one (for example into a
  dotfiles folder), and keeps the file's permissions.

## [1.4.1] - 2026-10-30

### Added
- **A new Home.** Up to three sections side by side. Whatever's live comes first: a call or the
  microphone, and music, each with its own buttons (Hang Up, mute, play). When two are on, they
  share the section. Click one to open its full view again. A running timer or stopwatch sits at
  the top of the Timer section, above the quick-start buttons.
- **Lyrics.** Songs with timed lyrics show the line being sung, in the music view and on Home.
  Lyrics come from lrclib.net, which is sent only the song's name, artist, album and length.
  Songs without them look as before. Turn them off in Settings › Activities.
- **Search and pin in Clipboard.** Search your clips as you type, and press Return to copy the
  first match. Pin a clip to keep it at the front and after you quit (up to 20). Clearing the
  history leaves pinned clips.
- **Pinned files in the Tray.** Pin a file to keep it in the Tray after you quit. A pinned file
  that's renamed or moved is still found. Clearing the Tray leaves pinned files.
- **Choose which apps show music.** In Settings › Activities, pick **Only these apps** and tick
  the ones you want, like Spotify. Anything else playing, such as a video in your browser, stays
  out of the notch. Apps join the list once they play something, or add one yourself.

### Fixed
- Hang Up works with WhatsApp's Leave call button as well as End call, and the call view closes
  as soon as you hang up.
- WhatsApp holding on to the microphone after a call, or while you record a voice note, no longer
  shows as a call (once Dynamic Ledge has Accessibility access; without it, WhatsApp mic use still
  shows as a call, as before).

## [1.4.0] - 2026-10-27

**Dynamic Notch is now Dynamic Ledge.** Same app, new name. Updating from Dynamic Notch keeps all
your settings, and the app renames itself in your Applications folder the first time it opens.
With Homebrew, it's now `brew install --cask shandilyaswagat/tap/dynamic-ledge`; existing installs
move across on their own.

### Added
- **Your own shortcuts.** Beside Home at the top left of the open notch, keep up to three
  shortcuts to the features you use most. They start as Files and Clipboard. To change them, open
  the grid and hold any feature, then click features to add or remove them and click Done. The
  shortcuts themselves stay put: holding or dragging them does nothing. A shortcut for
  something you've switched off in Settings is hidden until you switch it back on, and the Files
  shortcut shows how many files are in the Tray.
- **Elongated layout.** Pick it in Settings › Appearance and Home stretches across the top of the
  screen, with everything in one long row you can scroll sideways:
  - Music with a handle you can drag to any point in the song.
  - Mirror: click the circle to see yourself right there.
  - Calendar: tap a day in the strip to see its events, and join Meet, Zoom, Teams or Webex calls
    with one click.
  - Notes you can format, right in the row.
  - A timer with hour, minute and second wheels, plus 1 and 5 minute buttons.
  - A to-do list: type a task, press Return, tick it off. It's kept on your Mac.
  Tray and Clipboard go wide too.
- **On the Lock Screen.** Turn on Show on Lock Screen in Settings › General and, while your Mac
  is locked, the notch keeps showing a running timer, your music or charging beside the camera,
  just as it looks when you're logged in. It's off until you turn it on, since anyone at your Mac
  can see it.
- **Update button.** When a new version is out, a blue Update button appears at the top right of
  the open notch, next to the grid and Settings. One click installs it and relaunches.
- **Hang up from the notch.** On a Zoom, Teams, Webex or WhatsApp call, the call view has a red
  button that ends the call (Zoom asks you to confirm). The first time, macOS asks to let Dynamic
  Ledge use Accessibility. Click the app's icon to jump to the call window instead.
- **Click any date in the Calendar.** In the Calendar's month, click a day to see its events;
  click today or the same day again to go back to what's coming up.
- **Turn the camera off in Mirror.** A button in Mirror turns the camera preview off and back on.
- **A first look.** The very first time you open Dynamic Ledge, Home opens for a few seconds so
  you can see it's running.

### Changed
- **Free software.** Dynamic Ledge is now licensed under the GNU General Public License, version 3
  or later: you can use, study, share and change it, and changed versions you share stay free too.
- **A new app icon:** a friendly little cloud on a soft purple tile.
- **A roomier Tray:** more space between files, and the remove button sits clear of the top edge.
- **Stats uses even less.** With the notch closed it reads just memory and CPU, and it stops
  reading while your display is asleep.

### Fixed
- With Open on Hover, hovering over Stats now opens Stats instead of Home.
- Home no longer spills past its edges when music is playing; the Focus button drops its label
  when there isn't room.
- macOS asks for Accessibility access at most once each time the app starts, not on every try.
- Voice Control and other assistive tools can open Home even while the notch is tucked away.
- Holding or dragging anything on the open notch no longer brings up the Tray drop view.
- An activity's name at the top left ("Microphone", for example) no longer runs under the camera;
  it shortens to "Mic", or just the back arrow, when there isn't room.
- In Clipboard, the delete button sits inside the card's footer instead of hanging off its corner.

## [1.3.5] - 2026-10-27

### Fixed
- Dynamic Notch no longer quits right after you allow Reminders access, and the notch reopens on
  your list once you do.
- Reminders notices access you turn on in System Settings, and shows tomorrow's to-dos after
  midnight without waiting for a change.
- The Tray preview in the drop view shows your four newest files, not the four oldest.
- A long list of Shortcuts can no longer leave the list stuck loading.
- A live stream reporting a nonsense length can no longer crash the music time display.

## [1.3.4] - 2026-10-26

### Added
- **Stats.** Click the new Stats tile in the grid (or press ⌃⌥P, or use Settings › Home) and your
  memory and CPU show beside the camera whenever nothing else is going on, turning yellow and
  then red as your Mac gets busy. Click the tile again to turn it off. Click the numbers in the
  notch to see memory, CPU, free disk space and network speed. Everything is read on your Mac and
  never leaves it.
- **Format your notes.** Notes has a colour dot and A, B, I and U at the bottom: bigger text, bold,
  italic, underline and colours. Formatting is kept across launches.

### Changed
- The grid shows five tiles to a row and scrolls to more pages, with dots on the right.
- Dragging files to the notch looks cleaner: a dashed blue Files Tray on the left, with the files
  already in it peeking out, and a solid blue AirDrop on the right.

## [1.3.3] - 2026-10-25

### Changed
- **A real notch on every screen.** Screens without a notch, like an external monitor, now get a
  notch at the top centre instead of a floating island. It stays out of sight until something's
  going on, like music, a timer or a call.
- **Rest your pointer to bring it out.** On a screen without a notch, rest your pointer at the top
  centre for a moment (the same delay as hover, 0.4 seconds by default) and the notch slides down.
  Click it to open Home, or with Hover on it opens by itself. Move away and it slides back up, and
  the menu bar underneath keeps working until then.
- **Smoother animations.** Opening has a little give, like the iPhone's island, and what's inside
  now grows out of the notch instead of popping in. Closing slides the notch smoothly back into
  the edge with crisp outlines, and switching between Home, Tray and Clipboard is a soft
  crossfade.
- The floating pill style is gone, along with its position settings, so Settings › Appearance is
  simpler. If you were using it, you'll see the notch style instead.

## [1.3.2] - 2026-10-25

### Fixed
- Connecting Calendar or Reminders could look like it did nothing: you clicked Allow, and the notch
  still asked you to connect. It now shows your calendar and to-dos as soon as you allow access.
- Everything you open from the notch (Home, Tray, Clipboard, Calendar and the rest) now sits evenly
  inside it, instead of crowding up against the top.
- The empty Tray had a stray line about a browser. It now says files stay until you quit and your
  originals aren't touched.

## [1.3.1] - 2026-10-25

You can install this from Settings › About › Install and Relaunch. If your button says Download
instead, grab this version by hand once and drag it into Applications. From then on, updates
install right from Settings, and each one is checked before it's installed.

### Fixed
- When a copy of the app can't update itself (for example a build you made yourself), the update
  button now says Download instead of Install and Relaunch, since it opens the download page.

## [1.3.0] - 2026-10-25

### Added
- **Several apps playing at once.** When a second app starts playing music or video while the
  first keeps going, the music view shows a button for each so you can switch between them.
- **Click or hover.** Settings › General has a simple choice for how the notch opens: click it,
  or just rest the pointer on it. With Hover, you can also pick how quickly it opens (0.1 to 0.5
  seconds). If you had "Expand on hover" on, you're already set to Hover.
- **Drop whole windows into Tray.** Drag a saved Pages, Numbers, Keynote, TextEdit, Safari or
  Chrome window by its title bar onto the notch and it lands in Tray. macOS asks for
  Accessibility access the first time, and some apps ask for Automation access too.
- **Choose your screen.** Settings › General › Display lists your screens by name, plus All
  displays. With All displays, music, timers and alerts show on every screen, and whatever you
  open appears on the screen you're using.
- **Links in Tray.** Drop a web link onto Tray and it's kept as a shortcut you can drag out later.

### Changed
- **A nicer island on other screens.** On displays without a notch, the floating island is now a
  rounded rectangle in a very dark grey, so it stands out on bright wallpapers. The notch on your
  MacBook stays pure black.
- **Safer updates.** Every update is signed, and the app checks that signature before installing
  anything, so a tampered download can't sneak in.
- **Tray is now a scratch space.** It holds up to 30 items and empties when the app quits. Your
  original files are never touched.
- The timer row in Home is tidier: "Timer ›" opens the full timer, and 5m, 10m, 15m and Focus
  start one straight away. The Calendar and Shortcuts rows match it.
- The Calendar panel looks like Apple's Calendar widget: the month name in red, a dot under days
  with events, and Up Next with each event's calendar colour. Click an event to open it in
  Calendar. It now shows the whole coming week, including all-day events.
- The back arrow is a plain chevron that highlights under the pointer, like macOS toolbars.
- The feature grid has more room: taller tiles, lighter type and a small coloured dot for what's
  on right now.
- The notch stays on your MacBook's screen again by default instead of following the pointer to
  other displays. Choose Follow the pointer in Settings › General if you want that.

### Fixed
- Connecting Calendar, Reminders or the camera could seem to do nothing, because the permission
  dialog didn't always appear while the app sat in the background. The app now comes forward to
  ask, and if macOS already has an answer on file it opens the right switch in System Settings.
- If Calendar access was off, the Calendar row disappeared from Home with no way to turn it on.
  It now stays, with an Allow Access button. "Add Events Only" access is explained too.
- After connecting Calendar, nothing showed up on a day with no more events. The Calendar row now
  always shows once connected, and the notch opens on your calendar right after you allow access.
- Dropping several files at once, or one after another, now adds every file to Tray, and
  documents from Pages and other apps drop in properly.
- Dragging a browser or editor window no longer drops the app itself into Tray by mistake.
- Hover didn't open the pill while it was showing on its own (Show when idle, or while trying
  sizes in Settings › Appearance). It now opens at every size, and the whole hover puff around
  the notch counts, not just the camera housing.
- Very long song titles or huge album art from a music app can no longer slow the app down.

## [1.2.0] - 2026-10-24

### Added
- **Everything in one grid.** The grid button at the top right shows every feature as a tile,
  each with a keyboard shortcut (⌃⌥ + a letter, like ⌃⌥R for the timer).
- **Clipboard.** A tab with the last 20 things you copied. Click one to copy it again. Passwords
  from password managers are skipped, and the history is never saved to disk.
- **Scratchpad.** A quick notes pad in the grid. It saves as you type and stays open while you
  write. Press Escape or click outside to close it.
- **A new Timer panel.** Pick Timer, Pomodoro or Stopwatch, slide the ruler to any length and
  press Start. Open it from the timer icon or the ••• button in Home.
- **Pomodoro.** Tap Focus in Home for a 25 minute session. When it ends, the notch offers a
  5 minute break, then the next session. You can change both lengths in Settings.
- **Stopwatch.** Counts up next to the camera, with pause and reset.
- **Calendar panel.** Click your next event in Home to see this month and what's coming up.
- **Reminders.** Today's to-dos from the Reminders app. Click the circle to tick one off.
- **Mute your mic during calls.** A mute button in the call view that works for every app.
- **Keep Awake.** A tile in the grid that stops your Mac from sleeping.
- **Finished downloads.** Turn it on in Settings › Home and the notch tells you when a file lands
  in Downloads. Click to show it in Finder or drag it straight out.
- **Gestures.** Swipe sideways on the music to skip songs, pull down on the notch to open it and
  push up to close it.
- **Second screens.** The notch follows your pointer to other displays, where it shows as a
  floating island.
- **Updates inside the app.** Once a day it checks GitHub for a new version and can install it
  for you. You can turn this off in Settings › About.
- **Homebrew.** Install with `brew install --cask shandilyaswagat/tap/dynamic-notch`.
- The first-launch hello greets you by your first name, with a waving hand.

### Changed
- Only Home, Tray and Clipboard sit in the tab bar; everything else is in the grid, so the top
  right has just the grid and Settings.
- A running timer looks like the iPhone's: pause and cancel on the left, the time on the right.
  Every kind of timer uses the same orange.
- The quick timers in Home are now 5, 10 and 15 minutes, plus Focus and ••• for anything else.
- The battery is gone from the top of Home, since it's already in your menu bar.

### Fixed
- While music (or a timer, call or stopwatch) was open, there was no way back to Home and the
  other features. Every open activity now has a back arrow at the top left.
- After a while (sooner if you connect headphones or join calls often) the app could get stuck
  using a full CPU core and stop responding, including the menu bar icon.

## [1.1.0] - 2026-10-21

### Added
- **File Tray.** Drag files onto the notch and drop them on Tray to keep them handy. Drag them
  back out whenever you need them, double-click to open, right-click for more.
- **Mirror.** A quick camera preview in the notch so you can check how you look before a call.
  The camera only turns on while you're looking at it.
- **Calendar.** Your next event shows up in Home, and the notch gives you a heads up 5 minutes
  before it starts.
- **Shortcuts.** Pin up to 4 of your shortcuts to Home and run them with one click.
- **Volume and brightness.** The notch shows the level when you change them.
- **Battery level** in Home.
- **Hover to open.** With "Expand on hover" on, resting on the notch opens Home.
- Home now has tabs (Home, Tray, Mirror) and a new layout: wider and shorter, with your music on
  the left and everything else next to it.
- A new Home tab in Settings to turn each of these on or off.

### Changed
- Dropping files on the notch now gives you two choices: Tray or AirDrop.
- The app asks for camera access only when you open Mirror, and calendar access only when you
  click Connect.

## [1.0.0] - 2026-10-21

### Added
- First release. The notch grows to show music, timers, calls, charging, low battery,
  headphones and AirDrop.
- Small, Medium and Large sizes, plus width and thickness fine-tuning.
- Pitch black look so the extension blends into the notch.
- Optional floating pill style.
- Menu bar icon, Settings window, open at login.

[1.5.0]: https://github.com/shandilyaswagat/dynamic_ledge/releases/tag/v1.5.0
[1.4.3]: https://github.com/shandilyaswagat/dynamic_ledge/releases/tag/v1.4.3
[1.4.2]: https://github.com/shandilyaswagat/dynamic_ledge/releases/tag/v1.4.2
[1.4.1]: https://github.com/shandilyaswagat/dynamic_ledge/releases/tag/v1.4.1
[1.4.0]: https://github.com/shandilyaswagat/dynamic_ledge/releases/tag/v1.4.0
[1.3.5]: https://github.com/shandilyaswagat/dynamic_ledge/releases/tag/v1.3.5
[1.3.4]: https://github.com/shandilyaswagat/dynamic_ledge/releases/tag/v1.3.4
[1.3.3]: https://github.com/shandilyaswagat/dynamic_ledge/releases/tag/v1.3.3
[1.3.2]: https://github.com/shandilyaswagat/dynamic_ledge/releases/tag/v1.3.2
[1.3.1]: https://github.com/shandilyaswagat/dynamic_ledge/releases/tag/v1.3.1
[1.3.0]: https://github.com/shandilyaswagat/dynamic_ledge/releases/tag/v1.3.0
[1.2.0]: https://github.com/shandilyaswagat/dynamic_ledge/releases/tag/v1.2.0
[1.1.0]: https://github.com/shandilyaswagat/dynamic_ledge/releases/tag/v1.1.0
[1.0.0]: https://github.com/shandilyaswagat/dynamic_ledge/releases/tag/v1.0.0
