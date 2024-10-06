--# Services
local ServerScriptService = game:GetService("ServerScriptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")


--# Include
local RadiosityEngine = ServerScriptService:WaitForChild("RadiosityEngine")
local RadiosityEngineManager = require(RadiosityEngine:WaitForChild("Manager"))
local MathHelper = require(RadiosityEngine:WaitForChild("MathHelper"))


--# References
local radiosityActor = script:GetActor()


--# Set up your scene
local MyRadiosityManager
local maxBroadPatchRenderCount = 5
local currentBroadPatchRenderCount = 0

if radiosityActor == nil then
	-- Let's create a new radiosity manager and set it's properties!
	MyRadiosityManager = RadiosityEngineManager:new(script)
	
	MyRadiosityManager.BakeGlobalLights = true
	MyRadiosityManager.BakeLocalLights = false
	MyRadiosityManager.RandomLightSamplingEnabled = true
	MyRadiosityManager.SamplesPerPixel = 900
	MyRadiosityManager.DirectLightingEnabled = false
	MyRadiosityManager.IndirectLightingEnabled = true
	MyRadiosityManager.SunRadius = 0.1
	MyRadiosityManager.NarrowSurfacePatchScale = 32
	MyRadiosityManager.BroadSurfacePatchScale = 26
	
	-- Let's add some parts to render!
	-- This script automatically ignores all parts that aren't in the "Geometry" folder, are invisible, or are too small to lightmap.
	for _, part in workspace.Geometry:GetDescendants() do
		if part:IsA("Part") or part:IsA("WedgePart") then -- We wan't to make sure we're not rendering parts that aren't shaped as boxes.
			if part.Size.Magnitude > 2 and part.Transparency < 0.7 then
				local cannotMap = false
				
				for _, child in part:GetChildren() do
					if child.ClassName == "SpecialMesh" then
						cannotMap = true
					end
					
					if child:IsA("Light") then
						cannotMap = true
					end
				end
			
				if cannotMap == false then
					MyRadiosityManager:createCanvasOnAllSurfaces(part)
				end
			end
		end
	end
	
	-- We can also add lights that affect the final image!
	-- Point lights, Surface lights, and Spot lights are supported!
	if MyRadiosityManager.BakeLocalLights == true then
		for _, light in workspace.Geometry:GetDescendants() do
			if light:IsA("Light") then
				MyRadiosityManager:insertLight(light)
			end
		end
	end
end


--# Execution
if radiosityActor == nil then
	MyRadiosityManager:prepareLights()
	local workers = MyRadiosityManager:prepareRenderWorkers()

	-- Assign tasks to workers
	MyRadiosityManager:updateRenderVars()
	
	local startRender = os.clock()
	local numCanvases = #MyRadiosityManager.Canvases
		
	for canvasIndex, canvas in pairs(MyRadiosityManager.Canvases) do
		canvas:prepareRender()
		
		task.wait()
		
		for _, BroadPatch in pairs(canvas.BroadSurfacePatches) do
			-- OPTIONAL: task.defer allows multiple patches to be rendered at once
			local function renderPass()
				for xPixel = 0, MyRadiosityManager.NarrowSurfacePatchScale - 1 do
					workers[xPixel + 1]:SendMessage(
						table.unpack(MyRadiosityManager:getRenderInfo(canvas, BroadPatch, xPixel))
					)
				end
				
				currentBroadPatchRenderCount += 1
			end
			
			if currentBroadPatchRenderCount >= maxBroadPatchRenderCount then
				renderPass()
				task.wait()
			else
				task.defer(renderPass)
			end
		end
	end
	
	-- OPTIONAL: You can enable this if you enable task.defer()
	--MyRadiosityManager:waitUntilAllCanvasesAreRendered()
	
	print("Baked Lighting Complete:  "..tostring(os.clock() - startRender))
	
	-- finalize
	return
end

radiosityActor:BindToMessageParallel("RenderPatch", function(...)
	RadiosityEngineManager:renderPatch(...)
end)
