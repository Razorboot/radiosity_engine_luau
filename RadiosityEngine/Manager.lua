--# Point
local Manager = {}
Manager.__index = Manager


--# Services
local Lighting = game:GetService("Lighting")
local ServerScriptService = game:GetService("ServerScriptService")
local RunService = game:GetService("RunService")


--# Include
local RadiosityEngine = script.Parent
local Canvas = require(RadiosityEngine.Canvas)
local Rendering = require(RadiosityEngine.Rendering)
local TopologyHelper = require(RadiosityEngine.TopologyHelper)
local MathHelper = require(RadiosityEngine.MathHelper)


--# Variables
local vec2, cf, vec3, vec3FromNormalId, c3, abs, clamp = Vector2.new, CFrame.new, Vector3.new, Vector3.FromNormalId, Color3.new, math.abs, math.clamp
local sunDirection = game.Lighting:GetSunDirection()


--# Global Variables
local occlusionCheckBias = -0.0003
local occlusionCheckDistance = 0.12


--# Methods
function Manager:new(executionScript)
	local newManager = {
		Canvases = {},
		Lights = {},
		
		CanvasesRendered = 0,
		RenderingComplete = false,
		
		BroadSurfacePatchScale = 25,
		NarrowSurfacePatchScale = 32,
		SamplesPerPixel = 50,
		PixelSamplesScale = 0.0,
		PixelsPerStud = 50,
		NarrowToBroadFactor = 0.0,
		RayDistance = 300.0,
		MaxRayDepth = 8,
		
		PixelToWorldFactor = 0,
		PixelOffset = 0,

		BakeLocalLights = false,
		BakeGlobalLights = true,
		RandomLightSamplingEnabled = false,
		DirectLightingEnabled = true,
		IndirectLightingEnabled = true,
		RenderType = 0,
		
		Actor = executionScript:GetActor(),
		ExecutionScript = executionScript,
		
		IsSequential = true,
		SunRadius = 0.04,
	}

	setmetatable(newManager, Manager)
	return newManager
end

function Manager:transferSettingsToCanvas(myCanvas)
	--myCanvas.BroadSurfacePatchScale = self.BroadSurfacePatchScale
	--myCanvas.NarrowSurfacePatchScale = self.NarrowSurfacePatchScale
	--myCanvas.SamplesPerPixel = self.SamplesPerPixel
	--myCanvas.PixelSamplesScale = self.PixelSamplesScale
	--myCanvas.PixelsPerStud = self.PixelsPerStud
	--myCanvas.NarrowToBroadFactor = self.NarrowToBroadFactor
	--myCanvas.RayDistance = self.RayDistance
	--myCanvas.MaxRayDepth = self.MaxRayDepth
	--myCanvas.BakeLocalLights = self.BakeLocalLights
	--myCanvas.BakeGlobalLights = self.BakeGlobalLights
end

function Manager:insertCanvases(myCanvases: {}, inheritsSettings: boolean)
	if not inheritsSettings then
		for _, canvas in pairs(myCanvases) do
			self:transferSettingsToCanvas(canvas)
		end
	end
	for _, canvas in pairs(myCanvases) do
		table.insert(self.Canvases, canvas)
	end
end

function Manager:insertLight(myLight: Light)
	table.insert(self.Lights, myLight)
	--for _, canvas in self.Canvases do
	--	table.insert(canvas.InitRaycastParams.FilterDescendantsInstances, myLight)
	--end
end

function Manager:removeLight(myLight: Light)
	for i, light in self.Lights do
		if light == myLight then
			table.remove(self.Lights, i)
		end
	end
	--for _, canvas in self.Canvases do
	--	for i, element in canvas.InitRaycastParams.FilterDescendantsInstances do
	--		if element == myLight then
	--			table.remove(canvas.InitRaycastParams.FilterDescendantsInstances, i)
	--		end
	--	end
	--end
end

function Manager:prepareLights()
	for _, light in self.Lights do
		local lightPart = light.Parent
		local lightPartHalfSize = lightPart.Size / 2
		lightPart:SetAttribute("HalfSize", lightPartHalfSize)

		if light:IsA("PointLight") then
			light:SetAttribute("CornerCFrame", lightPart.CFrame * cf(-lightPartHalfSize.X, -lightPartHalfSize.Y, -lightPartHalfSize.Z))
		elseif light:IsA("SurfaceLight") or light:IsA("SpotLight") then
			light:SetAttribute("CornerCFrame", lightPart.CFrame * TopologyHelper.calculateLightCornerCF(light, lightPartHalfSize))
			--light:SetAttribute("SurfaceNormal", (lightPart.CFrame - lightPart.Position):pointToObjectSpace(Vector3.fromNormalId(lightPart.Light.Face)).Unit)
			
			-- Work smarter, not harder!
			light:SetAttribute("SurfaceNormal", lightPart.CFrame:vectorToWorldSpace(vec3FromNormalId(light.Face)).Unit )
		end
	end
