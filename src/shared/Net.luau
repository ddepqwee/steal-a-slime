--!strict
-- Единая точка для RemoteEvent/RemoteFunction. Сервер создаёт, клиент ждёт.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Net = {}

local function folder(): Folder
	if RunService:IsServer() then
		local f = ReplicatedStorage:FindFirstChild("Remotes") :: Folder?
		if not f then
			local nf = Instance.new("Folder")
			nf.Name = "Remotes"
			nf.Parent = ReplicatedStorage
			return nf
		end
		return f
	end
	return ReplicatedStorage:WaitForChild("Remotes") :: Folder
end

local function get(name: string, className: string): Instance
	local f = folder()
	local r = f:FindFirstChild(name)
	if r then
		return r
	end
	if RunService:IsServer() then
		local inst = Instance.new(className)
		inst.Name = name
		inst.Parent = f
		return inst
	end
	return f:WaitForChild(name)
end

function Net.event(name: string): RemoteEvent
	return get(name, "RemoteEvent") :: RemoteEvent
end

function Net.func(name: string): RemoteFunction
	return get(name, "RemoteFunction") :: RemoteFunction
end

return Net
