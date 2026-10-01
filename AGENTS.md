# RK S98 Spotify Display

## 1. Project goal

Build a macOS application/daemon that displays the currently playing Spotify track on the integrated TFT display of a Royal Kludge RK-S98 keyboard.

The desired display should contain:

- Album artwork
- Track title
- Artist
- Album name

The Spotify screen should behave like a dynamic standby/home screen.

The keyboard's original firmware, menus, dial/knob controls, RGB configuration, connection settings, brightness controls, battery information and other built-in functionality MUST remain usable.

The project must NOT replace or flash the keyboard firmware.

---

## 2. Target hardware

Keyboard:

Royal Kludge RK-S98 / S98

Known USB identifiers reported for this model:

- Vendor ID: `0x258A`
- Product ID reported for S98: `0x0174`

Do NOT assume PID `0x0174` without verifying the connected physical device.

Development machine:

- macOS
- Apple Silicon

Initial communication with the keyboard should be performed over USB/wired mode.

Wireless support is NOT required for the MVP.

---

## 3. Critical safety constraints

This is the most important rule of the project.

DO NOT send undocumented commands to the keyboard blindly.

DO NOT:

- flash firmware
- enter bootloader/DFU mode
- send firmware-update commands
- reset the keyboard without explicit user approval
- overwrite key mappings
- modify RGB settings
- modify persistent keyboard configuration
- fuzz HID commands against the physical device
- repeatedly send arbitrary HID reports
- assume another RK keyboard uses exactly the same protocol

until the S98 protocol has been sufficiently understood.

During reverse engineering, prefer:

1. passive observation
2. browser/WebHID inspection
3. USB/HID traffic capture
4. reproducing known-safe TFT operations

before attempting unknown commands.

The first write operation reproduced by this project should be equivalent to uploading a known test image through the official RK Web Driver.

Every command sent to the physical keyboard should ideally have first been observed in a known operation performed by the official RK software/Web Driver.

---


## 3A. Subagent orchestration policy

The main Codex agent acts as the project coordinator and should actively use subagents whenever independent work can be parallelized safely.

### Model and reasoning selection

For every subagent:

- Choose the most appropriate available model for the specific nature and difficulty of the task.
- Choose the most appropriate available reasoning/effort level for that task.
- Prefer stronger/high-reasoning capabilities for reverse engineering, protocol analysis, architecture, hardware-risk analysis, difficult debugging, or ambiguous technical decisions.
- Prefer faster/lighter capabilities when they are sufficient for mechanical tasks, focused research, documentation, classification, straightforward tests, or simple code changes.
- Do not automatically use the most powerful model for every task. Optimize for correctness, speed, and cost according to task complexity.
- If the environment does not allow explicit model or reasoning-level selection for a subagent, use the best available configuration and continue without fabricating unsupported settings.

### Delegation rules

Each subagent must receive:

- a clearly bounded objective
- relevant context
- explicit safety constraints
- expected deliverables
- ownership of a distinct area whenever possible

The coordinator must:

- avoid having multiple subagents edit the same files concurrently
- review subagent findings before integrating them
- resolve contradictions between subagents
- maintain the global architecture and project state
- consolidate research instead of blindly accepting individual conclusions
- distinguish verified facts from hypotheses
- prevent duplicated work when practical

Parallelize independent work aggressively when doing so is safe and useful.

Potential parallel research tracks include:

1. Existing Royal Kludge HID implementations and protocol research.
2. RK-S98-specific TFT and RK Web Driver/WebHID research.
3. macOS HID/IOKit investigation and READ-ONLY diagnostic tooling.
4. Current macOS Now Playing / Spotify metadata and artwork investigation.
5. Architecture, persistence/flash-risk, firmware-risk and recovery analysis.
6. Testing strategy and captured-traffic fixture design.

This list is not mandatory. The coordinator may choose a better decomposition.

### Single-owner rule for physical hardware

The physical RK-S98 has ONE owner: the main coordinating agent.

Subagents MAY:

- research
- inspect source code
- inspect captured traffic
- analyze protocols
- write documentation
- implement offline parsers
- implement renderers
- implement tests
- implement READ-ONLY diagnostic tooling
- prepare proposed experiments

