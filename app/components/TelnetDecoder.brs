' Turns raw bytes from the socket into display lines. Strips telnet (IAC)
' sequences and control characters, expands tabs, and keeps its state between
' reads because a sequence or a line can be split across two reads.

function newTelnetDecoder() as object
    return {
        state: 0            ' 0 data, 1 after IAC, 2 option byte, 3 subnegotiation, 4 IAC in subnegotiation
        line: CreateObject("roByteArray")
        maxLine: 4096       ' force a break if a line never ends
        feed: telnetDecoderFeed
        partial: telnetDecoderPartial
        takePartial: telnetDecoderTakePartial
    }
end function

' Decodes the first `count` bytes of `bytes`. Returns the completed lines.
function telnetDecoderFeed(bytes as object, count as integer) as object
    lines = []
    for i = 0 to count - 1
        b = bytes[i]
        if m.state = 0 then
            if b = 255 then
                m.state = 1
            else if b = 10 then
                lines.push(m.takePartial())
            else if b = 9 then
                for s = 1 to 8 - (m.line.count() mod 8)
                    m.line.push(32)
                end for
            else if b >= 128 then
                m.line.push(63)     ' "?"
            else if b >= 32 and b <> 127 then
                m.line.push(b)
            end if
            ' CR, BEL and other control characters are dropped.
            if m.line.count() >= m.maxLine then lines.push(m.takePartial())
        else if m.state = 1 then
            if b = 255 then
                m.line.push(63)     ' escaped literal 0xFF
                m.state = 0
            else if b >= 251 and b <= 254 then
                m.state = 2         ' WILL / WONT / DO / DONT: skip the option byte
            else if b = 250 then
                m.state = 3         ' SB: skip until IAC SE
            else
                m.state = 0         ' two-byte command (NOP, GA, ...)
            end if
        else if m.state = 2 then
            m.state = 0
        else if m.state = 3 then
            if b = 255 then m.state = 4
        else
            if b = 240 then
                m.state = 0
            else
                m.state = 3
            end if
        end if
    end for
    return lines
end function

' The current unterminated line (e.g. "login: ").
function telnetDecoderPartial() as string
    return m.line.ToAsciiString()
end function

' Returns the current unterminated line and clears it.
function telnetDecoderTakePartial() as string
    text = m.line.ToAsciiString()
    m.line.Clear()
    return text
end function
