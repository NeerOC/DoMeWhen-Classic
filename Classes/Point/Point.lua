local DMW = DMW
local LibDraw = LibStub("LibDraw-1.0")
local Point = DMW.Classes.Point

function Point:New(x, y, z)
    self.X = x
    self.Y = y
    self.Z = z
end

function Point:ToString()
    local dist = GetDistanceBetweenPositions(
        DMW.Player.PosX,
        DMW.Player.PosY,
        DMW.Player.PosZ,
        self.X,
        self.Y,
        self.Z
    )

    return '[X: ' .. Round(self.X) .. '] ' ..
        '[Y: ' .. Round(self.Y) .. '] ' ..
        '[Z: ' .. Round(self.Z) .. '] ' ..
        '[Distance: ' .. Round(dist) .. ']'
end

function Point:Draw(radius, text)
    LibDraw.Text(text, "GameFontNormalLarge", self.X, self.Y, self.Z)
    if DMW.Settings.profile.Grind.drawCircles then LibDraw.GroundCircle(self.X, self.Y, self.Z, radius) end
end

function Point:Distance(point)
    return GetDistanceBetweenPositions(
        self.X,
        self.Y,
        self.Z,
        point.X,
        point.Y,
        point.Z
    )
end

function Point:TwoDimensionalDistance(point)
    return sqrt(
        (self.X - point.X) ^ 2 +
        (self.Y - point.Y) ^ 2
    )
end

function Point:Near(point, yards)
    return self:Distance(point) < yards
end

function Point:NearAny(points, yards)
    for i = 1, #points do
        point = points[i]

        if self:Distance(point) < yards then
            return true
        end
    end

    return false
end
