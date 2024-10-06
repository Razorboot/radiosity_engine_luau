--# Point
local Canvas = {}
Canvas.__index = Canvas


--# Services
local Lighting = game:GetService("Lighting")


--# Include
local Modules = script.Parent
local MathHelper = require(Modules:WaitForChild("MathHelper"))
local TopologyHelper = require(Modules:WaitForChild("TopologyHelper"))
local Rendering = require(Modules:WaitForChild("Rendering"))


--# Quick References
local vec2, cf, vec3, udim2, c3, mr, mp, sqrt, abs, vec3FromNormalId = Vector2.new, CFrame.new, Vector3.new, UDim2.new, Color3.new, math.random, math.pow, math.sqrt, math.abs, Vector3.FromNormalId


--# Preparation Methods
function Canvas:new(myRadiosityManager)
	local newCanvas = {
		SurfaceGui = Instance.new("SurfaceGui"),
		SurfaceImage = Instance.new("EditableImage"),
		BroadSurfacePatches = {},
		
		NarrowSurfacePatches = {},
		Part = nil,
		PartCF = nil,
		PartCornerCF = nil,
		PartRotationCF = nil,
		PartColorVec3 = nil,
		PartSize = nil,
		HalfPartSize = nil,
		
		Surface = Enum.NormalId.Top,
		WorldSpaceNormal = nil,
		
		InitRaycastParams = RaycastParams.new(),
		CurrentRadiosityManager = myRadiosityManager
	}
	newCanvas.SurfaceGui.Name = "RadiosityCanvas"
	newCanvas.SurfaceGui.Face = newCanvas.Surface
	newCanvas.SurfaceGui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	newCanvas.SurfaceGui.ClipsDescendants = true
	
	setmetatable(newCanvas, Canvas)
	return newCanvas
end

function Canvas:assignPixelsPerStud(scale: number)
	self.PixelsPerStud = scale
	self.SurfaceGui.PixelsPerStud = scale
end

function Canvas:assignSurface(surfaceAssignment)
	self.Surface = surfaceAssignment
	self.SurfaceGui.Face = self.Surface
end

function Canvas:assignPart(partAssignment)
	self.Part = partAssignment
	self.SurfaceGui.Parent = self.Part
	self.Part:SetAttribute("RadiosityEnabled", true)
	
	self.PartColorVec3 = MathHelper.col3ToVec3(self.Part.Color)
	self.InitRaycastParams.FilterDescendantsInstances = {self.Part}
	self.InitRaycastParams.FilterType = Enum.RaycastFilterType.Exclude
	
	self.PartSize = partAssignment.Size
	self.HalfPartSize = partAssignment.Size / 2
	self.PartRotationCF = self.Part.CFrame - self.Part.Position
	
	TopologyHelper.setCornerCF(self)
end


