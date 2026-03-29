sort_dedup(v::Vector{Int}) = sort(unique(v))
sort_ranges(v::Vector{Tuple{Int,Int}}) = sort(v; by=r -> (r[1], r[2]))

function check_no_overlap(ranges::Vector{Tuple{Int,Int}}, path::String)
    length(ranges) <= 1 && return
    for i in 2:length(ranges)
        prev_end   = ranges[i-1][2]
        curr_start = ranges[i][1]
        if curr_start <= prev_end
            throw(A3ValidationError(
                "$path: ranges $(collect(ranges[i-1])) and $(collect(ranges[i])) overlap " *
                "(curr_start=$curr_start <= prev_end=$prev_end)"
            ))
        end
    end
end

function is_json_compatible(v)::Bool
    v === nothing        && return true
    v isa Bool           && return true
    v isa Number         && return true
    v isa AbstractString && return true
    v isa AbstractVector && return all(is_json_compatible, v)
    if v isa AbstractDict
        return all(k isa AbstractString && is_json_compatible(val) for (k, val) in v)
    end
    return false
end
