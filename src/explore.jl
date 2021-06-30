function findimages(dir=plotsdir(); recursive=false, exts=[".png", ".jpeg", ".jpg", ".svg"])
    dir = abspath(dir)
    paths = if recursive
        paths = String[]
        for (root, dirs, files) in walkdir(dir)
            foreach(file -> push!(paths, joinpath(root, file)), files)
        end
        paths
    else
        readdir(dir; join=true)
    end
    filter(file -> any(endswith.(file, exts)), paths)
end

function dataset(paths; force=false)
    props = parse_savename.(paths)
    prefixes = map(x -> basename(x[1]), props)
    params = map(x -> x[2], props)

    images = vcat(DataFrame.(params)..., cols=:union)

    if hasproperty(images, :path) && !force
        error("image files have a parameter called path; consider passing force=true")
    else
        images.path = "file://" .* paths;
    end

    if hasproperty(images, :dataset) && !force
        error("image files have a parameter called dataset; consider passing force=true")
    else
        images.dataset = prefixes
    end

    images
end

function sidebar(values)
    sidebar = []
    for (header, vals) in values
        list = []
        for (i, val) in enumerate(vals)
            push!(list,
                  m("li",
                    m("input", type="checkbox", name="$(header)$i", value=string(val),
                      onclick="Blink.msg(\"press\", [\"$header\", \"$val\"]);"),
                    m("label", string(val); :for => "$(header)$i")))
        end
        push!(sidebar, m("h2", header), m("ul", list...))
    end
    m("div", id="sidebar",
        m("h1", "Filters"),
        sidebar...,
        m("button", onclick="Blink.msg(\"reset\", [])", "Reset"))
end

function plots(data, visible)
    paths = filter(data) do row
        all(string(row[key]) in values for (key, values) in visible)
    end.path

    [m("h1", "Figures: $(length(paths))"); map(path -> m("img", src="$path"), paths)]
end

function render(win, data, visible)
    contents = plots(data, visible)
    content!(win, "#plots", prod(string.(contents)))
end

function explore(dir=plotsdir(); title="ImageExplorer", force=false, kwargs...)
    data = dataset(findimages(dir; kwargs...); force)

    cols = filter(!=("path"), names(data))
    values = filter(!(isempty∘last), Dict(map(col -> col => sort(unique(data[:, col])), cols)...))

    visible = Dict()

    w = Window(Dict("title" => title, "webPreferences" => Dict("webSecurity" => false)))

    handle(w, "press") do (header, value)
        if haskey(visible, header)
            if value in visible[header]
                delete!(visible[header], value)
                if isempty(visible[header])
                    delete!(visible, header)
                end
            else
                push!(visible[header], value)
            end
        else
            visible[header] = Set([value])
        end

        render(w, data, visible)
    end

    handle(w, "reset") do args...
        visible = Dict()
        js(w, Blink.JSString("d3.selectAll(\"input[type='checkbox']\").property('checked', false)"); callback=false)
        render(w, data, visible)
    end

    loadcss!(w, "file://$(@__DIR__)/../assets/style.css")
    loadjs!(w, "https://d3js.org/d3.v7.min.js")
    body!(w, m("div",
               sidebar(values),
               m("div", id="plots", plots(data, visible))
              ))

    nothing
end
