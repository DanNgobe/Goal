--[[
  SafeMath.lua
  
  Safe mathematical utility functions to prevent common errors.
  Handles division by zero, vector normalization, and boundary checks.
]]

local SafeMath = {}

-- Safe division that returns a default value if divisor is zero
function SafeMath.SafeDivide(numerator, denominator, defaultValue)
  defaultValue = defaultValue or 0
  
  if not numerator or not denominator then
    return defaultValue
  end
  
  if math.abs(denominator) < 0.0001 then
    return defaultValue
  end
  
  return numerator / denominator
end

-- Safe vector normalization that returns a default direction if magnitude is zero
function SafeMath.SafeNormalize(vector, defaultDirection)
  defaultDirection = defaultDirection or Vector3.new(0, 0, 1)
  
  if not vector then
    return defaultDirection
  end
  
  local magnitude = vector.Magnitude
  
  if magnitude < 0.0001 then
    return defaultDirection
  end
  
  return vector / magnitude
end

-- Clamp a value between min and max
function SafeMath.Clamp(value, min, max)
  if not value then
    return min
  end
  
  return math.max(min, math.min(max, value))
end

-- Check if a position is within field bounds
function SafeMath.IsWithinBounds(position, fieldBounds)
  if not position or not fieldBounds then
    return false
  end
  
  return position.X >= fieldBounds.minX and
         position.X <= fieldBounds.maxX and
         position.Z >= fieldBounds.minZ and
         position.Z <= fieldBounds.maxZ
end

-- Clamp a position to field bounds
function SafeMath.ClampToBounds(position, fieldBounds)
  if not position or not fieldBounds then
    return position or Vector3.new(0, 0, 0)
  end
  
  local clampedX = SafeMath.Clamp(position.X, fieldBounds.minX, fieldBounds.maxX)
  local clampedZ = SafeMath.Clamp(position.Z, fieldBounds.minZ, fieldBounds.maxZ)
  
  return Vector3.new(clampedX, position.Y, clampedZ)
end

-- Safe distance calculation with validation
function SafeMath.SafeDistance(pos1, pos2)
  if not pos1 or not pos2 then
    return math.huge
  end
  
  return (pos2 - pos1).Magnitude
end

-- Safe dot product with validation
function SafeMath.SafeDot(vec1, vec2)
  if not vec1 or not vec2 then
    return 0
  end
  
  return vec1:Dot(vec2)
end

-- Check if a number is valid (not NaN or infinite)
function SafeMath.IsValidNumber(value)
  if not value then
    return false
  end
  
  if value ~= value then  -- NaN check
    return false
  end
  
  if value == math.huge or value == -math.huge then
    return false
  end
  
  return true
end

-- Safe square root
function SafeMath.SafeSqrt(value, defaultValue)
  defaultValue = defaultValue or 0
  
  if not value or value < 0 then
    return defaultValue
  end
  
  return math.sqrt(value)
end

return SafeMath
