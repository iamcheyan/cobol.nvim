import os
from pathlib import Path
import pynvim
n=pynvim.attach('child',argv=['nvim','--embed','--headless','-u','NONE'])
n.ui_attach(80,20,rgb=True,ext_linegrid=True)
n.exec_lua('''vim.opt.rtp:prepend(ROOT_PATH)
require('cobol').setup({show_winbar=false,diagnostics={enable=false}})
vim.bo.filetype='cobol'
vim.api.nvim_buf_set_lines(0,0,-1,false,{'       DISPLAY X.','       DISPLAY Y.','       DISPLAY Z.','       DISPLAY W.'})
vim.wo.foldenable=false;vim.api.nvim_buf_set_lines(0,0,-1,false,vim.tbl_map(function(s) return s .. string.rep(' ',80-#s) end,vim.api.nvim_buf_get_lines(0,0,-1,false)));vim.o.cursorline=true;vim.o.cursorcolumn=true
vim.api.nvim_set_hl(0,'Normal',{fg='#ffffff',bg='#000087'})
vim.api.nvim_set_hl(0,'CursorColumn',{bg='#00aa55'})
vim.api.nvim_set_hl(0,'CursorLine',{bg='#005faf'})
vim.api.nvim_win_set_cursor(0,{2,CURSOR_COL});vim.cmd('redraw!')'''.replace('CURSOR_COL',str(int(os.environ.get('RULER_COL','7'))-1)).replace('ROOT_PATH',repr(str(Path(__file__).resolve().parents[1]))))
attrs={}; grids={}
n.eval('1')
while n._session._pending_messages:
 m=n._session.next_message()
 if m.name!='redraw':continue
 for e in m.args:
  for u in e[1:]:
   if e[0]=='hl_attr_define':attrs[u[0]]=u[1]
   elif e[0]=='grid_resize':grids[u[0]]=[[(' ',0) for _ in range(u[1])] for _ in range(u[2])]
   elif e[0]=='grid_line':
    g,r,c,cells=u[:4];h=0
    for cell in cells:
     if len(cell)>1:h=cell[1]
     for _ in range(cell[2] if len(cell)>2 else 1):grids[g][r][c]=(cell[0],h);c+=1
pos=n.exec_lua('return vim.fn.screenpos(vim.api.nvim_get_current_win(),1,' + os.environ.get('RULER_COL','7') + ')')

c=pos['col']-1;r=pos['row']-1
for row in [r,r+2,r+3]:
 ch,h=grids[1][row][c];print(row,ch,attrs.get(h))
 assert attrs.get(h,{}).get('background')==0x00aa55,'ruler erased cursor-column background'
print('Rendered cursor-column overlap: PASS')
try:n.command('qa!')
except (EOFError,OSError):pass
