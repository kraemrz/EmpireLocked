# Empire Locked

**One King. Many Subjects. One Empire.**

Build your own equipment. Support your Empire through professions. Keep your Subjects beneath the King.

**If the King falls, the Empire falls.**

Empire Locked is a self-imposed World of Warcraft challenge addon built around a group of characters on the same account forming a single crafting-based Empire.

> Current release: **v0.6.6**
>
> Empire Locked is still under active development.

---

## The Challenge

Your characters are no longer independent adventurers.

Together they form an **Empire**.

One character is chosen as the **King**. Every other registered character becomes a **Subject**. The Empire survives only while its King survives and its laws are obeyed.

The central idea is simple:

**Your Empire must build its own power.**

Looted equipment, outside trading and the Auction House are not the path forward. Your characters gather materials, learn professions, craft equipment for one another and slowly build an economy of their own.

---

## Core Rules

### The King

Every Empire has exactly one King.

The King determines the maximum level of the Empire. If the King dies, the Empire falls and the run is over.

### Subjects

All other characters are Subjects.

A Subject may never exceed the King's level. When a Subject reaches the King's current level, that character must wait until the King advances.

If a Subject dies, that Subject is removed from the Empire. The Empire itself survives.

### Empire-Crafted Equipment

Equipment must be crafted by a member of the Empire.

Empire Locked uses item information such as the **Made by** tag to verify crafted equipment and tracks known Empire crafters.

Starter equipment is recognized separately so a newly created character can begin the challenge normally.

Bags are part of the equipment rules as well: dropped or externally purchased bags are not intended to become free upgrades simply because they are containers.

### No Auction House

Buying or selling through the Auction House is forbidden.

The Empire is supposed to be economically self-sufficient.

### Death Matters

Empire Locked tracks Subject deaths and King deaths.

- **Subject death:** the character is removed from the Empire and its cached contribution is removed.
- **King death:** the Empire fails.

Death history is preserved by the Chronicle system.

---

## Getting Started

1. Install Empire Locked.
2. Log in on the character you want to become King.
3. Create your Empire using the `/empire` commands shown by the addon.
4. Log in on your other characters and register them as Subjects.
5. Begin gathering professions and crafting professions across the Empire.
6. Use the **Crafting** tab to see what the Empire can make and where required materials are stored.
7. Use the **Empire** tab to monitor the laws and current status.
8. Use the **Chronicle** tab to watch the history of the run unfold.

Type:

```text
/empire help
```

in game for the commands supported by your installed version.

---

## The Empire UI

Empire Locked currently has three main pages.

### Empire

The Empire page is the command center for the current run.

It shows the King, Subjects, levels and classes together with important rule checks such as:

- King registration
- Subject level rule
- Auction House violations
- Gear verification
- Subject deaths
- King deaths
- Current Empire status

### Crafting

The Crafting page combines profession and inventory information gathered from Empire characters.

It can show:

- known recipes
- which Empire character knows a recipe
- whether a recipe is currently craftable
- missing materials
- which characters have required materials
- whether materials are in bags or bank storage

This allows the Empire to function like a small account-wide production network without pretending that materials physically exist in one shared bank.

Characters must be logged into so their relevant information can be cached and updated.

### Chronicle

The Chronicle turns a challenge run into a history.

The **Current Reign** records information such as:

- King
- current and highest King level
- length of the reign
- Subjects recruited
- Subjects lost
- fallen Subjects
- law violations

When an Empire is archived, it becomes part of **Past Empires**.

Past Empires can be collapsed individually so a long history of previous runs remains manageable.

---

## Gear Verification

Empire Locked distinguishes between equipment it can approve and equipment whose origin violates or cannot satisfy the challenge rules.

Typical approved equipment includes:

- recognized starter gear
- equipment carrying a valid **Made by** tag from an Empire character

Gear checks are designed to help enforce the challenge, but remember that this is an addon-side ruleset rather than server-side security.

The player is ultimately responsible for playing the challenge in good faith.