--# Render Methods
function Canvas:createSurfacePatches()
	-- clear previous broad surface patches
	self.BroadSurfacePatches = {}
	
	-- sizing variables
	local xSize, ySize = TopologyHelper.calculateSurfaceDimensions(self.Part, self.Surface) -- Corrected to Surface space
	local xLimit, yLimit = 0, 0
	local xPatchDiv, yPatchDiv = xSize / self.CurrentRadiosityManager.BroadSurfacePatchScale, ySize / self.CurrentRadiosityManager.BroadSurfacePatchScale
	
	if xPatchDiv >= 1 then
		xLimit = xPatchDiv
	end
	if yPatchDiv >= 1 then
		yLimit = yPatchDiv
	end
	
	self.LimitNarrow = vec2(xLimit * self.CurrentRadiosityManager.NarrowSurfacePatchScale, yLimit * self.CurrentRadiosityManager.NarrowSurfacePatchScale)
	self.Limit = vec2(xLimit, yLimit)
	self.LimitBroad = self.CurrentRadiosityManager.BroadSurfacePatchScale * self.CurrentRadiosityManager.PixelsPerStud
	--self.LimitNarrow = vec2(math.floor(self.LimitNarrow.X), math.floor(self.LimitNarrow.Y))
	
	for xCoord = 0, xLimit, 1 do
		for yCoord = 0, yLimit, 1 do
			local pixelsPerStud = self.CurrentRadiosityManager.PixelsPerStud
			local xWorldPos, yWorldPos = (xCoord * self.CurrentRadiosityManager.BroadSurfacePatchScale), (yCoord * self.CurrentRadiosityManager.BroadSurfacePatchScale)
			
			if xCoord == xLimit  then
				if xSize == xWorldPos then
					break
				end
			end
			if yCoord == yLimit then
				if ySize == yWorldPos then
					break
				end
			end
			
			--if math.abs(xWorldPos) > self.CurrentRadiosityManager.BroadSurfacePatchScale then
			--	break
			--end
			--if math.abs(yWorldPos) > self.CurrentRadiosityManager.BroadSurfacePatchScale then
			--	break
			--end
			
			local xPos = xWorldPos * pixelsPerStud
			local yPos = yWorldPos * pixelsPerStud
			
			local SurfaceImageLabel = Instance.new("ImageLabel")
			SurfaceImageLabel.Name = "BroadSurfacePatch"
			SurfaceImageLabel.BorderSizePixel = 0
			SurfaceImageLabel.BackgroundTransparency = 1
			SurfaceImageLabel.Position = udim2(0, xPos, 0, yPos)
			SurfaceImageLabel.Size = udim2(0, self.LimitBroad, 0, self.LimitBroad)
			SurfaceImageLabel.Parent = self.SurfaceGui
			SurfaceImageLabel.ResampleMode = Enum.ResamplerMode.Default
			
			local EditableImage = Instance.new("EditableImage")
			EditableImage.Name = "NarrowSurfacePatch"
			EditableImage.Size = vec2(self.CurrentRadiosityManager.NarrowSurfacePatchScale, self.CurrentRadiosityManager.NarrowSurfacePatchScale)
			EditableImage.Parent = SurfaceImageLabel
			
			local worldCF = TopologyHelper.calculateBroadPatchWorldPosition(self.SurfaceGui, SurfaceImageLabel, self.Part, self.Surface, self.PartCornerCF)
			SurfaceImageLabel:SetAttribute("WorldCFrame", worldCF)
			SurfaceImageLabel:SetAttribute("IsRendering", false)
			
			self.SurfaceGui:SetAttribute("BroadSurfacePatchScale", self.CurrentRadiosityManager.BroadSurfacePatchScale)
			self.SurfaceGui:SetAttribute("NarrowSurfacePatchScale", self.CurrentRadiosityManager.NarrowSurfacePatchScale)
			self.SurfaceGui:SetAttribute("NarrowToBroadFactor", self.CurrentRadiosityManager.NarrowToBroadFactor)
			
			-- DEBUG WORLDCF
			--local myPart = Instance.new("Part")
			--myPart.Size = vec3(1, 1, 1)
			--myPart.BrickColor = BrickColor.new("Really red")
			--myPart.Anchored = true
			--myPart.CFrame = worldCF
			--myPart.CanCollide = false
			--myPart.CanQuery  = false
			--myPart.Parent = workspace
			
			-- return
			table.insert(self.BroadSurfacePatches, SurfaceImageLabel)
		end
	end
end

function Canvas:prepareRender()
	self.PartCF = self.Part.CFrame
	self.PixelsPerStud = self.SurfaceGui.PixelsPerStud
	self.WorldSpaceNormal = self.PartCF:VectorToWorldSpace(vec3FromNormalId(self.Surface)).Unit
	self:createSurfacePatches()
end

function Canvas:prepareRenderIndirect()
	self.PartCF = self.Part.CFrame
	self.PixelsPerStud = self.SurfaceGui.PixelsPerStud
	self.WorldSpaceNormal = self.PartCF:VectorToWorldSpace(vec3FromNormalId(self.Surface)).Unit
end


--# Finalize
return Canvas
