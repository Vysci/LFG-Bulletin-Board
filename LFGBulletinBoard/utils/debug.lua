local tocName, shared = ...
local profilingCache = {}
local debugHeader = KYRIAN_BLUE_COLOR
    :WrapTextInColorCode('[' .. tocName .. ']:');
local function print(...)
    return _G.print(debugHeader, ...)
end
---@param key string
local function benchMarkStart(key)
    local _debugstart = debugprofilestop()
    local cache = profilingCache[key] or {};
    cache.start = _debugstart
    profilingCache[key] = cache
end
benchMarkStart("Full Addon Load")
---@param key string
local function benchMarkPrint(key)
    local cache = profilingCache[key];
    if not cache then
        print("No cache for key: ", key)
        return
    end
    print(("%s took: %.4fms | avg: %.4fms | samples: %i"):format(key, cache.elapsed, cache.avg, cache.samples))
end

---@param key string
---@param abort boolean # if true, the cache entry will be removed
---@param print boolean # if true, profiling data will be printed
local function benchMarkStop(key, abort, print)
    local _debugend = debugprofilestop()
    local cache = profilingCache[key];
    if not cache then
        print("No cache for key: ", key)
        return
    end
    if abort then
        return
    end
    cache.stop = _debugend
    cache.elapsed = cache.stop - cache.start
    cache.samples = (cache.samples or 0) + 1
    cache.avg = cache.avg and (cache.avg + cache.elapsed) / 2 or cache.elapsed
    profilingCache[key] = cache
    if print then
        benchMarkPrint(key)
    end
end

local function profilefunc(funcOrTable, keyOrMember)
    local result
    if type(funcOrTable) == "function" then
        assert(type(keyOrMember) == "string", "arg2; profiling cache key must be a string")
        benchMarkStart(keyOrMember)
        result = { pcall(funcOrTable) }
    else
        assert(type(funcOrTable) == "table",
            "arg1 must be either a function reference or a table to query for a function")
        assert(type(keyOrMember) == "string", "arg2; table member functions key must be a string")
        local func = funcOrTable[keyOrMember]
        assert(type(func) == "function", "arg2; table member must be a function")
        benchMarkStart(keyOrMember)
        result = { pcall(func, funcOrTable) }
    end
    local isOk = result[1]
    benchMarkStop(keyOrMember, not isOk)
    if isOk then
        benchMarkPrint(keyOrMember)
    end
    if isOk then -- all ok
        return unpack(result, 2)
    else         -- error
        print("Profiling failed: Error in function: ", result[2])
        error(result[2])
    end
end

shared.benchMarkStart = benchMarkStart
shared.benchMarkStop = benchMarkStop
shared.benchMarkPrint = benchMarkPrint
shared.profilefunc = profilefunc
shared.print = print