end

function Manager:createCanvasOnAllSurfaces(part: BasePart)
	local tempTable = {}
	table.insert(tempTable, self:createCanvas(part, Enum.NormalId.Top))
	table.insert(tempTable, self:createCanvas(part, Enum.NormalId.Right))
	table.insert(tempTable, self:createCanvas(part, Enum.NormalId.Left))
	if not part:IsA("WedgePart") then
		table.insert(tempTable, self:createCanvas(part, Enum.NormalId.Front))
	end
	table.insert(tempTable, self:createCanvas(part, Enum.NormalId.Back))
	table.insert(tempTable, self:createCanvas(part, Enum.NormalId.Bottom))
	return tempTable
end

function Manager:quickCreateCanvas(part: BasePart, surface: Enum.NormalId)
	local myCanvas = Canvas:new(self)
	myCanvas:assignSurface(surface)
	if part then
		myCanvas:assignPart(part)
	else
		print("RadiosityEngine - Manager: 79: No BasePart assigned to Canvas.")
	end
	myCanvas:assignPixelsPerStud(self.PixelsPerStud)

	self:transferSettingsToCanvas(myCanvas)

	table.insert(self.Canvases, myCanvas)
	return myCanvas
end

function Manager:getRenderInfo(canvas, BroadPatch, xPixel)
	local MyRadiosityManager = self
	
	return
	{"RenderPatch",
	canvas.Part.ClassName,
	canvas.InitRaycastParams, canvas.PartCF, xPixel,
	MyRadiosityManager.NarrowSurfacePatchScale, MyRadiosityManager.SamplesPerPixel,
	canvas.HalfPartSize, MyRadiosityManager.PixelsPerStud,
	MyRadiosityManager.PixelSamplesScale, MyRadiosityManager.RayDistance,
	canvas.Surface, canvas.PartRotationCF, MyRadiosityManager.BakeGlobalLights,
	MyRadiosityManager.BakeLocalLights, MyRadiosityManager.NarrowToBroadFactor,
	Canvas.Patches[BroadPatch], BroadPatch:GetAttribute("WorldCFrame"),
	MyRadiosityManager.Lights, MyRadiosityManager.RandomLightSamplingEnabled,
	MyRadiosityManager.SunRadius, MyRadiosityManager.PixelToWorldFactor,
	canvas.WorldSpaceNormal, MyRadiosityManager.PixelOffset,
	MyRadiosityManager.IndirectLightingEnabled, MyRadiosityManager.DirectLightingEnabled,
	MyRadiosityManager.SamplesPerAxis}
end

function Manager:createCanvas(part: BasePart, surface: Enum.NormalId)
	-- For wedges, we need to instantiate a new box to render on
	surface = surface or Enum.NormalId.Top
	
	if part:IsA("WedgePart") then
		if surface == Enum.NormalId.Top then
			local newCanvasPart = Instance.new("Part")
			newCanvasPart.Anchored = true
			newCanvasPart.CanCollide = false
			newCanvasPart.CanTouch = false
			newCanvasPart.CanQuery = false
			newCanvasPart.Transparency = 1
			newCanvasPart.CastShadow = false
			
			newCanvasPart.CFrame, newCanvasPart.Size = TopologyHelper.calculateWedgeTopSurfaceDimensions(part)
			newCanvasPart.Parent = part
			
			local newCanvas = self:quickCreateCanvas(newCanvasPart, surface)
			table.insert(newCanvas.InitRaycastParams.FilterDescendantsInstances, part)
			return newCanvas
		else
			return self:quickCreateCanvas(part, surface)
		end
			
	-- Any other part can be rendered normally
	else
		--local myCanvas = Canvas:new(self)
		--myCanvas:assignSurface(surface or Enum.NormalId.Top)
		--if part then
		--	myCanvas:assignPart(part)
		--else
		--	print("RadiosityEngine - Manager: 79: No BasePart assigned to Canvas.")
		--end
		--myCanvas:assignPixelsPerStud(self.PixelsPerStud)

		--self:transferSettingsToCanvas(myCanvas)

		--table.insert(self.Canvases, myCanvas)
		--return myCanvas
		return self:quickCreateCanvas(part, surface)
	end
