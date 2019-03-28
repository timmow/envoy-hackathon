local ip_utils = require('./ip_utils')
local SubnetSet = ip_utils.SubnetSet

local blocked_subnets = SubnetSet()
blocked_subnets:insert("10.10.0.0/16")

local function envoy_on_request(request_handle)
    request_handle:logInfo("LUA: envoy_on_request()")

    -- Check if IP is blocked
    local client_ip = request_handle:headers():get("x-client-ip")
    if client_ip ~= nil then
        if blocked_subnets:contains(client_ip) then
            request_handle:respond(
                {[":status"] = "403"},
                "access denied")
        end
    end
end

local function envoy_on_response(response_handle)
    -- response_handle:logInfo("LUA: envoy_on_response()")
end

return {
    envoy_on_request = envoy_on_request,
    envoy_on_response = envoy_on_response,
}
