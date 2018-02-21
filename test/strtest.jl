@static VERSION < v"0.7.0-DEV" || (using Pkg, REPL)

const ver = "v0.$(VERSION.minor)"
const git = "https://github.com/JuliaString/"
const pkgdir = Pkg.dir()

const pkglist =
    ["StrTables", "LaTeX_Entities", "Emoji_Entities", "HTML_Entities", "Unicode_Entities",
     "Format", "StringLiterals", "Strs", "StrICU"]

const mparse = @static VERSION < v"0.7.0-DEV" ? parse : Meta.parse
_rep(str, a, b) = @static VERSION < v"0.7.0-DEV" ? replace(str, a, b) : replace(str, a => b)
const RC = @static VERSION < v"0.7.0-DEV" ? Base.REPLCompletions : REPL.REPLCompletions

function rmpkg(pkg)
    try
        Pkg.installed(pkg) == nothing || Pkg.free(pkg)
    catch ex
    end
    Pkg.rm(pkg)
    p = joinpath(pkgdir, pkg)
    run(`rm -rf $p`)
    j = joinpath(_rep(pkgdir, ver, joinpath("lib", ver)), string(pkg, ".ji"))
    run(`rm -rf $j`)
end

function loadall(loc=git)
    # Get rid of any old copies of the package
    for pkg in pkglist
        rmpkg(pkg)
    end

    rmpkg("JSON")
    Pkg.clone(loc == git ? "https://github.com/ScottPJones/JSON.jl" : "/j/JSON.jl")
    Pkg.checkout("JSON", "spj/useptr")
    Pkg.build("JSON")
    #loadpkg("LightXML"; loc = loc == git ? "https://github.com/JuliaIO/" : "/j/")
    loadpkg("LightXML"; loc="https://github.com/JuliaIO/")

    for pkg in pkglist
        Pkg.clone(joinpath(loc, string(pkg, ".jl")))
    end

    for pkg in pkglist
        Pkg.build(pkg)
    end
end

print_chr(val) = isempty(val) || print("\e[s", val, "\e[u\e[2C")

function str_chr(val)
    isempty(val) && return ("", 0, "")
    io = IOBuffer()
    for ch in val
        print(io, hex(ch%UInt32,4), ':')
    end
    str = String(take!(io))[1:end-1]
    val, length(str), str
end

function testtable(m::Module, symtab, fun, f2)
    def = m.default
    get_old(k) = symtab[f2(k)]
    get_new(k) = lookupname(def, k)
    tab = collect(def.nam)
    juliatab = [fun(k) for k in keys(symtab)]
    juliaval = Dict{String, Vector{String}}()
    tabval   = Dict{String, Vector{String}}()
    for k in keys(symtab)
        val = symtab[k]
        mykey = fun(k)
        haskey(juliaval, val) ? push!(juliaval[val], mykey) : (juliaval[val] = [mykey])
    end
    for k in tab
        val = lookupname(def, k)
        haskey(tabval, val) ? push!(tabval[val], k) : (tabval[val] = [k])
    end
    prnt = false
    for (val, keys) in juliaval
        haskey(tabval, val) || continue
        tabkeys = tabval[val]
        keys == tabkeys && continue
        prnt || (println("Names changed from old to new"); prnt = true)
        println("\e[s", val, "\e[u\e[16C", "Old: ", rpad(keys, 20), "New: ", tabkeys)
    end
    onlyjulia = setdiff(juliatab, tab)
    if !isempty(onlyjulia)
        tabjulia = [(key, str_chr(get_old(key))) for key in onlyjulia]
        maxjulia = mapreduce((v)->v[2][2], max, tabjulia)
        println("Entities present in Julia table, not present in this table: ", length(onlyjulia))
        for (key, v) in tabjulia
            (val, len, str) = v
            println("\e[s", val, "\e[u\e[2C ", rpad(str, maxjulia), " ", key)
        end
        println()
    end
    onlytable = setdiff(tab, juliatab)
    if !isempty(onlytable)
        tabnew = [(key, str_chr(get_new(key))) for key in onlytable]
        maxnew = mapreduce((v)->v[2][2], max, tabnew)
        println("Entities present in this table, not present in Julia table: ", length(onlytable))
        for (key, v) in tabnew
            (val, len, str) = v
            println("\e[s", val, "\e[u\e[2C ", rpad(str, maxnew), " ", key)
        end
        println()
    end
    bothtab = intersect(juliatab, tab)
    tabdiff = []
    for key in bothtab
        vold = get_old(key)
        vnew = get_new(key)
        vold == vnew || push!(tabdiff, (key, str_chr(vold), str_chr(vnew)))
    end
    if !isempty(tabdiff)
        maxdiff1 = mapreduce((v)->v[2][2], max, tabdiff)
        maxdiff2 = mapreduce((v)->v[3][2], max, tabdiff)
        println("Entities present in both tables, with different values: ", length(tabdiff))
        for (key, v1, v2) in tabdiff
            (val, len, str) = v1
            print("\e[s", val, "\e[u\e[2C ", rpad(str, maxdiff1), "   ")
            (val, len, str) = v2
            println("\e[s", val, "\e[u\e[2C ", rpad(str, maxdiff2), "   ", key)
        end
        println()
    end