end

function Manager:getCanvas(part: BasePart, surface: Enum.NormalId)
	for _, myCanvas in pairs(self.Canvases) do
		if myCanvas.Part == part and myCanvas.Surface == surface then
			return myCanvas
		end
	end
	return nil
end

function Manager:removeCanvas(part: BasePart, surface: Enum.NormalId)
	for i, myCanvas in pairs(self.Canvases) do
		if myCanvas.Part == part and myCanvas.Surface == surface then
			table.remove(self.Canvases, i)
			return true
		end
	end
	return nil
end

function Manager:countRenderedCanvases()
	local canvasesRendered = 0
	
	for _, canvas in pairs(self.Canvases) do
		for _, patch in pairs(canvas.BroadSurfacePatches) do
			if patch:GetAttribute("RenderingComplete") then
				local renderingComplete = patch:GetAttribute("RenderingComplete")
				if renderingComplete == true then
					canvasesRendered += 1
				end
			end
		end
	end
	
	return canvasesRendered
end

function Manager:waitUntilAllCanvasesAreRendered()
	local allPatchesRendered = true
	repeat
		for _, canvas in pairs(self.Canvases) do
			for _, patch in pairs(canvas.BroadSurfacePatches) do
				if patch:GetAttribute("RenderingComplete") then
					local renderingComplete = patch:GetAttribute("RenderingComplete")
					if renderingComplete == false then
						allPatchesRendered = false
						break
					end
				end
			end
		end
		wait(1)
	until allPatchesRendered == true
end

function Manager:updateRenderVars()
	self.PixelSamplesScale = 1.0 / self.SamplesPerPixel
	self.NarrowToBroadFactor = (self.BroadSurfacePatchScale * self.PixelsPerStud) / self.NarrowSurfacePatchScale 
	self.BroadToNarrowFactor = self.BroadSurfacePatchScale / (self.NarrowSurfacePatchScale * self.PixelsPerStud)
	self.PixelToWorldFactor = (self.NarrowToBroadFactor / self.PixelsPerStud)
	self.PixelOffset = 2 * self.PixelToWorldFactor
	self.SamplesPerAxis = math.ceil(math.sqrt(self.SamplesPerPixel))
	
	for _, canvas in self.Canvases do
		canvas.SurfaceGui.PixelsPerStud = self.PixelsPerStud
	end
end

function Manager:updateRenderVarsIndirect()
	self:updateRenderVars()
	--for _, light in self.Lights do
	--	for _, canvas in self.Canvases do
	--		table.insert(canvas.InitRaycastParams.FilterDescendantsInstances, light.Parent)
	--	end
	--end
end

function Manager:prepareRenderPixelData(myCanvas)
	--task.wait()
		
	local pixelData = SharedTable.new()
	for xPixel = 1, self.NarrowSurfacePatchScale do
		pixelData[xPixel] = {}
	end
	
	return pixelData
end

function Manager:prepareRenderWorkers()
	-- Set up actors for parallel processing
	local workers = {}
	local numOfWorkers = math.floor(self.NarrowSurfacePatchScale) * 2
	for i = 1, numOfWorkers do
		local actor = Instance.new("Actor")
		self.ExecutionScript:Clone().Parent = actor
		table.insert(workers, actor)
	end

	-- Parent all actors under self
	for _, actor in workers do
		actor.Parent = self.ExecutionScript
	end
	
	return workers
end


-- Actor Script (Inside the BindToMessageParallel)
-- Render direct lighting
function castOcclusionRay(pos, worldSpaceNormal, direction)
	return workspace:Raycast(pos + (worldSpaceNormal * -occlusionCheckBias) + (direction * occlusionCheckBias), direction * occlusionCheckDistance)
end

