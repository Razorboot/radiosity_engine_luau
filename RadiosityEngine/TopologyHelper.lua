--# Point
local TopologyHelper = {}


--# Include
local Modules = script.Parent
local MathHelper = require(Modules:WaitForChild("MathHelper"))


--# Quick References
local vec2, cf, vec3, udim2, c3, mr, mp, sqrt, abs, clamp, max, min, sin, cos, ceil, floor, vec3FromNormalId = Vector2.new, CFrame.new, Vector3.new, UDim2.new, Color3.new, math.random, math.pow, math.sqrt, math.abs, math.clamp, math.max, math.min, math.sin, math.cos, math.ceil, math.floor, Vector3.FromNormalId
local sampleScale = 10000
local lightShrinkFactor = 1
local boundsMarginFactor = 0.95

local DOUBLE_PI = math.pi * 2
local HALF_PI = math.pi / 2
local QUARTER_PI = math.pi / 4


--# Functions
@native
function TopologyHelper.calculateLightCornerCF(light, lightPartHalfSize: Vector3)
	if light.Face == Enum.NormalId.Top then
		return cf(-lightPartHalfSize.X, lightPartHalfSize.Y, -lightPartHalfSize.Z)
	elseif light.Face == Enum.NormalId.Bottom then
		return cf(-lightPartHalfSize.X, -lightPartHalfSize.Y, -lightPartHalfSize.Z)
	elseif light.Face == Enum.NormalId.Right then
		return cf(lightPartHalfSize.X, -lightPartHalfSize.Y, -lightPartHalfSize.Z)
	elseif light.Face == Enum.NormalId.Left then
		return cf(-lightPartHalfSize.X, -lightPartHalfSize.Y, -lightPartHalfSize.Z)
	elseif light.Face == Enum.NormalId.Front then
		return cf(-lightPartHalfSize.X, -lightPartHalfSize.Y, -lightPartHalfSize.Z)
	elseif light.Face == Enum.NormalId.Back then
		return cf(-lightPartHalfSize.X, -lightPartHalfSize.Y, lightPartHalfSize.Z)
	end
end

-- we need to calculate a vector to shoot to the sun if: we don't have random sampling enabled
@native
function TopologyHelper.calculateGlobalLightSampleVector(sunDirection: Vector3, sunRadius: number, sampleIndex: number, samplesPerAxis: number)
	-- Calculate the up vector, tangent, and bitangent
	local upVector = vec3(0, 1, 0)
	if abs(sunDirection:Dot(upVector)) > 0.999 then
		upVector = vec3(1, 0, 0)
	end
	local tangent = sunDirection:Cross(upVector).Unit
	local bitangent = sunDirection:Cross(tangent).Unit

	-- Calculate indices for the current sample
	local indexA = (sampleIndex % samplesPerAxis)
	local indexB = floor(sampleIndex / samplesPerAxis)

	-- Map indexA and indexB to a [-1, 1] range
	local u1 = (indexA + 0.5) / samplesPerAxis * 2 - 1
	local u2 = (indexB + 0.5) / samplesPerAxis * 2 - 1

	-- Concentric disk sampling
	local r, theta
	if u1 == 0 and u2 == 0 then
		r, theta = 0, 0
	else
		if abs(u1) > abs(u2) then
			r = u1
			theta = (QUARTER_PI) * (u2 / u1)
		else
			r = u2
			theta = (HALF_PI) - (QUARTER_PI) * (u1 / u2)
		end
	end

	-- Scale the offset by the sun radius and the distance to the surface
	local offsetX = r * cos(theta) * sunRadius
	local offsetY = r * sin(theta) * sunRadius

	-- Combine the sun direction with the calculated offset
	local offsetVector = (tangent * offsetX) + (bitangent * offsetY)

	-- Calculate the new direction vector
	local newSunDirection = (sunDirection + offsetVector)

	return newSunDirection
end

