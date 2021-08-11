@tags button div h1 h2 header img input label li span ul

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

    if hasproperty(images, :id) && !force
        error("image files have a parameter called id; consider passing force=true")
    else
        images.id = "image" .* string.(eachindex(images.path))
    end

    images
end

function sidebar(values)
    sidebar = []
    for (header, vals) in values
        list = []
        for (i, val) in enumerate(vals)
            push!(list,
                  li(input(type="checkbox", name="$(header)$i", value=string(val),
                           onclick="""Blink.msg("press", ["$header", "$val"]);"""),
                     label(string(val); :for => "$(header)$i")))
        end
        push!(sidebar, h2(header), ul(list...))
    end
    div(id="sidebar",
        header(h1("Filters")),
        sidebar...,
        button(id="reset", onclick="""Blink.msg("reset", []);""", "Reset"))
end

function plots(df, visible)
    combine(groupby(df, [:id, :path])) do group
        (; visible = all(string(group[1,key]) in values for (key, values) in visible))
    end
end

function images(df)
    map(eachrow(df)) do row
        img(src=row.path, id=row.id, title=row.path, loading="lazy", onload="setupImage('#$(row.id)');")
    end
end

function toggle(win, df, visible)
    df = plots(df, visible)
    @js_ win toggle($(df.id), $(df.visible))
end

function explore(dir=plotsdir(); title="ImageExplorer", force=false, kwargs...)
    data = dataset(findimages(dir; kwargs...); force)

    cols = filter(x -> !(x in ["id", "path"]), names(data))
    values = filter(!(isempty∘last), Dict(map(col -> col => sort(unique(data[:, col])), cols)...))

    visible = Dict()

    win = Window(Dict("title" => title, "webPreferences" => Dict("webSecurity" => false)))

    handle(win, "press") do (header, value)
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

        toggle(win, data, visible)
    end

    handle(win, "reset") do args...
        visible = Dict()
        @js_ win d3.selectAll("input[type='checkbox']").property("checked", false)
        toggle(win, data, visible)
    end

    let loaded = []
        handle(win, "loaded") do id
            push!(loaded, id)
            if isempty(setdiff(data.id, loaded))
                @js_ win d3.selectAll("#overlay").classed("hidden", true)
            end
        end
    end

    loadcss!(win, "file://$(@__DIR__)/../assets/style.css")
    loadjs!(win, "https://d3js.org/d3.v7.min.js")
    loadjs!(win, "file://$(@__DIR__)/../assets/explore.js")

    body!(win, div(div(id="overlay", class="flex",
                       img(src="file://$(@__DIR__)/../assets/spinner.gif"),
                       "Loading images..."),
                   sidebar(values),
                   div(id="content",
                       header(h1("$(nrow(data)) Images"),
                              div(span("Image Width:"),
                                  input(type="range", value=500, min=100, step=10, max=1000, name="width", onchange="resize();"),
                                  label("500px"; :for => "width"))),
                       div(id="plots", images(data)))))

    nothing
end