Subagents MUST NOT independently perform or instruct automatic write operations against the physical RK-S98.

All physical-device operations involving HID output reports, feature reports, configuration changes, TFT writes, reset commands, firmware operations, or other state-changing commands must be centralized through the main coordinator.

Before the first execution of any new physical write operation, the coordinator must explain to the user:

1. the exact operation/command that will be performed
2. where that command was obtained or observed
3. the evidence that it is safe
4. the expected effect
5. known and plausible risks
6. whether it is volatile or persistent, if known
7. the recovery procedure
8. what evidence/results should be collected

The user decides when the physical experiment is performed.

No subagent may bypass this approval boundary.


## 4. Recovery and preservation requirements

The project must be designed so that abandoning it leaves the keyboard usable with its original behaviour.

Before the first custom HID write:

1. Record USB descriptors.
2. Record HID interfaces and report descriptors.
3. Record all readable configuration/state.
4. Document the keyboard's original screen behaviour.
5. Document how to return to the native Home screen.
6. Document the official factory-reset procedure.
7. If technically possible, save any readable original configuration.

Suggested research structure:

```text
research/original-state/
├── usb-descriptors.txt
├── hid-report-descriptors/
├── original-config/
├── original-tft/
└── notes.md
```

The intended recovery hierarchy is:

1. Stop the custom daemon/application.
2. Return to native Home using the keyboard controls.
3. Disconnect/reconnect the keyboard if necessary.
4. Restore configuration through the official RK software/Web Driver if necessary.
5. Factory reset only if necessary and explicitly approved by the user.

Firmware recovery must NOT be required by the normal development process.

Firmware, bootloader and DFU operations are out of scope.

---

## 5. Existing keyboard behaviour that MUST be preserved

The S98 has an integrated TFT display and a rotary dial/knob.

The keyboard firmware currently provides built-in screens/functions including things such as:

- Home/status screen
- Battery information
- Connection mode
- WIN/MAC mode
- GIF/custom image display
- RGB configuration
- RGB brightness/speed
- Volume
- Other system/configuration screens

The physical dial is used to access and navigate these functions.

Our software must NOT replace these menus.

The intended UX is:

```text
Spotify playing
        |
        v
Spotify screen displayed
        |
user touches/presses dial
        |
        v
RK native menu
        |
user finishes interaction
        |
short inactivity period
        |
        v
Spotify screen returns
```

Ideal inactivity delay:

approximately 5–10 seconds.

This behaviour is a goal, not an assumption.

We first need to determine whether dial/menu state can be detected from the host or whether the firmware automatically takes display ownership when the menu is opened.

---

## 6. Preferred display strategy

Avoid continuously streaming frames unless experimentation proves it necessary.

Preferred approach:

```text
Track changes
    |
    v
Render one new TFT image
    |
    v
Send image to keyboard
    |
    v
STOP communicating with TFT
```

This is preferable to continuous frame streaming because it:

- reduces USB traffic
- reduces interference with firmware
- reduces CPU usage
- avoids fighting with the native menu
- potentially reduces TFT/storage writes
- makes the implementation considerably safer

The display should only need updating when relevant state changes.

Examples:

- track changed
- playback started
- playback stopped
- playback paused
- Spotify became unavailable

Do NOT continuously redraw a progress bar in the MVP.

---

## 7. Expected UX

When Spotify starts playing, display something conceptually similar to:

```text
+--------------------------------+
| +------------+                 |
| |            |  Track title    |
| |  ARTWORK   |                 |
| |            |  Artist         |
| |            |                 |
| +------------+  Album          |
+--------------------------------+
```

Exact dimensions/layout must be determined from the real TFT characteristics.

Do NOT hardcode an assumed TFT resolution until it has been verified.

Royal Kludge documentation may recommend particular asset dimensions, but this does NOT necessarily prove the physical framebuffer resolution or transfer format.

Determine the real characteristics experimentally.

---

## 8. Spotify integration

There are two possible strategies.

### Strategy A — local Spotify/macOS state

Prefer this for the initial prototype if practical.