function Manager:renderPatch(partClassName: string, initRaycastParams: RaycastParams, partCF: CFrame, xPixel: number, narrowSurfacePatchScale: number, samplesPerPixel: number, halfPartSize: Vector3, pixelsPerStud: number, pixelSamplesScale: number, rayDistance: number, surface: Enum.NormalId, partRotationCF: CFrame, bakeGlobalLights: boolean, bakeLocalLights: boolean, narrowToBroadFactor: number, narrowSurfacePatch: EditableImage, broadSurfacePatchCF: CFrame, lights: {}, randomSamplingEnabled: boolean, sunRadius: number, pixelToWorldFactor: number, worldSpaceNormal: Vector3, pixelOffset: number, indirectLightingEnabled: boolean, directLightingEnabled: boolean, samplesPerAxis: number)
	for yPixel = 0, narrowSurfacePatchScale - 1 do
		local pixelCoord = nil
		local pixelColor = nil
		local pixelBrightness = nil
		local pixelIsOutOfBounds = false
		
		local worldSpacePixelCoord = TopologyHelper.calculateWorldSpacePixelPos(broadSurfacePatchCF, xPixel, yPixel, pixelsPerStud, surface, narrowToBroadFactor)
		
		-- Bounds check
		if TopologyHelper.isPointOutOfBounds(worldSpacePixelCoord, partCF, halfPartSize) == true then
			pixelIsOutOfBounds = true
			break
		end
		
		-- Coloring
		pixelCoord = vec2(xPixel, yPixel)
		pixelColor = vec3(0, 0, 0)
		pixelBrightness = 0.0
		
		if pixelIsOutOfBounds == false then
			if partClassName == "WedgePart" and surface ~= Enum.NormalId.Top and surface ~= Enum.NormalId.Back and surface ~= Enum.NormalId.Front and surface ~= Enum.NormalId.Bottom then
				local is_out = TopologyHelper.isPointOutOfRangeWedge(worldSpacePixelCoord, partCF, halfPartSize)
				if is_out then
					pixelIsOutOfBounds = true
					pixelBrightness = 1
				end
			end
		end
		
		-- Occluder check
		local occlusionWorldNormal = worldSpaceNormal * occlusionCheckBias
		local occlusionCast = workspace:Raycast(worldSpacePixelCoord.Position + occlusionWorldNormal, worldSpaceNormal * occlusionCheckDistance, initRaycastParams)
		
		local pixelBlocked = false
		if occlusionCast then
			pixelBlocked = true
		else
			--local tangent, bitangent
			--if math.abs(worldSpaceNormal.Y) > 0.999 then
			--	tangent = Vector3.xAxis
			--else
			--	tangent = worldSpaceNormal:Cross(Vector3.yAxis).Unit
			--end
			--bitangent = tangent:Cross(worldSpaceNormal).Unit
			
			--if castOcclusionRay(worldSpacePixelCoord.Position, worldSpaceNormal, tangent) then
			--	pixelBlocked = true
			--else
			--	if castOcclusionRay(worldSpacePixelCoord.Position, worldSpaceNormal, -tangent) then
			--		pixelBlocked = true
			--	else
			--		if castOcclusionRay(worldSpacePixelCoord.Position, worldSpaceNormal, bitangent) then
			--			pixelBlocked = true
			--		else
			--			if castOcclusionRay(worldSpacePixelCoord.Position, worldSpaceNormal, -bitangent) then
			--				pixelBlocked = true
			--			end
			--		end
			--	end
			--end
		end
		
		-- Calculate lighting
		if pixelBlocked == false and pixelIsOutOfBounds == false then
			-- Perform basic light attenuation for every light in the scene
			-- Perform shadow sampling
			-- perform indirect lighting (if enabled)
			for sampleIndex = 1, samplesPerPixel do
				pixelBrightness, pixelColor = Rendering.calculatePixelCombinedBrightness(initRaycastParams, worldSpacePixelCoord, sunRadius, rayDistance, surface, pixelBrightness, pixelColor, partRotationCF, partCF, sunDirection, pixelSamplesScale, samplesPerPixel, lights, bakeGlobalLights, bakeLocalLights, sampleIndex, randomSamplingEnabled, pixelToWorldFactor, worldSpaceNormal, pixelOffset, indirectLightingEnabled, directLightingEnabled, samplesPerAxis)
			end
		end
		
		-- Draw to canvas
		local pixelColorX = clamp(pixelColor.X, 0, 1)
		local pixelColorY = clamp(pixelColor.Y, 0, 1)
		local pixelColorZ = clamp(pixelColor.Z, 0, 1)
		local pixelBrightnessF = clamp(pixelBrightness, 0, 1)
		
		if pixelIsOutOfBounds == false and pixelBlocked == false then
			pixelColorX = MathHelper.linearToGamma(pixelColorX)
			pixelColorY = MathHelper.linearToGamma(pixelColorY)
			pixelColorZ = MathHelper.linearToGamma(pixelColorZ)
			pixelBrightnessF = MathHelper.linearToGamma(pixelBrightnessF)
		end
		
		task.synchronize()			
		narrowSurfacePatch:DrawLine(pixelCoord, pixelCoord, c3(pixelColorX, pixelColorY, pixelColorZ), pixelBrightnessF, Enum.ImageCombineType.AlphaBlend)
		task.desynchronize()
	end
end


--# Finalize
return Manager
