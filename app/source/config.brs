' Loads the connection settings that tools/deploy.sh writes to pkg:/config.json.
' Returns { host, port, callsign, mode, error }; error is "" when the config is usable.
function loadConfig() as object
    config = { host: "", port: 0, callsign: "", mode: "telnet-login", error: "" }

    text = ReadAsciiFile("pkg:/config.json")
    if text = "" then
        config.error = "no configuration - build with tools/deploy.sh"
        return config
    end if

    json = ParseJson(text)
    if type(json) <> "roAssociativeArray" then
        config.error = "pkg:/config.json is not a valid JSON object"
        return config
    end if

    for each key in ["host", "callsign", "mode"]
        if GetInterface(json[key], "ifString") <> invalid then config[key] = json[key]
    end for
    if GetInterface(json.port, "ifInt") <> invalid then config.port = json.port

    if config.host = "" then
        config.error = "host is not set"
    else if config.port <= 0 or config.port > 65535 then
        config.error = "port is not set or out of range"
    else if config.mode <> "telnet-login" and config.mode <> "raw" then
        config.error = "unknown mode '" + config.mode + "'"
    else if config.mode = "telnet-login" and config.callsign = "" then
        config.error = "callsign is required in telnet-login mode"
    end if
    return config
end function
