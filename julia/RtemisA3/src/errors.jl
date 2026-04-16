struct A3ValidationError <: Exception
    msg::String
end

struct A3ParseError <: Exception
    msg::String
end

Base.showerror(io::IO, e::A3ValidationError) = print(io, "A3ValidationError: ", e.msg)
Base.showerror(io::IO, e::A3ParseError) = print(io, "A3ParseError: ", e.msg)
