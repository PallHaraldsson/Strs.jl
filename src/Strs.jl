__precompile__(true)
"""
Strs package

Copyright 2017-018 Gandalf Software, Inc., Scott P. Jones
Licensed under MIT License, see LICENSE.md
"""
module Strs

using ModuleInterfaceTools
using ModuleInterfaceTools: @api, m_eval, cur_mod
export @api, V6_COMPAT

using PCRE2

import StrTables: lookupname, matchchar, matches, longestmatches, completions
export lookupname, matchchar, matches, longestmatches, completions

@api extend! StrRegex, StrLiterals, Format
@api use! StrFormat, StrEntities

using InternedStrings: intern
export @i_str, @I_str, intern

macro i_str(str) ; Expr(:call, :intern, interpolated_parse(str, StrBase._str)) ; end
macro I_str(str) ; Expr(:call, :intern, interpolated_parse(str, StrBase._str, true)) ; end

const m_eval = ModuleInterfaceTools.m_eval

function __init__()
    StrLiterals.string_type[] = UniStr
end

# Need to fix ModuleInterfaceTools to do this!
for mod in (StrRegex, StrLiterals), grp in (:modules, :public, :public!)
    m_eval(cur_mod(), Expr( :export, getfield(m_eval(mod, :__api__), grp)...))
end

@api freeze

end # module Strs
