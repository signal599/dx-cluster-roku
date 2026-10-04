sub init()
    theme = getTheme()
    m.top.findNode("background").color = theme.background

    m.terminal = m.top.findNode("terminal")
    m.terminal.callFunc("setup", {
        width: 1728
        height: 972
        columns: 80
        color: theme.text
        fontUri: "pkg:/fonts/JetBrainsMono-Regular.ttf"
    })

    config = loadConfig()
    if config.error <> "" then
        print "[DX] config error: "; config.error
        m.terminal.callFunc("appendLines", ["*** Error: " + config.error + " ***"])
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
    m.cluster.control = "RUN"
end sub

sub onClusterLines(event as object)
    m.terminal.callFunc("appendLines", event.getData())
end sub

sub onClusterPartial(event as object)
    m.terminal.partial = event.getData()
end sub

' The status line arrives in M4; log it for now.
sub onClusterStatus(event as object)
    print "[DX] status: "; event.getData()
end sub
