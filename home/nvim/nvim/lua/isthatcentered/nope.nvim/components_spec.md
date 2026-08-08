each component only updates it's window into the buffer

local active_test = signal(nil)
local active_test_results = tests[active_test.key]

stack(
  columns(
    tree({

on_click = function(selected)
    active_test = selected
end, 
on_cursor = function()



end
      }), 
    right_display({
        active_test_results = active_test_results
      })
  )
)
