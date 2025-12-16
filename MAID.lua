--!strict
-- Maid.lua
-- A class for managing the cleanup of events, objects, and tasks.

local Maid = {}
Maid.ClassName = "Maid"
Maid.__index = Maid

-- Type Definitions for Luau
export type MaidTask = function | RBXScriptConnection | { Destroy: (any) -> () } | { destroy: (any) -> () }
export type Maid = {
	GiveTask: (self: Maid, task: MaidTask) -> number,
	DoCleaning: (self: Maid) -> (),
	Destroy: (self: Maid) -> (),
	[any]: any
}

-- Constructor
function Maid.new(): Maid
	local self = setmetatable({}, Maid)
	self._tasks = {}
	return self :: any
end

--[[
	Adds a task to the Maid.
	Returns an ID (number) that can be used to remove the task later if needed.
]]
function Maid:GiveTask(task: MaidTask): number
	if not task then
		error("Task cannot be false or nil", 2)
	end

	local taskId = #self._tasks + 1
	self._tasks[taskId] = task

	-- If the task is a table with a Destroy method (like a custom class),
	-- we ensure it's compatible.
	if type(task) == "table" and (not (task :: any).Destroy and not (task :: any).destroy) then
		warn("[Maid] Given task is a table but has no Destroy method")
	end

	return taskId
end

--[[
	Cleans up all tasks.
	Disconnects events, Destroys instances, and calls functions.
]]
function Maid:DoCleaning()
	local tasks = self._tasks

	-- Loop backwards to allow tasks to be removed safely during iteration
	-- and to respect Last-In-First-Out (LIFO) order which is often safer
	for i = #tasks, 1, -1 do
		local task = tasks[i]
		
		if typeof(task) == "RBXScriptConnection" then
			task:Disconnect()
		elseif typeof(task) == "function" then
			task()
		elseif typeof(task) == "Instance" then
			task:Destroy()
		elseif type(task) == "table" then
			if (task :: any).Destroy then
				(task :: any):Destroy()
			elseif (task :: any).destroy then
				(task :: any):destroy()
			end
		end
		
		tasks[i] = nil
	end
end

--[[
	Alias for DoCleaning.
	Useful for treating the Maid itself as a task for another Maid.
]]
function Maid:Destroy()
	self:DoCleaning()
end

--[[
	Allows assigning tasks via standard table syntax:
	maid.Key = connection
]]
function Maid:__newindex(index: any, newTask: MaidTask)
	if Maid[index] ~= nil then
		rawset(self, index, newTask)
	else
		-- If a task already exists at this key, clean it up first
		local oldTask = self._tasks[index]
		if oldTask then
			if typeof(oldTask) == "RBXScriptConnection" then
				oldTask:Disconnect()
			elseif typeof(oldTask) == "function" then
				oldTask()
			elseif typeof(oldTask) == "Instance" then
				oldTask:Destroy()
			elseif type(oldTask) == "table" then
				if (oldTask :: any).Destroy then
					(oldTask :: any):Destroy()
				end
			end
		end

		self._tasks[index] = newTask
	end
end

return Maid