@native
function TopologyHelper.calculateWedgeTopSurfaceDimensions(Wedge: WedgePart)
	-- Calculate the size of the top surface of the Wedge
	local width = Wedge.Size.X
	local height = Wedge.Size.Y
	local length = Wedge.Size.Z

	local height_half = height / 2
	local length_half = length / 2

	-- Create a part representing the top surface
	local topSurfacePart = Instance.new("Part")
	topSurfacePart.Anchored = true
	topSurfacePart.CanCollide = false  -- No collision needed
	topSurfacePart.CanTouch = false
	topSurfacePart.CanQuery = false

	-- Convert the normal into world space
	local min_edge_pos = Vector3.new(0, -height_half, -length_half)
	local max_edge_pos = Vector3.new(0, height_half, length_half)
	local forward_vector = (max_edge_pos - min_edge_pos).Unit
	local right_vector = Vector3.new(1, 0, 0)
	local local_space_normal = forward_vector:Cross(right_vector).Unit
	local world_space_normal = Wedge.CFrame:VectorToWorldSpace(local_space_normal)

	-- Apply position and rotation to the part
	local surface_cf = CFrame.new(Wedge.Position, Wedge.Position + world_space_normal) * CFrame.new(0, 0, 0.025) * CFrame.Angles(-1.5707963267948966, 0, 0)
	local surface_dimensions =  Vector3.new(width, 0.1, math.sqrt(length^2 + height^2) )  -- See! Middle school math is actually useful!
	
	-- Finalize
	return surface_cf, surface_dimensions
end

@native
function TopologyHelper.calculatePixelSamplePoint(worldSpaceNormal: Vector3, worldSpacePixelCoord: CFrame, pixelOffset: number, sampleIndex: number, samplesPerPixel: number, randomSamplingEnabled: boolean)
	local upVector = Vector3.yAxis
	if abs(worldSpaceNormal:Dot(upVector)) > 0.999 then
		upVector = Vector3.xAxis
	end
	local tangent = worldSpaceNormal:Cross(upVector).Unit
	local bitangent = worldSpaceNormal:Cross(tangent).Unit

	-- Determine the sampling method
	local randomXOffset, randomZOffset
	
	if randomSamplingEnabled == true then
		-- Randomly sample a point within a circle
		randomXOffset, randomZOffset = MathHelper.randomPointInCircle(pixelOffset)
	else
		-- Uniformly sample points within a circle
		local samplesPerAxis = ceil(sqrt(samplesPerPixel))

		-- Calculate indices for the current sample
		local indexA = (sampleIndex % samplesPerAxis)
		local indexB = floor(sampleIndex / samplesPerAxis)

		-- Map indexA and indexB to a [-1, 1] range for concentric disk sampling
		local u1 = (indexA + 0.5) / samplesPerAxis * 2 - 1
		local u2 = (indexB + 0.5) / samplesPerAxis * 2 - 1

		-- Concentric disk sampling
		local r, theta
		if u1 == 0 and u2 == 0 then
			r, theta = 0, 0
		else
			if abs(u1) > abs(u2) then
				r = u1
				theta = (QUARTER_PI) * (u2 / u1)
			else
				r = u2
				theta = (HALF_PI) - (QUARTER_PI) * (u1 / u2)
			end
		end

		randomXOffset = r * cos(theta) * pixelOffset
		randomZOffset = r * sin(theta) * pixelOffset
	end

	return worldSpacePixelCoord
		+ (worldSpaceNormal * 0.0001)
		+ (tangent * randomXOffset) 
		+ (bitangent * randomZOffset)
end

