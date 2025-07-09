![roaming](https://i.ibb.co/WNRsHLxm/Untitled-1-4.png)

> [!NOTE]  
> **I'm currently looking for your feedback.** A new obstacle mitigation pathfinding algorithm has been implemented in the experimental mode (`AGENT.bExperimental = true`) and may become a part of the master library. If you find an edge case or a way to improve it, feel free to create an issue or pull request.

> [!WARNING]
> **If this script does not work or throws errors on PostBellum HL2 RP** (or similar servers), please note that most likely the problem is not in the script, but in the environment. Some servers intentionally limit client functionality (for example, they do not supply some modules or standard library scripts to the client), which makes it incapable of functioning properly.

> [!TIP]
> To mitigate these measures, consider creating your own bypass that will execute your script in a safe and complete environment. If you have any trouble setting this up, create a GitHub issue.

# About Roaming
Roaming is a client-side framework written in pure lua that was made for creating scripted bots in Garry's Mod. With agents (models), you can create your own well-designed scenarios for moving around and interacting with the environment using the interface provided by Roaming.

# The Concept
As a framework, Roaming provides an interface for creating movement agents right out of the box. The agent serves as a model unit that contains all the logic for interacting with the interface. All motion handlers, including point-to-point motion, are defined by the agent. Users can switch between agents using the command interface in the game.

# Usage
As an end user, after the script has been successfully run, you would like to import an agent containing all the logic for interacting with the framework. This can be done with the `+roaming` console command, which when passed the first string argument tries to import an agent, and if the argument isn't passed, performs initialization of an already imported agent; nothing happens if it doesn't have an activation handler.

For example: `+roaming construct` imports the "construct" agent, and `+roaming` initializes its operation.

**Please note!** All agents are stored outside the game directory, because all files inside it can be read by the client-side anti-cheat and subsequently transferred to the server. The hard-coded directory from which agents are imported is `Steam/steamapps/common/GarrysMod.Roaming`. If necessary, you can change this path manually directly in the script.

To abort all actions that are being performed by the agent, you can use `-roaming`. Note that the correctness of aborting an agent depends on its quality and thoughtfulness. **Agents are the same scripts executed in a modified environment, but in your Lua state. Check the contents of the agents you are going to import.**

If your agent prompts for an argument upon activation, you can use `$roaming`. It will pass all arguments to the activation handler (e.g.: `$roaming 8` will pass "8" to the handler)

# Agent Creation
To get started with creating an agent, create its folder in the directory `Steam/steamapps/common/GarrysMod.Roaming`. The name of the folder will reflect the name of the agent that the player will need to pass to the `+roaming` command.

Inside the created folder you need to create two mandatory files: the main executable script and a pathmap, which contains information about movement points. The name of the executable script file must start with the prefix `cl_` and end with the folder name with the .lua extension. Pathmap file should be named `pathmap.json`. **If the script fails to import one of these files, an error will be thrown.**

## Pathmaps
Pathmap is a JSON file that contains a specification of the route and the points that can be utilized by the agent. In addition to the information about the points stored in the `sites` key table, it can also contain metadata. The metadata does not have specific keys and is provided in a free format as an indicator for the end user describing the recommended usage of the pathmap (for example, it is recommended to include fields such as `map` and `gamemode`).

Each object in the sites key table must contain the point's name as a key, keys for the coordinates (x, y, and z), as well as an array under the then key indicating which points can be used to continue the route.

```json
{
  "map": "gm_construct",
  "gamemode": "sandbox",
  "sites": {
    "construct-1": {
      "y": 545.4047241210938,
      "x": 848.9285888671875,
      "z": -143.96875,
      "then": [
        "construct-2",
      ]
    },
    "construct-2": {
      "y": 545.2730102539063,
      "x": 1388.7952880859375,
      "z": -143.96875,
      "then": [
        "construct-1",
      ]
    },
  }
}
```

Pathmap can be either non-sequential or sequential. A sequential pathmap is characterized by the use of an array in site instead of an object, where each element lacks the then field. It is assumed that in a proper implementation, such an array reflects the sequence of the path (in the order of literal iteration, the very first object represents the very first point of the path, while the last one represents the final point). An example of handling non-sequential arrays is presented in the `construct` agent.

```json
{
  "map": "gm_construct",
  "gamemode": "sandbox",
  "sites": [
    {
      "y": 545.4047241210938,
      "x": 848.9285888671875,
      "z": -143.96875,
    },
    {
      "y": 545.2730102539063,
      "x": 1388.7952880859375,
      "z": -143.96875,
    },
  ]
}
```

It is recommended to use automated scripts for creating Pathmaps. You can make such a script yourself or use my own implementation, the utility script `cl_pathmapper.lua`. Adding a point is done through `+pathmapper`, passing the point's name as the first argument, resetting the script session is done with `-pathmapper`, and saving (to the `garrysmod/data` directory) is done with `*pathmapper`. For sequential pathmaps, the script will automatically match related points. To create a sequential pathmap, do not specify an identifier for any point. **Please note that this script may have issues related to the limited time dedicated to quality control.**

# Agent API
The agent provides the script with a specific interface that is used for user interaction with the agent.

## Globals
### `AGENT`
An upvalue passed to the agent's executable script environment. A new table where its state should be stored.

### `AGENT.bExperimental`
Whether the agent uses the experimental mode. It is used to test new framework features before adding them to the master library. Will pop up a message on the client when the agent is imported.

## Functions
> [!TIP]
> Try to take a functional approach when creating an agent. Store all functions in the provided `AGENT` upvalue.

### `AGENT:OnActivate(<vector: pos>, <vararg: ...>)`
Invoked whenever the client activates the agent using the `+roaming` or `$roaming` console command.
```lua
function AGENT:OnActivate(pos, ...)
    print("You've successfully activated the agent");
    print("Your position is:", pos);
end
```
- - -
### `AGENT:OnDeactivate(<vector: pos>)`
Invoked whenever the player deactivates the agent using the `-roaming` console command.
```lua
function AGENT:OnDeactivate(pos)
    -- some abortion logic goes here
    return ROAMING:Abort();
end
```

# Roaming API
If you want to create your own agent, explore the Roaming API presented, which you can use in your own script.

## Globals
### `ROAMING`
A master table containing the entire library interface.

## Functions
Make sure you pass arguments of the required types. Almost all functions enforce runtime validation of arguments. There are also some undocumented internal functions that you can access through `ROAMING`.

### `ROAMING:Error(<string: err>, <vararg: ...>): None`
Invoked upon an internal script error. Throws a formatted message in the client console.
```lua
ROAMING:Error("Some error has occured at the point %s", point);
```
- - -
### `ROAMING:Abort(): None`
Safely aborts the current movement task.
```lua
if (ROAMING.client:Health() < 30) then
    return ROAMING:Abort();
end
```
- - -
### `ROAMING:MoveTo(<vector: vec>, <number: threshold>, <function: callback>)`
Creates and processes a client movement task. You should not cancel the current task to create a new one, as it will overwrite the current one. `threshold` is the accuracy allowed to consider a point reached (recommended to use 20 for normal points and 40 for player points).
```lua
ROAMING:MoveTo(Vector(0, 0, 0), 20, function(pos)
    ROAMING.client:EmitSound("buttons/blip1.wav");
    return chat.AddText("You've successfully reached the point!");
end);
```
- - -
### `ROAMING.listener:Add(<string: event>, <string: id>, <function: callback>)`
Creates a new safe event handler. Similar to `hook.Add`, but utilizes a safe ID that is randomized for each script session.
- - -
### `ROAMING.listener:Remove(<string: event>, <string: id>, <function: callback>)`
Removes an existing event handler. Similar to `hook.Remove`, but utilizes a safe ID that is randomized for each script session.
- - -
### `ROAMING.pathmap:GetPointVector(<string: name>): Vector`
Returns the position vector from pathmap by its name.
- - -
### `ROAMING.pathmap:FindEntryPoint(): String`
Searches for and returns the id of the first matching entry point in the Pathmap. Such point is the very first point in the entire Pathmap to which the player has unobstructed access.
```lua
function AGENT:OnActivate()
    local entry = ROAMING.pathmap:FindEntryPoint();
    local vec = ROAMING.pathmap:GetPointVector(entry);

    return ROAMING:MoveTo(vec, 20, function(pos)
        return self:OnFinishMove(entry, pos);
    end);
end
```
- - -
### `ROAMING.trace:GetColor(<number: distance>, <number: threshold>): Color`
Returns the color for the visual tracer based on distance. You can override this function to change the logic for selecting the tracer color.
```lua
function ROAMING.trace:GetColor(distance, threshold)
    return distance < (threshold + 120)
        and Color(51, 255, 0) or Color(0, 0, 255);
end
```

# Contributions
This project is open source and accepts all kinds of contributions. You can suggest your own changes, or your own agents using Pull Requests. If there is an issue that you can't solve on your own, feel free to create an issue.
