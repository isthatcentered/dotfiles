local pending = false

local function showStatus(connected, tooltip)
  barWidget.setText("AWARE")
  barWidget.setGlyph("circle-filled")
  barWidget.setGlyphColor(connected and "#22c55e" or "#ef4444")
  barWidget.setTooltip(tooltip)
end

showStatus(false, "Checking AWARE Wi-Fi connection…")
noctalia.setUpdateInterval(3000)

function update()
  if pending then return end
  pending = true
  local accepted = noctalia.runAsync(
    "LC_ALL=C nmcli -t -f NAME,TYPE connection show --active",
    function(result)
      pending = false
      if result.exitCode ~= 0 or result.timedOut or result.stdoutTruncated then
        showStatus(false, "Unable to check AWARE Wi-Fi connection")
        return
      end
      local connected = false
      for line in string.gmatch(result.stdout, "[^\r\n]+") do
        if line == "AWARE Wi-Fi:802-11-wireless" then
          connected = true
          break
        end
      end
      showStatus(connected, connected and "Connected to AWARE Wi-Fi" or "Not connected to AWARE Wi-Fi")
    end
  )
  if not accepted then
    pending = false
    showStatus(false, "Unable to check AWARE Wi-Fi connection")
  end
end

function onClick()
  noctalia.runAsync("noctalia msg panel-toggle control-center network")
end