@native
function TopologyHelper.calculateCosineWeightedHemisphereSample(worldSpaceNormal: Vector3, sampleIndex: number, samplesPerPixel: number, randomLightSamplingEnabled: boolean)
	local u1Mapped = MathHelper.randomDouble()
	local u2Mapped = MathHelper.randomDouble()

	-- Cosine-weighted hemisphere sampling over the polar and azimuthal angles
	-- u1Mapped gives us the azimuth (phi), u2Mapped gives us the cosine-weighted elevation (theta)

	-- Azimuthal angle phi (0 to 2π) for the X, Y sampling
	local phi = 2 * math.pi * u1Mapped

	-- Cosine-weighted elevation angle theta (0 to π/2 for hemisphere) for the Z (upwards) sampling
	local theta = math.acos(sqrt(u2Mapped))  -- Adjusted for cosine-weighted distribution

	-- Convert spherical coordinates (theta, phi) to Cartesian coordinates (x, y, z)
	local diskX = math.sin(theta) * math.cos(phi)
	local diskY = math.sin(theta) * math.sin(phi)
	local diskZ = math.cos(theta)  -- Z is the cosine-weighted component

	-- Now construct the sampled direction vector in local space
	local sampleDirection = Vector3.new(diskX, diskY, diskZ)

	-- Transform the sample direction to world space using the worldSpaceNormal
	-- To do this, we need to construct a local tangent and bitangent to the normal
	local tangent, bitangent
	if math.abs(worldSpaceNormal.Y) > 0.999 then
		tangent = Vector3.xAxis
	else
		tangent = worldSpaceNormal:Cross(Vector3.yAxis).Unit
	end
	bitangent = tangent:Cross(worldSpaceNormal).Unit

	-- Transform the sample direction from local space to world space
	local worldSampleDirection = 
		sampleDirection.X * tangent + 
		sampleDirection.Y * bitangent + 
		sampleDirection.Z * worldSpaceNormal

	-- Return the cosine-weighted sample direction in world space
	return worldSampleDirection.Unit
end

function TopologyHelper.calculateLightSamplePoint(light: Light, sampleIndex: number, samplesPerPixel: number, samplesPerAxis: number, randomSamplingEnabled: boolean)
	local lightPart = light.Parent
	local cornerCF = light:GetAttribute("CornerCFrame")
	local lightSize = lightPart.Size

	local pointX, pointY, pointZ = 0, 0, 0

	-- Calculate the grid indices for this sampleIndex
	local indexA = (sampleIndex % samplesPerAxis)
	local indexB = floor(sampleIndex / samplesPerAxis)

	if light:IsA("SurfaceLight") or light:IsA("SpotLight") then
		if light.Face == Enum.NormalId.Top or light.Face == Enum.NormalId.Bottom then
			if randomSamplingEnabled == false then
				-- Sampling over XZ plane
				local fractionX = indexA / samplesPerAxis
				local fractionZ = indexB / samplesPerAxis
				pointX = (lightSize.X * fractionX) * lightShrinkFactor
				pointZ = (lightSize.Z * fractionZ) * lightShrinkFactor
			else
				pointX = ((lightSize.X / sampleScale) * mr(0, sampleScale)) * lightShrinkFactor
				pointZ = ((lightSize.Z / sampleScale) * mr(0, sampleScale)) * lightShrinkFactor
			end
			
			if light.Face == Enum.NormalId.Bottom then
				pointY = 0  -- Bottom face (Y is at 0 from corner)
			else
				pointY = 0  -- Top face (Y is at full height from corner)
			end

		elseif light.Face == Enum.NormalId.Right or light.Face == Enum.NormalId.Left then
			if randomSamplingEnabled == false then
				-- Sampling over YZ plane
				local fractionY = indexA / samplesPerAxis
				local fractionZ = indexB / samplesPerAxis
				pointY = (lightSize.Y * fractionY) * lightShrinkFactor
				pointZ = (lightSize.Z * fractionZ) * lightShrinkFactor
			else
				pointY = ((lightSize.Y / sampleScale) * mr(0, sampleScale)) * lightShrinkFactor
				pointZ = ((lightSize.Z / sampleScale) * mr(0, sampleScale)) * lightShrinkFactor
			end
			
			if light.Face == Enum.NormalId.Left then
				pointX = 0  -- Left face (X is at 0 from corner)
			else
				pointX = 0  -- Right face (X is at full width from corner)
			end

		elseif light.Face == Enum.NormalId.Front or light.Face == Enum.NormalId.Back then
			if randomSamplingEnabled == false then
				-- Sampling over XY plane
				local fractionX = indexA / samplesPerAxis
				local fractionY = indexB / samplesPerAxis
				pointX = (lightSize.X * fractionX) * lightShrinkFactor
				pointY = (lightSize.Y * fractionY) * lightShrinkFactor
			else
				pointX = ((lightSize.X / sampleScale) * mr(0, sampleScale)) * lightShrinkFactor
				pointY = ((lightSize.Y / sampleScale) * mr(0, sampleScale)) * lightShrinkFactor
			end
			
			if light.Face == Enum.NormalId.Back then
				pointZ = 0  -- Back face (Z is at 0 from corner)
			else
				pointZ = 0  -- Front face (Z is at full depth from corner)
			end
		end
	else
		if randomSamplingEnabled == false then
			-- Handle PointLight or any other light type with 3D sampling (from the previous code)
			samplesPerAxis = ceil(samplesPerPixel ^ (1/3))
			local indexX = (sampleIndex % samplesPerAxis)
			local indexY = floor((sampleIndex / samplesPerAxis) % samplesPerAxis)
			local indexZ = floor(sampleIndex / (samplesPerAxis * samplesPerAxis))
			local fractionX = indexX / samplesPerAxis
			local fractionY = indexY / samplesPerAxis
			local fractionZ = indexZ / samplesPerAxis
			pointX = (lightSize.X * fractionX) * lightShrinkFactor
			pointY = (lightSize.Y * fractionY) * lightShrinkFactor
			pointZ = (lightSize.Z * fractionZ) * lightShrinkFactor
			
		else
			pointX = ((lightSize.X / sampleScale) * mr(0, sampleScale)) * lightShrinkFactor
			pointY = ((lightSize.Y / sampleScale) * mr(0, sampleScale)) * lightShrinkFactor
			pointZ = ((lightSize.Z / sampleScale) * mr(0, sampleScale)) * lightShrinkFactor
		end
	end

	-- Offset from the corner of the light part
	local samplePoint = cornerCF * CFrame.new(pointX, pointY, pointZ)

	return samplePoint.Position
