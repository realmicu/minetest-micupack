# MicuPack v2.5

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
    and faster way than copying it with text books; can be write-protected and labelled
  - Memory Programmer - improved Memory Copier, with read/write protection to prevent
    accidental memory loss and code injection functionality (works like original Programmer
    but for SL Controllers); it allows to replace special marker in init() section
    code with array containing collected Tubelib numbers, making redeployments of SL
    Controllers much easier (for example for mobile mining with Quarries and Pushers)

  *Note: due to node's formspec implementation, only inactive tabs can be populated - before
  code upload/rewrite please change active tab on SaferLua Controller to 'outp' or 'help'.*


* **Smartline Modules** (slmodules)

  This mod adds following Smartline-compatible nodes:

  - **Furnace Monitor**

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

  - **Digital Switch**

    Configurable multi-state switch with one-digit simple decimal LCD display.
    Its purpose is to enhance SaferLua Controller functionality by providing selectable input
    via standard Tubelib messaging. SL Controller can be programmed to perform different
    actions depending on value selected on digital panel.
    Right after placement, panel is in setup mode and should be configured before use; after
    successful configration, setup screen is no longer accessible. To change parameters again,
    simply collect and redeploy node.

    Configuration options:

    - destination number(s) of Controller(s) to send events to (optional, if not set - no
      messages are sent)
    - set of accepted digits (should be at least one digit or device refuses to start)
    - direction of value change ("up" means increase, "down" decrease); values do wrap around

    Switch value setting is changed with right click, like standard Tubelib buttons.

    To get value currently set on panel, query its status using SaferLua $get_status(NUMBER)
    function which returns "0" through "9" or "off" if panel is unconfigured. When panel is
    connected to Controller(s), switch sends "on" events every time it is changed (please note
    Controller limit of one event per second!)

    Status:

    - "0" .. "9" - current value
    - "off" - placed but not yet configured

    Events (optional):
    - "on" - on digit change

  - **AutoSieve Sensor**

    This node is a sensor pad for Techpack Automated Gravel Sieve. Although AutoSieve
    can interact with Tubelib machinery like any other Techpack machine, it does
    not have Tubelib ID, so it cannot be controlled or monitored. Sensor pad node should
    be placed directly under AutoSieve. It gets Techpack 4-digit ID and its working principle
    is identical to Furnace Monitor, allowing standard status query using Tubelib messaging.
    In addition, reading AutoSieve item counter is also supported.
    Sensor reads data from attached node only when requested so it does not consume CPU
    resources when idle (no timers).

    Placement: place directly under Automated Gravel Sieve.

    Status:

    - "fault" - there is no AutoSieve on top of sensor node
    - "stopped" - AutoSieve is not working
    - "running" - AutoSieve is running
    - "defect" - AutoSieve is broken due to aging and needs to be repaired

    Note: there is no "standby" state.

    Supported SaferLua functions:

    - $get_status(...)
    - $get_counter(...)

    Punch node to see current status.


* **Biogas Machines** (biogasmachines)

  Expands Tubelib (and TechPack) with various machines that use Biogas either as a product
  or a power source. *Machines are compatible with Techpack v2 and use Tubelib2 API.*

  Available:

  - **Water Freezer**

    Freezing machine that converts water to ice using Biogas as coolant. Water can be supplied
    in buckets or (if pipeworks mod is installed) through pipes. One water bucket is converted
    to one ice cube, in case of pipe network there is no need for any vessels however fresh
    water should be provided via pipelines. Empty buckets are returned as secondary products
    so Freezer can be easily paired with Liquid Sampler and other Tubelib machinery.

  - **Gasifier**

    Machine to extract Biogas from compressed dry organic material, such as fossil fuels.
    Designed primarily to retrieve gas from Coal blocks (not lumps!), it allows to convert
    Straw blocks to Biogas units as well. Equipped with 'recipe hint bar' that shows processing
    ingredients, products and duration. Primary goal is to convert piles of Coal blocks to another
    burnable agent, better suited for use in modern machinery.
    More recipes can be added via simple API function (see source file).

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

  - **Biogas Jet Furnace**

    Biogas Furnace that is 2 times faster than standard version in both item cooking time
    and Biogas consumption. While functionally identical to its predecessor, it supports stack
    pulling from output tray as well (can be paired with High Perf Pusher).

  - **Compactor**

    Heavy press with heating, compacting and cooling functions that can compress stone-like
    resources into very dense and hard materials, like obsidian. Default recipes include
    converting cobble and compressed gravel to obsidian, flint to obsidian shards and coal
    blocks to diamonds. Machine consumes Biogas for heating/compacting and Ice for rapid cooling.
    Custom recipes can be added via API function.

  - **Biogas Torch**

    Although not really a Tubelib-compatible machine, this item also helps to shift from Coal
    to Biogas as primary burning agent. Biogas Torch, a Biogas-powered eternal light source
    is a modern version of standard torch. Its goal is to replace coal torches as a basic,
    easy craftable and deployable source of light. Usage and light parameters are identical
    to original torch. Additionally, Biogas Torch becomes a heat source when placed, removing
    nearby snow and melting down ice to water (in a 3x3 cube around torch). There are many
    flavours of Biogas Torch, depending on metal used for handle, but these variations have
    only decorational purposes.
    Code and models are imported from Minetest Game default torch (torch.lua) - see source
    file for details.

  - **Biogas Tank**

    Dedicated storage for Biogas units. A convenient replacement for standard and Techpack
    chests when it comes to stockpiling Biogas.

    Gas tank comes in 3 sizes:
    - Small - 2 stacks
    - Medium - 32 stacks (standard Chest equivalent)
    - Large - 72 stacks (Tubelib HighPerf Chest equivalent)

    Features:
    - Biogas-only inventory
    - Tubelib I/O compatibility
    - real-time 3-level color visual fill indicator on device box
    - up-to-date capacity information in infotext (displayed when looking at the tank)
    - support for Tubelib stack pulling (can be paired with HighPerf Pusher)
    - not a machine, so no aging and no defects
    - support for standard SaferLua storage status query ("empty"/"loaded"/"full")
    - no node timer (capacity information and visual status updated only when node inventory
      is modified)

    Supported SaferLua functions:

    - $get_status(...)


  Future plans - see TODO file.