Determine whether the installed Spotify macOS application or macOS Now Playing infrastructure exposes enough information locally to obtain:

- playback state
- track title
- artist
- album
- track identifier
- artwork or artwork URL

Possible mechanisms to investigate:

- AppleScript
- macOS MediaRemote / Now Playing APIs
- Spotify application's scripting interface
- other non-invasive macOS APIs

Advantages:

- potentially no Spotify developer application
- no OAuth flow
- no polling against Spotify servers
- simpler personal-use application
- potentially faster track-change detection

Investigate this FIRST.

Do not assume an old AppleScript example still works with the current Spotify client.

### Strategy B — Spotify Web API

Use if local metadata/artwork is insufficient or unreliable.

Relevant endpoint:

`GET /v1/me/player/currently-playing`

Relevant OAuth scope:

`user-read-currently-playing`

Potential additional scope:

`user-read-playback-state`

The response can contain:

- track
- artists
- album
- album images
- playback state
- progress

Album images can be obtained from the album metadata.

Use the smallest suitable image when possible.

Cache artwork by album/track ID.

Do NOT download the same artwork repeatedly.

Respect Spotify rate limits and handle HTTP 429 correctly.

Before choosing this architecture, review the CURRENT Spotify Developer Terms and API documentation.

This project is initially intended for personal/local use.

---

## 9. State machine

Implement the application around an explicit state machine.

Suggested states:

- `DISCONNECTED`
- `IDLE`
- `PLAYING`
- `PAUSED`
- `RK_MENU_ACTIVE`
- `UPDATING_DISPLAY`
- `ERROR`

Example:

```text
DISCONNECTED
    |
keyboard connected
    v
IDLE
    |
Spotify playback detected
    v
PLAYING
    |
track changes
    v
UPDATING_DISPLAY
    |
upload finished
    v
PLAYING
```

If native menu activity can be detected:

```text
PLAYING
    |
dial/menu interaction
    v
RK_MENU_ACTIVE
    |
inactivity timeout
    v
PLAYING
```

The application MUST avoid sending display updates while `RK_MENU_ACTIVE`.

If menu activity cannot be detected reliably, prefer event-based image uploads so the firmware has control of the display most of the time.

---

## 10. Architecture

Keep hardware-specific logic separated from Spotify logic.

Suggested structure:

```text
src/
  keyboard/
    device.*
    hid.*
    protocol.*
    tft.*
    capture-analysis.*

  spotify/
    provider.*
    local-provider.*
    web-api-provider.*

  display/
    renderer.*
    layout.*
    artwork.*

  state/
    state-machine.*

  app/
    daemon.*
    config.*

  cli/
    main.*

tests/

research/
  captures/
  notes/
  protocol/
  original-state/
```

Do not lock the project into these exact filenames if the selected language/framework has better conventions.

The architectural separation is what matters.

Conceptual interfaces:

```text
interface MusicProvider {
    getPlaybackState()
    onTrackChanged(callback)
}

interface DisplayRenderer {
    render(track): ImageBuffer
}

interface KeyboardDisplay {
    connect()
    disconnect()
    uploadImage(image)
}
```

The Spotify implementation MUST NOT know about HID packets.

The HID implementation MUST NOT know about Spotify.

The renderer MUST be independently testable without physical hardware.

---

## 11. Phase 0 — repository and research setup

Before implementing Spotify support, create:

```text
README.md
AGENTS.md
research/
research/protocol/
research/captures/
research/notes/
research/original-state/
```

Document:

- keyboard model
- USB descriptors
- interfaces
- endpoints
- report descriptors
- usage pages
- report IDs
- observations

Provide a safe diagnostic command.

Conceptual CLI:

```bash
rk-s98 info
```

Expected output:

```text
RK S98 detected

VID: 0x258A
PID: 0x....
Manufacturer: ...
Product: ...
Serial: ...

Interfaces:
...

HID collections:
...
```

NO writes should occur when running this command.

---

## 12. Phase 1 — identify the device

Enumerate HID devices on macOS.

Find the S98.

Inspect:

