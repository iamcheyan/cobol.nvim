local M = {}

local markers = { ".cobol.json", "Makefile", ".git" }

function M.find_root(start_path)
  local path = vim.fs.normalize(vim.fn.fnamemodify(start_path or vim.fn.getcwd(), ":p"))
  if vim.fn.isdirectory(path) ~= 1 then path = vim.fs.dirname(path) end
  while path and path ~= "" do
    for _, marker in ipairs(markers) do
      local candidate = vim.fs.joinpath(path, marker)
      if vim.fn.filereadable(candidate) == 1 or (marker == ".git" and vim.fn.isdirectory(candidate) == 1) then
        return path
      end
    end
    local parent = vim.fs.dirname(path)
    if not parent or parent == path then break end
    path = parent
  end
end

local function is_string_list(value)
  if type(value) ~= "table" then return false end
  for _, item in ipairs(value) do
    if type(item) ~= "string" or item == "" then return false end
  end
  return true
end

local function validate(profile)
  if type(profile) ~= "table" then return nil, "profile must be a JSON object" end
  if profile.source_format and profile.source_format ~= "fixed"
    and profile.source_format ~= "free" and profile.source_format ~= "auto" then
    return nil, "source_format must be fixed, free, or auto"
  end
  if profile.dialect ~= nil and type(profile.dialect) ~= "string" then
    return nil, "dialect must be a string"
  end
  if profile.compiler ~= nil and (type(profile.compiler) ~= "string" or profile.compiler == "") then
    return nil, "compiler must be a non-empty string"
  end
  for _, key in ipairs({ "copybook_paths", "compiler_args", "warnings" }) do
    if profile[key] ~= nil and not is_string_list(profile[key]) then
      return nil, key .. " must be an array of non-empty strings"
    end
  end
  if profile.commands ~= nil then
    if type(profile.commands) ~= "table" then return nil, "commands must be an object" end
    for _, action in ipairs({ "build", "run", "test" }) do
      local command = profile.commands[action]
      if command ~= nil and not is_string_list(command) then
        return nil, "commands." .. action .. " must be an array of non-empty strings"
      end
    end
  end
  return profile
end

function M.load(root)
  if not root or root == "" then return {} end
  local path = vim.fs.joinpath(root, ".cobol.json")
  if vim.fn.filereadable(path) ~= 1 then return nil, "no .cobol.json found; using Neovim defaults" end
  local contents = table.concat(vim.fn.readfile(path), "\n")
  local ok, profile = pcall(vim.json.decode, contents)
  if not ok then return nil, "invalid .cobol.json: " .. tostring(profile) end
  local valid, err = validate(profile)
  if not valid then return nil, ".cobol.json: " .. err end
  return valid
end

function M.compiler_args(profile, root, mode, source, output)
  profile = profile or {}
  local args = {}
  if mode == "check" then
    vim.list_extend(args, { "-fsyntax-only", "-fdiagnostics-plain-output" })
  elseif mode == "build" then
    table.insert(args, "-x")
  end

  local source_format = profile.source_format
  if source_format == "fixed" then
    table.insert(args, "-fixed")
  elseif source_format == "free" then
    table.insert(args, "-free")
  end
  if profile.dialect and profile.dialect ~= "" then
    table.insert(args, "-std=" .. profile.dialect)
  end

  local warnings = profile.warnings or {}
  for _, warning in ipairs(warnings) do
    if warning == "all" then
      table.insert(args, "-Wall")
    elseif warning:sub(1, 2) == "no" then
      table.insert(args, "-W" .. warning)
    elseif warning:sub(1, 1) == "W" then
      table.insert(args, "-" .. warning)
    else
      table.insert(args, "-W" .. warning)
    end
  end

  local include_dirs, seen = {}, {}
  if root and root ~= "" then
    local absolute_root = vim.fs.normalize(vim.fn.fnamemodify(root, ":p"))
    include_dirs[#include_dirs + 1] = absolute_root
    seen[absolute_root] = true
    for _, path in ipairs(profile.copybook_paths or {}) do
      path = vim.fn.expand(path)
      if not vim.startswith(path, "/") then path = vim.fs.joinpath(absolute_root, path) end
      path = vim.fs.normalize(path)
      if not seen[path] then
        seen[path] = true
        include_dirs[#include_dirs + 1] = path
      end
    end
  end
  for _, directory in ipairs(include_dirs) do
    vim.list_extend(args, { "-I", directory })
  end
  vim.list_extend(args, profile.compiler_args or {})
  if output then vim.list_extend(args, { "-o", output }) end
  if source then table.insert(args, source) end
  return args
end

function M.settings(root, base)
  root = root or vim.fn.getcwd()
  base = base or {}
  local profile, err = M.load(root)
  if not profile then profile = {} end
  local diagnostics = base.diagnostics or {}
  local settings = {
    root = root,
    source_format = profile.source_format or base.source_format or "auto",
    dialect = profile.dialect or diagnostics.dialect,
    compiler = profile.compiler or diagnostics.command or base.cobc_command or "cobc",
    copybook_paths = profile.copybook_paths or diagnostics.copybook_paths or base.copybook_paths or { "." },
    compiler_args = profile.compiler_args or diagnostics.extra_args or base.cobc_extra_args or {},
    warnings = profile.warnings or diagnostics.warnings or { "all", "no-obsolete" },
    commands = profile.commands or {},
  }
  local root_path = vim.fs.normalize(vim.fn.fnamemodify(root, ":p"))
  settings.copybook_dirs = { root_path }
  local seen = { [root_path] = true }
  for _, relative in ipairs(settings.copybook_paths) do
    local path = vim.fn.expand(relative)
    if not vim.startswith(path, "/") then path = vim.fs.joinpath(root_path, path) end
    path = vim.fs.normalize(path)
    if not seen[path] then
      seen[path] = true
      settings.copybook_dirs[#settings.copybook_dirs + 1] = path
    end
  end
  return settings, err
end

local function make_targets(root)
  local path = root and vim.fs.joinpath(root, "Makefile")
  if not path or vim.fn.filereadable(path) ~= 1 then return {} end
  local targets = {}
  for _, line in ipairs(vim.fn.readfile(path)) do
    local target = line:match("^([%w_.-]+)%s*:")
    if target and target ~= ".PHONY" then targets[target] = true end
  end
  return targets
end

function M.command(settings, action, source, output)
  local custom = settings.commands and settings.commands[action]
  if custom then return vim.deepcopy(custom), "project" end

  local targets = make_targets(settings.root)
  local target = action
  if action == "build" and not targets.build and targets.all then target = "all" end
  if action == "test" and not targets.test and targets.check then target = "check" end
  if targets[target] then return { "make", target }, "make" end

  if action == "run" then return nil, "no_run_command" end
  local mode = action == "test" and "check" or action
  return vim.list_extend({ settings.compiler or "cobc" }, M.compiler_args(settings, settings.root, mode, source, output)), "cobc"
end

return M
