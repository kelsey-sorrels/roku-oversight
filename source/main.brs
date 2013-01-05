' ********************************************************************
' ********************************************************************
' **
' **  Roku Oversight Channel (BrightScript)
' **
' **  January 2013
' ********************************************************************
' ********************************************************************

REM Roku Oversight Browser

Sub Main()

    SetTheme()

    screen = CreateObject("roScreen")
    port = CreateObject("roMessagePort")
	fontRegistry = CreateObject("roFontRegistry")
	fontRegistry.Register("pkg:/fonts/FontAwesome.otf")
	'36pt, 50=med weight, no italices
	fontAwesome = fontRegistry.Get("FontAwesome", 36, 50, false) 

	screen.SetPort(port)

	history = CreateObject("roList")
	history.AddTail("http://google.com")
	showMenu = false
	selectedMenuIndex = 0
	selectedElementIndex = 0
	currentUrl = "http://google.com"
	elements = NavigateToUrl(screen, currentUrl)
	DrawPage(screen, elements, selectedElementIndex)
	While(true)
		msg = wait(0, port)
		If type(msg) = "roUniversalControlEvent" Then
			i = msg.GetInt()
			print "Key Pressed - " ; msg.GetInt()
			If i = 0 and history.Count() > 1 Then
				' Back - Go to previous URL.
				previousUrl = history.RemoveTail()
				elements = NavigateToUrl(screen, previousUrl)
				selectedElementIndex = 0
				DrawPage(screen, elements, selectedElementIndex)
			Else If i = 2 Then
				' Up - Go to previous element
				selectedElementIndex = selectedElementIndex - 1
				DrawPage(screen, elements, selectedElementIndex)
			Else If i = 3 Then
				' Down - Go to next element
				selectedElementIndex =  selectedElementIndex + 1
				DrawPage(screen, elements, selectedElementIndex)
			Else If i = 4 Then
				' Left - If showMenu then advance
				If showMenu Then
					selectedMenuIndex = selectedMenuIndex - 1
					If selectedMenuIndex < 0 Then
						selectedMenuIndex = 5
					End If
					DrawMenu(screen, selectedMenuIndex)
				End If
			Else If i = 5 Then
				' Right - If showMenu then advance
				If showMenu Then
					selectedMenuIndex = selectedMenuIndex + 1
					If selectedMenuIndex > 5 Then
						selectedMenuIndex = 0
					End If
					DrawMenu(screen, selectedMenuIndex)
				End If
			Else If i = 6 Then
				' Select - Go to Link
				targetUrl = elements.links[selectedElementIndex].href
				history.AddTail(currentUrl)
				currentUrl = targetUrl
				elements = NavigateToUrl(screen, currentUrl)
				selectedElementIndex = 0
				DrawPage(screen, elements, selectedElementIndex)
			Else If i = 10 Then
				' Info - Show menu
				showMenu = NOT showMenu
				If showMenu Then
					DrawMenu(screen, selectedMenuIndex)
				Else
					DrawPage(screen, elements, selectedElementIndex)
				End If
			End If
		End If
	End While
End Sub

REM ******************************************************
REM
REM Setup theme for the application 
REM
REM ******************************************************

Sub SetTheme()
    app = CreateObject("roAppManager")
    theme = CreateObject("roAssociativeArray")
    app.SetTheme(theme)
End Sub

REM ******************************************************
REM
REM Navigate to URL
REM
REM ******************************************************

Function NavigateToUrl(screen, url) as Object
    http = CreateObject("roUrlTransfer")
    port = CreateObject("roMessagePort")
	http.SetPort(port)
	
	http.SetUrl("http://oversight-js.herokuapp.com/page?href=" + url)
    json = ParseJSON(http.GetToString())
	' Go to http://oversize-js.herokuapp.com + json.data repeatedly until it is no longer a 404
	' Then
	json = ParseJson(http.GetToString())

	print "JSON:"
	print json
	http.SetUrl("http://oversight-js.herokuapp.com" + json.data)
	http.AsyncGetToString()
	notFound = true

	While(notFound)
		msg = wait(0, port)
		If type(msg) = "roUrlEvent" Then
			If msg.GetResponseCode() = 200 Then
				response = msg.GetString()
				print "Response:"
				print response
				json = ParseJson(response)
				notFound = false
			Else If msg.GetResponseCode() = 404 Then
				print "retrying..."
				http.AsyncGetToString()
			End If
		End If
	End While

	print "JSON:"
	print json

	http.SetUrl("http://oversight-js.herokuapp.com" + json.images[0])
	pageImgPath = "tmp:/page.jpg"
	http.GetToFile(pageImgPath)
	print "Navigation complete"
	return json
End Function

Sub DrawPage(screen, elements, selectedElementIndex)
	pageImgPath = "tmp:/page.jpg"
	page = CreateObject("roBitmap", pageImgPath)
	screen.DrawObject(5, 5, page)
	selectedElement = elements.links[selectedElementIndex]
	DrawElementSelectionBox(screen, selectedElement.x, selectedElement.y, selectedElement.width, selectedElement.height)	
	screen.Finish()
	print "Drawing to screen complete"
End Sub

Sub DrawMenu(screen, selectedMenuIndex)
	buttonImgPaths = ["pkg:/images/back-button.png"
	                  "pkg:/images/refresh-button.png"
	                  "pkg:/images/www-button.png"]
	selectedButtonImgPaths = ["pkg:/images/back-button-selected.png"
	                          "pkg:/images/refresh-button-selected.png"
	                          "pkg:/images/www-button-selected.png"]
	buttons = CreateObject("roList")
	For Each i in [0, 1, 2]
		If i = selectedMenuIndex Then
			buttons.AddTail({x:i*64+20, bitmap:CreateObject("roBitmap", selectedButtonImgPaths[i])})
		Else
			buttons.AddTail({x:i*64+20, bitmap:CreateObject("roBitmap", buttonImgPaths[i])})
		End If
	End For

	For Each button in buttons
		screen.DrawObject(button.x, 646, button.bitmap)
	End For
	screen.Finish()
	print "Drawing menu complete"
End Sub

REM ******************************************************
REM
REM Draw element selection box
REM
REM ******************************************************

Sub DrawElementSelectionBox(screen, x, y, width, height)
	x = x + 5
	y = y + 5
	screen.DrawLine(x-1, y, x+width, y, &hFF9900FF)
	screen.DrawLine(x-1, y, x, y+height, &hFF9900FF)
	screen.DrawLine(x+width, y+height, x+width, y, &hFF9900FF)
	screen.DrawLine(x+width, y+height, x, y+height, &hFF9900FF)
	screen.Finish()
End Sub
