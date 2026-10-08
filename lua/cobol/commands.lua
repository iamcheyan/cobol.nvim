local M = {}
local active_jobs = {}

local severity_type = {
  error = "E",
  fatal = "E",
  warning = "W",
  note = "I",
  info = "I",
}

function M.parse_output(output, root, source_file)
  local diagnostics = require("cobol.diagnostics")
  local entries = {}
  for _, line in ipairs(vim.split(output or "", "\n", { trimempty = true })) do
    local item = diagnostics.parse_line(line)
    if item and (item.file ~= "-" or source_file) then
      local filename = item.file == "-" and source_file or item.file
      local absolute = vim.startswith(filename, "/") or filename:match("^%a:[/\\]")
      if not absolute then filename = vim.fs.joinpath(root or vim.fn.getcwd(), filename) end
      entries[#entries + 1] = {
        filename = vim.fs.normalize(filename),
        lnum = item.lnum or 1,
        col = item.col or 1,
        type = severity_type[item.severity] or "E",
        text = item.message,
      }
    end
  end
  return entries
end

local function notify(message, level)
  vim.notify("COBOL: " .. message, level or vim.log.levels.INFO)
end

local function set_quickfix(title, result, root, source_file)
  local output = table.concat({ result.stdout or "", result.stderr or "" }, "\n")
  local entries = M.parse_output(output, root, source_file)
  vim.fn.setqflist({}, " ", { title = title, items = entries })
  return output, entries
end

local function start_process(key, command, root, input, title, callback, source_file)
  if active_jobs[key] then pcall(function() active_jobs[key]:kill(9) end) end
  local ok, job = pcall(vim.system, command, { cwd = root, stdin = input, text = true }, function(result)
    active_jobs[key] = nil
    vim.schedule(function()
      local output, entries = set_quickfix(title, result, root, source_file)
      callback(result, output, entries)
    end)
  end)
  if not ok then
    active_jobs[key] = nil
    notify("could not start command: " .. tostring(job), vim.log.levels.ERROR)
    return false
  end
  active_jobs[key] = job
  return true
end

local function cache_dir()
  local path = vim.fs.joinpath(vim.fn.stdpath("cache"), "cobol.nvim", "build")
  vim.fn.mkdir(path, "p")
  return path
end

local function is_project_command(settings, action)
  local command = settings.commands and settings.commands[action]
  if command then return true end
  local targets = {}
  local makefile = vim.fs.joinpath(settings.root, "Makefile")
  if vim.fn.filereadable(makefile) == 1 then
    for _, line in ipairs(vim.fn.readfile(makefile)) do
      local target = line:match("^([%w_.-]+)%s*:")
      if target then targets[target] = true end
    end
  end
  if action == "build" then return targets.build or targets.all end
  if action == "run" then
    return targets.run or (vim.fn.filereadable(makefile) == 1 and (targets.build or targets.all))
      or (settings.commands and settings.commands.build ~= nil)
  end
  if action == "test" then return targets.test or targets.check end
  return false
end

