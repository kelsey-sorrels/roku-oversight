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
	'----- Screen Facade Background here ---------------
	screenFacade = CreateObject("roPosterScreen")
	screenFacade.show()

    SetTheme()

	' List of {url:String, selectedElementIndex:Int}
	history = CreateObject("roList")
	showMenu = false
	selectedMenuIndex = 0
	selectedElementIndex = 0
	currentUrl = "http://google.com"
	history.AddTail({url:currentUrl, selectedElementIndex:0})
	elements = NavigateToUrl(currentUrl)

    port = CreateObject("roMessagePort")
    screen = CreateObject("roScreen")
	screen.SetPort(port)

	DrawPage(screen, elements, selectedElementIndex)
	While(true)
		msg = wait(0, port)
		If type(msg) = "roUniversalControlEvent" Then
			i = msg.GetInt()
			print "Key Pressed - " ; msg.GetInt()
			If i = 0 and history.Count() > 1 Then
				' Back - Go to previous URL.
				previous = history.RemoveTail()
				elements = NavigateToUrl(previous.url)
				selectedElementIndex = previous.selectedElementIndex
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
						selectedMenuIndex = 3
					End If
					DrawMenu(screen, selectedMenuIndex)
				End If
			Else If i = 5 Then
				' Right - If showMenu then advance
				If showMenu Then
					selectedMenuIndex = selectedMenuIndex + 1
					If selectedMenuIndex > 3 Then
						selectedMenuIndex = 0
					End If
					DrawMenu(screen, selectedMenuIndex)
				End If
			Else If i = 6 Then
				If showMenu Then
					' Select - Perform menu button action
					If selectedMenuIndex = 0 Then
						' Back - Go to previous URL.
						previous = history.RemoveTail()
						elements = NavigateToUrl(previous.url)
						currentUrl = previous.url
						selectedElementIndex = previous.selectedElementIndex
						DrawPage(screen, elements, selectedElementIndex)
					Else If selectedMenuIndex = 1 Then
						' Refresh - Go to same URL.
						elements = NavigateToUrl(currentUrl)
						selectedElementIndex = 0
						DrawPage(screen, elements, selectedElementIndex)
					Else If selectedMenuIndex = 2 Then
						' WWWW - Show keyboard screen
						targetUrl = ShowURLKeyboard()
						print "User entered: "; targetUrl
						If not (targetUrl = invalid) Then
							history.AddTail({url:currentUrl, selectedElementIndex:selectedElementIndex})
							currentUrl = targetUrl
							screen = invalid
						    screen = CreateObject("roScreen")
							screen.SetPort(port)
							elements = NavigateToUrl(currentUrl)
							selectedElementIndex = 0
							showMenu = false
							DrawPage(screen, elements, selectedElementIndex)
						End If
					Else If selectedMenuIndex = 3 Then
						' Bookmarks - Show bookmarks screen
						targetUrl = ShowBookmarksScreen(currentUrl)
						print "User selected: "; targetUrl
						If not (targetUrl = invalid) Then
							history.AddTail({url:currentUrl, selectedElementIndex:selectedElementIndex})
							currentUrl = targetUrl
						    screen = invalid
							screen = CreateObject("roScreen")
							screen.SetPort(port)
							elements = NavigateToUrl(currentUrl)
							selectedElementIndex = 0
							showMenu = false
							DrawPage(screen, elements, selectedElementIndex)
						End If
					End If
				Else
					' Select - Go to Link
					targetUrl = elements.links[selectedElementIndex].href
					history.AddTail({url:currentUrl, selectedElementIndex:selectedElementIndex})
					currentUrl = targetUrl
					elements = NavigateToUrl(currentUrl)
					selectedElementIndex = 0
					DrawPage(screen, elements, selectedElementIndex)
				End If
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
	screenFacade.showMessage("")
	sleep(25)
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

Function NavigateToUrl(url) as Object
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
				print "Get response."
				'print "Response:"
				'print response
				json = ParseJson(response)
				notFound = false
			Else If msg.GetResponseCode() = 404 Then
				print "retrying..."
				http.AsyncGetToString()
			End If
		End If
	End While

	'print "JSON:"
	'print json

	http.SetUrl("http://oversight-js.herokuapp.com" + json.images[0])
	pageImgPath = "tmp:/page.jpg"
	http.GetToFile(pageImgPath)
	print "Navigation complete"
	return json
