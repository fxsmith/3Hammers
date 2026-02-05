local vpnMenu = hs.menubar.new()

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
                -- Debug to Console:
                -- print("Checking " .. inf)
                
                -- Check 1: IPv4
                if details.IPv4 then
                    -- print("  " .. inf .. " has IPv4")
                    return true, inf
                end
                
                -- Check 2: Global IPv6
                if details.IPv6 and details.IPv6.Addresses then
                    for _, addr in ipairs(details.IPv6.Addresses) do
                        if not string.match(addr, "^fe80:") then
                            -- print("  " .. inf .. " has Global IPv6")
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
        vpnMenu:setTitle("🔒 VPN")
        vpnMenu:setTooltip("VPN Connected via " .. iface)
    else
        vpnMenu:setTitle("🔓 No VPN")
        vpnMenu:setTooltip("VPN Disconnected")
    end
end

-- Update every 3 seconds
hs.timer.doEvery(3, updateVPNStatus)

-- Initial check
updateVPNStatus()

return vpnMenu