end

function showchanges(m::Module, symtab, fun)
    def = m.default
    tab = collect(def.nam)
    juliaval = Dict{String, Set{String}}()
    tabval   = Dict{String, Set{String}}()
    for k in keys(symtab)
        val = symtab[k]
        haskey(juliaval, val) || (juliaval[val] = Set{String}())
        push!(juliaval[val], fun(k))
    end
    for k in tab
        contains(k, "{") && continue
        val = lookupname(def, k)
        haskey(tabval, val) || (tabval[val] = Set{String}())
        push!(tabval[val], k)
    end
    prnt = false
    preftab = Dict{String, Set{String}}()
    for (val, keys) in juliaval
        haskey(tabval, val) || continue
        tabkeys = tabval[val]
        keys == tabkeys && continue
        prnt || (println("Names changed from old to new"); prnt = true)
        # See if there is a common suffix
        jkeys = collect(keys)
        tkeys = collect(tabkeys)
        onlyjulia = collect(setdiff(keys, tabkeys))
        onlytable = collect(setdiff(tabkeys, keys))
        bothtabs  = collect(intersect(keys, tabkeys))
        if length(keys) == length(tabkeys) == 1
            jk = jkeys[1]
            tk = tkeys[1]
            jlen = sizeof(jk)
            tlen = sizeof(tk)
            mlen = min(jlen, tlen)
            lasteq = mlen
            for i = 0:mlen-1
                jk[end-i] == tk[end-i] || (lasteq = i ; break)
            end
            pref1 = tk[1:(end-lasteq)]
            pref2 = jk[1:(end-lasteq)]
            haskey(preftab, pref1) || (preftab[pref1] = Set{String}())
            push!(preftab[pref1], pref2)
            println("\e[s$pref1 -> $pref2\e[u\e[30C\e[s$val\e[u\e[3C$(rpad(jk,30))$(rpad(tk,30))")
        elseif isempty(onlyjulia)
            println("\e[s$bothtabs +\e[u\e[30C\e[s$val\e[u\e[3C$onlytable")
        elseif isempty(onlytable)
            println("\e[s$bothtabs -\e[u\e[30C\e[s$val\e[u\e[3C$onlyjulia")
        else
            println("\e[s$bothtabs\e[u\e[30C\e[s$val\e[u\e[3C$onlytable -> $onlyjulia")
        end
    end
    preftab
end

showlatex() = showchanges(LaTeX_Entities, RC.latex_symbols, (x)->x[2:end])

function testall()
    # Compare tables against what's currently in Base (for this version of Julia)
    testtable(LaTeX_Entities, RC.latex_symbols, (x)->x[2:end], (x)->"\\$x")
    testtable(Emoji_Entities, RC.emoji_symbols, (x)->x[3:end-1], (x)->"\\:$x:")
    for pkg in pkglist
        try
            Pkg.test(pkg)
        catch ex
            println(pkg, " failed")
            println(sprint(showerror, ex, catch_backtrace()))
        end
    end
end

"""Load up a non-registered package"""
function loadpkg(pkg; loc=git, branch=nothing)
    rmpkg(pkg)
    Pkg.clone(joinpath(loc, string(pkg, ".jl")))
    branch == nothing || Pkg.checkout(pkg, branch)
    Pkg.build(pkg)
end

macro usestr()
    io = IOBuffer()
    print(io, "using ")
    for pkg in pkglist
        print(io, pkg, ", ")
    end
    :( $(mparse(String(take!(io)[1:end-2]))) )
end

nothing
