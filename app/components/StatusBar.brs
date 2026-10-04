sub init()
    m.bar = m.top.findNode("bar")
    m.label = m.top.findNode("label")
    m.columns = 80
    m.clock = m.top.findNode("clock")
    m.clock.observeField("fire", "redraw")
end sub

' params: { font, width, lineHeight, columns, color, background }
function setup(params as object) as object
    m.columns = params.columns
    m.label.font = params.font
    m.label.color = params.color
    ' The bar extends a little past the text on each side.
    m.bar.color = params.background
    m.bar.translation = [-12, 0]
    m.bar.width = params.width + 24
    m.bar.height = params.lineHeight
    redraw()
    m.clock.control = "start"
    return invalid
end function

sub redraw()
    time = utcTimeZ()
    m.label.text = padRight(m.top.text, m.columns - Len(time) - 1) + " " + time
end sub
