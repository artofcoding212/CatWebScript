# CatWebScript
CatWeb is a video game produced in the Roblox game engine. The game lets its users create and explore webpages made by the CatWeb community--entirely for free! It features a block language, similar to that of Scratch, which is very verbose. The game lets you import scripts and other objects as JSON, and if you've seen the title of this silly little project, you'll know what this is already.\
CatWebScript is a scripting langauge that directly compiles into CatWeb's native block language; with the goal of being much less verbose as well as being comfortable for all kinds of programmers.

# Installation
Installation is easy, straightforward, and can take up to 5 minutes if you know what you're doing.
* First, install LuaJIT:
    * **Windows**\
You can install LuaJIT via: `winget install DEVCOM.LuaJIT`. Make sure to restart your terminal after this.
    * **Mac/Linux**\
You can install LuaJIT via: `sudo apt install luajit`.
    * **Other**\
    Lua can run on almost any piece of hardware. Our source code needs to be ran with LuaJIT, which is incredibly portable. Search how you can install LuaJIT on your device, and there'll likely be a method.
* Then, clone our GitHub repo with `git clone "repo"`.
    * If you don't have Git installed, see how to for your OS.
* Finally, `cd` into the repo and run `luajit ./main.lua [path_to_your_file]` to compile a CatWebScript file. A `.json` file will pop up, which you can import into CatWeb.

# TODOs
What's upcoming for CatWebScript?
* IR optimizations (i.e. `set var x=3, log x` -> `log 3`)
* More CatWeb library interfaces (i.e. sounds, objects, etc.)
* Import JSON pages / Object paths (i.e. `page.foo`)
   * *This can't be done until `:FindFirstChild()` is implemented into CatWeb!*