end

@native
function TopologyHelper.isPointOutOfBounds(worldPoint: CFrame, partCF: CFrame, halfPartSize: Vector3)
	local localWorldSpacePixelCoord = partCF:ToObjectSpace(worldPoint).Position
	if abs(localWorldSpacePixelCoord.X*boundsMarginFactor) > halfPartSize.X or abs(localWorldSpacePixelCoord.Y*boundsMarginFactor) > halfPartSize.Y or abs(localWorldSpacePixelCoord.Z*boundsMarginFactor) > halfPartSize.Z then
		return true
	end
end

@native
function TopologyHelper.isPointOutOfRangeWedge(worldPoint: CFrame, wedgeCF: CFrame, halfPartSize: Vector3)
	-- Calculate the size of the top surface of the wedge
	local height_half = halfPartSize.Y / 2
	local length_half = halfPartSize.Z / 2

	-- Convert the normal into world space
	local min_edge_pos = vec3(0, -height_half, -length_half)
	local max_edge_pos = vec3(0, height_half, length_half)

	local slant_vector = (max_edge_pos - min_edge_pos).Unit
	local slant_center = (max_edge_pos - min_edge_pos)/2

	local test_local_pos = wedgeCF:PointToObjectSpace(worldPoint.Position)
	--local test_to_line = (test_local_pos - slant_center).Unit
	
	-- Calculate AB and AP vectors
	local pointA = min_edge_pos
	local pointB = max_edge_pos
	local pointP = test_local_pos
	
	local AB = pointB - pointA
	local AP = pointP - pointA
	local flippedAB = -AB
	local AB_dot_AB = AB:Dot(AB)
	local AP_dot_flippedAB = AP:Dot(flippedAB)
	local scalar = AP_dot_flippedAB / AB_dot_AB
	local projection = pointA + (scalar * flippedAB)
	
	if projection.Y <= (test_local_pos.Y - 0.5) then
		return true
	end
	
	--local to_line_cross = slant_vector:Cross(test_to_line)

	--if to_line_cross.X <= 0 then
	--	return true
	--end
