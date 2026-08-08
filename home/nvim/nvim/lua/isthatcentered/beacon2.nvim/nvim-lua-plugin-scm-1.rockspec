rockspec_format = '3.0'
-- TODO: Rename this file and set the package
package = "nvim-lua-plugin"
version = "scm-1"
source = {
  -- TODO: Update this URL
  url = "git+https://github.com/isthatcentered/nope.nvim"
}
dependencies = {
  -- Add runtime dependencies here
  -- e.g. "plenary.nvim",
}
test_dependencies = {
  "lua >= 5.1",
  "nlua",
  "busted >= 2.0"
}
build = {
  type = "builtin",
  copy_directories = {
    -- Add runtimepath directories, like
    -- 'plugin', 'ftplugin', 'doc'
    -- here. DO NOT add 'lua' or 'lib'.
  },
}
test = {
  type = "busted",
  directories = {
    "lua"
  }
}
