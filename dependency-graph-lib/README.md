There are object nodes and requirement nodes. An example object node is 'iron-plate (recipe)' and 'iron-plate (item)'. An example requirement node is 'enable (iron-plate (recipe))' and '1 (iron-plate (recipe))'. The first requirement node represents that the recipe either needs to be unlocked from the start or by a technology. This will be fulfilled by either the 'START' object node or a technology object node. The second represents you need to be able to create the first item of the recipe. This will be fulfilled by the 'iron ore (item)' object node.

Requirements can be fulfilled by zero or more object nodes (ideally at least one). Objects can be fulfillers for any number of requirement nodes, and will have a fixed number of requirement nodes, depending on what it represents. There are 3 kinds of requirement nodes: independent requirements, such as electricity or heat (for Aquilo). These represent requirements that need only be fulfilled once. The second are typed requirements, for example crafting categories. Every crafting category is a typed requirement node: one requirement node exists for every crafting category. The final one are object specific requirement nodes, such as the enable and ingredient requirement nodes of a recipe. The first two types of requirement nodes are created initially and only looked up; the third type is created as part of the object functors.

Every object functor contains some code representing how to deal with a Factorio object of a certain type, for example items, recipes and entities. They contain two functions: the first function only creates object requirement nodes, the second does most of the work and actually hooks up object and requirement nodes.

There are several helper functions that should be used to link object and requirement nodes. They generally have one of these patterns:
- you already have the object node in question and it's going to be able to fulfil some requirement node, so you need to look up that requirement node
- you pick one of the object requirement nodes of your object nodes, and you link it to some other object node you need to look up that will fulfil it
- your object node has a requirement on a non-object requirement node

This results in the following functions to add a fulfiller for a requirement. The parameters of these functions tend to make it clear already what they do. 'reverse' usually implies the fulfiller will be looked up.
- add_fulfiller_for_independent_requirement:
  - looks up an independent requirement
  - fulfiller has to be a known object node
- add_fulfiller_for_typed_requirement:
  - looks up a typed requirement
  - fulfiller has to be a known object node
- add_fulfiller_for_object_requirement:
  - looks up an object requirement
  - fulfiller has to be a known object node
- reverse_add_fulfiller_for_object_requirement:
  - object requirement node: object node is known, requirement name to be provided
  - looks up the fulfiller

And for the requirement adding:
- add_independent_requirement_to_object:
  - looks up an independent requirement
  - makes known object node require it
- add_typed_requirement_to_object:
  - looks up a typed requirement
  - makes known object node require it

Some helper functions:
- add_productlike_fulfiller:
  - Similar to reverse_add_fulfiller_for_object_requirement except it deals with the item/fluid format from Factorio
- add_fulfiller_to_productlike_object:
  - Similar to add_fulfiller_for_object_requirement except it deals with the results/results format from Factorio