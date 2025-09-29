# Worldforged Item Tracker

## Description
Worldforged Item Tracker is a lightweight addon for **WoW Ascension** that helps you and your party track the locations of **Worldforged items** and **Mystic Enchants** as you discover them.  
It automatically creates waypoints on your world map and syncs them with your group, making it easy to build a shared record of discoveries.

## Features
* **Automatic Tracking** – Detects when Worldforged items or Mystic Enchants are looted (from mobs, containers, or quests).  
* **Waypoint Creation** – Marks the spot on your world map where the item was found.  
* **Persistent Storage** – Keeps waypoints saved between sessions.  
* **Party Sync** – Shares and syncs waypoints in real time with other party members using the addon.  
* **Informative Tooltips** – Hover over a waypoint to see item details and its source (mob, container, or quest).  

## How It Works
The addon listens to loot and combat logs.  
When a Worldforged item or Mystic Enchant is detected:  
1. The location is recorded.
2. A waypoint is placed on the world map.  
3. If you are in a party, the waypoint is automatically synced with your group.  

This ensures everyone in your party has a **complete, collective record of item locations**.

## Slash Commands
Base command: `/wfit` or `/worldforged`

- `/wfit help` → Show all available commands  
- `/wfit clear` → Clear all saved waypoints  

## Limitations
- No manual creation of waypoints yet.  
- No way to remove a single waypoint (only clear all).  
- When loot bot is enabled, the recorded source is an **approximation** (usually accurate, but not guaranteed).  
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
