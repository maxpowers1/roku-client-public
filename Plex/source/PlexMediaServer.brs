'*
'* Facade to a PMS server responsible for fetching PMS meta-data and
'* formatting into Roku format as well providing the interface to the
'* streaming media
'* 

'* Constructor for a specific PMS instance identified via the URL and 
'* human readable name, which can be used in section names
Function newPlexMediaServer(pmsUrl, pmsName) As Object
	pms = CreateObject("roAssociativeArray")
	pms.serverUrl = pmsUrl
	pms.name = pmsName
	pms.GetContent = directoryContent
	pms.GetHomePageContent = homePageContent
	pms.GetListNames = listNames
	pms.GetListKeys = listKeys
	pms.VideoScreen = constructVideoScreen
	pms.PluginVideoScreen = constructPluginVideoScreen
	pms.StopVideo = stopTranscode
	pms.GetQueryResponse = xmlContent
	pms.GetPaginatedQueryResponse = paginatedXmlContent
	pms.DetailedVideoMetadata = detailedVideoMetadata
	pms.SetProgress = progress
	pms.Scrobble = scrobble
	pms.Unscrobble = unscrobble
	pms.Rate = rate
	pms.ExecuteCommand = issueCommand
	pms.ExecutePostCommand = issuePostCommand
	pms.UpdateAudioStreamSelection = updateAudioStreamSelection
	pms.UpdateSubtitleStreamSelection = updateSubtitleStreamSelection
	pms.Search = search
	pms.TranscodedImage = TranscodedImage
	return pms
End Function

Function search(query) As Object
	searchResults = CreateObject("roAssociativeArray")
	searchResults.names = []
	searchResults.content = []
	movies = []
	shows = []
	episodes = []
	xmlResult = m.GetQueryResponse("", "/search?query="+HttpEncode(query))
	for each directoryItem in xmlResult.xml.Directory
		if directoryItem@type = "show" then
			directory = newDirectoryMetadata(m, xmlResult.sourceUrl, xmlResult.xml, directoryItem)
			shows.Push(directory)
		endif
	next
	for each videoItem in xmlResult.xml.Video
		video = newVideoMetadata(m, xmlResult.sourceUrl, xmlResult.xml, videoItem)
		if videoItem@type = "movie" then
			movies.Push(video)
		else if videoItem@type = "episode" then
			episodes.Push(video)
		end if
	next
	if movies.Count() > 0  then
		searchResults.names.Push("Movies")
		searchResults.content.Push(movies)
	end if	
	if shows.Count() > 0  then
		searchResults.names.Push("TV Shows")
		searchResults.content.Push(shows)
	end if	
	if episodes.Count() > 0  then
		searchResults.names.Push("TV Episodes")
		searchResults.content.Push(episodes)
	end if
	videoClips = []
	videoSurfResult = m.GetQueryResponse("", "/system/services/search?identifier=com.plexapp.search.videosurf&query="+HttpEncode(query))
	for each videoItem in videoSurfResult.xml.Video
		video = newVideoMetadata(m, videoSurfResult.sourceUrl, videoSurfResult.xml, videoItem)
		if videoItem@type = "clip" then
			videoClips.Push(video)
		end if
	next
	if videoClips.Count() > 0 then
		searchResults.names.Push("Video Clips")
		searchResults.content.Push(videoClips)
	end if
	return searchResults
End Function

'* This needs a HTTP PUT command that does not exist in the Roku API but it's faked with a POST
Function updateAudioStreamSelection(partId As String, audioStreamId As String)
	commandUrl = "/library/parts/"+partId+"?audioStreamID="+audioStreamId
	m.ExecutePostCommand(commandUrl)
End Function

Function updateSubtitleStreamSelection(partId As String, subtitleStreamId As String)
	subtitle = invalid
	if subtitleStreamId <> invalid then
		subtitle = subtitleStreamId
	endif
	commandUrl = "/library/parts/"+partId+"?subtitleStreamID="+subtitle
	m.ExecutePostCommand(commandUrl)
End Function

Function issuePostCommand(commandPath)
	commandUrl = m.serverUrl + commandPath
	print "Executing POST command with full command URL:";commandUrl
	request = CreateObject("roUrlTransfer")
	request.SetUrl(commandUrl)
	request.PostFromString("")
