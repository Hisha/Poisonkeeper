# Poisonkeeper

Poisonkeeper is a Rogue poison-management addon for **World of Warcraft 3.3.5a**. It handles routine restocking and obsolete-rank cleanup, provides quick poison application to either weapon, and warns about expiring temporary weapon enchants.

## Installation

1. Download and extract the repository archive, or copy your local repository.
2. Place the addon files in a folder named **Poisonkeeper** inside your WoW installation's `Interface/AddOns` directory.
3. Enable **Poisonkeeper** in the character-selection screen's **AddOns** list, then log in on your Rogue.

The folder layout must be:

```text
World of Warcraft/
  Interface/
    AddOns/
      Poisonkeeper/
        Poisonkeeper.toc
        Core.lua
        ...
```

`Poisonkeeper.toc` must sit directly inside `Poisonkeeper`, alongside the addon's Lua files. Rename an archive wrapper such as `Poisonkeeper-main`; do not leave the addon nested inside another wrapper directory. No addon manager or external library is required.

## Getting Started

Open **Interface → AddOns → Poisonkeeper**. Enable management for the poison families you want to restock, set their target quantities, then visit a vendor that sells the appropriate poisons.

By default, Poisonkeeper and expiration warnings are enabled, and the bar is shown and unlocked. **Every poison family starts unmanaged**, with a saved target of **40**. Enable management explicitly before expecting automatic purchases or cleanup.

## Features

### Automatic Poison Restocking

When you open a merchant, Poisonkeeper finds the highest catalog rank usable at your Rogue's current level for each managed family. If the merchant offers that exact poison, it buys the shortage toward your configured target, counting copies of that rank already in your bags. Reopening the vendor does not buy more when that rank is already at or above target.

- Targets accept whole numbers from **0 through 1000**. Invalid values are rejected, never silently clamped.
- Purchases respect available money, verified bag space, vendor stock, bundle quantities, and stack limits. Restocking may stop below target; it never rounds a purchase above the target to complete a bundle.
- If you cannot afford even one vendor bundle, nothing is purchased. If you can afford only part of the shortage, it can buy that affordable portion.
- **Target 0 prevents purchases**, but still permits safe obsolete-rank cleanup for a managed family. It does not sell your current rank just to reduce its count to zero.

### Safe Rank Replacement

Poisonkeeper sells only catalogued **lower ranks of managed families**, and only after verifying that the open merchant offers the exact current usable rank. The replacement must be usable, have valid merchant data, use ordinary money rather than extended costs, and have at least one bundle available if stock is limited.

Replacement availability is rechecked before every sale, and the bag slot is checked again immediately before selling. Current and higher ranks are preserved. **Unmanaged families are neither automatically restocked nor cleaned up.**

Selling obsolete ranks does not require enough money or space to buy a replacement. This allows cleanup even at target 0. Purchases are checked separately after sales. Operations proceed one at a time and wait for inventory confirmation; closing the merchant stops further processing. If maintenance stops with a message, resolve the reported issue and reopen the merchant to retry.

### Poison Application Bar

The movable bar displays the highest usable rank **you actually own** in each family, with that rank's bag count. Owning an older usable rank still lets you apply it even if you could use a newer one.

| State | Appearance and behavior |
| --- | --- |
| Managed and in stock | Normal-colored icon with inventory count; available for application. |
| Managed and out of stock | Red-tinted icon for the highest currently usable rank, count 0, and an out-of-stock tooltip; cannot apply poison. |
| Unmanaged but owned | Red-tinted icon with inventory count and an unmanaged tooltip; still available for application. |
| Unmanaged and absent, or no usable rank | Family is hidden. |

- **Left-click:** apply the displayed poison to the Main Hand.
- **Right-click:** apply it to the Off Hand.
- Drag the handle while unlocked to move the bar. Show/hide, lock/unlock, and reset its position through Interface Options.

Application requires a player click and an equipped weapon in the selected hand. Close the merchant before applying poison. The bar hides during combat; settings changes affecting it take effect after combat ends. Nothing is applied automatically.

### Poison Expiration Warnings

Main Hand and Off Hand temporary enchants are monitored independently, approximately once per second:

- A chat warning is issued when an observed remaining duration crosses from above **5 minutes** to **5 minutes or less**, while time still remains.
- An expiration message is issued after a previously observed enchant is absent on **two consecutive checks** of the same weapon.
- Messages are not repeatedly emitted while an enchant remains low or absent. Reapplying or refreshing an enchant allows a new warning cycle.

