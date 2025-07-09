> [!NOTE]
> This model is a demonstration and contains just basic logic. It is assumed that you have a fundamental understanding of the simplest scripting language and can create your own agent by analogy. The pathmap was specifically created for the `gm_construct` map and cannot be used elsewhere.

# Usage
The agent is activated through the commands `+roaming` and `$roaming` (the latter is used to pass an argument). If no argument is provided during activation, the agent will enter patrol mode for non-sequential or sequential points (depending on the pathmap; this repository includes a non-sequential pathmap, but you can create your own sequential one).

If an argument is provided during the agent's activation, it will be interpreted as a player ID, and the bot will enter pursuit mode, replicating the player's movements (for more details, see sections below).

You can abort the agent by using the `-roaming` command.

## Sequential Patrolling
Sequential patrolling applies to sequential pathmaps and involves the movement of the agent along a specified route from one (first) point to another (subsequent point). Upon reaching the final point, the bot will continue the route in the reverse direction, and so on, creating a continuous loop.

## Non-Sequential Patrolling
Non-sequential patrolling applies to non-sequential pathmaps and involves the random movement of the agent along connected points. For instance, upon reaching point `A`, which is linked to points `B` and `C`, the agent will autonomously make a random decision to move to either point `B` or point `C`.

## Dynamic Obstacles Mitigation
A system for obstacle recognition and mitigation was implemented in the experimental mode. For example, if the agent recognizes an obstacle on its path to a point while moving, it will find the most relevant way to navigate around it. The advanced system covers (based on empirical tests) up to 70% of cases but may struggle with stacked obstacles (when they overlap, creating an excessively large path to navigate around). Additionally, brushes and displacements cannot be mitigated, as they belong to the worldspawn entity, making it impossible to determine their boundaries using Lua.

If you know how to improve this algorithm, please create an issue or pull request.

Below is a diagram of the algorithm that determines the most relevant point for mitigating an obstacle.

![algorithm](https://i.ibb.co/DgSj2nsM/image.png)