end

@native
function TopologyHelper.calculateSurfaceDimensions(partInstance: BasePart, surfaceAssignment: Enum.NormalId)
	if surfaceAssignment == Enum.NormalId.Top then
		return partInstance.Size.Z, partInstance.Size.X
	elseif surfaceAssignment == Enum.NormalId.Bottom then
		return partInstance.Size.Z, partInstance.Size.X
	elseif surfaceAssignment == Enum.NormalId.Right then
		return partInstance.Size.Z, partInstance.Size.Y
	elseif surfaceAssignment == Enum.NormalId.Left then
		return partInstance.Size.Z, partInstance.Size.Y
	elseif surfaceAssignment == Enum.NormalId.Front then
		return partInstance.Size.X, partInstance.Size.Y
	elseif surfaceAssignment == Enum.NormalId.Back then
		return partInstance.Size.X, partInstance.Size.Y
	end
end

@native
function TopologyHelper.calculateCrossVectors(partCornerCF: CFrame, surfaceAssignment: Enum.NormalId, partAssignment: BasePart, pixelsPerStud: number)
	if surfaceAssignment == Enum.NormalId.Top then
		local rightNormal = partCornerCF:VectorToWorldSpace(vec3(1, 0, 0))
		local downNormal = partCornerCF:VectorToWorldSpace(vec3(0, 0, -1))
		return rightNormal, downNormal
	elseif surfaceAssignment == Enum.NormalId.Bottom then
		local rightNormal = partCornerCF:VectorToWorldSpace(vec3(-1, 0, 0))
		local downNormal = partCornerCF:VectorToWorldSpace(vec3(0, 0, -1))
		return rightNormal, downNormal
	elseif surfaceAssignment == Enum.NormalId.Right then
		local rightNormal = partCornerCF:VectorToWorldSpace(vec3(0, 0, -1))
		local downNormal = partCornerCF:VectorToWorldSpace(vec3(0, -1, 0))
		return rightNormal, downNormal
	elseif surfaceAssignment == Enum.NormalId.Left then
		local rightNormal = partCornerCF:VectorToWorldSpace(vec3(0, 0, 1))
		local downNormal = partCornerCF:VectorToWorldSpace(vec3(0, -1, 0))
		return rightNormal, downNormal
	elseif surfaceAssignment == Enum.NormalId.Back then
		local rightNormal = partCornerCF:VectorToWorldSpace(vec3(1, 0, 0))
		local downNormal = partCornerCF:VectorToWorldSpace(vec3(0, -1, 0))
		return rightNormal, downNormal
	elseif surfaceAssignment == Enum.NormalId.Front then
		local rightNormal = partCornerCF:VectorToWorldSpace(vec3(-1, 0, 0))
		local downNormal = partCornerCF:VectorToWorldSpace(vec3(0, -1, 0))
		return rightNormal, downNormal
	end
end

