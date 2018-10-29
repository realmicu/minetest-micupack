Minetest modpack, tested with version 0.4.17.1.

This modpack contains:

* Modern Tables

  Simple wooden tables. To be expanded.


* Miner Tools

  Electronic gadgets for professional miners. Inspired by mod called 'Mineral Detector'.
  
  This mod provides following portable devices: 
  
  - geothermometer - shows temperature variations of solid blocks (water and lava
    affect block relative temperature - water cools it down while lava warms it up);
    useful for underground mining to search - or avoid - flooded caverns or lava pools
  - mineral scanner - shows ore count in area around player, selectable range (designed
    to be a handheld, improved version of Mineral Detector mentioned earlier)
  - mineral finder - short range directional scanner to find nearby deposits of selected
    mineral; very picky, especially at angles, but driven by simple logic
  - all-in-one versions of above devices, each one with improved characteristics


* SaferLua Programming Tools

  Devices for interacting with SaferLua Controller from TechPack mod:

  - Memory Copier - portable dongle to transfer code between SL Controllers in much simpler
    and faster fashion than copying it with text books
  - Memory Programmer - improved Memory Copier, with read/write protection to prevent
    accidental memory loss and code injection functionality (works like original Programmer
    but for SL Controllers); the latter allows to replace special marker in init() section
    code with array containing collected Tubelib numbers, making redeployments of SL
    Controllers (for example for mobile mining with Quarries and Pushers) much easier

  Note: due to formspec implementation, only inactive tabs can be populated - before code
  upload/rewrite please change active tab on SaferLua Controller to 'outp' or 'help'.


* Furnace Monitor

  This simple device allows to monitor Minetest Game standard furnace with Tubelib/Smartline
  devices that are capable of reading Tubelib node state (like SaferLua Controllers etc).
  It receives 4-digit number and can be referred like any other compatible read-only node.
  Monitor checks attached node only when status is requested so it does not consume CPU
  resources when idle (no timers).

  Placement: place on any side of a furnace, make sure back plate of device has contact with
  monitored node. In case of wrong orientation use screwdriver.

  Status:
  - "fault" - monitor is not placed on a furnace
  - "stopped" - furnace is not smelting/cooking
  - "running" - furnace is smelting/cooking items
  - "standby" - furnace is burning fuel but there are no items loaded

  Punch node to see current status.


* Biogas Machines

  Work in progress, only a stub for now. Planned to expand TechPack with biogas-fuelled
  furnace, machine to extract biogas from coal blocks and a high temperature compressor
  to convert (albeit slowly) stone to obsidian.

