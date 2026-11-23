-- ClipForge Bridge: talks to the local ClipForge bot server (python -m clipforge serve).
-- Studio asks once per plugin whether it may reach 127.0.0.1: allow it.

local HttpService = game:GetService("HttpService")

local Bridge = {}
Bridge.url = "http://127.0.0.1:7313"
Bridge.token = nil
Bridge.connected = false
Bridge.lastError = nil
Bridge.version = nil

local function friendly(err: string): string
	err = tostring(err)
	if string.find(err, "ConnectFail") or string.find(err, "refused") or string.find(err, "HttpError: Connect") then
		return "Bot server is not running. Start it with start-server.ps1 (or: python -m clipforge serve)."
	elseif string.find(err, "not enabled") or string.find(err, "permission") or string.find(err, "Permission") then
		return "Studio blocked the request: allow ClipForge to access 127.0.0.1 when Studio asks (Plugin Management)."
	elseif string.find(err, "Timedout") or string.find(err, "timed out") then
		return "The bot server did not answer in time."
	end
	return err
end

function Bridge.request(method: string, path: string, body: any?, timeout: number?)
	local headers = { ["Content-Type"] = "application/json", ["X-ClipForge-Client"] = "studio" }
	if Bridge.token and Bridge.token ~= "" then
		headers["Authorization"] = "Bearer " .. Bridge.token
	end
	local ok, res = pcall(function()
		return HttpService:RequestAsync({
			Url = Bridge.url .. path,
			Method = method,
			Headers = headers,
			Body = if body ~= nil then HttpService:JSONEncode(body) else nil,
		})
	end)
	if not ok then
		Bridge.lastError = friendly(res)
		return false, Bridge.lastError
	end
	local data = nil
	if res.Body and #res.Body > 0 then
		local okJ, decoded = pcall(HttpService.JSONDecode, HttpService, res.Body)
		if okJ then
			data = decoded
		end
	end
	if not res.Success then
		local msg = (type(data) == "table" and data.error) or ("HTTP " .. tostring(res.StatusCode))
		Bridge.lastError = msg
		return false, msg
	end
	Bridge.lastError = nil
	return true, data
end

function Bridge.health()
	local ok, data = Bridge.request("GET", "/api/health")
	Bridge.connected = ok and type(data) == "table" and data.name == "ClipForge"
	Bridge.version = Bridge.connected and data.version or nil
	return Bridge.connected, if ok then data else data
end

function Bridge.submit(payload)
	payload.client = payload.client or "studio"
	return Bridge.request("POST", "/api/jobs", payload)
end

function Bridge.jobs(limit: number?)
	local ok, data = Bridge.request("GET", "/api/jobs?limit=" .. tostring(limit or 25))
	if ok then
		return true, data.jobs, data.seq
	end
	return false, data
end

function Bridge.job(id: string)
	return Bridge.request("GET", "/api/jobs/" .. id)
end

function Bridge.result(id: string)
	return Bridge.request("GET", "/api/jobs/" .. id .. "/result")
end

function Bridge.delivered(id: string, info)
	return Bridge.request("POST", "/api/jobs/" .. id .. "/delivered", info or {})
end

function Bridge.cancel(id: string)
	return Bridge.request("DELETE", "/api/jobs/" .. id)
end

return Bridge
