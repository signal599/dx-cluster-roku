' Made-up cluster traffic for testing the display without a connection.

' Lines for one timer tick: usually one spot, sometimes a burst or a long
' announcement (to exercise wrapping).
function fakeFeedLines(tick as integer) as object
    if tick mod 15 = 0 then
        return ["To ALL de W1AW: This is a long announcement line that is wider than eighty columns so it should wrap onto the next line at a word boundary. Supercalifragilisticexpialidociousxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx tests a hard split."]
    else if tick mod 7 = 0 then
        return [fakeSpotLine(), fakeSpotLine(), fakeSpotLine()]
    end if
    return [fakeSpotLine()]
end function

' A spot in DXSpider's layout:
' DX de K7GS:      14004.0  C5R          op2                            2141Z
function fakeSpotLine() as string
    spotters = ["K7GS", "VE3BR", "N5YS", "LU5WA", "PY1KO", "W6NJB", "F4BJN", "AD6E", "G4ABC", "JA1XYZ", "DL1ABC", "VK2DEF"]
    dxCalls = ["C5R", "TK4TH", "N6O", "ZZ2T", "TT1GD", "LW3DG", "3Y0J", "VP8PJ", "ZL7X", "JW5E", "9M2A", "P29XX"]
    comments = ["CW", "FT8 -13 Thx for qso 73", "59 NE OH UP 5", "USB", "CA QSO Party: Contra Costa", "", "QSB QSB BRASIL CW", "tnx qso 73"]
    bands = [[1800, 2000], [3500, 3800], [7000, 7300], [10100, 10150], [14000, 14350], [18068, 18168], [21000, 21450], [24890, 24990], [28000, 28700]]

    band = pick(bands)
    tenths = band[0] * 10 + Rnd((band[1] - band[0]) * 10) - 1
    freq = (tenths \ 10).ToStr() + "." + (tenths mod 10).ToStr()

    return "DX de " + padRight(pick(spotters) + ":", 7) + padLeft(freq, 11) + "  " + padRight(pick(dxCalls), 12) + " " + padRight(pick(comments), 30) + " " + utcTimeZ()
end function

function pick(items as object) as dynamic
    return items[Rnd(items.count()) - 1]
end function