End Function

Function progress(key, identifier, time)
	commandUrl = "/:/progress?key="+key+"&identifier="+identifier+"&time="+time.tostr()
	m.ExecuteCommand(commandUrl)
End Function

Function scrobble(key, identifier)
	commandUrl = "/:/scrobble?key="+key+"&identifier="+identifier
	m.ExecuteCommand(commandUrl)
End Function

Function unscrobble(key, identifier)
	commandUrl = "/:/unscrobble?key="+key+"&identifier="+identifier
	m.ExecuteCommand(commandUrl)
End Function

Function rate(key, identifier, rating)
	commandUrl = "/:/rate?key="+key+"&identifier="+identifier+"&rating="+rating
	m.ExecuteCommand(commandUrl)
End Function

Function issueCommand(commandPath)
	commandUrl = m.serverUrl + commandPath
	print "Executing command with full command URL:";commandUrl
	request = CreateObject("roUrlTransfer")
	request.SetUrl(commandUrl)
	request.GetToString()
End Function

Function homePageContent() As Object
	xml = m.GetQueryResponse("", "/library/sections")
	librarySections = m.GetContent(xml)
	content = CreateObject("roArray", librarySections.Count() + 1, true)
	for each section in librarySections
		'* Exclude music for now until transcode to mp3 is available
		if section.type = "movie" OR section.type = "show" then
			content.Push(section)
		endif
	next
	
	'* TODO: only add this if we actually have any valid apps?
	appsSection = CreateObject("roAssociativeArray")
	appsSection.server = m
    appsSection.sourceUrl = ""
	appsSection.ContentType = "series"
	appsSection.Key = "apps"
	appsSection.Title = "Channels"
	appsSection.ShortDescriptionLine1 = "Channels"
	appsSection.SDPosterURL = "file://pkg:/images/plex.jpg"
	appsSection.HDPosterURL = "file://pkg:/images/plex.jpg"
	content.Push(appsSection)
	
	searchSection = CreateObject("roAssociativeArray")
	searchSection.server = m
    searchSection.sourceUrl = ""
	searchSection.ContentType = "series"
	searchSection.Key = "globalsearch"
	searchSection.Title = "Search"
	searchSection.ShortDescriptionLine1 = "Search"
	searchSection.SDPosterURL = "file://pkg:/images/icon-search.jpg"
	searchSection.HDPosterURL = "file://pkg:/images/icon-search.jpg"
	content.Push(searchSection)
	
	return content
End Function

'* Detailed video meta-data for springboard screen
Function detailedVideoMetadata(sourceUrl, key) As Object
	xmlResponse = m.GetQueryResponse(sourceUrl, key)
	videoItem = xmlResponse.xml.Video[0]
	
	video = newDetailedVideoMetadata(m, sourceUrl, xmlResponse.xml, videoItem)
	return video
End Function

Function paginatedXmlContent(sourceUrl, key, start, size) As Object

	xmlResult = CreateObject("roAssociativeArray")
	xmlResult.server = m
	if key = "apps" then
		'* Fake a minimal server response with a new viewgroup
		xml=CreateObject("roXMLElement")
		xml.Parse("<MediaContainer viewgroup='apps'/>")
		xmlResult.xml = xml
		xmlResult.sourceUrl = invalid
	else
			queryUrl = FullUrl(m.serverUrl, sourceUrl, key)
			response = paginatedQuery(queryUrl, start, size)
			xml=CreateObject("roXMLElement")
			if not xml.Parse(response) then
				print "Can't parse feed:";response
			endif
			xmlResult.xml = xml
			xmlResult.sourceUrl = queryUrl
	endif
	return xmlResult
End Function

Function paginatedQuery(queryUrl, start, size) As Object
	print "Fetching content from server at query URL:";queryUrl
	print "Pagination start:";start.tostr()
	print "Pagination size:";size.tostr()
	httpRequest = NewHttp(queryUrl)
	httpRequest.Http.AddHeader("X-Plex-Container-Start", start.tostr())
	httpRequest.Http.AddHeader("X-Plex-Container-Size", size.tostr())
	response = httpRequest.GetToStringWithRetry()
	return response
End Function

