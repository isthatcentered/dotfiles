local pending = false

local function showStatus(connected, tooltip)
  barWidget.setText("AWARE")
  barWidget.setGlyph("circle-filled")
  barWidget.setGlyphColor(connected and "#22c55e" or "#ef4444")
  barWidget.setTooltip(tooltip)
end

showStatus(false, "Checking AWARE Wi-Fi and VPN…")
noctalia.setUpdateInterval(3000)

function update()
  if pending then return end
  pending = true
  local accepted = noctalia.runAsync(
    "LC_ALL=C nmcli -g connection.uuid,connection.secondaries connection show 'AWARE Wi-Fi' && LC_ALL=C nmcli -t -f UUID,TYPE,STATE connection show --active",
    function(result)
      pending = false
      if result.exitCode ~= 0 or result.timedOut or result.stdoutTruncated then
        showStatus(false, "Unable to check AWARE Wi-Fi and VPN")
        return
      end
      local wifiUuid, secondaries, connections = string.match(result.stdout, "^([^\n]+)\n([^\n]*)\n(.*)$")
      if not wifiUuid then
        showStatus(false, "Unable to read AWARE Wi-Fi profile")
        return
      end
      local active = {}
      for uuid, kind, state in string.gmatch(connections, "([^:\r\n]+):([^:\r\n]+):([^:\r\n]+)") do
        if state == "activated" then
          active[uuid] = kind
        end
      end
      if active[wifiUuid] ~= "802-11-wireless" then
        showStatus(false, "AWARE Wi-Fi is not connected")
        return
      end
      local vpnCount = 0
      for uuid in string.gmatch(secondaries, "[^,; %s]+") do
        vpnCount = vpnCount + 1
        if active[uuid] ~= "vpn" then
          showStatus(false, "AWARE Wi-Fi connected; required VPN is not connected")
          return
        end
      end
      if vpnCount == 0 then
        showStatus(false, "AWARE Wi-Fi has no VPN configured")
        return
      end
      showStatus(true, "AWARE Wi-Fi and its required VPN are connected")
    end
  )
  if not accepted then
    pending = false
    showStatus(false, "Unable to check AWARE Wi-Fi and VPN")
  end
end

function onClick()
  noctalia.runAsync("noctalia msg panel-toggle control-center network")
end
