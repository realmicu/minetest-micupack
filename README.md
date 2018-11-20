# MicuPack v0.4

**Minetest modpack by (real)micu, tested with Minetest 0.4.17.1 and Minetest Game**

This modpack contains:

* **Modern Tables** (moderntables)

  Simple wooden tables. *To be expanded.*


* **Miner Tools** (minertools)

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


* **SaferLua Programming Tools** (slprogtools)

  Devices for interacting with SaferLua Controller from TechPack mod:

  - Memory Copier - portable dongle to transfer code between SL Controllers in much simpler
    and faster way than copying it with text books
  - Memory Programmer - improved Memory Copier, with read/write protection to prevent
    accidental memory loss and code injection functionality (works like original Programmer
    but for SL Controllers); it allows to replace special marker in init() section
    code with array containing collected Tubelib numbers, making redeployments of SL
    Controllers much easier (for example for mobile mining with Quarries and Pushers)

  *Note: due to node's formspec implementation, only inactive tabs can be populated - before
  code upload/rewrite please change active tab on SaferLua Controller to 'outp' or 'help'.*


* **Furnace Monitor** (furnacemonitor)

  This simple device allows to monitor Minetest Game standard furnace with Tubelib/Smartline
  devices that are capable of reading Tubelib node state (like SaferLua Controllers etc).
  It gets standard 4-digit Tubelib ID number and can be referred like any other compatible
  read-only node.
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


* **Biogas Machines** (biogasmachines)

  Expands Tubelib (and TechPack) with various machines that use Biogas either as a product
  or a power source.  *Work in progress!*

  Available:

  - **Water Freezer**

    Freezing machine that converts water to ice using Biogas as coolant; water can be supplied
    in buckets or (if pipeworks mod is installed) through pipes; one water bucket is converted
    to one ice cube; in case of pipe network there is no need for any containers however fresh
    water should be provided via pipelines; empty buckets are returned as secondary products
    so Freezer can be easily paired with Liquid Sampler and other Tubelib machinery;
    punch node to see status

  - **Gasifier**

    Machine to extract Biogas from compressed dry organic material, such as fossil
    fuels; designed primarily to retrieve gas from Coal blocks (not lumps!), allows also to 
    convert Straw blocks to Biogas units; equipped with 'recipe hint bar' that shows processing
    ingredients, products and duration; primary goal is to convert piles of Coal blocks to another
    burnable agent, better suited for use in modern machinery; more recipes can be added via
    simple API function; as usual, punch node for quick status check

  Planned:

  - Biogas Furnace - modern furnace powered by Biogas instead of coal or wood; accepts
    all recipes from original furnace as well as new custom ones; probably will also allow
    to smelt unused metal tools and armor back to single ingots
  - High Temperature Compressor - advanced machine to convert (albeit slowly) stone to obsidian
    and coal block to diamonds; will require water supplied either via buckets or through
    pipes (like freezer)
  - Portable Biogas Torch - a tool to melt down ice and produce water source from it