Function xmlContent(sourceUrl, key) As Object

	xmlResult = CreateObject("roAssociativeArray")
	xmlResult.server = m
	if key = "apps" then
		'* Fake a minimal server response with a new viewgroup
		xml=CreateObject("roXMLElement")
		xml.Parse("<MediaContainer viewgroup='apps'/>")
		xmlResult.xml = xml
		xmlResult.sourceUrl = invalid
	else
		queryUrl = FullUrl(m.serverUrl, sourceUrl, key)
		print "Fetching content from server at query URL:";queryUrl
		httpRequest = NewHttp(queryUrl)
		response = httpRequest.GetToStringWithRetry()
		xml=CreateObject("roXMLElement")
		if not xml.Parse(response) then
			print "Can't parse feed:";response
		endif
			
		xmlResult.xml = xml
		xmlResult.sourceUrl = queryUrl
	endif
	return xmlResult
End Function

Function listNames(parsedXml) As Object
	content = CreateObject("roArray", 10, true)
	if parsedXml.xml@viewGroup = "apps" then
		content.Push("Video")
		content.Push("Channel Directory")
		'content.Push("Audio")
		'content.Push("Photo")
	else
		sectionViewGroup = parsedXml.xml@viewGroup
		if sectionViewGroup = "secondary" then
			sections = m.GetContent(parsedXml)
			for each section in sections
				content.Push(section.title)
			next
		endif
	endif
	return content
End Function

Function listKeys(parsedXml) As Object
	content = CreateObject("roArray", 10, true)
	if parsedXml.xml@viewGroup = "apps" then
		content.Push("/video")
		content.Push("/system/channeldirectory")
		'content.Push("/music")
		'content.Push("/photos")
	else
		sectionViewGroup = parsedXml.xml@viewGroup
		if sectionViewGroup = "secondary" then
			sections = m.GetContent(parsedXml)
			for each section in sections
				content.Push(section.key)
			next
		endif
	endif
	return content
End Function
		
Function directoryContent(parsedXml) As Object
	content = CreateObject("roArray", 11, true)
	for each directoryItem in parsedXml.xml.Directory
		if directoryItem@search = invalid then
			directory = newDirectoryMetadata(m, parsedXml.sourceUrl, parsedXml.xml, directoryItem)
			content.Push(directory)
		endif
	next
	for each videoItem in parsedXml.xml.Video
		video = newVideoMetadata(m, parsedXml.sourceUrl, parsedXml.xml, videoItem)
		content.Push(video)
	next
	print "Found a content list with elements";content.count()
	return content
End Function

Function IndirectMediaXml(server, originalKey) As Object
	queryUrl = FullUrl(server.serverUrl, "", originalKey)
	print "Fetching content from server at query URL:";queryUrl
	httpRequest = NewHttp(queryUrl)
	response = httpRequest.GetToStringWithRetry()
	xml=CreateObject("roXMLElement")
	if not xml.Parse(response) then
			print "Can't parse feed:";response
			return originalKey
	endif
    return xml
End Function
		
Function constructPluginVideoScreen(metadata) As Object
    print "Constructing plugin video screen for ";metadata.key
    'printAA(metadata)
    if metadata.preferredMediaItem = invalid then
        print "No preferred part"
    	videoclip = ConstructVideoClip(m.serverUrl, metadata.key, metadata.sourceUrl, "", "", metadata.title, "", "")
    else
    	mediaItem = metadata.preferredMediaItem
    	mediaPart = mediaItem.preferredPart
		mediaKey = mediaPart.key
		sourceUrl = metadata.sourceUrl
    	if mediaItem.indirect then
			mediaKeyXml = IndirectMediaXml(m, mediaKey)
			mediaKey = mediaKeyXml.Video.Media.Part[0]@key
			httpCookies = mediaKeyXml@httpCookies
			videoclip = ConstructVideoClip(m.serverUrl, mediaKey, sourceUrl, "", "", metadata.title, httpCookies, "")
		else
			videoclip = ConstructVideoClip(m.serverUrl, mediaKey, sourceUrl, "", "", metadata.title, "", "")
    	end if
        print "Using preferred part ";mediaKey
    end if
    
    p = CreateObject("roMessagePort")
    video = CreateObject("roVideoScreen")
    video.setMessagePort(p)
    video.SetContent(videoclip)
    m.Cookie = StartTranscodingSession(videoclip.StreamUrls[0])
	video.AddHeader("Cookie", m.Cookie)
	return video
