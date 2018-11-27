# MicuPack v0.7

**Minetest modpack by (real)micu, tested with Minetest 0.4.17.1 running Minetest Game**

### Installation:

Enter Minetest mod directory and run:
```
git clone https://github.com/realmicu/minetest-micupack.git micupack
```

### This modpack contains:

* **Modern Tables** (moderntables)

  Full height wooden and metal tables in two variants: simple and with storage drawer
  (inventory for 16 items). If Tubelib mod is installed, four-legged machine stand
  and 4 more tables (designed to match both plain Tubelib and BiogasMachines style)
  are added as well.


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
  or a power source.  *To be expanded*

  Available:

  - **Water Freezer**

    Freezing machine that converts water to ice using Biogas as coolant. Water can be supplied
    in buckets or (if pipeworks mod is installed) through pipes. One water bucket is converted
    to one ice cube, in case of pipe network there is no need for any vessels however fresh
    water should be provided via pipelines. Empty buckets are returned as secondary products
    so Freezer can be easily paired with Liquid Sampler and other Tubelib machinery.
    Punch node to see status.

  - **Gasifier**

    Machine to extract Biogas from compressed dry organic material, such as fossil fuels.
    Designed primarily to retrieve gas from Coal blocks (not lumps!), it allows to convert
    Straw blocks to Biogas units as well. Equipped with 'recipe hint bar' that shows processing
    ingredients, products and duration. Primary goal is to convert piles of Coal blocks to another
    burnable agent, better suited for use in modern machinery.
    More recipes can be added via simple API function (see source file).
    As usual, punch node for quick status check.

  - **Biogas Furnace**

    Biogas-fuelled, Tubelib-compatible version of standard furnace. All cooking recipes apply.
    Notable differences are:
    - fuel is used only when cooking (Biogas is not wasted)
    - both input and output trays are larger allowing more items to be stored and processed
    - items that leave containers after cooking (for example farming:salt) do not block cooking
      tray; such vessels (buckets etc) are routed to output tray as well
    - uncookable items stay in input tray and are not routed anywhere
    - device tries its best to fill output tray and can choose input items to effectively utilize
      remaining space there

  Planned:

  - High Temperature Compressor - advanced machine to convert (albeit slowly) stone (or compressed
    gravel) to obsidian and coal block to diamonds; it will require water supplied either via buckets,
    through pipes (like freezer) or ice cubes(!) and a decent amount of Biogas
  - Metal Recycler - decomposing device to retrieve metal ingots and Mese shards from all items
    and nodes that were crafted from these resources; device will return random number of ingots
    and shards - between 1 and craft quantity; Mese crystals will be converted to shards for
    calculation purposes; fuelled by moderate volume of Biogas
  - Portable Biogas Torch (optional, TBD) - a tool to melt down ice and produce water source from it

