sub init()
    m.top.functionName = "run"
end sub

sub run()
    target = m.top.host + ":" + m.top.port.ToStr()
    backoff = 5
    while true
        connectedSeconds = runSession(target)
        if connectedSeconds > 60 then backoff = 5
        setStatus("disconnected", "Disconnected - retrying in " + backoff.ToStr() + "s")
        sleep(backoff * 1000)
        backoff = backoff * 2
        if backoff > 60 then backoff = 60
    end while
end sub

' One connection, from connect to close. Returns how many seconds it stayed connected.
function runSession(target as string) as integer
    setStatus("connecting", "Connecting to " + target)

    address = CreateObject("roSocketAddress")
    if not address.setAddress(target) or not address.isAddressValid() then
        setStatus("error", "Cannot resolve " + target)
        m.top.lines = ["*** Cannot resolve " + target + " ***"]
        return 0
    end if

    port = CreateObject("roMessagePort")
    socket = CreateObject("roStreamSocket")
    socket.setMessagePort(port)
    socket.setSendToAddress(address)
    socket.setKeepAlive(true)
    if not socket.connect() then
        setStatus("error", "Cannot connect to " + target)
        m.top.lines = ["*** Cannot connect to " + target + " ***"]
        socket.close()
        return 0
    end if
    socket.notifyReadable(true)

    print "[DX] connected to "; target
    setStatus("connected", "Connected to " + target)
    m.top.lines = ["*** Connected to " + target + " ***"]

    connectedTime = CreateObject("roTimespan")
    decoder = newTelnetDecoder()
    loggedIn = (m.top.mode <> "telnet-login")
    lastPartial = ""
    buffer = CreateObject("roByteArray")
    buffer[4095] = 0

    ' A closed connection shows up as a readable event with no data (or an
    ' error). Don't poll isConnected(): it can report false on a live socket.
    reason = ""
    while reason = ""
        msg = wait(0, port)
        if type(msg) = "roSocketEvent" and socket.isReadable() then
            count = socket.receive(buffer, 0, 4096)
            if count = 0 then
                reason = "closed by remote"
            else if count < 0 or not socket.eOK() then
                reason = "socket error " + socket.status().ToStr()
            else
                lines = decoder.feed(buffer, count)
                if not loggedIn and Instr(1, LCase(decoder.partial()), "login:") > 0 then
                    socket.sendStr(m.top.callsign + Chr(13) + Chr(10))
                    ' Show the prompt with the callsign after it, as telnet does.
                    lines.push(decoder.takePartial() + m.top.callsign)
                    loggedIn = true
                    print "[DX] logged in as "; m.top.callsign
                end if

                if lines.count() > 0 then m.top.lines = lines
                partial = decoder.partial()
                if partial <> lastPartial then
                    m.top.partial = partial
                    lastPartial = partial
                end if
            end if
        end if
    end while

    seconds = connectedTime.TotalSeconds()
    socket.close()
    print "[DX] disconnected from "; target; " after "; seconds; "s: "; reason

    lines = []
    leftover = decoder.takePartial()
    if leftover <> "" then lines.push(leftover)
    lines.push("*** Disconnected from " + target + " ***")
    m.top.lines = lines
    m.top.partial = ""
    return seconds
end function

sub setStatus(status as string, text as string)
    m.top.status = status
    m.top.statusText = text
end sub