Logging in, changing weapons, or re-enabling monitoring starts a fresh, silent baseline. An enchant first observed with five minutes or less remaining does not trigger an immediate low-time warning. Removing a weapon does not count as expiration.

The 3.3.5a API reports temporary weapon enchants without identifying their type. Consequently, these warnings can also describe non-poison temporary enchants, and messages say **weapon enchant**. Monitoring can be disabled in Interface Options or with `/pk warnings off`.

### Interface Options

**Interface → AddOns → Poisonkeeper** is the normal graphical configuration method. Its scrollable panel exposes:

| Setting | Purpose |
| --- | --- |
| Enable Poisonkeeper | Enable or disable addon activity. |
| Manage each poison family | Choose which families receive automatic restocking and obsolete-rank cleanup. |
| Target Stock | Set each family's desired quantity of its highest usable rank. Disabling management preserves the target. |
| Show Poison Bar | Show or hide the application bar. |
| Lock Poison Bar | Prevent or allow dragging the bar's handle. |
| Reset Bar Position | Return the bar to the screen center without changing other settings. |
| Poison Expiration Warnings | Enable or disable temporary weapon-enchant warnings. |
| Reset Poisonkeeper Settings | Restore all addon defaults after a Yes/No confirmation. |

Checkbox changes save immediately. Target fields save on Enter, focus loss, or panel close; Escape in a field discards its uncommitted text. Invalid target text returns to the saved value. Interface Options **Cancel does not undo saved changes**.

The panel and slash commands share the same settings. Reopening the panel reflects command changes. Use the custom **Reset Poisonkeeper Settings** button to reset the addon; Blizzard's standard **Defaults** button does not reset Poisonkeeper.

### Slash Commands

For users who prefer commands, **`/pk` and `/poisonkeeper` are interchangeable for every command below**. Commands are case-insensitive and tolerate surrounding whitespace.

| Command | Purpose / example |
| --- | --- |
| `/pk` or `/pk help` | Show help and basic addon/character information. |
| `/pk status` | Show version, enabled state, Rogue detection, level, and each family's management state, target, and highest usable rank with required level. |
| `/pk enable` | Enable Poisonkeeper. |
| `/pk disable` | Disable Poisonkeeper. |
| `/pk <family>` | Show the family's state, target, and highest usable rank with required level; for example, `/pk instant`. |
| `/pk <family> on` | Enable management; for example, `/pk deadly on`. |
| `/pk <family> off` | Disable management; for example, `/pk wound off`. |
| `/pk <family> <target>` | Set an integer target from 0–1000; for example, `/pk instant 40`, `/pk deadly 60`, or `/pk wound 0`. |
| `/pk warnings on` | Enable expiration warnings. |
| `/pk warnings off` | Disable expiration warnings. |
| `/pk bar show` | Show the poison bar when usable families are available. |
| `/pk bar hide` | Hide the poison bar. |
| `/pk bar lock` | Lock the bar's position. |
| `/pk bar unlock` | Allow dragging the bar. |
| `/pk reset` | Explain the required confirmation; does not reset settings. |
| `/pk reset confirm` | Immediately restore all addon defaults. |

Family names: `instant`, `deadly`, `wound`, `crippling`, `mindnumbing`, `anesthetic`. For Mind-numbing Poison, `mind-numbing` and `mindnumb` are also accepted.

## Supported Poisons

- Instant Poison
- Deadly Poison
- Wound Poison
- Crippling Poison
- Mind-numbing Poison
- Anesthetic Poison

## Compatibility

- **World of Warcraft 3.3.5a**
- **Interface 30300**
- **Rogue characters** for poison management, application, and warnings

Compatibility with other WoW client versions is not claimed.

## Saved Settings

Configuration persists across sessions through WoW's `PoisonkeeperDB` SavedVariables. Settings are shared by characters using the same WoW account's saved addon configuration; management defaults do not need to be edited in Lua files.

A full reset enables the addon and warnings, makes the bar shown and unlocked at the screen center, and sets every family to unmanaged with target stock 40.

## Development / Data Accuracy

[PoisonCatalog.lua](PoisonCatalog.lua) contains intentionally static 3.3.5a poison data. [reference/poison_catalog.sql](reference/poison_catalog.sql) provides a query for validating the catalog against an AzerothCore world database. This is a development reference; **AzerothCore is not required to use the addon**, and the addon does not connect to a database.

## License

Poisonkeeper is available under the [MIT License](LICENSE).