- VID
- PID
- HID interfaces
- usage pages
- usage IDs
- report descriptors
- input report sizes
- output report sizes
- feature report sizes

Important:

RK keyboards may expose multiple HID interfaces.

Do NOT assume the standard keyboard HID interface is the TFT/configuration interface.

Identify which interface the official RK Web Driver opens.

---

## 13. Phase 2 — investigate RK Web Driver

Royal Kludge provides a browser-based Web Driver capable of uploading custom GIFs to supported TFT keyboards.

This is likely the most valuable reference implementation.

Use Chrome/Chromium DevTools to investigate:

- JavaScript bundles
- `navigator.hid.requestDevice()`
- `device.open()`
- `sendReport()`
- `sendFeatureReport()`
- `receiveFeatureReport()`
- report IDs
- chunk sizes
- TFT commands
- image conversion
- image framing
- upload initialization
- upload termination
- checksums
- delays
- acknowledgements

Search relevant JavaScript for terms such as:

```text
navigator.hid
sendReport
sendFeatureReport
receiveFeatureReport
258a
0174
TFT
GIF
image
frame
```

Pretty-print relevant bundles.

Document findings in:

```text
research/protocol/rk-web-driver.md
```

Do NOT blindly copy proprietary minified code into the project.

Understand and independently implement the protocol.

---

## 14. Phase 3 — capture a known-safe upload

Perform a controlled experiment.

Create simple test images:

- BLACK
- RED
- GREEN
- BLUE
- CHECKERBOARD

Upload ONE through the official RK Web Driver.

Capture the HID/USB traffic if possible.

Record:

- initialization packets
- report IDs
- image metadata
- image payload
- chunk size
- packet ordering
- checksums
- finalization command
- acknowledgements
- timing

Repeat using another image where only a tiny number of pixels differ.

Compare captures.

This should help reveal which bytes represent:

- headers
- dimensions
- sequence numbers
- payload
- checksums
- commands

Document every understood packet.

---

## 15. Existing reverse-engineering references

Study these projects for general Royal Kludge protocol knowledge:

- Rangoli: https://github.com/rnayabed/rangoli
- Royal Kludge Configurator: https://github.com/Ripwords/royal-kludge-configurator
- Kludge Knight: https://github.com/vinc3m1/kludgeknight
- RKCU: https://github.com/oddlyspaced/rkcu

Do NOT assume TFT support exists in them.

These repositories may be useful for:

- HID interface selection
- device enumeration
- report structure
- command serialization
- macOS HID handling
- general RK architecture

But the S98 TFT protocol must still be independently verified.

---

## 16. Phase 4 — reproduce a static image upload

Only after the protocol is understood, implement something conceptually equivalent to:

```bash
rk-s98 display test-image.png
```

Expected result:

1. detect S98
2. validate exact supported device/interface
3. convert image into TFT format
4. send documented upload sequence
5. display image
6. exit

After the process exits:

- keyboard must continue working
- dial must continue working
- native menus must continue working
- RGB must remain unchanged
- keyboard mappings must remain unchanged
- connection configuration must remain unchanged

This is the first major milestone.

Before proceeding to Spotify, explicitly verify that the keyboard can return to its original behaviour.

---

## 17. Phase 5 — determine TFT image format and persistence

Determine experimentally:

- physical/native resolution
- orientation
- pixel format
- RGB565 vs RGB888 vs another format
- endianness
- image compression
- GIF handling
- maximum payload
- whether GIF is decoded host-side or keyboard-side
- frame limits
- image persistence
- storage behaviour

CRITICAL QUESTION:

Does uploading an image write it to persistent flash?

If YES:

DO NOT upload a new persistent image on every track change until flash endurance implications are understood.

Investigate whether there is:

- RAM framebuffer transfer
- temporary preview command
- volatile image mode
- streaming command

Prefer volatile/RAM updates if available.

Flash wear is a critical design consideration.

---

## 18. Phase 6 — dial/menu interaction

Determine what happens when the Spotify/test image is displayed and the dial is pressed.

Questions:

1. Does firmware automatically replace the custom image with the menu?
2. Does it restore the image after leaving the menu?
3. Is an HID input report emitted when the dial is pressed?
4. Can menu-active state be queried?
5. Can inactivity be inferred?
6. Does uploading an image while the menu is open interrupt it?

Capture input reports while:

- rotating dial clockwise
- rotating dial counter-clockwise
- short pressing dial
- long pressing dial
- entering menus
- leaving menus

DO NOT change the dial's native behaviour.

If reliable menu detection is possible:

pause TFT updates while menu is active.

Resume after approximately 5–10 seconds of inactivity.

If menu detection is NOT possible:

do not continuously write to the TFT.

Only update when track changes.

---

## 19. Phase 7 — local Spotify prototype

Create a diagnostic command:

```bash
rk-s98 spotify status
```

Example:

```text
State: playing
Track: Beautiful Things
Artist: Benson Boone
Album: Fireworks & Rollerblades
Artwork: available
Track ID: ...
```

This phase must work WITHOUT communicating with the keyboard.

Test:

- play
- pause
- resume
- next track
- previous track
- Spotify closed
- Spotify reopened
- advertisement if applicable
- podcast
- local file if applicable
- no active playback

---

## 20. Phase 8 — renderer

Create a renderer independent from the keyboard.

Input concept:

```text
TrackInfo {
    title
    artist
    album
    artwork
}
```

Output:

native TFT image buffer

Initial layout:

```text
+------------------------------+
| +----------+                 |
| |          | Track title     |
| | ARTWORK  |                 |
| |          | Artist          |
| |          | Album           |
| +----------+                 |
+------------------------------+
```

Requirements:

- preserve artwork aspect ratio
- do not distort artwork
- readable typography
- UTF-8/Unicode support
- ellipsis or scrolling strategy for long strings
- sensible fallback if artwork unavailable
- sensible fallback if album unavailable
- render offline for testing

Provide a command conceptually similar to:

```bash
rk-s98 render --mock
```

which creates a preview PNG on macOS without touching the keyboard.

---

## 21. Phase 9 — integrate Spotify and TFT

Pipeline:

```text
Spotify/local media provider
        |
        v
TrackInfo
        |
        v
change detector
        |
        v
artwork cache
        |
        v
renderer
        |
        v
TFT buffer
        |
        v
RK HID transport
```

Only update if relevant display content changed.

Use a stable fingerprint such as:

```text
track ID + artwork ID + playback state
```

Avoid redundant uploads.

---

## 22. Pause/stop behaviour

Initial preferred behaviour:

```text
PLAYING:
display track

PAUSED:
keep current track displayed

STOPPED / Spotify closed:
allow original RK standby/home behaviour if technically possible
```

If restoring the native home screen requires an undocumented command, do NOT guess.

Research the correct mechanism.

---

## 23. Failure behaviour

The application must fail safely.

If Spotify fails:

- do nothing to keyboard

If artwork fails:

- render metadata without artwork

If keyboard disconnects:

- stop HID operations

If keyboard reconnects:

- re-detect interfaces before sending anything

If an HID write fails:

- do NOT retry indefinitely
- use bounded retries

Never create a tight HID retry loop.

---

## 24. Logging

Implement structured/debug logging.

Useful events:

- `keyboard.detected`
- `keyboard.disconnected`
- `hid.interface.selected`
- `tft.upload.started`
- `tft.upload.completed`
- `tft.upload.failed`
- `spotify.playing`
- `spotify.paused`
- `spotify.track_changed`
- `spotify.unavailable`
- `menu.activity`
- `renderer.completed`

Never log:

- OAuth access tokens
- refresh tokens
- Spotify client secrets
- sensitive macOS credentials

---

## 25. Development mode

Implement a dry-run mode.

Example:

```bash
rk-s98 daemon --dry-run
```

Dry run should:

- detect Spotify
- render images
- log intended HID operations

but MUST NOT write anything to the keyboard.

Also consider:

```bash
rk-s98 daemon --verbose
rk-s98 inspect-hid
```

Inspection commands must be read-only unless explicitly stated otherwise.

---

## 26. Tests

Unit-test at minimum:

