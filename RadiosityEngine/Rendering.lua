--# Point
local Rendering = {}


--# Include
local Modules = script.Parent
local MathHelper = require(Modules:WaitForChild("MathHelper"))
local TopologyHelper = require(Modules:WaitForChild("TopologyHelper"))


--# Quick References
local vec2, cf, vec3, udim2, c3, mr, mp, sqrt, abs, clamp, ceil, pi, vec3FromNormalId = Vector2.new, CFrame.new, Vector3.new, UDim2.new, Color3.new, math.random, math.pow, math.sqrt, math.abs, math.clamp, math.ceil, math.pi, Vector3.FromNormalId
local clamp, max, min, abs = math.clamp, math.max, math.min, math.abs


--# Variables
local fullBrightVec3 = vec3(1, 1, 1)

local reflectionIncAmount = 1.99
local reflectionIncAmountIndirect = 0.8
local reflectionIncAmountColor = 1.99
local reflectionAOColorAccum = vec3(1, 1, 1)
local reflectionIncAmountColorAO = 0.35
local reflectionIncAmountAO = 0.93
local reflectionIncAmountAOVec = vec3(reflectionIncAmountAO, reflectionIncAmountAO, reflectionIncAmountAO)
local reflectionLimit = 2


--# Lighting Calculations
function calculateIndirectLightingContribution(sunRayDirection, sunRadius: number, totalLightContribution: number, accumulatedColor: number, worldSpaceNormal: Vector3, worldSpacePixelCoord: CFrame, pixelOffset: number, sampleIndex: number, samplesPerPixel: number, pixelSamplesScale: number, randomSamplingEnabled: boolean, rayDistance: number, initRaycastParams: RaycastParams, sunDirection: Vector3)
	local reflectionRayResult = nil
	local reflectionAccumColor = vec3(0, 0, 0)

	local finalTotalContribution = 0
	local finalAccumColor = vec3(0, 0, 0)

	local rayOrigin = worldSpacePixelCoord.Position + worldSpaceNormal * 0.0003

	-- Initial cosine-weighted sampling
	--local reflectionDirection = TopologyHelper.calculateCosineWeightedHemisphereSample(worldSpaceNormal, sampleIndex, samplesPerPixel, randomSamplingEnabled).Unit
	local reflectionDirection = (worldSpaceNormal + MathHelper.randomUnitVector()).Unit
	local reflectionNormal = worldSpaceNormal
	local reflectionCount = 0
	local canBounce = true

	while canBounce do
		local lastDist: number
		if reflectionRayResult then
			lastDist = reflectionRayResult.Distance
		end

		-- Perform raycasting from the origin along the reflection direction
		reflectionRayResult = workspace:Raycast(rayOrigin, reflectionDirection * rayDistance)
		
		local cosTheta = math.max(0.2, reflectionNormal:Dot(reflectionDirection))
		local pdfFactor = cosTheta / math.pi  -- Importance sampling PDF factor

		if reflectionRayResult then
			local hitColor = MathHelper.col3ToVec3(reflectionRayResult.Instance.Color)

			-- Handle if the ray hits an emissive light source
			local isLight = false
			local myLight = nil

			for _, items in reflectionRayResult.Instance:GetChildren() do
				if items:IsA("Light") then
					isLight = true
					myLight = items
				end
			end

			if isLight then
				local lightFixedAttenuation = (reflectionRayResult.Distance * reflectionRayResult.Distance)
				local attenuation = 1 / lightFixedAttenuation
				attenuation = math.clamp(attenuation * (myLight.Range * 8), 0, 0.5)

				finalTotalContribution += 2 * attenuation * pdfFactor
				finalAccumColor += hitColor * reflectionIncAmountColor * reflectionAOColorAccum * attenuation * pdfFactor
				canBounce = false  -- Stop bouncing after hitting a light source
				reflectionCount = reflectionLimit  -- Ensure reflection limit is reached
			else
				-- If not a light, bounce the reflection ray for indirect lighting
				local reflectionToSun = nil
				if sunRayDirection then
					local newSunDir = sunRayDirection.Unit
					reflectionToSun = workspace:Raycast(reflectionRayResult.Position + reflectionRayResult.Normal * 0.0001, newSunDir * rayDistance)
					canBounce = false
				end

				-- Apply lighting if the reflection ray doesn't reach the sun
				if not reflectionToSun then
					finalTotalContribution += reflectionIncAmount * pdfFactor
					finalAccumColor += hitColor * reflectionIncAmountColor * pdfFactor
				else
					finalAccumColor += vec3(hitColor.X, hitColor.Y, hitColor.Z) * reflectionIncAmountColorAO * pdfFactor
					
					-- Apply ambient occlusion effect for blocked rays
					-- I commented this part out because indirect lighting already simulates this. You can uncomment if you want more prominent AO, but it's usually not necessary.
					--local attenuation = 1 / (reflectionRayResult.Distance * 1.6)
					--attenuation = math.min(0.25, attenuation)
					--attenuation = math.max(0.1, attenuation)
					--finalTotalContribution -= reflectionIncAmountAO * attenuation
					--finalAccumColor -= reflectionIncAmountAOVec * attenuation

					-- Update reflection direction for next bounce
					reflectionDirection = TopologyHelper.calculateCosineWeightedHemisphereSample(reflectionRayResult.Normal, sampleIndex, samplesPerPixel, randomSamplingEnabled).Unit
					rayOrigin = reflectionRayResult.Position + reflectionRayResult.Normal * 0.0001
					reflectionNormal = reflectionRayResult.Normal
				end

				-- Increment the reflection bounce count
				reflectionCount += 1
			end
		else
			-- For rays that miss objects, add indirect lighting contribution
			finalTotalContribution += reflectionIncAmountIndirect * pdfFactor
			finalAccumColor += vec3(reflectionIncAmountIndirect, reflectionIncAmountIndirect, reflectionIncAmountIndirect) * pdfFactor
			canBounce = false
		end

		-- Limit reflection bounces
		if reflectionCount > reflectionLimit then
			canBounce = false
		end
	end

	-- Add the final contribution to the total lighting
	return finalTotalContribution, finalAccumColor
