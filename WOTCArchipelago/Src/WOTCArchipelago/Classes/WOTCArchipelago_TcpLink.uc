// Most of this code by https://github.com/chrishayesmu
// See: https://github.com/chrishayesmu/XCOM2-Twitch-Integration/blob/master/Twitch%20Integration/Src/TwitchIntegration/Classes/HttpGetRequest.uc

class WOTCArchipelago_TcpLink extends TcpLink config(WOTCArchipelago);

struct HttpHeader {
	var string Key;
	var string Value;
};

struct HttpResponse {
	var array<HttpHeader> Headers;
	var string Body;
	var int ResponseCode;
};

var private string Host;
var private string Path;

var private bool bIsTickRequest;
var private float TimeOutDelay;

// State tracking for reading the response data in chunks
var private bool bIsChunkTransferEncoding;
var private bool bFirstChunkReceived;
var private bool bLastChunkReceived;
var private bool bRequestInProgress;
var private int RemainingBytesInChunk;
var private HttpResponse Response;

var private delegate<ResponseHandler> OnRequestComplete;
var private delegate<ResponseHandler> OnRequestError;

var config int ProxyPort;

delegate ResponseHandler(WOTCArchipelago_TcpLink Link, HttpResponse Resp);

function Call(coerce string RequestPath,
			  delegate<ResponseHandler> CompletionHandler,
			  delegate<ResponseHandler> ErrorHandler = none)
{
	local HttpResponse EmptyResponse;

	if (bRequestInProgress)
	{
        `WARN("[WOTCArchipelago_TcpLink] Same object is being re-used while still in use, which is not allowed");
        return;
    }

	// Take proxy address from config
	Host = "localhost";
    Path = RequestPath;

	OnRequestComplete = CompletionHandler;
	OnRequestError = ErrorHandler;

	bIsTickRequest = ((Left(Path, 5) == "/Tick") || (Left(Path, 10) == "/DeathTick"));
	TimeOutDelay = 3.0;

	// Reset per-request state
    bIsChunkTransferEncoding = false;
    bFirstChunkReceived = false;
    bLastChunkReceived = false;
    bRequestInProgress = true;
    RemainingBytesInChunk = 0;

	Response = EmptyResponse;

    if (!bIsTickRequest) `AMLOG("Resolving host: " $ Host);
    Resolve(Host);

	SetTimer(TimeOutDelay, false, 'TimeOut');
}

function TimeOut()
{
	if (bRequestInProgress)
	{
		`AMLOG("Request Timed Out");
		Response.ResponseCode = 408;

		if (OnRequestError != none) OnRequestError(self, Response);
	}
}

function name GetCheckName()
{
	return name(Mid(Path, 7));
}

function int SendText(coerce string str)
{
	if (!bIsTickRequest) `AMLOG("[SEND] " $ str);

	return super.SendText(str);
}

event Resolved(IpAddr Addr)
{
    local int LocalPort;

	Addr.Port = default.ProxyPort;
    LocalPort = BindPort();

    if (!bIsTickRequest) `AMLOG(Host $ " resolved to " $ IpAddrToString(Addr));
    if (!bIsTickRequest) `AMLOG("Bound to local port: " $ LocalPort);

    if (!Open(Addr))
    {
        `WARN("[WOTCArchipelago_TcpLink] Failed to open request");

        Response.ResponseCode = 400;

        if (OnRequestError != none) OnRequestError(self, Response);
    }
}

event ResolveFailed()
{
    if (!bIsTickRequest) `AMLOG("Unable to resolve address " $ Host);

    Response.ResponseCode = 400;

    if (OnRequestError != none) OnRequestError(self, Response);
}

event Opened()
{
    local string CRLF;
    CRLF = chr(13) $ chr(10);

    if (!bIsTickRequest) `AMLOG("Sending HTTP request body");

    // Simple HTTP GET request
    SendText("GET " $ Path $ " HTTP/1.1" $ CRLF);
    SendText("Host: " $ Host $ CRLF);
    SendText("Connection: close" $ CRLF);
    SendText(CRLF); // indicate request is done

    if (!bIsTickRequest) `AMLOG("GET request sent");
}

event Closed()
{
    if (!bIsTickRequest) `AMLOG("Connection closed; final response body is " $ Response.Body);

    bRequestInProgress = false;

    OnRequestComplete(self, Response);
}

event ReceivedText(string Text)
{
    local array<string> HeaderStrings;
	local array<string> ResponseParts;
    local int Index;
    local string ChunkBody;
    local string ChunkSizeInHex;
	local string CRLF;
	local string HeaderLine;

	CRLF = chr(13) $ chr(10);

    // Trim any leading CRLF, which chunks sometimes start with
    if (Left(Text, 2) == CRLF) {
        Text = Mid(Text, 2);
    }

    // Chunks can also start with just LF due to buffering
    if (Left(Text, 1) == chr(10)) {
        Text = Mid(Text, 1);
    }

    if (!bIsTickRequest) `AMLOG("Received text: " $ Text);

    if (bLastChunkReceived) {
        // We might receive headers after the response body, but we don't care about them
        return;
    }

    if (!bFirstChunkReceived) {
        bFirstChunkReceived = true;

        // The headers and body are separated by two CRLFs
        ResponseParts = SplitString(Text, CRLF $ CRLF, /* bCullEmpty */ true);

        // Headers are one per line, though the first line is the response code so we'll handle it specially
        HeaderStrings = SplitString(ResponseParts[0], CRLF, /* bCullEmpty */ true);
        Response.Headers.Length = HeaderStrings.Length - 1;

        // The first line is always "HTTP/1.1 xxx TEXT", where xxx is the response code (200 being OK) and TEXT is the text
        // version of the response code (OK, Bad Request, etc). We only care about xxx so we grab it directly.
        Response.ResponseCode = int(Mid(HeaderStrings[0], 9, 3));

        for (Index = 1; Index < HeaderStrings.Length; Index++) {
            HeaderLine = HeaderStrings[Index];
            Response.Headers[Index - 1].Key = Left(HeaderLine, InStr(HeaderLine, ":"));
            Response.Headers[Index - 1].Value = Split(HeaderLine, ": ", /* bOmitSplitStr */ true);

            if (Response.Headers[Index - 1].Key == "Transfer-Encoding" && Response.Headers[Index - 1].Value == "chunked") {
                bIsChunkTransferEncoding = true;
            }
        }

        if (Response.ResponseCode < 200 || Response.ResponseCode >= 300) {
            if (OnRequestError != none) {
                OnRequestError(self, Response);
            }

            return;
        }

        // For the body, in a chunked encoding, the first line of the body will be a hex number indicating the number of bytes
        // in the first chunk; otherwise we go straight into the body
        if (bIsChunkTransferEncoding) {
            ChunkSizeInHex = Left(ResponseParts[1], Instr(ResponseParts[1], CRLF));
            Response.Body = Split(ResponseParts[1], CRLF, /* bOmitSplitStr */ true);

            RemainingBytesInChunk = HexToInt(ChunkSizeInHex);
            RemainingBytesInChunk -= Len(Response.Body);
        }
        else {
            Response.Body = ResponseParts[1];
        }
    }
    else {
        // We've already received the first chunk. Non-chunk encodings are simply appended, but for chunked encodings, we need to see
        // whether we're currently in the middle of a chunk, because the TcpLink class isn't handing us the entire chunk at once. We
        // also need to see if we're receiving the last chunk, which is just a chunk with a size of 0.
        if (!bIsChunkTransferEncoding) {
            Response.Body $= Text;
            return;
        }

        // If we're not expecting more bytes in the current chunk, this should start with a new chunk size
        if (RemainingBytesInChunk == 0) {
            ChunkSizeInHex = Left(Text, Instr(Text, CRLF));
            RemainingBytesInChunk = HexToInt(ChunkSizeInHex);

            Text = Mid(Text, Instr(Text, CRLF) + 2);
        }

        // We might get multiple chunks concatenated thanks to TcpLink buffering, so we need to be able to identify a new chunk mid-stream
        if (Len(Text) > RemainingBytesInChunk) {
            Response.Body $= Left(Text, RemainingBytesInChunk);
            Text = Mid(Text, RemainingBytesInChunk + 2); // skip past the CRLF that ends this chunk

            RemainingBytesInChunk = 0;
        }

        if (RemainingBytesInChunk == 0) {
            // Previous chunk is done; we may be about to start a new one, or end completely
            ChunkSizeInHex = Left(Text, Instr(Text, CRLF));

            if (ChunkSizeInHex != "") {
                RemainingBytesInChunk = HexToInt(ChunkSizeInHex);

                if (RemainingBytesInChunk == 0) {
                    bLastChunkReceived = true;
                    return;
                }

                ChunkBody = Split(Text, CRLF, /* bOmitSplitStr */ true);
            }
            else {
                // If there's nothing, then the chunk size is coming in the next message
                ChunkBody = "";
            }
        }
        else {
            ChunkBody = Text;
        }

        // Append data from the current chunk
        Response.Body $= ChunkBody;
        RemainingBytesInChunk -= Len(ChunkBody);

        if (!bIsTickRequest) `AMLOG("Chunk processed. Remaining bytes: " $ RemainingBytesInChunk);

        if (RemainingBytesInChunk < 0) {
            `WARN("[WOTCArchipelago_TcpLink] Negative number of bytes remaining in chunk: " $ RemainingBytesInChunk);
        }
    }
}

private function int HexToInt(string HexVal) {
    local int CurrentCharAscii;
    local int IntVal;
    local int Index;
    local int Power;

    HexVal = Locs(HexVal);
    Power = 1;

    for (Index = 0; Index < Len(HexVal); Index++) {
        // Asc gives the ASCII value of the first character of the string, so we just pull successively
        // more characters from the right side of the string
        CurrentCharAscii = Asc(Right(HexVal, Index + 1));

        // ASCII characters 0 through 9 map to [48, 57]; a through f map to [97, 102]
        CurrentCharAscii = CurrentCharAscii - 48;

        if (CurrentCharAscii > 9) {
            CurrentCharAscii = CurrentCharAscii - 39;
        }

        if (CurrentCharAscii < 0 || CurrentCharAscii > 15) {
            `WARN("[WOTCArchipelago_TcpLink] Character out of range; adjusted ASCII value is " $ CurrentCharAscii);
            return -1;
        }

        IntVal += CurrentCharAscii * Power;
        Power *= 16;
    }

    return IntVal;
}
