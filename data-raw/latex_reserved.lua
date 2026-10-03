-- Called from latex_reserved.tex at \begin{document}: write every all-letter
-- control sequence that is currently defined to reserved-<jobname>.txt.
-- A name whose meaning is \relax is skipped, because LaTeX's \@ifundefined
-- (and so \newcommand / \providecommand) treats it as undefined -- except
-- \relax itself, which must never be redefined.
local out = {}
for _, n in ipairs(tex.hashtokens()) do
  if string.match(n, "^[A-Za-z]+$") and token.is_defined(n) then
    local t = token.create(n)
    if t.cmdname ~= "relax" or n == "relax" then
      out[#out + 1] = n
    end
  end
end
table.sort(out)
local f = io.open("reserved-" .. tex.jobname .. ".txt", "w")
f:write(table.concat(out, "\n"), "\n")
f:close()