-- Returns WorldCFrame
@native
function TopologyHelper.calculateBroadPatchWorldPosition(patchSurfaceGui: SurfaceGui, patchImageLabel: ImageLabel, partInstance: BasePart, surfaceAssignment: Enum.NormalId, partCornerCF: CFrame)
	if surfaceAssignment == Enum.NormalId.Top then
		local pixelsPerStud = patchSurfaceGui.PixelsPerStud
		local patchImageWorldSpacePos = partCornerCF * cf(patchImageLabel.Position.Y.Offset / pixelsPerStud, 0, -patchImageLabel.Position.X.Offset / pixelsPerStud)
		return patchImageWorldSpacePos

	elseif surfaceAssignment == Enum.NormalId.Bottom then
		local pixelsPerStud = patchSurfaceGui.PixelsPerStud
		local patchImageWorldSpacePos = partCornerCF * cf(-patchImageLabel.Position.Y.Offset / pixelsPerStud, 0, -patchImageLabel.Position.X.Offset / pixelsPerStud)
		return patchImageWorldSpacePos

	elseif surfaceAssignment == Enum.NormalId.Right then
		local pixelsPerStud = patchSurfaceGui.PixelsPerStud
		local patchImageWorldSpacePos = partCornerCF * cf(0, -patchImageLabel.Position.Y.Offset / pixelsPerStud, -patchImageLabel.Position.X.Offset / pixelsPerStud)
		return patchImageWorldSpacePos
		
	elseif surfaceAssignment == Enum.NormalId.Left then
		local pixelsPerStud = patchSurfaceGui.PixelsPerStud
		local patchImageWorldSpacePos = partCornerCF * cf(0, -patchImageLabel.Position.Y.Offset / pixelsPerStud, patchImageLabel.Position.X.Offset / pixelsPerStud)
		return patchImageWorldSpacePos

	elseif surfaceAssignment == Enum.NormalId.Back then
		local pixelsPerStud = patchSurfaceGui.PixelsPerStud
		local patchImageWorldSpacePos = partCornerCF * cf(patchImageLabel.Position.X.Offset / pixelsPerStud, -patchImageLabel.Position.Y.Offset / pixelsPerStud, 0)
		return patchImageWorldSpacePos

	elseif surfaceAssignment == Enum.NormalId.Front then
		local pixelsPerStud = patchSurfaceGui.PixelsPerStud
		local patchImageWorldSpacePos = partCornerCF * cf(-patchImageLabel.Position.X.Offset / pixelsPerStud, -patchImageLabel.Position.Y.Offset / pixelsPerStud, 0)
		return patchImageWorldSpacePos
	end
end

@native
function TopologyHelper.calculateWorldSpaceOffset(xPixel: number, yPixel: number, pixelsPerStud: number, surface: Enum.NormalId, narrowToBroadFactor: number)
	local yPixelOffset = (yPixel * narrowToBroadFactor) / pixelsPerStud
	local xPixelOffset = (xPixel * narrowToBroadFactor) / pixelsPerStud

	if surface == Enum.NormalId.Top then
		return cf( yPixelOffset, 0, -xPixelOffset )

	elseif surface == Enum.NormalId.Bottom then
		return cf( -yPixelOffset, 0, -xPixelOffset )

	elseif surface == Enum.NormalId.Right then
		return cf( 0, -yPixelOffset, -xPixelOffset )

	elseif surface == Enum.NormalId.Left then
		return cf( 0, -yPixelOffset, xPixelOffset )

	elseif surface == Enum.NormalId.Back then
		return cf( xPixelOffset, -yPixelOffset, 0 )

	elseif surface == Enum.NormalId.Front then
		return cf( -xPixelOffset, -yPixelOffset, 0 )
	end
end

@native
function TopologyHelper.worldToPixelSpace(xPixel: number, yPixel: number, pixelsPerStud: number, surface: Enum.NormalId, narrowToBroadFactor: number)
	local yPixelOffset = (yPixel * narrowToBroadFactor) / pixelsPerStud
	local xPixelOffset = (xPixel * narrowToBroadFactor) / pixelsPerStud
	
	local yPixelOffset = (yPixel / pixelsPerStud) * narrowToBroadFactor

	if surface == Enum.NormalId.Top then
		return cf( yPixelOffset, 0, -xPixelOffset )

	elseif surface == Enum.NormalId.Bottom then
		return cf( -yPixelOffset, 0, -xPixelOffset )

	elseif surface == Enum.NormalId.Right then
		return cf( 0, -yPixelOffset, -xPixelOffset )

	elseif surface == Enum.NormalId.Left then
		return cf( 0, -yPixelOffset, xPixelOffset )

	elseif surface == Enum.NormalId.Back then
		return cf( xPixelOffset, -yPixelOffset, 0 )

	elseif surface == Enum.NormalId.Front then
		return cf( -xPixelOffset, -yPixelOffset, 0 )
	end
end

