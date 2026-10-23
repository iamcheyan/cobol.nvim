local source = require('cobol.dropbar')
require('cobol').setup({show_winbar=false, diagnostics={enable=false}, folding={enable=false}})
local buf=vim.api.nvim_create_buf(true,false)
vim.api.nvim_set_current_buf(buf)
vim.api.nvim_buf_set_lines(buf,0,-1,false,{
  '      * Leading comment.',
  '       IDENTIFICATION DIVISION.',
  '       PROGRAM-ID. TEST.',
  '       PROCEDURE DIVISION.',
  '       RUN-PARA.',
  '           IF A > 1',
  '               DISPLAY "X"',
  '           END-IF.',
})
vim.bo.filetype='cobol'
local win=vim.api.nvim_get_current_win()
vim.api.nvim_win_set_cursor(win,{1,0})
local text=vim.api.nvim_eval_statusline(source.render(buf,win),{winid=win,use_winbar=true}).str
assert(text:find('(root)',1,true), 'a leading comment must not remove the bar')
assert(text:sub(1,1)=='[', 'breadcrumb must start at window edge')
if require('cobol.ast').parser(buf) then
  vim.api.nvim_win_set_cursor(win,{7,16})
  text=vim.api.nvim_eval_statusline(source.render(buf,win),{winid=win,use_winbar=true}).str
  assert(text:sub(1,1)=='[', 'line numbers must not pad the breadcrumb')
  assert(text:find('󰌗',1,true), 'division icon missing')
  assert(text:find('PROCEDURE DIVISION',1,true), text)
  assert(text:find('END-IF',1,true), 'waiting closer must fit with the icon chain: '..text)
  local clipped=vim.api.nvim_eval_statusline(
    source.render(buf,win,{left_width=math.max(0,vim.api.nvim_win_get_width(win)-40)}),
    {winid=win,use_winbar=true}).str
  assert(clipped:find('PROCEDURE DIVISION',1,true), 'active division must survive clipping: '..clipped)
  assert(clipped:find('IF A > 1',1,true), 'current condition must survive clipping: '..clipped)
  local long_buf=vim.api.nvim_create_buf(true,false)
  vim.api.nvim_buf_set_lines(long_buf,0,-1,false,{
    '       IDENTIFICATION DIVISION.',
    '       PROGRAM-ID. LONG.',
    '       PROCEDURE DIVISION.',
    '       STRING-PARA.',
    '           STRING "SUMMARY,COUNT=" DELIMITED BY SIZE',
    '               WS-OUT-COUNT DELIMITED BY SIZE',
    '               WS-OUT-SUCCESS DELIMITED BY SIZE',
    '               INTO WS-REPORT-LINE',
    '           END-STRING.',
  })
  vim.bo[long_buf].filetype='cobol'
  vim.api.nvim_win_set_buf(win,long_buf)
  vim.api.nvim_win_set_cursor(win,{5,11})
  local long=vim.api.nvim_eval_statusline(
    source.render(long_buf,win,{left_width=math.max(0,vim.api.nvim_win_get_width(win)-40)}),
    {winid=win,use_winbar=true}).str
  assert(vim.fn.strdisplaywidth(long)<=vim.api.nvim_win_get_width(win),
    'long statement label must be clipped to the window: '..long)
  assert(long:find('STRING',1,true), 'long statement label must stay visible: '..long)
end
vim.opt.runtimepath:append(vim.fn.stdpath('data')..'/lazy/dropbar.nvim')
local ok = pcall(require, 'dropbar')
if ok then
  local symbols=source.get_symbols(buf,win,nil,{left_width=12})
  assert(#symbols==1)
  local plain=symbols[1]:cat(true)
  assert(vim.fn.strdisplaywidth(plain)<vim.api.nvim_win_get_width(win),
    'symbol width must measure text instead of expanding the right-alignment spacer')
end
-- Winbar components must follow the active theme, including dark WinBar
-- surfaces where the old hard-coded colors disappeared.
vim.api.nvim_set_hl(0,'WinBar',{fg=0xf0f0f0,bg=0x101010})
require('cobol.ast').setup_highlights()
require('cobol').setup_highlights()
for _,name in ipairs({'CobolWaitingClosure','CobolBreadcrumbProc','CobolBreadcrumbData',
  'CobolBreadcrumbEnv','CobolBreadcrumbId'}) do
  local fg=vim.api.nvim_get_hl(0,{name=name,link=false}).fg
  assert(fg==0xf0f0f0, name .. ' must follow the WinBar foreground, got '..vim.inspect(fg))
end
print('dropbar_spec: OK')
