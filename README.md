# Worldforged Item Tracker

## Description
Worldforged Item Tracker is a lightweight addon for **WoW Ascension** that helps you and your party track the locations of **Worldforged items** as you discover them.  
It automatically creates waypoints on your world map and syncs them with your group, making it easy to build a shared record of discoveries.

## Features
* **Automatic Tracking** – Detects when Worldforged items are looted.  
* **(Experimental) Mystic Enchant Tracking** – This feature is experimental and must be enabled manually (see Slash Commands). It generally works, but since many enchants drop from mobs (and some from quests), tracking their exact source is approximate. Many enchant locations are already listed on the [Ascension Database](https://db.ascension.gg/?items=0.6&filter=cr=152:184;crs=13:1;crv=0:0;na=mystic%20scroll;ub=7;ty=6#0-1), so in many cases tracking adds limited value. Also, enchants only need to be discovered once per account, so tracking is mainly useful when sharing information with others.
* **Waypoint Creation** – Marks the spot on your world map where the item was found.  
* **Persistent Storage** – Keeps waypoints saved between sessions.  
* **Party Sync** – Shares and syncs waypoints in real time with other party members using the addon.  
* **Informative Tooltips** – Hover over a waypoint to see item details and its source (mob, container, or quest).  

## How It Works
The addon listens to loot and combat logs.  
When a Worldforged item (or Mystic Enchant) is detected:  
1. The location is recorded.
2. A waypoint is placed on the world map.  
3. If you are in a party, the waypoint is automatically synced with your group.  

This ensures everyone in your party has a **complete, collective record of item locations**.

## Usage
- Left-click a waypoint on the map to mark it as picked up.
- Right-click a waypoint on the map to delete it.

## Slash Commands
Base command: `/wfit` or `/worldforged`

- `/wfit help` → Show all available commands  
- `/wfit sharing` → Toggles waypoint sharing on or off  
- `/wfit enchants` → Toggles experimental enchant tracking on or off
- `/wfit clear` → Clear all saved waypoints
- `/wfit reset` → Resets the database of items you have picked up. Useful for prestige.  

## Limitations
- No manual creation of waypoints yet.  
- When loot bot or a party member loots a target the recorded source is an **approximation** (usually accurate, but not guaranteed).  
- No way to filter the waypoints on the map.
- Same Icon is used for all waypoints.

*(Planned improvements may address these in future updates.)*

## Installation

### Method 1: Manual Installation
1. Download the latest version of the addon by pressing the green **Code** button and selecting **Download ZIP**.  
2. Unzip the file. The extracted files will appear directly in a folder (not already wrapped in an addon folder).  
3. Create a new folder named **`WorldforgedItemTracker`** inside your WoW addons directory: 
4. Move all extracted addon files into this new `WorldforgedItemTracker` folder.  
	- The final structure should look like:  
	  ```
	  ...\Interface\AddOns\WorldforgedItemTracker\WorldforgedItemTracker.toc
	  ...\Interface\AddOns\WorldforgedItemTracker\core.lua
	  ...\Interface\AddOns\WorldforgedItemTracker\... (other files)
	  ```
5. Restart WoW or reload the UI with `/reload`.

### Method 2: Git Clone
1. Navigate to your WoW addons directory with your terminal (`...\Interface\AddOns`).
2. Run `git clone https://github.com/Koldskaal/WorldforgedItemTracker.git`
3. A folder named `WorldforgedItemTracker` will be created in your addons directory.
4. Restart WoW or reload the UI with `/reload`.

Any updates can be installed by running `git pull` in the `WorldforgedItemTracker` folder.
