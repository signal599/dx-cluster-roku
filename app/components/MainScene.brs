sub init()
    theme = getTheme()
    m.top.findNode("background").color = theme.background

    ' Action-safe area: 90% of the 1920 x 1080 screen.
    safe = { x: 96, y: 54, width: 1728, height: 972 }
    columns = 80

    m.terminal = m.top.findNode("terminal")
    metrics = m.terminal.callFunc("fitFont", {
        width: safe.width
        columns: columns
        fontUri: "pkg:/fonts/JetBrainsMono-Regular.ttf"
    })

    ' Status line on the top row, a small gap, then the terminal below it.
    gap = Int(metrics.lineHeight / 4)
    m.status = m.top.findNode("status")
    m.status.translation = [safe.x, safe.y]
    m.status.callFunc("setup", {
        font: metrics.font
        width: metrics.width
        lineHeight: metrics.lineHeight
        columns: columns
        color: theme.statusText
        background: theme.statusBackground
    })

    terminalTop = metrics.lineHeight + gap
    m.terminal.translation = [safe.x, safe.y + terminalTop]
    m.terminal.callFunc("setup", { height: safe.height - terminalTop, color: theme.text })

    config = loadConfig()
    if config.error <> "" then
        print "[DX] config error: "; config.error
        m.terminal.callFunc("appendLines", ["*** Error: " + config.error + " ***"])
        m.status.text = "Error: " + config.error
    else
        print "[DX] config loaded: "; config.host; ":"; config.port; " mode="; config.mode; " callsign="; config.callsign
        startCluster(config)
    end if

    m.top.setFocus(true)
end sub

sub startCluster(config as object)
    m.cluster = CreateObject("roSGNode", "ClusterTask")
    m.cluster.host = config.host
    m.cluster.port = config.port
    m.cluster.callsign = config.callsign
    m.cluster.mode = config.mode
    m.cluster.observeField("lines", "onClusterLines")
    m.cluster.observeField("partial", "onClusterPartial")
    m.cluster.observeField("statusText", "onClusterStatus")
    m.status.text = "Starting"
    m.cluster.control = "RUN"
end sub

sub onClusterLines(event as object)
    m.terminal.callFunc("appendLines", event.getData())
end sub

sub onClusterPartial(event as object)
    m.terminal.partial = event.getData()
end sub

sub onClusterStatus(event as object)
    print "[DX] status: "; event.getData()
    m.status.text = event.getData()
end sub
