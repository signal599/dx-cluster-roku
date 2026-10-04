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
        summary = config.host + ":" + config.port.ToStr() + "  mode=" + config.mode + "  callsign=" + config.callsign
        print "[DX] config loaded: "; summary
        m.terminal.callFunc("appendLines", ["*** DX Cluster (M1, fake feed) - " + summary + " ***"])
    end if

    ' M1: fake traffic until the socket task exists.
    m.tick = 0
    m.fakeTimer = m.top.findNode("fakeTimer")
    m.fakeTimer.observeField("fire", "onFakeTimer")
    m.fakeTimer.control = "start"

    m.top.setFocus(true)
end sub

sub onFakeTimer()
    m.tick = m.tick + 1
    m.terminal.callFunc("appendLines", fakeFeedLines(m.tick))
end sub
