local project = require("cobol.project")

local root = vim.fn.tempname() .. "-cobol-project"
local nested = root .. "/src/programs"
vim.fn.mkdir(nested, "p")
vim.fn.writefile({ "{}" }, root .. "/.cobol.json")

assert(project.find_root(nested) == root, "project root discovery should find .cobol.json in a parent directory")

vim.fn.writefile({ vim.json.encode({
  source_format = "fixed",
  dialect = "ibm",
  compiler = "cobc-custom",
  copybook_paths = { "copy", "common/cpy" },
  compiler_args = { "-Wall", "-DTEST" },
}) }, root .. "/.cobol.json")
local profile = project.load(root)
assert(profile.source_format == "fixed", "project profile should load the source format")
assert(profile.dialect == "ibm", "project profile should load the GnuCOBOL dialect")
assert(profile.copybook_paths[2] == "common/cpy", "project profile should load Copybook paths")
vim.fn.mkdir(root .. "/copy", "p")
vim.fn.mkdir(root .. "/common/cpy", "p")
local args = project.compiler_args(profile, root, "check", "-")
assert(vim.deep_equal(args, {
  "-fsyntax-only", "-fdiagnostics-plain-output", "-fixed", "-std=ibm",
  "-I", root, "-I", root .. "/copy", "-I", root .. "/common/cpy",
  "-Wall", "-DTEST", "-",
}), "compiler arguments should share format, dialect, includes, and extras")
local settings = project.settings(root, {
  source_format = "auto",
  cobc_command = "cobc",
  cobc_extra_args = { "-DGLOBAL" },
  copybook_paths = { "." },
  diagnostics = { warnings = { "all", "no-obsolete" } },
})
assert(settings.compiler == "cobc-custom", "project settings should override the global compiler")
assert(settings.dialect == "ibm" and settings.source_format == "fixed", "project settings should override format and dialect")
assert(settings.copybook_dirs[2] == root .. "/copy", "relative Copybook paths should resolve from the project root")
vim.fn.writefile({ "{ invalid json" }, root .. "/.cobol.json")
local fallback_settings, profile_error = project.settings(root, { cobc_command = "fallback-cobc" })
assert(fallback_settings and profile_error, "invalid project JSON should report an error and fall back to global settings")
assert(fallback_settings.compiler == "fallback-cobc", "invalid project JSON should not discard safe global defaults")
local cwd_settings = project.settings(nil, { cobc_command = "cobc" })
assert(cwd_settings.root == vim.fn.getcwd(), "a missing root should safely fall back to the current directory")
local no_profile = root .. "/no-profile"
vim.fn.mkdir(no_profile, "p")
local default_settings, missing_message = project.settings(no_profile, { cobc_command = "safe-default-cobc" })
assert(default_settings.compiler == "safe-default-cobc" and missing_message:find("using Neovim defaults", 1, true),
  "a missing profile should explain the fallback and retain safe global settings")
vim.fn.writefile({ vim.json.encode({ warnings = "all" }) }, root .. "/.cobol.json")
local invalid_warnings, warning_error = project.settings(root, { cobc_command = "cobc" })
assert(invalid_warnings and warning_error, "malformed warning configuration should fall back with an error")

vim.fn.delete(root, "rf")
print("project_spec: OK")
