' Pads with spaces (or truncates) to exactly n characters, text on the left.
function padRight(s as string, n as integer) as string
    if Len(s) >= n then return Left(s, n)
    return s + String(n - Len(s), " ")
end function

' Pads with `fill` on the left to at least n characters.
function padLeft(s as string, n as integer, fill = " " as string) as string
    if Len(s) >= n then return s
    return String(n - Len(s), fill) + s
end function

' Current UTC time as "HHMMZ", the format used in spot lines.
function utcTimeZ() as string
    now = CreateObject("roDateTime")
    return padLeft(now.GetHours().ToStr(), 2, "0") + padLeft(now.GetMinutes().ToStr(), 2, "0") + "Z"
end function

' Splits a line into pieces of at most `width` characters, breaking at the
' last space that fits. A word longer than `width` is split hard.
function wrapLine(line as string, width as integer) as object
    pieces = []
    rest = line
    while Len(rest) > width
        breakAt = 0
        for i = width + 1 to 2 step -1
            if Mid(rest, i, 1) = " " then
                breakAt = i
                exit for
            end if
        end for

        if breakAt > 0 then
            pieces.push(Left(rest, breakAt - 1))
            rest = Mid(rest, breakAt + 1)
        else
            pieces.push(Left(rest, width))
            rest = Mid(rest, width + 1)
        end if

        while Left(rest, 1) = " "
            rest = Mid(rest, 2)
        end while
    end while
    if rest <> "" or pieces.count() = 0 then pieces.push(rest)
    return pieces
end function
