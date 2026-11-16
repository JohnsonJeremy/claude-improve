# Apple Reminders MCP (local, self-built)

A small MCP server that lets the Claude desktop app (Chat and Cowork) read and
write Apple Reminders on your Mac.

- **One source file** (`Sources/main.swift`), Apple frameworks only. No
  third-party packages, no network code, no telemetry.
- **You build it yourself**, so the program that runs is exactly the code here.
- **Can**: read lists and reminders; create, edit, complete, move and delete
  reminders; due dates; time and location alarms; repeat rules; priority;
  notes; native tags (through two Shortcuts you create).
- **Cannot**: create, rename or delete lists. Flags, subtasks, sections, the
  URL field and images are not available through Apple's EventKit API.

> Status: written and reviewed, but **not yet compiled or run** — it was
> authored on a machine without macOS. Step 1 below is the first real build.
> If it reports a compile error, send the error text back and it can be fixed.

## Requirements

- macOS 14 (Sonoma) or newer
- Xcode Command Line Tools (`xcode-select --install`, about 1 GB, one time)
- Claude desktop app

## 1. Build

In Terminal, from this folder:

```bash
./build.sh
```

This produces `build/apple-reminders.mcpb`.

Optional checks, also from Terminal:

```bash
build/bundle/server/reminders-mcp --doctor   # permission, lists, tag Shortcuts
./build.sh test                              # creates, edits and deletes ONE test reminder
```

The first run asks for Reminders access for Terminal. That grant is separate
from the one Claude will ask for later.

## 2. Install into Claude

1. Open Claude > Settings > Extensions.
2. Drag `build/apple-reminders.mcpb` into the window (or double-click the file)
   and choose Install.
3. Start a new chat and ask: "Check my Reminders status."
4. macOS asks whether to allow access to Reminders. Choose **Allow Full Access**.

Claude asks for approval before each tool the first time. A sensible setup:
allow the read tools always, keep `delete_reminder` on "ask every time".

## 3. Tags setup (two Shortcuts, one time)

Apple does not let apps read or write Reminders tags directly. The Shortcuts
app can, so the server calls two Shortcuts that you create. The names must
match exactly. Action names below are from Apple's documentation; the wording
in your macOS version may differ slightly.

### Shortcut A: `Reminders MCP Set Tags`

| # | Action | Settings |
|---|--------|----------|
| 1 | **Get Dictionary from Input** | Input: *Shortcut Input* |
| 2 | **Get Dictionary Value** | Get *Value* for `marker` in *Dictionary* |
| 3 | **Set Variable** | Name: `Marker` |
| 4 | **Get Dictionary Value** | Get *Value* for `tags` in *Dictionary* (the one from step 1) |
| 5 | **Set Variable** | Name: `Tags` |
| 6 | **Find Reminders** | Filter: *Title* *contains* `Marker` |
| 7 | **Set Variable** | Name: `Found` |
| 8 | **Edit Reminder** (shows as "Set … of Reminder") | Set *Tags* of `Found` to `Tags` |
| 9 | **Count** | Count *Items* in `Found` |
| 10 | **Stop and Output** | Output: *Count* |

In the Shortcut's details (ⓘ), allow it to receive input (Text / Files), and
the first time it runs choose **Always Allow** when asked about Reminders.

How it is used: the server appends a random marker word to the reminder's
title, runs this Shortcut to find that one reminder and set its tags, then
restores the title. This takes a few seconds per reminder.

### Shortcut B: `Reminders MCP Read Tags`

| # | Action | Settings |
|---|--------|----------|
| 1 | **Find Reminders** | Filter: *Is Not Completed* |
| 2 | **Repeat with Each** | Input: *Reminders* |
| 3 | &nbsp;&nbsp;**Text** (inside the repeat) | `@@R@@`*Title*`@@L@@`*List*`@@T@@`*Tags*`@@E@@` |
| 4 | **End Repeat** | |
| 5 | **Combine Text** | *Repeat Results*, separator: New Lines |
| 6 | **Stop and Output** | Output: *Combined Text* |

In step 3, *Title*, *List* and *Tags* are properties of the *Repeat Item*
variable: insert *Repeat Item*, click it, and pick the property. Type the
`@@R@@`, `@@L@@`, `@@T@@`, `@@E@@` markers exactly.

### Verify

```bash
./build.sh test
```

The `set tags` and `read tags back` lines should say PASS.

### Known limits of tags

- Tags are matched to reminders by **list + title**. Two incomplete reminders
  with the same title in the same list will show each other's tags.
- Tags are only read for **incomplete** reminders.
- `tags` on create/update is the **complete** set. Whether an empty set clears
  existing tags depends on the Shortcuts "Edit Reminder" action; test it once.
- While tags are being set, the reminder's title briefly ends in a word like
  `mcptag1a2b3c…`. If the Mac loses power at that moment the marker stays in
  the title; just delete it.

## Tools

| Tool | What it does |
|------|--------------|
| `reminders_status` | Permission state, whether the tag Shortcuts exist |
| `list_lists` | Lists with id, account, default flag |
| `list_reminders` | Filter by list, status, due range, text, priority, tags |
| `get_reminder` | One reminder by id |
| `create_reminder` | Title, list, notes, due, alarms, repeat, priority, tags |
| `update_reminder` | Change any field; complete/reopen; move between lists |
| `delete_reminder` | Permanently delete one reminder |

Dates: `2026-01-05` (all day), `2026-01-05T09:00` (local time), or full
ISO 8601 with an offset. A due date with a time gets an alert at that time
unless `alert_at_due` is false or `alarms` is given.

## Security notes

- The server only reads stdin and writes stdout; it opens no sockets.
- The only other programs it ever starts are `/usr/bin/shortcuts list` and
  `/usr/bin/shortcuts run` for the two Shortcut names above.
- It needs only the Reminders permission. Remove it any time in System
  Settings > Privacy & Security > Reminders.
- Reminder text is returned to Claude as data. A shared list could contain
  text written by someone else, so keep `delete_reminder` on "ask every time".
- The binary is signed ad hoc for this Mac only. After every rebuild macOS
  treats it as a new program and may ask for Reminders access again.

## Troubleshooting

- **"No access to Reminders" and no permission prompt appears.** macOS decides
  which app "owns" the request. Look in System Settings > Privacy & Security >
  Reminders for either **Claude** or **reminders-mcp** and turn it on, then
  quit and reopen Claude. If neither is listed, update the Claude desktop app
  (older versions could not request Reminders access for extensions).
- **Reset the permission and try again:**
  `tccutil reset Reminders local.apple-reminders-mcp`
- **Tags fail with "could not find the reminder".** Step 6 of Shortcut A must
  filter on *Title contains Marker* (the variable, not the literal word).
- **Manual install instead of .mcpb.** Add to
  `~/Library/Application Support/Claude/claude_desktop_config.json`:

  ```json
  {
    "mcpServers": {
      "apple-reminders": {
        "command": "/full/path/to/build/bundle/server/reminders-mcp"
      }
    }
  }
  ```

## Uninstall

Claude > Settings > Extensions > Apple Reminders (local) > Uninstall, delete
the two Shortcuts, and remove the entry under Privacy & Security > Reminders.
