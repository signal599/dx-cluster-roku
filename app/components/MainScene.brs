sub init()
    theme = getTheme()
    m.top.findNode("background").color = theme.background
    message = m.top.findNode("message")
    message.color = theme.text

    config = loadConfig()
    if config.error <> "" then
        print "[DX] config error: "; config.error
        message.text = "Error: " + config.error
    else
        summary = config.host + ":" + config.port.ToStr() + "  mode=" + config.mode + "  callsign=" + config.callsign
        print "[DX] config loaded: "; summary
        message.text = "DX Cluster (M0)" + Chr(10) + Chr(10) + summary
    end if

    m.top.setFocus(true)
end sub
