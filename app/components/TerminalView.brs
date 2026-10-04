' A fixed pool of single-line Labels, one per row. The newest line is always
' on the bottom row; older lines move up and drop off the top.

sub init()
    m.rows = []
    m.lines = []
    m.columns = 80
end sub

' params: { width, columns, fontUri }
' Picks the largest font size that fits `columns` characters across `width`.
' Returns { font, width, lineHeight } so other components can share the font.
function fitFont(params as object) as object
    m.columns = params.columns
    font = CreateObject("roSGNode", "Font")
    font.uri = params.fontUri

    ' Measure at a large size, scale down, then step down until it fits.
    font.size = 100
    font.size = Int(100 * params.width / measure(font, m.columns).width)
    metrics = measure(font, m.columns)
    while metrics.width > params.width and font.size > 8
        font.size = font.size - 1
        metrics = measure(font, m.columns)
    end while

    m.font = font
    m.lineHeight = metrics.height
    print "[DX] terminal: font size "; font.size; ", "; m.columns; " columns ("; metrics.width; " x "; metrics.height; " px per line)"
    return { font: font, width: metrics.width, lineHeight: metrics.height }
end function

' params: { height, color }. Call after fitFont(); creates as many rows as fit.
function setup(params as object) as object
    rowCount = Int(params.height / m.lineHeight)
    for i = 0 to rowCount - 1
        label = m.top.createChild("Label")
        label.font = m.font
        label.color = params.color
        label.translation = [0, i * m.lineHeight]
        m.rows.push(label)
    end for

    print "[DX] terminal: "; m.columns; " x "; rowCount
    return { columns: m.columns, rows: rowCount }
end function

' Size of one line of `columns` characters in `font`.
function measure(font as object, columns as integer) as object
    probe = m.top.createChild("Label")
    probe.font = font
    probe.text = String(columns, "M")
    rect = probe.boundingRect()
    m.top.removeChild(probe)
    return { width: rect.width, height: rect.height }
end function

' Adds complete lines, wrapping any that are wider than the screen.
function appendLines(lines as object) as object
    for each line in lines
        for each piece in wrapLine(line, m.columns)
            m.lines.push(piece)
        end for
    end for
    while m.lines.count() > m.rows.count()
        m.lines.shift()
    end while
    redraw()
    return invalid
end function

sub redraw()
    rowCount = m.rows.count()
    texts = []
    capacity = rowCount
    partial = Left(m.top.partial, m.columns)
    if partial <> "" then capacity = rowCount - 1

    first = m.lines.count() - capacity
    if first < 0 then first = 0
    for i = first to m.lines.count() - 1
        texts.push(m.lines[i])
    end for
    if partial <> "" then texts.push(partial)

    ' Bottom-align: empty rows at the top until the screen fills.
    offset = rowCount - texts.count()
    for i = 0 to rowCount - 1
        if i >= offset then
            m.rows[i].text = texts[i - offset]
        else
            m.rows[i].text = ""
        end if
    end for
end sub
