--# Point
local MathHelper = {}


--# Quick References
local vec2, cf, vec3, udim2, c3, mr, mp, sqrt, abs, clamp, vec3FromNormalId = Vector2.new, CFrame.new, Vector3.new, UDim2.new, Color3.new, math.random, math.pow, math.sqrt, math.abs, math.clamp, Vector3.FromNormalId
local DOUBLE_PI = 2 * math.pi
MathHelper.EPSILON = 0.0001


--# Functions
@native
function MathHelper.lengthSquaredVec3(vector: Vector3)
	return mp(vector.Magnitude, 2)
end

@native
function MathHelper.randomDouble()
	return mr(-100000, 100000) * 0.00001
end

@native
function MathHelper.quickRandomDouble()
	return mr(-1000, 1000) * 0.001
end

@native
function MathHelper.randomPointInCircle(maxRadius: number)
	-- Generate a random point within the circle
	local randomRadiusX = MathHelper.quickRandomDouble() * maxRadius
	local randomTheta = MathHelper.randomDouble() * DOUBLE_PI
	local randomTheta2 = MathHelper.randomDouble() * DOUBLE_PI

	local xOffset = randomRadiusX * math.cos(randomTheta)
	local zOffset = randomRadiusX * math.sin(randomTheta2)
	return xOffset, zOffset
end

@native
function MathHelper.randomVec3()
	return vec3(MathHelper.randomDouble(), MathHelper.randomDouble(), MathHelper.randomDouble())
end

@native
function MathHelper.randomInUnitSphere()
	while true do
		local p = MathHelper.randomVec3()

		if (MathHelper.lengthSquaredVec3(p) < 1) then
			return p
		end
	end
end

@native
function MathHelper.randomUnitVector()
	return MathHelper.randomInUnitSphere().Unit
end

@native
function MathHelper.randomOnHemisphere(normal: Vector3)
	local onUnitHemisphere = MathHelper.randomUnitVector()
	if (onUnitHemisphere:Dot(normal) > 0.0) then -- In the same hemisphere as the normal
		return onUnitHemisphere
	else
		return -onUnitHemisphere
	end
end

@native
function MathHelper.linearToGamma(linearComponent: number)
	if (linearComponent > 0) then
		return math.pow(linearComponent, 0.7)
	else
		return 0
	end
end

@native
function MathHelper.lerpNum(a: number, b: number, t: number)
	return a + (b - a) * t
end

@native
function MathHelper.nearZero(vector: Vector3)
	local s = 1e-8
	return (vector.X < s) or (vector.Y < s) or (vector.Z < s)
end

@native
function MathHelper.col3ToVec3(color: Color3)
	return vec3(color.R, color.G, color.B)
end

@native
function MathHelper.vec3ToGamma(myVec: Vector3)
	return vec3(MathHelper.linearToGamma(myVec.X), MathHelper.linearToGamma(myVec.Y), MathHelper.linearToGamma(myVec.Z))
end

@native
function MathHelper.clampVec3(myVec: Vector3, minClamp: number, maxClamp: number)
	minClamp = minClamp or 0
	maxClamp = maxClamp or 1
	return vec3(clamp(myVec.X, minClamp, maxClamp), clamp(myVec.Y, minClamp, maxClamp), clamp(myVec.Z, minClamp, maxClamp))
end


--# Finalize
return MathHelper