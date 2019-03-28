local bit = require("bit")
local tobit = bit.tobit
local bor = bit.bor
local band = bit.band
local rshift = bit.rshift
local lshift = bit.lshift

--
-- IP is a class representing a single IPv4 address as an array of bytes.
--

local IP = {}
IP.__index = IP

setmetatable(IP, {
    __call = function(cls, s)
        return cls.parse(s)
    end,
})

-- @internal
-- Parse IPv4 address (d.d.d.d)
-- Returns: 4-items byte array, representing each octet of the address
local parse_ipv4 = function(s)
    local a, b, c, d = s:match("^(%d+)%.(%d+)%.(%d+)%.(%d+)$")
    if a == nil then
        return nil
    end

    a, b, c, d = tobit(a), tobit(b), tobit(c), tobit(d)
    if a > 0xFF or b > 0xFF or c > 0xFF or d > 0xFF then
        return nil
    end

    return {a, b, c, d}
end

-- Parse IPv4 address and return an instance of the class
-- In the address in not valid, the function returns nil
function IP.parse(s)
    if s == nil or type(s) ~= "string" then
        return nil
    end

    local self = parse_ipv4(s)
    if self == nil then
        return nil
    end

    return setmetatable(self, IP)
end

--
-- SubnetSet class
-- Fast O(1) IPv4 lookup in CIDR block(s)
-- The basic implementation uses a trie to store CIDR blocks
--
-- TODO:
--   * Add path compression (use Radix tree)
--

local SubnetSet = {}
SubnetSet.__index = SubnetSet

setmetatable(SubnetSet, {
    __call = function(cls, ...)
        return cls.new(...)
    end,
})

-- Return an empty instance of SubnetSet class
function SubnetSet.new()
    local self = {
        root = {},
    }
    return setmetatable(self, SubnetSet)
end

-- @internal
-- Parse CIDR and return IP and number of bits (mask value)
local parse_cidr = function(cidr)
    local addr, nbits = cidr:match("^(.+)/(%d+)$")

    local ip = IP(addr)
    if ip == nil then
        return nil, nil, "invalid CIDR format"
    end

    local mask_nbits = tobit(nbits)
    if mask_nbits > 32 then
        return nil, nil, "invalid CIDR format"
    end

    return ip, mask_nbits
end

-- @internal
-- Return n-th bit of IPv4 address (counting right-to-left)
local get_bitn = function(ip, n)
    local ip4num = bor(lshift(ip[1], 24), lshift(ip[2], 16), lshift(ip[3], 8), ip[4])
    return band(rshift(ip4num, n), 1)
end

-- Insert CIDR block to SubnetSet
-- Return error if the CIDR is invalid
function SubnetSet:insert(cidr)
    local ip, mask_nbits, err = parse_cidr(cidr)
    if err ~= nil then
        return err
    end

    local next = self.root
    for i = 1, mask_nbits do
        local bi = get_bitn(ip, 32-i)+1 -- bit index starting from 1
        if next[3] ~= nil then
            return -- inserted subnet is a subset of an existing subnet in set
        end
        if next[bi] == nil then
            next[bi] = {}
        end
        next = next[bi]
    end
    next[1], next[2], next[3] = nil, nil, true
end

-- Test whether IP is contained in added CIDR block(s)
function SubnetSet:contains(ip)
    if type(ip) == "string" then
        ip = IP(ip)
    end
    if ip == nil then
        return false
    end

    local next = self.root
    for i = 1, 32 do
        local bi = get_bitn(ip, 32-i)+1 -- bit index starting from 1
        if next[3] ~= nil then
            return true
        end
        if next[bi] == nil then
            return false
        end
        next = next[bi]
    end

    return true
end

return {
    IP = IP,
    SubnetSet = SubnetSet,
}
