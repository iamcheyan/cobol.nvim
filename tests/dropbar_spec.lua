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
end
print('dropbar_spec: OK')
