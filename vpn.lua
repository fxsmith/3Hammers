local M = {}
M.menu = hs.menubar.new()

-- Configuration
local specificInterface = false -- e.g. "utun1"

local function isVPNConnected()
    local interfaces = hs.network.interfaces()
    for _, inf in ipairs(interfaces) do
        -- Check for utun, ppp, ipsec, OR if the user specified a specific interface
        if (specificInterface and inf == specificInterface) or 
           (not specificInterface and (string.find(inf, "utun") or string.find(inf, "ppp") or string.find(inf, "ipsec"))) then
            
            local details = hs.network.interfaceDetails(inf)
            
            if details then
                print("Checking interface: " .. inf)
                if details.IPv4 then
                    print("  IPv4 found: " .. hs.inspect(details.IPv4))
                else
                    print("  No IPv4 table")
                end

                if details.IPv6 then
                    print("  IPv6 found: " .. hs.inspect(details.IPv6))
                else
                    print("  No IPv6 table")
                end

                -- Check 1: IPv4 (Must have actual addresses)
                if details.IPv4 and details.IPv4.Addresses and #details.IPv4.Addresses > 0 then
                    print("  -> MATCH: valid IPv4 found")
                    return true, inf
                end
                
                -- Check 2: Global IPv6
                if details.IPv6 and details.IPv6.Addresses then
                    for _, addr in ipairs(details.IPv6.Addresses) do
                        -- Ignore link-local (fe80:...) and localhost (::1)
                        if not string.match(addr, "^fe80:") and addr ~= "::1" then
                            print("  -> MATCH: valid global IPv6 found: " .. addr)
                            return true, inf
                        end
                    end
                end
            end
        end
    end
    return false, nil
end

local function updateVPNStatus()
    local connected, iface = isVPNConnected()
    
    if connected then
        M.menu:setTitle("🔒 VPN")
        M.menu:setTooltip("VPN Connected via " .. iface)
    else
        M.menu:setTitle("🔓 No VPN")
        M.menu:setTooltip("VPN Disconnected")
    end
end

-- Update every 15 seconds
M.timer = hs.timer.doEvery(15, updateVPNStatus)

-- Initial check
updateVPNStatus()

return M