end


function Rendering.calculatePixelCombinedBrightness(initRaycastParams: RaycastParams, worldSpacePixelCoord: CFrame, sunRadius: number, rayDistance: number, surface: Enum.NormalId, pixelBrightness: number, pixelColor: Vector3, partRotationCF: CFrame, partCF: CFrame, sunDirection: Vector3, pixelSamplesScale: number, samplesPerPixel: number, lightsContainer: {}, bakeGlobalLights: boolean, bakeLocalLights: boolean, sampleIndex: number, randomSamplingEnabled: boolean, pixelToWorldFactor: number, worldSpaceNormal: Vector3, pixelOffset: number, indirectLightingEnabled: boolean, directLightingEnabled: boolean, samplesPerAxis: number)
	-- Calculate the up vector, tangent, and bitangent
	--local rayOrigin = TopologyHelper.calculatePixelSamplePoint(worldSpaceNormal, worldSpacePixelCoord, pixelOffset, sampleIndex, samplesPerPixel, randomSamplingEnabled).Position
	local rayOrigin = worldSpacePixelCoord.Position + worldSpaceNormal * 0.0003
	
	-- Initialize total brightness and color contributions
	local totalLightContribution = 0
	local accumulatedColor = vec3(0, 0, 0)
	local totalLightFactor = 0
	local currentGlobalDepth = 0
	local canContributeLight = false

	-- Calculate global light contribution
	local lightFacingFactor = sunDirection:Dot(worldSpaceNormal)
	
	local canDoMultipleLightSamples = true
	if samplesPerPixel <= 1 or sunRadius <= 0 then
		canDoMultipleLightSamples = false
	end
	
	local canRenderGlobalLight = true
	local sunRayDirection = nil
	
	if bakeGlobalLights then
		totalLightFactor += 1
		
		local rayDirection = nil
		if canDoMultipleLightSamples then
			if randomSamplingEnabled then
				rayDirection = sunDirection + MathHelper.randomUnitVector() * sunRadius
			else
				rayDirection = TopologyHelper.calculateGlobalLightSampleVector(sunDirection, sunRadius, sampleIndex, samplesPerAxis)
			end
		else
			rayDirection = sunDirection
		end
		sunRayDirection = rayDirection.Unit
		
		if directLightingEnabled == true then
			local worldRaycastResult = workspace:Raycast(rayOrigin, sunRayDirection * rayDistance, initRaycastParams)
			
			if lightFacingFactor > 0 then
				if not worldRaycastResult then
					accumulatedColor += (fullBrightVec3 * lightFacingFactor * 1)
					totalLightContribution += (lightFacingFactor * 1)
				else
					canRenderGlobalLight = false
				end
			else
				canRenderGlobalLight = false
			end
		end
		
	end
	
	if indirectLightingEnabled == true then
		-- Perform AO instead
		local canDoIndirect = false
		if directLightingEnabled == false then
			canDoIndirect = true
		else
			if canRenderGlobalLight == false then
				canDoIndirect = true
			end
		end
		
		if canDoIndirect then
			local finalTotalContribution, finalAccumColor = calculateIndirectLightingContribution(sunRayDirection, sunRadius, totalLightContribution, accumulatedColor, worldSpaceNormal, worldSpacePixelCoord, pixelOffset, sampleIndex, samplesPerPixel, pixelSamplesScale, randomSamplingEnabled, rayDistance, initRaycastParams, sunDirection)
			
			totalLightContribution += finalTotalContribution
			accumulatedColor += finalAccumColor
		end
	end

	-- Calculate local light contributions
	if directLightingEnabled == false then bakeLocalLights = false end
	
	if bakeLocalLights then
		for _, light in pairs(lightsContainer) do
			totalLightFactor += 1
			
			local lightPart = light.Parent
			local surfaceLightPos = TopologyHelper.calculateLightSamplePoint(light, sampleIndex, samplesPerPixel, samplesPerAxis, randomSamplingEnabled)
			local rayDirection = (surfaceLightPos - rayOrigin)
			local distance = rayDirection.Magnitude
			rayDirection = rayDirection.Unit
			local lightSurfaceNormal: Vector3 -- For surface and spot lights only
			local lightFixedAttenuation = (distance * distance)
			lightFacingFactor = worldSpaceNormal:Dot(rayDirection)
			local lightBrightness = light.Brightness
			
			if lightFacingFactor > 0 then
				if distance < lightFixedAttenuation then -- I don't have a better way to calculate light distance atm
					local skipLight = false
					
					-- Make sure that our light is within visible FOV of light
					if light:IsA("SurfaceLight") or light:IsA("SpotLight") then
						-- Calculate the dot product between the surface normal and the ray direction
						lightSurfaceNormal = light:GetAttribute("SurfaceNormal")
						local dotProduct = rayDirection:Dot(lightSurfaceNormal)
						
						if ( dotProduct <= -0.05 ) then
						else
							skipLight = true
						end
					end
					
					-- We can continue lighting the pixel if the light is in FOV
					if skipLight == false then
						local raycastResult = workspace:Raycast(rayOrigin, rayDirection * distance * 1.01, initRaycastParams)
						
						if raycastResult then
							local hasLight = false
							for _, child in raycastResult.Instance:GetChildren() do
								if child:IsA("Light") then
									hasLight = true
								end
							end
							
							if hasLight then
								-- FULL: we add light instead of removing it
								local attenuation = 1 / lightFixedAttenuation
								attenuation = clamp(attenuation * (light.Range * 8), 0, 0.5)
								
								totalLightContribution += attenuation * lightFacingFactor
								accumulatedColor += (MathHelper.col3ToVec3(light.Color) * attenuation) * lightFacingFactor
							end
						end
					end
					
				end
			end
			
		end
	end
	
	-- Normalize the total light contribution by the total number of samples
	local normalizedLightContribution = totalLightContribution * pixelSamplesScale

	-- Adjust pixel brightness and color based on total light contribution
	pixelBrightness = clamp(pixelBrightness + normalizedLightContribution, 0, 1)
	pixelColor = MathHelper.clampVec3(pixelColor + (accumulatedColor * pixelSamplesScale), 0, 1)

	return pixelBrightness, pixelColor
end


--# Finalize
return Rendering