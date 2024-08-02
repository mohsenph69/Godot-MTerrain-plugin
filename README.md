# Godot M Terrain
MTerrain is an optimized terrain system/editor for Godot Engine.

![Screenshot_20230707_104154](https://github.com/mohsenph69/Godot-MTerrain-plugin/assets/52196206/7e3eb7da-af57-4ae5-8f55-f9fc1c8b26f8)


## Features
* Terrain that uses an octree based LOD system for terrain sizes as big as 16km x 16km
* Terrain shader with support for splatmapping, bitwise, and index mapping
* Navigation integration with Godot's navigation system
* Grass system with collision for things like trees, grass, rocks, etc
* Path system based on bezier curves with mesh deformation for roads, rivers, etc.
* Octree system for optimized control of LOD allowing for large number of objects in the world 
* Editor tools for Terrain sculpting, Grass painting, Navigation painting, Path editing, and importing/exporting heightmaps and splatmaps
  
![Screenshot_20230719_144752](https://github.com/mohsenph69/Godot-MTerrain-plugin/assets/52196206/704c51a8-7554-4345-907b-efc635a67dd0)

# Getting Started

To use this plugin you will need to learn some concepts - this terrain plugin will not work out of the box.
Please read the [wiki](https://github.com/mohsenph69/Godot-MTerrain-plugin/wiki/)  

Or watch this video will be helpful:
https://www.youtube.com/watch?v=PcAkWClET4U

This video shows how to use use height brushes to sculpt the terrain:
https://www.youtube.com/watch?v=e7nplXnemGo

This video shows how to use Texture painting:
https://www.youtube.com/watch?v=0zEYzKEMWR8

## Patreon

You can support me with patreon [Click here](https://patreon.com/mohsenzare?utm_medium=clipboard_copy&utm_source=copyLink&utm_campaign=creatorshare_creator&utm_content=join_link)

![Screenshot_20230719_144757](https://github.com/mohsenph69/Godot-MTerrain-plugin/assets/52196206/ef78652f-c4cc-4226-948e-9f4e44bb1af8)

## Build by yourself
First clone this repo on your local machine, so you need godot-cpp to exist in GDExtension folder so you can build that, godot-cpp is added as a submodule in this project so to put that inside GDExtension folder only thing you need to do after cloning this repo is runing this code
```
git submodule update --init --recursive
```
This will automaticly pull godot-cpp into GDextension folder, After that go inside GDExtension folder and use scons to build this project