End Function

'* TODO: this assumes one part media. Implement multi-part at some point.
Function constructVideoScreen(metadata, mediaData, StartTime As Integer) As Object
	mediaPart = mediaData.preferredPart
	mediaKey = mediaPart.key
    print "Constructing video screen for ";mediaKey
    p = CreateObject("roMessagePort")
    video = CreateObject("roVideoScreen")
    video.setMessagePort(p)
    videoclip = ConstructVideoClip(m.serverUrl, mediaKey, metadata.sourceUrl, metadata.ratingKey, metadata.key, metadata.title, "", "")
    videoclip.PlayStart = StartTime
    video.SetContent(videoclip)
    m.Cookie = StartTranscodingSession(videoclip.StreamUrls[0])
	video.AddHeader("Cookie", m.Cookie)
	return video
End Function

Function stopTranscode()
	stopTransfer = CreateObject("roUrlTransfer")
    stopTransfer.SetUrl(m.serverUrl + "/video/:/transcode/segmented/stop")
    stopTransfer.AddHeader("Cookie", m.Cookie) 
    content = stopTransfer.GetToString()
End Function


'* Constructs a Full URL taking into account relative/absolute. Relative to the 
'* source URL, and absolute URLs, so
'* relative to the server URL
Function FullUrl(serverUrl, sourceUrl, key) As String
    'print "ServerURL:";serverUrl
    'print "SourceURL:";sourceUrl
    'print "Key:";key
	finalUrl = ""
	if left(key, 4) = "http" then
	    finalUrl = key
	else if key = "" AND sourceUrl = "" then
	    finalUrl = serverUrl
    else if key = "" AND serverUrl = "" then
        finalUrl = sourceUrl
	else if left(key, 1) = "/" then
		finalUrl = serverUrl+key
	else
		finalUrl = sourceUrl+"/"+key
	endif
    'print "FinalURL:";finalUrl
	return finalUrl
End Function

'* Constructs an image based on a PMS url with the specific width and height. 
Function TranscodedImage(queryUrl, imagePath, width, height) As String
	imageUrl = FullUrl(m.serverUrl, queryUrl, imagePath)
	encodedUrl = HttpEncode(imageUrl)
	image = m.serverUrl + "/photo/:/transcode?url="+encodedUrl+"&width="+width+"&height="+height
	'print "Final Image URL:";image
	return image
End Function

'* Starts a transcoding session by issuing a HEAD request and captures
'* the resultant session ID from the cookie that can then be used to
'* access and stop the transcoding
Function StartTranscodingSession(videoUrl) As String
	cookiesRequest = CreateObject("roUrlTransfer")
	cookiesRequest.SetUrl(videoUrl)
	cookiesHead = cookiesRequest.Head()
	cookieHeader = cookiesHead.GetResponseHeaders()["set-cookie"]
	return cookieHeader
End Function

'* Roku video clip definition as an array
Function ConstructVideoClip(serverUrl as String, videoUrl as String, sourceUrl As String, ratingKey As String, key As String, title as String, httpCookies as String, userAgent as String) As Object
	deviceInfo = CreateObject("roDeviceInfo")
	quality = "SD"
	if deviceInfo.GetDisplayType() = "HDTV" then
		quality = "HD"
	endif
	print "Setting stream quality:";quality
	videoclip = CreateObject("roAssociativeArray")
    videoclip.StreamBitrates = [0]
    videoclip.StreamUrls = [TranscodingVideoUrl(serverUrl, videoUrl, sourceUrl, ratingKey, key, httpCookies, userAgent)]
    videoclip.StreamQualities = [quality]
    videoclip.StreamFormat = "hls"
    videoclip.Title = title
    return videoclip
End Function

'* Deal with absolute, full then relative URLs
Function ResolveUrl(serverUrl As String, sourceUrl As String, uri As String) As String
	if left(uri, 1) = "/" then
    	return serverUrl + uri 
    else if left(uri, 7) = "http://"
    	return uri
    else
    	return sourceUrl + "/" + uri
    endif
End Function