End Function

Sub DrawPage(screen, elements, selectedElementIndex)
	screen.Clear(&h00000000)
	pageImgPath = "tmp:/page.jpg"
	page = CreateObject("roBitmap", pageImgPath)
	screen.DrawObject(8, 8, page)
	selectedElement = elements.links[selectedElementIndex]
	If not (selectedElement = invalid) Then
		DrawElementSelectionBox(screen, selectedElement.x, selectedElement.y, selectedElement.width, selectedElement.height)	
	End If
	screen.Finish()
	print "Drawing to screen complete"
End Sub

Sub DrawMenu(screen, selectedMenuIndex)
	buttonImgPaths = ["pkg:/images/back-button.png"
	                  "pkg:/images/refresh-button.png"
	                  "pkg:/images/www-button.png"
	                  "pkg:/images/bookmark-button.png"]
	selectedButtonImgPaths = ["pkg:/images/back-button-selected.png"
	                          "pkg:/images/refresh-button-selected.png"
	                          "pkg:/images/www-button-selected.png"
	                          "pkg:/images/bookmark-button-selected.png"]
	buttons = CreateObject("roList")
	For Each i in [0, 1, 2, 3]
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
	x = x + 8
	y = y + 8
	screen.DrawLine(x-1, y, x+width, y, &hFF9900FF)
	screen.DrawLine(x-1, y, x, y+height, &hFF9900FF)
	screen.DrawLine(x+width, y+height, x+width, y, &hFF9900FF)
	screen.DrawLine(x+width, y+height, x, y+height, &hFF9900FF)
	screen.Finish()
End Sub

Function ShowURLKeyboard() As String
	kbdScreen = CreateObject("roKeyboardScreen")
	port = CreateObject("roMessagePort")
	kbdScreen.setMessagePort(port)
	kbdScreen.SetTitle("Navigate to URL")
	kbdScreen.SetDisplayText("enter destination")
	kbdScreen.SetMaxLength(50)
	kbdScreen.AddButton(1, "Go")
	kbdScreen.AddButton(2, "Back")
	kbdScreen.Show()

	While true
		msg = wait(0, kbdScreen.GetMessagePort())
		If type(msg) = "roKeyboardScreenEvent" Then
			If msg.isScreenClosed() Then
				return invalid
			Else If msg.isButtonPressed() Then
				If msg.GetIndex() = 1 Then
					url = kbdScreen.GetText()
					' If the user didn't enter http://, then enter it for them
					If not (Left(url, 7) = "http://") Then
						url = "http://" + url
					End If
					return url
				Else
					return invalid
				End If
			End If
		End If
	End While
End Function

Function ShowBookmarksScreen(currentUrl) As String
	bookmarksScreen = CreateObject("roPosterScreen")
	port = CreateObject("roMessagePort")
	bookmarksScreen.setMessagePort(port)
	bookmarksScreen.SetTitle("Bookmarks")
	bookmarksScreen.SetListStyle("arced-16x9")

	content = [{HDPosterUrl:"http://thumbs-js.herokuapp.com/thumb?href=http://news.ycombinator.com&size=300"
	            ShortDescriptionLine1:"Hacker News"
	            Url:"http://news.ycombinator.com"}
	           {HDPosterUrl:"http://thumbs-js.herokuapp.com/thumb?href=http://www.wikipedia.org&size=300"
	            ShortDescriptionLine1:"Wikipedia - The free encyclopedia"
	            Url:"http://en.wikipedia.org"}
	           {HDPosterUrl:"http://thumbs-js.herokuapp.com/thumb?href=http://www.reddit.com&size=300"
	            ShortDescriptionLine1:"Reddit: the front page of the internet"
	            Url:"http://reddit.com"}
	           ]
	bookmarksScreen.SetContentList(content)
	bookmarksScreen.Show()

	While true
		msg = wait(0, bookmarksScreen.GetMessagePort())
		If type(msg) = "roPosterScreenEvent" Then
			If msg.isScreenClosed() Then
				return invalid
			Else If msg.isListItemSelected() Then
				return content[msg.GetIndex()].Url
			End If
		End If
	End While
End Function