- Spotify metadata parsing
- track-change detection
- state transitions
- artwork caching
- text truncation
- image scaling
- renderer
- HID packet encoding once protocol is known
- checksum generation if applicable

Use captured HID traffic as fixtures.

Example:

```text
tests/fixtures/hid/
  upload-black.*
  upload-red.*
  upload-checkerboard.*
```

Protocol encoding should be testable WITHOUT a physical keyboard.

---

## 27. Language / implementation choice

Before selecting the stack, evaluate the best option for:

- macOS HID access
- image manipulation
- daemon/background execution
- Spotify/macOS media integration
- maintainability

Good candidates include:

- Swift
- Rust
- TypeScript/Node.js
- Python

Do not choose solely based on prototyping speed.

For the MVP, prioritize:

1. reliable HID access on macOS
2. easy protocol experimentation
3. image manipulation
4. maintainability

If a quick Python/Node prototype helps reverse engineer HID, it is acceptable to prototype before deciding on the final daemon architecture.

---

## 28. Future possibilities

Do NOT implement these in the MVP, but keep architecture extensible for:

- Apple Music
- YouTube Music
- generic macOS Now Playing
- playback progress
- volume display
- weather
- calendar
- CPU/RAM monitoring
- notifications
- custom screens
- configurable layouts
- menu bar application
- launch-at-login
- multiple RK TFT keyboards

The music source should therefore ideally be abstracted as `MusicProvider` rather than hard-coding Spotify throughout the project.

---

## 29. MVP definition

The MVP is complete when:

1. S98 is detected reliably on macOS.
2. Exact TFT HID interface is documented.
3. Static image can be safely uploaded.
4. Native dial/menu still works.
5. Current Spotify track can be detected.
6. Album artwork can be obtained through an appropriate source.
7. Artwork + title + artist + album are rendered.
8. Display updates automatically when track changes.
9. Pausing/resuming Spotify does not break anything.
10. Native RK menus remain accessible.
11. Application survives keyboard disconnect/reconnect.
12. No firmware modification is required.
13. No RGB/keymap/configuration settings are accidentally modified.
14. A documented recovery path back to original keyboard behaviour exists.
15. The implementation does not perform unnecessary persistent flash writes.

---

## 30. Mandatory first physical-write validation

Before Spotify is allowed to communicate with the keyboard, complete this cycle:

```text
Original state
     |
     v
capture baseline information
     |
     v
send ONE known-safe test image
     |
     v
verify TFT
     |
     v
test dial
     |
     v
test native Home/menu
     |
     v
test RGB controls
     |
     v
test volume controls
     |
     v
test normal typing
     |
     v
test Bluetooth/2.4G if relevant
     |
     v
restore original behaviour
```

If any part fails, STOP.

Do not proceed to automatic Spotify updates until the cause is understood.

---

## 31. First task for Codex

DO NOT begin by implementing the Spotify daemon.

Start with hardware research.

Perform the following:

1. Inspect the repository.
2. Create the research/documentation structure if missing.
3. Act as coordinator and launch appropriate subagents for independent research tracks.
4. Research the RK S98 and existing RK HID implementations.
5. Research the RK Web Driver/TFT path independently from the macOS HID implementation where useful.
6. Identify safe methods to enumerate the keyboard on macOS.
7. Implement a READ-ONLY diagnostic utility that enumerates matching HID devices and prints their descriptors/interfaces.
8. Do not send any HID output reports or feature reports.
9. Document everything discovered, including which conclusions are verified and which remain hypotheses.
10. Review and consolidate subagent results.
11. Explain what information must be collected from the physical S98 before proceeding.
12. Stop before any state-changing physical-device operation and request the required physical-device test from the user.

When the safe first phase is complete, provide a consolidated report containing:

- subagents used and the responsibility of each
- major findings from each research track
- code/tools implemented
- verified information about the physical S98
- remaining unknowns
- current TFT/protocol hypotheses
- identified risks
- the exact next physical experiment required from the user

The first milestone is:

> Understand how this specific S98 exposes itself to macOS.

NOT:

> Make Spotify appear on the screen.

Safety and preservation of the keyboard's original behaviour take priority over speed.