'*
'* Construct the Plex transcoding URL. 
'*
Function TranscodingVideoUrl(serverUrl As String, videoUrl As String, sourceUrl As String, ratingKey As String, key As String, httpCookies As String, userAgent As String) As String
    print "Constructing transcoding video URL for "+videoUrl
    location = ResolveUrl(serverUrl, sourceUrl, videoUrl)
    print "Location:";location
    if len(key) = 0 then
    	fullKey = ""
    else
    	fullKey = ResolveUrl(serverUrl, sourceUrl, key)
    end if
    print "Original key:";key
    print "Full key:";fullKey
    
	if not(RegExists("quality", "preferences")) then
		RegWrite("quality", "7", "preferences")
	end if
	baseUrl = "/video/:/transcode/segmented/start.m3u8?identifier=com.plexapp.plugins.library&ratingKey="+ratingKey+"&key="+HttpEncode(fullKey)+"&offset=0"
	currentQuality = RegRead("quality", "preferences")
    if currentQuality = "Auto" then
    	myurl = baseUrl+"&minQuality=4&maxQuality=8"
    else
    	myurl = baseUrl+"&quality="+currentQuality
    end if
    myurl = myurl + "&url="+HttpEncode(location)+"&3g=0&httpCookies="+HttpEncode(httpCookies)+"&userAgent="+HttpEncode(userAgent)
	publicKey = "KQMIY6GATPC63AIMC4R2"
	time = LinuxTime().tostr()
	msg = myurl+"@"+time
	finalMsg = HMACHash(msg)
	finalUrl = serverUrl + myurl+"&X-Plex-Access-Key=" + publicKey + "&X-Plex-Access-Time=" + time + "&X-Plex-Access-Code=" + HttpEncode(finalMsg) + "&X-Plex-Client-Capabilities=" + HttpEncode(Capabilities())
	print "Final URL:";finalUrl
    return finalUrl
End Function


Function Capabilities() As String
	protocols = "protocols=http-live-streaming,http-mp4-streaming,http-mp4-video,http-mp4-video-720p,http-streaming-video,http-streaming-video-720p"
	decoders = "videoDecoders=h264{profile:high&resolution:1080&level:40};audioDecoders=aac"
	return protocols+";"+decoders
End Function

'*
'* HMAC encode the message
'* 
Function HMACHash(msg As String) As String
	hmac = CreateObject("roHMAC") 
	privateKey = CreateObject("roByteArray") 
	privateKey.fromBase64String("k3U6GLkZOoNIoSgjDshPErvqMIFdE0xMTx8kgsrhnC0=")
	result = hmac.setup("sha256", privateKey)
	if result = 0
		message = CreateObject("roByteArray") 
		message.fromAsciiString(msg) 
		result = hmac.process(message)
		return result.toBase64String()
	end if
End Function

'*
'* Time since the start (of UNIX time)
'*
Function LinuxTime() As Integer
	time = CreateObject("roDateTime")
	return time.asSeconds()
End Function


REM ******************************************************
REM Constucts a URL Transfer object
REM ******************************************************

Function CreateURLTransferObject(url As String) as Object
    obj = CreateObject("roUrlTransfer")
    obj.SetPort(CreateObject("roMessagePort"))
    obj.SetUrl(url)
    obj.AddHeader("Content-Type", "application/x-www-form-urlencoded")
	obj.AddHeader("X-Plex-Version", "0.9") '* Correct ?
	obj.AddHeader("X-Plex-Language", "en") '* Anyway to get this from the platform ?
	obj.AddHeader("X-Plex-Client-Platform", "Roku")
    obj.EnableEncodings(true)
    return obj
End Function

REM ******************************************************
REM Url Query builder
REM so this is a quick and dirty name/value encoder/accumulator
REM ******************************************************

Function NewHttp(url As String) as Object
    obj = CreateObject("roAssociativeArray")
    obj.Http                        = CreateURLTransferObject(url)
    obj.FirstParam                  = true
    obj.AddParam                    = http_add_param
    obj.AddRawQuery                 = http_add_raw_query
    obj.GetToStringWithRetry        = http_get_to_string_with_retry
    obj.PrepareUrlForQuery          = http_prepare_url_for_query
    obj.GetToStringWithTimeout      = http_get_to_string_with_timeout
    obj.PostFromStringWithTimeout   = http_post_from_string_with_timeout

    if Instr(1, url, "?") > 0 then obj.FirstParam = false

    return obj
End Function