@native
function TopologyHelper.calculateWorldSpacePixelPos(BroadSurfacePatchCF: CFrame, xPixel: number, yPixel: number, pixelsPerStud: number, surface: Enum.NormalId, narrowToBroadFactor: number)
	local worldSpacePixelCoord = BroadSurfacePatchCF * TopologyHelper.calculateWorldSpaceOffset(xPixel, yPixel, pixelsPerStud, surface, narrowToBroadFactor)
	return worldSpacePixelCoord
end

function TopologyHelper.setCornerCF(canvasObject)
	if canvasObject.Surface == Enum.NormalId.Top then
		local partSurfaceSizeX, partSurfaceSizeY = TopologyHelper.calculateSurfaceDimensions(canvasObject.Part, canvasObject.Surface)
		local yOffset = canvasObject.Part.Size.Y/2
		canvasObject.PartCornerCF = canvasObject.Part.CFrame * cf(-partSurfaceSizeY/2, yOffset, partSurfaceSizeX/2)
		canvasObject.SurfaceGui:SetAttribute("PartCornerCF", canvasObject.PartCornerCF)
		
	elseif canvasObject.Surface == Enum.NormalId.Bottom then
		local partSurfaceSizeX, partSurfaceSizeY = TopologyHelper.calculateSurfaceDimensions(canvasObject.Part, canvasObject.Surface)
		local yOffset = (canvasObject.Part.Size.Y/2) * -1
		canvasObject.PartCornerCF = canvasObject.Part.CFrame * cf(partSurfaceSizeY/2, yOffset, partSurfaceSizeX/2)
		canvasObject.SurfaceGui:SetAttribute("PartCornerCF", canvasObject.PartCornerCF)

	elseif canvasObject.Surface == Enum.NormalId.Right then
		local partSurfaceSizeX, partSurfaceSizeY = TopologyHelper.calculateSurfaceDimensions(canvasObject.Part, canvasObject.Surface)
		local xOffset = canvasObject.Part.Size.X / 2
		canvasObject.PartCornerCF = canvasObject.Part.CFrame * cf(xOffset, partSurfaceSizeY/2, partSurfaceSizeX/2)
		canvasObject.SurfaceGui:SetAttribute("PartCornerCF", canvasObject.PartCornerCF)

	elseif canvasObject.Surface == Enum.NormalId.Left then
		local partSurfaceSizeX, partSurfaceSizeY = TopologyHelper.calculateSurfaceDimensions(canvasObject.Part, canvasObject.Surface)
		local xOffset = (canvasObject.Part.Size.X / 2) * -1
		canvasObject.PartCornerCF = canvasObject.Part.CFrame * cf(xOffset, partSurfaceSizeY/2, -partSurfaceSizeX/2)
		canvasObject.SurfaceGui:SetAttribute("PartCornerCF", canvasObject.PartCornerCF)

	elseif canvasObject.Surface == Enum.NormalId.Back then
		local partSurfaceSizeX, partSurfaceSizeY = TopologyHelper.calculateSurfaceDimensions(canvasObject.Part, canvasObject.Surface)
		local zOffset = (canvasObject.Part.Size.Z / 2)
		canvasObject.PartCornerCF = canvasObject.Part.CFrame * cf(-partSurfaceSizeX/2, partSurfaceSizeY/2, zOffset)
		canvasObject.SurfaceGui:SetAttribute("PartCornerCF", canvasObject.PartCornerCF)

	elseif canvasObject.Surface == Enum.NormalId.Front then
		local partSurfaceSizeX, partSurfaceSizeY = TopologyHelper.calculateSurfaceDimensions(canvasObject.Part, canvasObject.Surface)
		local zOffset = (canvasObject.Part.Size.Z / 2) * -1
		canvasObject.PartCornerCF = canvasObject.Part.CFrame * cf(partSurfaceSizeX/2, partSurfaceSizeY/2, zOffset)
		canvasObject.SurfaceGui:SetAttribute("PartCornerCF", canvasObject.PartCornerCF)
	end
end


--# Finalize
return TopologyHelper
