-- vim: sw=4:noexpandtab

local M = {}

-- constants
local reg_t  = 0
local lnk_t  = 1
local sym_t  = 2
local chr_t  = 3
local blk_t  = 4
local dir_t  = 5
local fifo_t = 6
local cont_t = 7

M.REG  = reg_t
M.LNK  = lnk_t
M.SYM  = sym_t
M.CHR  = chr_t
M.BLK  = blk_t
M.DIR  = dir_t
M.FIFO = fifo_t
M.CONT = cont_t

function M:isreg()  return self.typeflag == reg_t end
function M:islnk()  return self.typeflag == lnk_t end
function M:issym()  return self.typeflag == sym_t end
function M:ischr()  return self.typeflag == chr_t end
function M:isblk()  return self.typeflag == blk_t end
function M:isdir()  return self.typeflag == dir_t end
function M:isfifo() return self.typeflag == fifo_t end
function M:iscont() return self.typeflag == cont_t end

return M