---

## Starter Gear

New characters obviously need to begin somewhere.

Empire Locked recognizes appropriate starter equipment so a fresh Subject is not immediately treated as a cheater for wearing the equipment supplied when the character was created.

Once that equipment is replaced, future upgrades should follow the Empire crafting rules.

---

## Death Enforcement

Death is one of the defining parts of Empire Locked.

When a Subject dies:

1. the death is recorded;
2. the Subject is removed from the Empire;
3. cached inventory/bank information belonging to that Subject is removed;
4. cached profession and recipe contributions are removed;
5. the death appears in Empire history.

The fallen character should no longer contribute phantom materials or crafting knowledge to the surviving Empire.

When the King dies, the run is considered failed.

---

## Banishment

Subjects can also be removed manually.

This is useful when a character is retired, has broken the challenge rules, or otherwise should no longer belong to the Empire.

Manual removals are tracked separately from deaths.

---

## Empire Chronicle Archive

Resetting an Empire can archive a snapshot of the completed run before the active Empire data is cleared.

Archived runs can retain information such as:

- Empire name
- King
- final King level
- highest King level
- reign duration
- Subjects recruited
- Subjects lost
- fallen characters
- violations
- final status and fate

The goal is for your SavedVariables file to become a history book of all the Empires you have attempted.

---

## Debug / Development Commands

Empire Locked contains development commands used while testing new systems.

These are **not challenge mechanics** and should not be used during a legitimate run unless you are intentionally testing the addon.

For example, development builds may contain commands that restore a deliberately failed test state or create a fake Chronicle archive entry.

Use:

```text
/empire help
```

to see the exact commands available in your installed version.

---

## Installation

Extract the addon so the directory looks like:

```text
World of Warcraft/
└── Interface/
    └── AddOns/
        └── EmpireLocked/
            ├── EmpireLocked.toc
            ├── Core.lua
            ├── Database.lua
            ├── Commands.lua
            └── ...
```

Restart World of Warcraft or reload the UI after updating the addon.

```text
/reload
```

### Updating

When updating Empire Locked, replace the addon files but **do not delete your SavedVariables** unless you intentionally want to erase your Empire history.

Making a backup of your SavedVariables before testing development releases is strongly recommended.

---

## Compatibility

Empire Locked is currently being developed and tested against the WoW environment for which this release was built.

WoW addon APIs differ substantially between client generations. A future port to newer client versions may require API compatibility changes even though the challenge rules themselves remain the same.

---


## Realm Separation

Empire data is stored **per realm/server**.

Characters on the same realm share one Empire database, while characters on another realm have a completely separate active Empire and Chronicle archive.

When upgrading from v0.6.5 or earlier, the existing account-wide Empire data is automatically migrated to the realm you first log into after installing v0.6.6. Backing up SavedVariables before upgrading is still recommended.

---

## Important Limitation

Empire Locked is an addon, not a server-side rules engine.

World of Warcraft does not expose every possible action or historical fact perfectly to addons. Empire Locked therefore combines event tracking, cached character data and item verification to enforce as much of the challenge as the client API allows.

It is best thought of as both:

**a rules engine and an extremely strict referee for a self-imposed challenge.**

If you deliberately bypass it, the addon cannot climb out of your monitor and confiscate your keyboard.

Yet.

---

## Contributing and Forking

Empire Locked is intentionally open source.

**Fork it. Modify it. Break it. Improve it. Create your own challenge modes.**

You are welcome to change the rules, redesign the UI, port the addon, add professions, create new Chronicle systems or turn the entire idea into something completely different.

Pull requests, forks and experiments are part of the fun.

---

## License

Empire Locked is released under the **MIT License**.

You may use, copy, modify, merge, publish, distribute, sublicense and/or sell copies of the software subject to the terms of the license.

See [LICENSE](LICENSE).

---

## The Empire Endures

Every crafted sword has a history.

Every Subject has a purpose.

Every death leaves a name behind.

**Long live the King.**
