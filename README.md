![radiosity_engine_thumbnail (2)](https://github.com/user-attachments/assets/799b9deb-e56b-40b9-852b-b8c26359568b)

---

<div align="center">

## Video Showcase of Radiosity Engine:

[![Video Demo](https://img.youtube.com/vi/4z33Ls0PmxM/0.jpg)](https://www.youtube.com/watch?v=4z33Ls0PmxM)

</div>

---

> # Notice
---
- This is a WIP experimental lighting framework that takes full advantage of Roblox's Editable Image instance. This means lighting is calculated separately from Roblox's in-house lighting engine by using a light transport simulation. As a result, you can use this engine to add to Roblox's existing lighting, or render a scene using only baked lighting! Changes are still being made to Editable Image, so expect updates as Roblox rolls out the feature!

- **If you use the place file, run the game from the "Run" execution.**
This is because EditableImage beta does not support Server to Client replication yet, but will likey be rolled out with the official release of EditableImage!

![image](https://github.com/user-attachments/assets/fd19c867-30a7-4dcf-b4c3-d38373b2bfaf)

- **Rendering will pause your game temporarily.** This means it should only be done in Studio. (Later on I will cache the results to draw on client) This is because the engine is using its full capacity to render lighting in parallel with an optimized number of threads.
---

> # Introduction

A year ago I released a custom lighting framework that pre-renders the lighting in your experience. Since then, Roblox has implemented changes to Parallel Luau and added support for low-level image manipulation that enables many improvements in rendering times, performance, and most importantly, quality. This post details a complete rewrite of my lighting framework.

This release is modeled after a rendering technique called Radiosity Lightmapping, which was popular during the early 2000's to bake lights and shadows and global illumination (indirect lighting) in video-games. 

Instead of having your GPU calculate lighting for every pixel on the screen in real-time, radiosity is a pre-rendered, world-space technique that isn't limited to performance issues inherent to real-time rendering. As a result, radiosity can afford intensive light calculations such as raytracing, soft shadows, and indirect illumination regardless of hardware limitations.

Radiosity Engine v2 currently supports:
+ Parallel Luau
+ Global lights (sun)
+ Local lights (spotlights, pointlights, surfacelights)
+ Direct Illumination
+ Global Illumination
+ Hard & Soft shadows

There are also a few limitations to keep in mind, which I will explain in depth below:
+ EditableImages don't transfer between client and server at the moment. The engine is designed to be rendered on the server and lighting data is saved globally. Despite this, I believe Roblox is planning to fix this limitation once Editable Images are released.
+ Only parts with their ``Shape`` set to ``Enum.PartType.Block`` or ``Enum.PartType.Wedge`` can have lightmaps (textures with lighting data) applied to them. This means Radiosity Engine cannot accurately render lighting on unions, meshparts, spheres, corner wedges, etc. However, these parts still cast shadows!
+ Increasing the resolution of lightmaps too much can create performance issues. (You can only render so much image data at once!)
+ Rendering times are affected by the complexity of your scene.

---

> # Getting Started
**Learn how to set up a new experience with Radiosity Engine.**

I highly suggest downloading the sample place file below instead of downloading the required modules.
**If you use the place file, run the game from the "Run" execution**. This is because EditableImage beta does not support Server to Client replication yet, but will likely be rolled out with the official release of EditableImage!

An example scene is already set up for you inside the ``"Geometry"`` folder in Workspace. Currently, Radiosity Engine is split into two parts, the ``"Modules"`` folder and the ``"Main"`` script.

The Modules folder contains the Radiosity ``"Manager"`` class, which allows you to create a new container to render a specific part of your scene. For example, if you have an open area in your experience that doesn't have many shadows and another area that has many shadow-casting objects, you can render lighting at a lower resolution for the open area, and use a higher resolution for the closed area. By using Managers, you can split the scene up into two containers with different properties. The Main script communicates directly with Radiosity Managers to bake lighting in your experience.

You can create a new Radiosity Manager by including the ``"Manager"`` module and instancing a new Manager:
```lua
local RadiosityEngine = ServerScriptService:WaitForChild("RadiosityEngine")
local RadiosityEngineManager = require(RadiosityEngine:WaitForChild("Manager"))
MyRadiosityManager = RadiosityEngineManager:new( script )
```

The Main script already has Radiosity Engine set up and running with a Radiosity Manager! However, you can learn specifics about how to use Radiosity Engine if you continue reading.

---

> # Preparing Lighting Information
**Learn how to add parts to render and lights to influence your scene.
**
Before baking anything, you need to include all the parts you want to render. Because Radiosity renders lighting on individual surfaces of parts, you need to apply lightmaps to the specific surfaces of each part you want to render.

You can apply a lightmap to all surfaces of a part with:
```lua
MyRadiosityManager:createCanvasOnAllSurfaces( part: BasePart )
```
You can apply a lightmap to a specific surface of a part with:
```lua
Manager:createCanvas( part: BasePart, surface: Enum.NormalId )
```
Optionally, you can toggle local lighting and add local light sources to a Radiosity Manager:
```lua
MyRadiosityManager.BakeLocalLights = true
MyRadiosityManager:insertLight( light: Light )
```
You can toggle Global Lighting with:
```lua
MyRadiosityManager.BakeGlobalLights = false
```
❗Keep in mind that lights behave differently than in Roblox's default lighting engine. ``Brightness`` is ignored and light use a physically-accurate quadratic falloff. 

Additionally, lights are treated as volumes rather than points. This means lights must be attached to a part because the properties of the part (size, rotation, etc.) are essential in calculating realistic light emission.

---

![Group 34 (1)](https://github.com/user-attachments/assets/9207886a-7ca7-44f0-a7c0-b08bff3b2a15)

---

> # Lighting Features
**Learn how to use the different rendering options supported!**

Each Radiosity Manager contains a few core properties that can be modified to achieve different results.
+ ``MyRadiosityManager.NarrowSurfacePatchScale = [number]`` sets the pixel resolution for each patch. By default, the pixel resolution is 32, which means each patch contains 32x32 pixels.

+ ``MyRadiosityManager.BroadSurfacePatchScale = [number]`` sets the scale of each patch in studs. By default this value is 25, meaning each patch will have a size of 25x25 studs.

+ ``MyRadiosityManager.BakeGlobalLights = [Boolean]`` toggles whether light and shadows from the sun are rendered.

+ ``MyRadiosityManager.BakeLocalLights = [Boolean]`` toggles whether light and shadows from local light sources (point lights, spot lights, surface lights) are rendered.

+ ``MyRadiosityManager.DirectLightingEnabled = [Boolean]`` toggles whether direct light and shadows are rendered.

+ ``MyRadiosityManager.IndirectLightingEnabled = [Boolean]`` toggles whether global illumination is rendered.

❗ Indirect Illumination requires a high number of samples per pixel to minimize noise in the resulting image. This is because indirect illumination needs to sample more lighting information around the current pixel. This also extends script execution time.

A reasonable optimization to achieve faster global illumination in your experience is to disable ``DirectLightingEnabled``, and simply render indirect lighting at a lower patch resolution (by lowering ``NarrowSurfacePatchScale``). You can then enable shadow map lighting and/or voxel lighting to get real-time direct lighting with baked global illumination! 

Take a look at the comparison below of using this method compared to strictly using Roblox's default shadow map lighting!

![Group 41](https://github.com/user-attachments/assets/0cd8f0d8-d4da-4da4-a8dd-acd8db225369)

Mixing Direct and Indirect lighting with Voxel Lighting yields the best results:
![Group 42 (1)](https://github.com/user-attachments/assets/4b48c19e-1e34-4d15-8cc1-8dc0fb2c856d)

+ ``MyRadiosityManager.SunRadius = [number between 0 - 1]`` toggles how smooth shadows casted by the sun are. A higher value means shadows will appear softer and blurrier, while lower values produce sharper shadows.

+ ``MyRadiosityManager.SamplesPerPixel = [number]`` sets how many sample rays are fired per pixel. This allows Radiosity Engine to gather information about the scene around the pixel. Setting SamplesPerPixel too high can result in lag because more rays are fired per pixel.

+ ``MyRadiosityManager.RandomLightSamplingEnabled = [Boolean]`` Toggles whether random sampling or uniform sampling is used when sampling points on a light source.

❗ Both random light sampling and uniform hemisphere sampling come with advantages and drawbacks. Uniform hemisphere sampling eliminates noise, but creates banding artifacts when the ``samplesPerPixel`` value is too low. Random light sampling on the other hand eliminates banding, but creates noise if ``samplesPerPixel`` is too low.

Here is a table comparing the lighting results between random and uniform light sampling:
![Group 38 (1)](https://github.com/user-attachments/assets/35d517c1-1ffa-4877-a6a9-2d902e730721)

---

> # Baking Lights
**Learn how to render lighting information into your scene.**

==This process can be skipped over if you're using the place file.** However, it may be beneficial to understand how the engine works!==

After you've prepared the lighting information for your scene, you're ready to bake! The process I'll describe below is optimized for Parallel Luau and is separated into sections. The example place file includes the full implementation.

Before baking, lighting information needs to be updated and render workers need to be instantiated. These workers are Lua actors which work on rendering multiple pixels on the lightmap at once. The number of actors is based on the resolution of the lightmap, which I'll cover later.
You can prepare lighting information and render workers using:
```lua
MyRadiosityManager:prepareLights()
local workers = MyRadiosityManager:prepareRenderWorkers()
```
You also need to update the current Radiosity Manager before rendering:
```lua
MyRadiosityManager:updateRenderVars()
```
Now that the rendering setup is complete, we can begin baking. Radiosity Engine stores lighting information by creating a SurfaceGui for each surface in the Radiosity Manager. These SurfaceGuis are part of a special class called a ``"Canvas"``, which contains essential information about the surface to bake. Each Canvas is then split up into ImageLabels called ``"BroadSurfacePatches"``. The engine then divides each patch into pixels which are stored in an EditableImage called the ``"NarrowSurfacePatch"``. You can assign a render worker to a pixel on each patch to calculate lighting information in parallel.

``RadiosityEngineManager:renderPatch(...)`` allows you to render lighting for a specific patch. Because Radiosity Engine is designed for parallel Luau, you need to pass information to workers for rendering. The snippet below scans through each broad surface patch of every canvas, renders that patch with a render worker, and then repeats the process until rendering is complete.
```lua
for canvasIndex, canvas in pairs(MyRadiosityManager.Canvases) do
	canvas:prepareRender() -- Required before rendering.
	
	task.wait()
	
	for _, BroadPatch in pairs(canvas.BroadSurfacePatches) do
		-- OPTIONAL: task.defer allows multiple patches to be rendered at once, heavy performance impact but viable for simple scenes.
	
		--task.defer(function()
		for xPixel = 0, MyRadiosityManager.NarrowSurfacePatchScale - 1 do
			workers[xPixel + 1]:SendMessage(
				table.unpack(MyRadiosityManager:getRenderInfo(canvas, BroadPatch, xPixel))
			)
		end
		--end)
	
		task.wait()
	end
end

radiosityActor:BindToMessageParallel("RenderPatch", function(...)
	RadiosityEngineManager:renderPatch(...)
end)
```