local function run_action(action, bufnr, settings)
  local name = vim.api.nvim_buf_get_name(bufnr)
  local modified = vim.bo[bufnr].modified
  local project_command = is_project_command(settings, action)
  if project_command and modified then
    notify("save the current buffer before running project commands", vim.log.levels.WARN)
    return false
  end

  local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
  local input = table.concat(lines, "\n") .. "\n"
  local file = name ~= "" and vim.fn.fnamemodify(name, ":p") or nil
  if settings.source_format == "auto" then
    local ok, cobol = pcall(require, "cobol")
    settings.source_format = ok and cobol.detect_format and cobol.detect_format(bufnr) or "fixed"
  end

  local key = tostring(bufnr) .. ":" .. action
  if action == "test" then
    local command, kind = require("cobol.project").command(settings, action, "-")
    notify("running " .. (kind == "make" and "project tests" or "compiler check") .. "…")
    return start_process(key, command, settings.root, input, "COBOL " .. action, function(result, _, entries)
      if result.code == 0 then
        notify(kind == "make" and "tests passed" or "syntax check passed")
      else
        notify(string.format("%s failed (exit %d)%s", action, result.code, #entries > 0 and "; see Quickfix" or ""), vim.log.levels.ERROR)
      end
    end, file)
  end

  if action == "run" and project_command then
    local command = require("cobol.project").command(settings, action)
    if not command then
      notify("project has no run command; add a Makefile run target or commands.run to .cobol.json", vim.log.levels.WARN)
      return false
    end
    notify("running project…")
    return start_process(key, command, settings.root, nil, "COBOL run", function(result, _, entries)
      if result.code == 0 then notify("program finished")
      else notify(string.format("run failed (exit %d)%s", result.code, #entries > 0 and "; see Quickfix" or ""), vim.log.levels.ERROR) end
    end, file)
  end

  local output_name = vim.fs.basename(file or "untitled.cob")
  output_name = output_name:gsub("%.[^.]+$", "") .. "-" .. bufnr
  local executable = vim.fs.joinpath(cache_dir(), output_name)
  local source = file
  local temp_source
  if modified or not source then
    temp_source = vim.fs.joinpath(cache_dir(), "buffer-" .. bufnr .. ".cob")
    local write_ok, write_err = pcall(vim.fn.writefile, lines, temp_source)
    if not write_ok or write_err ~= 0 then
      notify("could not write temporary source file", vim.log.levels.ERROR)
      return false
    end
    source = temp_source
  end

  local command = require("cobol.project").command(settings, "build", source, executable)
  notify(action == "run" and "building before run…" or "building…")
  return start_process(key, command, settings.root, nil, "COBOL build", function(result, _, entries)
    if temp_source then vim.fn.delete(temp_source) end
    if result.code ~= 0 then
      notify(string.format("build failed (exit %d)%s", result.code, #entries > 0 and "; see Quickfix" or ""), vim.log.levels.ERROR)
      return
    end
    if action == "build" then
      notify("build succeeded; output: " .. executable)
      return
    end
    notify("running compiled program…")
    start_process(key .. ":run", { executable }, settings.root, nil, "COBOL run", function(run_result, _, run_entries)
      vim.fn.delete(executable)
      if run_result.code == 0 then notify("program finished")
      else notify(string.format("program exited with code %d%s", run_result.code, #run_entries > 0 and "; see Quickfix" or ""), vim.log.levels.WARN) end
    end, file)
  end, file)
end

function M.run(action, bufnr)
  bufnr = bufnr or vim.api.nvim_get_current_buf()
  if not vim.api.nvim_buf_is_valid(bufnr) then return false end
  local ok, cobol = pcall(require, "cobol")
  local plugin_config = ok and cobol.config or {}
  local project = require("cobol.project")
  local name = vim.api.nvim_buf_get_name(bufnr)
  local root = project.find_root(name)
    or (ok and cobol.get_project_root and cobol.get_project_root(bufnr, name))
    or vim.fn.getcwd()
  if vim.fn.isdirectory(root) ~= 1 then
    notify("no valid project directory is available", vim.log.levels.ERROR)
    return false
  end
  local settings, profile_error = project.settings(root, plugin_config)
  if profile_error then vim.notify_once("COBOL: " .. profile_error, vim.log.levels.WARN) end
  if vim.fn.executable(settings.compiler) ~= 1 and not is_project_command(settings, action) then
    notify("compiler '" .. settings.compiler .. "' was not found in PATH", vim.log.levels.ERROR)
    return false
  end
  return run_action(action, bufnr, settings)
end

function M.setup()
  for action, command in pairs({ build = "CobolBuild", run = "CobolRun", test = "CobolTest" }) do
    if vim.fn.exists(":" .. command) ~= 2 then
      vim.api.nvim_create_user_command(command, function()
        M.run(action)
      end, { desc = "COBOL: " .. action .. " current project" })
    end
  end
end

return M
