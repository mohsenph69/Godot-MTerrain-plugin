# godot M Terrain Plugin
## Please read before using this plugin
Using this plugin require to learn some concept about terrain, This terrain plugin will not work out of the box, so I really suggest to read the [wiki](https://github.com/mohsenph69/Godot-MTerrain-plugin/wiki/) which I add recently added, I will add more stuff to wiki but for now I wrote the main concept that you need to know.

Also watching this video will be helpful:
https://www.youtube.com/watch?v=PcAkWClET4U

And then this video shows how to use use height brushes to modifying the terrain:
https://www.youtube.com/watch?v=e7nplXnemGo

Video about Texture painting:
https://www.youtube.com/watch?v=0zEYzKEMWR8

## patreon

You can support me with patreon [Click here](https://www.youtube.com/redirect?event=video_description&redir_token=QUFFLUhqbFM3emR4cTlkaGdPNXRwTk1JZEN6cklkXzlZUXxBQ3Jtc0trYzlGVkZMYUI4V293Z0tDNmkwVHdHQmxmYWF1SGNka3hvTVA5SU8tY2lNT2RXNktfZHNkcUFic0V0bzZCMm5FN2NTNmd4c0tpWXdLNUVEM0pFNmpnNDRIaGJ4bDRucDMyTnVRb2VnMlkxREVSQ0RSMA&q=https%3A%2F%2Fpatreon.com%2Fmohsenzare%3Futm_medium%3Dclipboard_copy%26utm_source%3DcopyLink%26utm_campaign%3Dcreatorshare_creator%26utm_content%3Djoin_link&v=0zEYzKEMWR8)

## Get Camera
Currentlly there is a bug, and sometimes the camera can not be accessed by Terrain
Use `set_custom_camera(Node3D node)` and pass your player or camera in that!
## download
To downalod the latest release use this link:
https://github.com/mohsenph69/Godot-MTerrain-plugin/releases
## build by yourself
First clone this repo on your local machine, so you need godot-cpp to exist in GDExtension folder so you can build that, godot-cpp is added as a submodule in this project so to put that inside GDExtension folder only thing you need to do after cloning this repo is runing this code
```
git submodule update --init --recursive
```
This will automaticly pull godot-cpp into GDextension folder, After that go inside GDExtension folder and use scons to build this project
