# InfiltrationEngine Custom Missions
This repository contains tooling and templates for the InfiltrationEngine games, better known as Entry Point: Freelancer's Cut and Operators

The initial documentation for this system can be found here, courtesy of GhfjSpero:
https://docs.google.com/document/d/1LAvisY11Fq8_jbyoq5iz7pWnZoSETy429hJYfsEwdP0.
This document is out of date, and does not contain additions to the engine that have been made since it's creation. A community run documentation project can be found here: https://infiltrationengineeditor.miraheze.org

Mission templates and prop models provided in this repo are licensed under Creative Commons Attribution-NonCommercial-ShareAlike license (https://creativecommons.org/licenses/by-nc-sa/4.0/). Generally, this means is that you're free to create and share derivative works for non-commercial purposes as long as they are distributed under the same license.

## Quick Start
The InfiltrationEngineTools plugin provided in this repo are the internal tools used for the development of official missions. Install them by placing them in the plugins folder for Roblox Studio. The Prop Preview plugin also requires the Props asset from the Templates folder to be added to the place file that you're opening (refer to the README in the asset itself for more details). All tooling requires your mission to be placed in workspace and named `DebugMission` to function properly

The SerializationTools plugin generates the mission codes from your custom missions that can be loaded into the game. It's installed in the same way as the InfiltrationEngineTools plugin.

## Using Mission Templates
Official missions, featured community missions, and mechanics sample files in this repo are provided as templates to work off of/learn from for creating custom missions. When inserting a template into Roblox Studio, make sure workspace is clear of other parts and models (including the baseplate). If the mission is moved from it's original location on insert (or dragged to another location later) the pathfinding data will be offset and NPC pathing will likely break. You can check if pathfinding nodes are in the correct place using the Meadow Map plugin.

## Loading Mission In Game
To test your mission in game, open the Mission Exporter and hit generate code. If things are set up properly, one or more code segments will by generated that can then be selected and copied. Once you have mission codes, you can enter the game, start a custom mission from the main menu, and then copy your mission codes into the input modal. While in the custom mission or custom mission lobby, you can hit L at any time to reopen the modal and load a different mission code. If multiple code segments are given by the exporter, they must all be copied into the modal individually (Roblox restricts how many characters can be copied into a textbox at once)

Custom missions loaded with a code can only be played in singleplayer or with friends.

## GitHub Gist Importing
To make missions easier to share, you can upload the mission data to a GitHub Gist. You can copy the link to the Gist into the load mission modal instead of the code segments. You CANNOT use segmented mission codes for this - You can export large missions as a single code by creating an attribute called `ReadDocs` on workspace and setting it to true. Codes more than 200k characters cannot be directly imported into Roblox.

## Community Missions Showcase
The Freefall Softworks Community server has a channel for showcasing community created missions. Start there if you're looking for custom missions to play. Missions featured in game are also selected from that channel, so if you have a mission you want featured you can submit it there.
