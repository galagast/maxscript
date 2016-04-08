/*
Point Cache Conductor
Version: 1.2
by Jefferson D. Lim

- Enables PointCaching in WORLD SPACE a selection of objects onto a path repository using.
- Uses the recorded cache to reassign them back to the objects by name.
- Can create a Local Timer node to control a PointCache's playback graph with offset.
- Can also create a Global Timer control for all Local Timers.
- This can also be used to simply just set a PointCache's path by object name.

* Names of objects for caching should not end with 3 trail numbers

[1.2]
2016-04-08
		Uploaded to Github.
		Further update notes will be there.
		Renamed to Point Cache Conductor.

[1.1]
2015-09-14
01		Fixed Not centering when Connecting Local Timer
		Fixed Connect Local Timer Issues
			- Local timer being created even is selection has no pcache mods.

[1.0]
2015-07-28
01		Initial Build
2015-07-29
13		Fixed scaling. 
		Added xform and convertToPoly
14		Added UI
2015-07-30
20		Ground center position of LocalTimer based on selection
		Ui acces disabled if path is not set
25		Added path history rcmenu
29		Added checks for existing pcache mods
		Enabled record and load buttons
		Added messages to log
31		Fixed percent display
2015-08-01
39		Adjustable internal history count
40		Connect Local Timer Functional
41		Connect Global Timer Functional
42		Layer name saved to ini
		Added Icons
43		Added cache types
		Added Timer Layer on/off
45		Added windows.processPostedMessages() to update logWindow messages
2015-08-02
47		Updated Load Cache logic (see fn for notes)
49		Slight tweak in Options UI
2015-08-04
50		Fixed matchpattern, removed "*" in file
		Fixed Local Timer Connect evaluating "val"; changed to objArr
2015-08-05
51		Fixed Load Cache not loading time correctly
53		Was looking for a way to set modifier properties in a fn. (unable to)
55		Added name check and warning.
56		Added overwrite if existing cache used by object is same as output.
58		Updated UI
59		Added tooltips
		Improved dupe detection and selection
		added messageBox when done
60		Working Lock Anim button
2015-08-08
63		restore custom range frame on load cache
2015-08-10
65		added ability to connect local timer by common parent
*/

try(destroyDialog pcacheConductor)catch()
rollout pcacheConductor "PCache Conductor 1.2" width:200 height:435
(
	local tStart
	local tEnd
	
	local arr = #()
	local delArr = #()
	local mode = 0
	local thePath = ""
	local HistoryPaths

	local timerLayer = "Cache Timer"
	local localTimerPos = [0,0,0]
	local iniFile = getDir #plugCfg + @"\pcacheConductor.ini"
	local numHistory = 15
	
	local logWindow
	local logMsg = ""
	local logOpen = off
	
	local debugMode = 0

	GroupBox grp_path "Cache Path:" pos:[5,5] width:190 height:45 
 
	edittext edt_path "" pos:[10,20] width:159 height:20 readOnly:true fieldwidth:155
	button btn_path "..." pos:[172,20] width:20 height:20 border:false
	
	GroupBox grp1 "Timing:" pos:[5,55] width:190 height:90
	button btn_time_icon "" pos:[15,75] width:25 height:25 border:false
	label lbl_start "Start:" pos:[50,75] width:40 height:15
	spinner spn_start "" pos:[85,75] width:100 height:16 range:[-999999,999999,0]
	label lbl_end "End:" pos:[50,95] width:40 height:15
	spinner spn_end "" pos:[85,95] width:100 height:16 range:[-999999,999999,0]
	button btn_anim "Animation Range" pos:[50,115] width:115 height:20
	checkbutton btn_anim_lock "L" pos:[165,115] width:20 height:20
	
	GroupBox grp_proc "Process:" pos:[5,150] width:190 height:125
	button btn_proc_icon "" pos:[15,170] width:25 height:25 border:false
	button btn_rec "Record Cache" pos:[50,170] width:135 height:20
	button btn_load "Load Cache" pos:[50,195] width:135 height:20
	button btn_loc "Local Timer" pos:[50,220] width:135 height:20 enabled:false
	button btn_glo "Global Timer" pos:[50,245] width:135 height:20 enabled:false
	
	GroupBox grp_ops "Options:" pos:[5,280] width:190 height:65
	button btn_ops_icon "" pos:[15,300] width:25 height:25 border:false
	checkbox chk_lay "Timer Layer:" pos:[55,300] width:80 height:15 checked:true
	edittext edt_lay "" pos:[70,320] width:114 height:17 fieldwidth:155
	GroupBox grp_type "" pos:[5,338] width:190 height:57
	radiobuttons rdo_type "Cache Type:" pos:[55,355] width:99 height:30 labels:#("PC2", "XML") default:1 columns:2 offsets:#([20,0], [0,0])
	
	button btn_log "" pos:[5,400] width:30 height:30
	button btn_apply "Apply" pos:[35,400] width:130 height:30
	button btn_sel "" pos:[165,400] width:30 height:30
	
-- 	button btn_log "Show Log Window..." pos:[5,423] width:190 height:18 border:false

	fn setRange =
	(
		tStart = spn_start.value = animationRange.start.frame
		tEnd = spn_end.value = animationRange.end.frame
	)
	
	fn formatPercent txt =
	(
		txt = txt as string
		local txtArr = filterstring txt "."
		local a = txtArr[1]
		local b = txtArr[2]
		if a.count == 1 then a = "0"+ a[1]
		if b.count == 1 then b = b[1] +"0"
		if b.count >= 2 then b = b[1] + b[2]
		if a.count == 3 then (a = "100"; b = "0")
		
		a + "." + b
	)
	
	fn deNumber txt check:off =
	(
		local n = txt.count
		local check1 = execute txt[n-0] != undefined
		local check2 = execute txt[n-1] != undefined
		local check3 = execute txt[n-2] != undefined
		local result = check1 and check2 and check3
		if debugMode == 3 then format "checks: % % % = %\n" check1 check2 check3 result
		local outTxt = if result then trimright txt "1234567890" else txt
		
		if check then return result else return outTxt
	)
		
	fn showProgress pType pCurrent pTotal pObj =
	(
		local theVal = pCurrent*100.0/pTotal
		local theType = case pType of
		(
			1: "Record Cache"
			2: "Load Cache"
			3: "Attaching Local Timer"
			4: "Attaching Global Timer"
		)
		local msg = "[" + (formatPercent theVal) + "] " + theType + ": " + pObj.name 
		pcacheConductor.logWindow.setMsg msg
		
		msg
	)
	
	fn countPhrase txt num =
	(
		case of
		(
			(num == 0): "0 " + txt + "s"
			(num == 1): "1 " + txt
			(num >= 2): num as string + " " + txt + "s"
		)
	)
	
	fn isValidArr selArr =
	(
		local theNames = #()
		local count = selArr.count
		
		local theDupes = #()
		local theNums = #()
		for i in 1 to count do
		(
			local theObj = selArr[i]
			local theName = theObj.name
			local dex = findItem theNames theName
			if dex > 0 then
			(
				appendIfUnique theDupes theObj
				appendIfUnique theDupes selArr[dex]
			)
			if (deNumber theName check:on) then append theNums theObj
			append theNames theName
		)
		
		local dupeCount = theDupes.count
		local numCount = theNums.count
		local checkDupe = dupeCount != 0
		local checkNum = numCount != 0
		if checkDupe or checkNum then
		(
			for i in 1 to dupeCount do
			(
				local msg = "[" + i as string + "][Duplicate Name] " + theDupes[i].name
				pcacheConductor.logWindow.setMsg msg				
			)
			for i in 1 to numCount do
			(
				local msg = "[" + i as string + "][Numbered Name] " + theNums[i].name
				pcacheConductor.logWindow.setMsg msg				
			)
			
			local msgTxt = ""
			msgTxt += "Unable to proceed.\n\n"
			if checkDupe then msgTxt += "Found " + countPhrase "object" dupeCount + " with duplicate names.\n"
			if checkNum then msgTxt += "Found " + countPhrase "object" numCount  + " with trailing 3 digit numbers.\n\n"
			msgTxt += "Do you want to select the objects?"
			
			if queryBox msgTxt title:"Point Cache Conductor Warning" then
			(
				deselect $*
				select (join theDupes theNums)
			)
			return (#())
		)
		else
		(
			return selArr
		)
	)
	
	fn getSelection =
	(
		/*
		Collect selection for processing.
		Also collect center point of selection.
		*/
		local p = [0,0,0]
		tempArr = #()
		for obj in selection where superClassOf obj == GeometryClass do
		(
			append tempArr obj
			p += obj.center
		)
		p = p/selection.count
		
		localTimerPos = [p.x, p.y, selection.min.z]
-- 		format "mode: %\n" mode
-- 		format "tempArr: %\n" tempArr
		if mode <= 2 then isValidArr tempArr else tempArr
	)
	
	fn getCacheType = if rdo_type.state == 1 then ".pc2" else ".xml"
	
	fn getPCacheMods objArr =
	(
		local objArr = if classOf objArr != array then #(objArr) else objArr
		local pCacheMods = #()
		local count = objArr.count
		for i in 1 to count do
		(
			local obj  = objArr[i]
			local mods = obj.modifiers
			local count = mods.count
			for m in 1 to count do
			(
				if classOf mods[m] == pointCache do appendIfUnique pCacheMods mods[m] 
			)
		)
		pCacheMods
	)
	
	fn recordPCache objArr =
	(
		local objCount = objArr.count
		for i in 1 to objCount do
		(
			windows.processPostedMessages()
			local theObj = objArr[i]
			local theName = theObj.name
			local theCacheFile = thePath + @"\" + theObj.name + (getCacheType())
			local theModArr = getPCacheMods theObj
			local addMod = true
			if theModArr.count > 0 then
			(
				local theMod = theModArr[1]
				if theMod.fileName == theCacheFile then
				(
					msg = "[Skipped] " + theName + " (Avoided overwriting the same cache.)"
					pcacheConductor.logWindow.setMsg msg
					addMod = false
				)
			)
			if addMod then
			(
				showProgress 1 i objCount theObj
				
				local theMod = copy (PointCacheWSM filename:theCacheFile)
				addModifier theObj theMod
				theMod = theObj.modifiers[1]
				cacheOps.RecordCache theMod
				deleteModifier theObj 1
			)
		)
		objArr
	)
	
	fn collectSubfolderCache =
	(
		local cacheFilesSub = #()
		local theFolders = getDirectories (thePath + @"\*")
		local count = theFolders.count
		for i in 1 to count do
		(
			local theFiles = getFiles (theFolders[i] + @"\*" + (getCacheType())) 
			join cacheFilesSub theFiles
		)
		if debugMode == 2 then format "folders: %\n" theFolders
		if debugMode == 2 then format "cacheFilesSub: %\n" cacheFilesSub
		cacheFilesSub
	)
	
	fn matchInFiles file fileArr =
	(
		/*
		<file>		: string filename
		<fileArr>	: string array of names
		return	: integer index, 0 if not found
		*/
		local dex = 0
		local count = fileArr.count
		for i in 1 to count do
		(
			local check = matchpattern fileArr[i] pattern:file
			if check then
			(
				dex = i
				exit
			)
		)
		dex
	)
	
	fn getParentFolder txt up:1=
	(
		/*
		<txt>		: string file path
		return	: string immediate folder of file
		*/
		local par = ""
		local txtArr = filterstring txt "\\"
		local count = txtArr.count
		if count != 0 then par = txtArr[count-up]
		par
	)
	
	fn getCache theObj theMod =
	(
		/*
		<theObj>	: node to process
		<theMod>	: modifier pcache
		return		: string cache path
		
		1. Get the file name without its numbering
		2. collect the cache files (and it's names) in the path for comparison
		3. If not found in the immediate path, look through subfolders.
		4. Check the original parent folder name first
		5. If original parent folder not found, match to any other folder contents.
		*/
		local theName = theObj.name
		local theFile = deNumber theName -- 1
-- 		local theFile = trimright theName "1234567890"  -- 1
		if debugMode == 3 then format "theFile: %\n"  theFile
		local cacheFiles = getFiles (thePath + @"\*" + (getCacheType())) -- 2
		local cacheNames = for n in cacheFiles collect getFilenameFile n  -- 2
		
		local dex = matchInFiles theFile cacheNames -- 3
		if dex != 0 then 
		(
			if debugMode == 3 then format "dex: %\n" dex
			return cacheFiles[dex]
		)
		else
		(
			local modCacheFile = theMod.filename
			if modCacheFile != "" then
			(
				local cacheParentFolder = getParentFolder modCacheFile
				local cacheFolders = getDirectories  (thePath + @"\*")
				local cacheFolderNames = for n in cacheFolders collect getParentFolder n up:0

				local dexPar = matchInFiles cacheParentFolder cacheFolderNames -- 4
				if dexPar != 0 then
				(
					if debugMode == 3 then format "dexPar: %\n" dexPar
					local theCacheFile = cacheFolders[dexPar] + theFile +  (getCacheType())
					return theCacheFile
				)
				else
				(
					local cacheFilesSub = collectSubfolderCache()
					local cacheNamesSub = for n in cacheFilesSub collect getFilenameFile n
					
					local dexSub = matchInFiles theFile cacheNamesSub -- 5
					if dexSub != 0 then
					(
						if debugMode == 3 then format "dexSub: %\n" dexSub
						return cacheFilesSub[dexSub]
					)
					else
					(
						return ""
					)
				)
			)
		)
	)
	
	fn loadCache objArr =
	(
		local newObjs = #()
		local objCount = objArr.count
		for i in 1 to objCount do
		(
			local theObj = objArr[i]	
			local theName = theObj.name
			showProgress 2 i objCount theObj
			
			local rStartFrame
			local rEndFrame
			local theModArr = getPCacheMods theObj
			local theMod 
			if theModArr.count != 0 then
			(
				theMod = theModArr[1] -- get only first found mod
				
				rStartFrame = theMod.playBackStart
				rEndFrame = theMod.playBackEnd
			)
			else
			(
				theMod = PointCache recordStart:tStart recordEnd:tEnd
				local theMat = theObj.material
				local theClr = theObj.wireColor
				local preLayer = for o in (refs.dependson theObj) where classof o == Base_LayerBase_Layer collect o
				local theLayerName = if preLayer.count > 0 then preLayer[1].name else "0"
				
				local preObj = snapShot theObj
				append delArr theObj
				theObj = preObj
				(LayerManager.getLayerFromName theLayerName).addNode theObj
				theObj.name = theName
				theObj.material = theMat
				theObj.wireColor = theClr
				theObj.parent = undefined
				resetxform theObj
				convertToMesh theObj
				theObj.transform = matrix3 1
				addModifier theObj theMod
			)
			theMod.recordStart = tStart
			theMod.recordEnd = tEnd
			theMod.loadType = 2
			
			local theCacheFile = getCache theObj theMod
			if theCacheFile != undefined then
			(
				if doesFileExist theCacheFile then
				(
					theMod.filename = theCacheFile
					theMod.playBackStart = if rStartFrame != undefined then rStartFrame else tStart
					theMod.playBackEnd = if rEndFrame != undefined then rEndFrame else tEnd
					append newObjs theObj
				)
				else
				(
					local msg = "Match Not Found in Directory: " + theName
					pcacheConductor.logWindow.setMsg msg
				)
			)
			else
			(
				local msg = "Match Not Found in Directory: " + theName
				pcacheConductor.logWindow.setMsg msg
			)
		)
		newObjs
	)
	
	fn addToLayer obj layer =
	(
		local theLayer = LayerManager.getLayerFromName layer
		if theLayer == undefined then theLayer = LayerManager.newLayerFromName layer
		theLayer.addnode obj
	)	
	
	/* Local Timer Functions */
	local locTimeDef = attributes 'Local Timer Parameters'
	(
		parameters main rollout:params
		(
			'Time' type:#float ui:spn_time default:0
			'Offset' type:#float ui:spn_offset default:0
		)
		
		rollout params "Local Timer"
		(
			spinner spn_time "Time:" type: #float range:[-999999,999999,0] enabled:on
			spinner spn_offset "Offset:" type: #float range:[-999999,999999,0]
		)
	)
	fn createLocalTimer locPos: =
	(
		local locObj = dummy name:"Local Timer" pos:(if locPos == unsupplied then localTimerPos else locPos)
		if debugMode == 1 then format "centerLocalTimer\n\t%\n" arr
		if chk_lay.checked then  addToLayer locObj timerLayer
		CustAttributes.add locObj locTimeDef
		
		-- Local Playback
		locObj.time.controller = bezier_float()
		local theLst = float_list()
		locObj.time.controller = theLst
		theLst.setName 1 "TimePlayback"
		
		-- Offset
		locObj.offset.controller = bezier_float()
		locObj.time.controller.available.controller = locObj.offset.controller 
		theLst.setName 2 "TimeOffset"
		
		locObj
	)
	fn attachLocalTimer pcArr obj: =
	(
		local locObj = if isValidNode obj then
		(
			obj
		)
		else
		(
			if debugMode == 1 then format "createLocalTimer...\n" 
			createLocalTimer()
		)
		
		local theName = locObj.name
		local pcCount = pcArr.count
		for i in 1 to pcCount do
		(
			local theObj = pcArr[i]
			showProgress 3 i pcCount theObj
			local theMod = theObj.modifiers[1]
			if classOf theMod == pointCache then
			(
				theMod.playbackType = 3
				theMod.playbackFrame.controller = locObj.time.controller
			)
			else
			(
				local msg = "No PointCache Modifier Found: " + theObj.name
				pcacheConductor.logWindow.setMsg msg
			)
		)
		locObj
	)
	
	/* Global Timer Functions */
	local gloTimeDef = attributes 'Global Timer Parameters'
	(
		parameters main rollout:params
		(
			'Time' type:#float ui:spn_time default:0
		)
		
		rollout params "Global Timer"
		(
			spinner spn_time "Time:" type: #float range:[-999999,999999,0]
		)
	)
	fn createGlobalTimer =
	(
		local gloTimer = dummy name:"Global Timer"boxsize:	[50,50,50]
		if chk_lay.checked then  addToLayer gloTimer timerLayer
		CustAttributes.add gloTimer gloTimeDef
		
		-- Global Playback
		gloTimer.time.controller = bezier_float()
		gloTimer
	)
	mapped fn attachGlobalTimer theLoc obj: =
	(
		local gloObj = if not isValidNode obj then
		(
			if debugMode == 1 then format "createGlobalTimer...\n" 
			createGlobalTimer()
		)
		else
		(
			obj
		)
		
		local theName = gloObj.name
		local msg = "Attaching Global Timer: " + theName
		pcacheConductor.logWindow.setMsg msg
		
		if isValidNode obj then
		(
			local oldCon = theLoc.time.controller[1].controller
			local newCon = gloObj.time.controller
			replaceInstances oldCon newCon
		)
		else
		(
			local theCon = bezier_float()
			gloObj.time.controller = theLoc.time.controller["TimePlayback"].controller = theCon
			theLoc.time.controller.setname 1 "TimePlayback"
			
			addNewKey theCon tStart
			addNewKey theCon tEnd
			
			theKey = gloObj.time.controller.keys[1]
			theKey.value = 0
			theKey.inTangentType = #linear
			theKey.outTangentType = #linear
			
			theKey = gloObj.time.controller.keys[2]	
			theKey.value = tEnd - tStart
			theKey.inTangentType = #linear
			theKey.outTangentType = #linear
		)
		
		gloObj
	)
	
	fn findDuplicateName arr =
	(
		
	)
	
	fn cleanUpArray arr =
	(
		for obj in arr where isValidNode obj collect obj
	)

	fn findAttrib arr txt =
	(
		/*
		<arr> node array
		<txt> string attribute name
		*/
		local foundArr = #()
		for obj in arr do
		(
			local count = custAttributes.count obj
			for i in 1 to count do
			(
				local att = custAttributes.get obj i
				if att.name == txt then append foundArr obj
			)
		)
		foundArr
	)
	
	fn getLocalTimer all:false=
	(
		local localTimerArr = findAttrib selection "Local Timer Parameters"
		if localTimerArr.count != 0 then (if all then localTimerArr else localTimerArr[1]) else #()
	)

	fn collectPointCacheObjects collection  =
	(
		local foundObjs = #()
		for obj in collection do
		(
			for m in obj.modifiers do
			(
				if classOf m == PointCache then
				(
					local theFile = m.filename
					appendIfUnique foundObjs obj
				)
			)
		)
		foundObjs
	)
	
	fn connectLocalTimerX =
	(
		local locObjs = getLocalTimer all:on
		if locObjs.count > 1 then
		(
			/*
			- This will work on a seletion of objects and localTimers
			- In order to properly make a connection, Both objects
			   and localTimer nodes should have the same parent each.
			*/
			local pcObjs = collectPointCacheObjects selection
			local locPars = for i in locObjs collect i.parent
			
			local pcCount = pcObjs.count
			local locCount = locPars.count
			for i in 1 to pcCount do
			(
				for j in 1 to locCount do
				(
					local theObj = pcObjs[i]
					local objPar = theObj.parent
					local locPar = locPars[j]
					if isValidNode objPar and isValidNode locPar then
					(
						if objPar == locPar then
						(
							for m in theObj.modifiers where classOf m == pointCache do
							(
								local locObjX = locObjs[j]
								
								m.playbackType = 3
								locObjX.time.controller[2].controller = locObjX.offset.controller
								m.playbackFrame.controller = locObjX.time.controller
								
								msg = "Connected: " + theObj.name + " | " + locObjX.name
								pcacheConductor.logWindow.setMsg msg
							)
						)
					)
				)
			)
			locObjs
		)
		if locObjs.count == 0 or locObjs == 1 then
		(
			/*
			works on a single loc timer against multiple selection
			*/
			local modArrX = getPCacheMods (selection as array)
			local modArr = makeUniqueArray modArrX
			
			local count = modArr.count
			if count > 0 then
			(
				local locObj = locObjs[1] --getLocalTimer()
				locObj = if isValidNode locObj then locObj
				else
				(
					local msg = "Local Timer Not Found in Selection"
					pcacheConductor.logWindow.setMsg msg
					attachLocalTimer arr
				)
				
				local msg = "Connecting a Local Timer to "+ count as string + " Object(s)"
				pcacheConductor.logWindow.setMsg msg
				for i in 1 to count do
				(
					local m = modArr[i]
					-- check existing playback type here
					m.playbackType = 3
					locObj.time.controller[2].controller = locObj.offset.controller
					m.playbackFrame.controller = locObj.time.controller
				)
				locObj
			)
			else
			(
				try(delete locObj)catch()
			)
		)
	)
	
	fn connectLocalTimer =
	(
		-- connect to existing timers
		
		-- create new local timers
		if keyboard.controlPressed then
		(
			-- 1 local timer for all, but use current time range for animation
		)
		else
		(
			-- 1 local timer for each object
			for obj in arr do
			(
				local theMods = getPCacheMods obj
				local mCount = theMods.count
				if mCount > 0 then
				(
					local msg = "Attaching Local Timer: " + obj.name
					pcacheConductor.logWindow.setMsg msg
					
					local locObj = createLocalTimer locPos:(obj.center * [1,1,0])
					for i in 1 to mCount do
					(
						local m = theMods[i]		
						local pType = m.playbackType
						
						case pType of
						(
							0: -- if set to original range
							(
								local pStart = m.recordStart
								local pEnd = m.recordEnd
								animate on
								(
									at time pStart locObj.time = pStart
									at time pEnd locObj.time = pEnd
								)
							)
							1: -- if set to custom start
							(
								local pStart = m.recordStart
								local pEnd = m.recordEnd
								animate on
								(
									at time pStart locObj.time = pStart
									at time pEnd locObj.time = pEnd
								)
								locObj.offset = -m.playBackStart
							)
							2: -- custom range
							(
								local pStart = m.playBackStart
								local pEnd = m.playBackEnd
								animate on
								(
									at time pStart locObj.time = pStart
									at time pEnd locObj.time = pEnd
								)
							)
							3: -- if set to playback graph, use existing animation controller
							(
								locObj.time.controller["TimePlayback"].controller = m.playbackFrame.controller
							)
						)
						
						m.playbackType = 3
						m.playbackFrame.controller = locObj.time.controller
					)
				)
			)
		)
	)
	
	fn getGlobalTimer  =
	(
		local globalTimerArr = findAttrib selection "Global Timer Parameters"
		if globalTimerArr.count != 0 then globalTimerArr[1]
	)
	
	fn connectGlobalTimer =
	(
		local locArr = getLocalTimer all:true
		local gloObj = getGlobalTimer()
		
		local count = locArr.count
		if count != 0 then
		(
			if not isValidNode gloObj then
			(
				local msg = "Global Timer Not Found in Selection"
				pcacheConductor.logWindow.setMsg msg
				gloObj = createGlobalTimer()
				
				animate on
				(
					at time tStart gloObj.time = tStart
					at time tEnd gloObj.time = tEnd
				)
			)
			attachGlobalTimer locArr obj:gloObj
			
			return gloObj
		)
		else
		(
			local msg = "Local Timer Not Found in Selection"
			pcacheConductor.logWindow.setMsg msg
		)
	)
	
	/* Execution */
	fn exe =
	(
		if mode == 0 then -- All Process
		(
			if thePath != undefined and thePath != "" then undo "Point Cache Manager" on 
			(
				arr = getSelection()
				if arr.count != 0 then -- Start Process
				(
					local cMode = getCommandPanelTaskMode()
					setCommandPanelTaskMode #utility
					with redraw off
					(
						(
							if debugMode == 1 then format "recordPCache\n\t%\n" arr
							arr = recordPCache arr
							if debugMode == 1 then format "loadCache\n\t%\n" arr
							arr = loadCache arr
							if debugMode == 1 then format "attachLocalTimer\n\t%\n" arr
							local locObj = attachLocalTimer arr
							if debugMode == 1 then format  "attachGlobalTimer\n\t%\n" arr
							local gloObj = attachGlobalTimer locObj
							if debugMode == 1 then format "Done.\n\t%\n" arr
						)
						delete (cleanUpArray delArr)
						select (cleanUpArray arr)
					)
					setCommandPanelTaskMode cMode
				)
			)
		)
		else -- Record / Load Cache / Local / Global Timer
		(
			arr = getSelection()
			case mode of
			(
				1:
				(
					arr = recordPCache arr
				)
				2:
				(
					arr = loadCache arr
				)
				3:
				(
					local locObj = connectLocalTimer()
					arr = #(locObj)
				)
				4:
				(
					local gloObj = connectGlobalTimer()
					arr = #(gloObj)
				)
			)
			select (cleanUpArray arr)
		)
	)
	
	fn addHistory num =
	(
		local txt = ""
		txt += "setIniSetting pcacheConductor.iniFile \"History\" \"Item" + num as string + "\" \"\""
		execute txt
	)
	
	fn loadSettings =
	(
		if not doesFileExist iniFile then
		(
			setIniSetting iniFile "Settings" "Layer" timerLayer
			for i in 1 to numHistory do addHistory i
		)
		timerLayer = getIniSetting iniFile "Settings" "Layer"
	)
	
	fn setIcon btn iconbmp count dex =
	(
		if iconbmp != "" then
		(
			local iconPath = GetDir #ui_ln + @"\icons\"
			btn.images = #(iconPath + iconBmp, undefined, count, dex, dex, dex, dex, false, true)
		)
		else
		(
			btn.images = undefined
		)
	)	
	
	fn initUI =
	(
		local cons = pcacheConductor.controls
		local check = thePath != ""
		
		/* Enabled|Disabled */
		for c in 12 to cons.count do cons[c].enabled = check
		btn_anim.enabled = spn_start.enabled = spn_end.enabled = not btn_anim_lock.checked
		btn_time_icon.enabled = btn_proc_icon.enabled = btn_ops_icon.enabled = off
		btn_loc.enabled = btn_glo.enabled = on
		edt_lay.enabled = chk_lay.checked and chk_lay.enabled
		
		/* Icons */
		setIcon btn_path "bip_mixerio_i.bmp" 4 1
		setIcon btn_anim_lock "bip_mixer_i.bmp" 20 10
		setIcon btn_time_icon "TrackViewTools_24i.bmp" 117 17
		setIcon btn_proc_icon "TrackViewTools_24i.bmp" 117 95
		setIcon btn_ops_icon "TrackViewTools_24i.bmp" 117 105
		if check then
		(

			setIcon btn_log "Maxscript_24i.bmp" 5 1
			setIcon btn_sel "crwd_cog_i.bmp" 12 10
		)
		else
		(
			setIcon btn_sel "" 0 0
-- 			setIcon btn_time_icon "" 0 0
-- 			setIcon btn_proc_icon "" 0 0
-- 			setIcon btn_ops_icon "" 0 0
		)
-- 		setIcon btn_sel "crwd_cog_i.bmp" 12 (if check then 9 else 10)
		
		/* Tooltips */
		local tip = ""
		tip += "Choose a folder to save the recorded cache files." + "\n"
		tip += "Or Choose a base folder to load caches from." + "\n\n"
		tip += "[ALT] Explore Path."
		btn_path.tooltip = tip
		btn_anim.tooltip = "Set timing to current animation range."
		btn_anim_lock.tooltip = "Lock to automatically set timing to animation range."
		tip = "Create PointCache files." + "\n\n"
		tip += "Applies a PointCache World-Space Modifier to the selected objects and saves them to the specified path." + "\n\n"
		tip += "This also checks if the object already has a PointCache Modifier with a filename that may be overwritten, resulting in a null cache."
		btn_rec.tooltip = tip
		tip = "Load PointCache files." + "\n\n"
		tip += "Applies a PointCache Object-Space Modifier to the selected objects." + "\n\n"
		tip += "* This will load cache files based on the object's un-numbered name." + "\n"
		tip += "* The objects are collpased onto an Editable Mesh." + "\n"
		tip += "* Transforms are also reset to the origin." + "\n"
		tip += "* Materials and Layer assignments are preserved."
		btn_load.tooltip = tip
		tip = "Creates a Local Timer object." + "\n\n"
		tip += "* These objects will have Time and Offset Paramters to control the PointCache's PlaybackGraph." + "\n"
		tip += "* This will only connect to a selection with PointCache Modifiers in their stack."
		btn_loc.tooltip = tip
		tip = "Creates a Global Timer object." + "\n\n"
		tip +=  "This can be used to globally control all connected Local Tiimer objects." + "\n\n"
		tip += "* Valid only for a selection of Local Timers."
		btn_glo.tooltip = tip
		chk_lay.tooltip = "Created Local and Global Timer objects will be placed in this layer."
		btn_log.tooltip = "Open Log Window..."
		btn_apply.tooltip = "Applies the whole Point Cache Conductor Process to the selected objects."
		btn_sel.tooltip = "Select Processed Objects."
	)
	
	on pcacheConductor open do
	(
		loadSettings()
		
		chk_lay.checked = on
		btn_anim_lock.checked = true
		setRange()
		initUI()
		edt_lay.text = timerLayer
	)
	
	/* intermediary function */
	fn updateRange =
	(
		setRange()
	)
	
	on btn_anim_lock changed state do
	(
		if btn_anim_lock.checked then
		(
			print "registered"
			updateRange()
			registerTimeCallback updateRange
		)
		else
		(
			print "unregistered"
			unRegisterTimeCallback updateRange
		)
		initUI()
	)
	
	on chk_lay changed state do initUI()
	
	on pcacheConductor close do
	(
		unRegisterTimeCallback setRange
	)
	
	fn saveHistory txt =
	(
		local historyItems = getIniSetting iniFile "History"
		local newHistoryPaths = #(txt)
		local oldHistoryPaths = for i in historyItems collect getIniSetting iniFile "History" i
		local dupDex = findItem oldHistoryPaths txt
		if dupDex != 0 then deleteItem oldHistoryPaths dupDex
		join newHistoryPaths oldHistoryPaths
		local historyItemsCount = historyItems.count
		for i in 1 to numHistory do
		(
			if i <= historyItemsCount then
			(
				setIniSetting iniFile "History" historyItems[i] newHistoryPaths[i]
			)
			else
			(
				addHistory i
			)
		)
	)
	
	fn setPath txt =
	(
		thePath = txt
		local pathArr = filterString txt "\\"
		edt_path.text = pathArr[pathArr.count]
		
		saveHistory thePath
		
		initUI()
		
		local tip = btn_path.toolTip
		btn_path.toolTip = thePath + "\n\n" + tip
	)
	
	on btn_path pressed do
	(
		if keyboard.altPressed then
		(
			try( shellLaunch thePath "" )catch()
		)
		else
		(
			dirPath = if isDirectoryWriteable thePath then thePath else maxfilepath
			prePath = getSavePath caption:"Point Cache Folder" initialDir:dirPath
			if prePath != undefined do setPath prePath
		)
	)

	fn showHistoryMenu =
	(
		local historyItems = getIniSetting iniFile "History"
		historyPaths = for i in historyItems collect getIniSetting iniFile "History" i
		local historyItemsCount = historyItems.count
		
		local txt  = "rcmenu historyPathsMenu"
		txt += "\n" + "("
		for i in 1 to numHistory do
		(
			if i <= historyItemsCount then
			(
				if historyPaths[i] != "" then
				(
					local dex = i as string
					local thePathName = "\"" + historyPaths[i] + "\""
					txt += "\n" + "\t" + "menuItem item" + dex + " " + thePathName
					txt += "\n" + "\t" + "on item" + dex +  " picked do pcacheConductor.setPath " + thePathName
				)
			)
			else
			(
				addHistory i
			)
		)
		txt += "\n" + ")"
		txt += "\n" + "PopupMenu historyPathsMenu\n"
		
		try
		(
			execute txt
		)
		catch
		(
			print (getCurrentexception())
		)
	)
		
	on btn_path rightClick do
	(
		showHistoryMenu()
	)
	
	on spn_start chacnged val do tStart = val
	on spn_end changed val do tEnd = val
	on btn_anim pressed do setRange()
	
	on edt_lay changed txt do
	(
		timerLayer = txt
		setIniSetting iniFile "Settings" "Layer" txt
	)
	
	struct pcacheConductorLog
	(
		tf,
		tx,
		fontSize = 8,
		fn bringToFront =
		(
			pcacheConductor.logWindow.tf.BringToFront()
		),
		fn getMsg =
		(
			pcacheConductor.logWindow.tx.text
		),
		fn setMsg txt =
		(
			bringToFront()
			local mptx = pcacheConductor.logWindow.tx
			
			if txt != "" then
			(
				local txFontStyle = dotNetClass "System.Drawing.FontStyle"
				local txFontBoldStyle = dotnet.combineenums txFontStyle.bold
				local txFontBold = dotNetObject "System.Drawing.Font" "Consolas" fontSize txFontBoldStyle
				
				if matchPattern txt pattern:"*Record Cache*" then
				(
					mptx.SelectionColor = mptx.SelectionColor.DarkTurquoise
				)
				if matchPattern txt pattern:"*Load Cache*" then
				(
					mptx.SelectionColor = mptx.SelectionColor.MediumSpringGreen
				)
				if matchPattern txt pattern:"*Attaching Local*" then
				(
					mptx.SelectionColor = mptx.SelectionColor.GreenYellow
				)
				if matchPattern txt pattern:"*Connected*" then
				(
					mptx.SelectionColor = mptx.SelectionColor.GreenYellow
				)
				if matchPattern txt pattern:"*Local Timer Found in Selection*" then
				(
					mptx.SelectionColor = mptx.SelectionColor.GreenYellow
				)
				if matchPattern txt pattern:"*Connecting a Local Timer*" then
				(
					mptx.SelectionColor = mptx.SelectionColor.lime
				)
				if matchPattern txt pattern:"*Attaching Global*" then
				(
					mptx.SelectionColor = mptx.SelectionColor.lime
				)
				if matchPattern txt pattern:"*[Skipped]*" then
				(
					mptx.SelectionColor = mptx.SelectionColor.LightPink
				)
				if matchPattern txt pattern:"*Not Found*" then
				(
					mptx.SelectionColor = mptx.SelectionColor.LightPink
				)
				if matchPattern txt pattern:"*No Point Cache*" then
				(
					mptx.SelectionColor = mptx.SelectionColor.LightPink
				)
				if matchPattern txt pattern:"*[Duplicate Name]*" then
				(
					mptx.SelectionColor = mptx.SelectionColor.LightPink
				)
				if matchPattern txt pattern:"*[Numbered Name]*" then
				(
					mptx.SelectionColor = mptx.SelectionColor.LightPink
				)
			)
			mptx.AppendText (txt + "\r\n")
			
			mptx.SelectionFont = mptx.Font
			mptx.SelectionColor = mptx.ForeColor
		),
		fn buildDialog =
		(
			tf = dotNetObject "MaxCustomControls.MaxForm"
			tf.text = "Point Cache Conductor Log"
			tf.ShowInTaskbar = on
			tf.width = 400
			tf.height = 400
			tf.FormBorderStyle = tf.FormBorderStyle.FixedSingle
			tf.MaximizeBox = tf.MinimizeBox = false
			
			tx = dotNetObject "RichTextBox"
			tx.scrollbars = tx.scrollbars.vertical
			tx.width = 385
			tx.height = 362
			tx.multiline = true
			tx.wordwrap = false
			tx.readOnly = on
			tx.BackColor = tx.BackColor.FromArgb 50 50 50
			tx.ForeColor = tx.ForeColor.Silver
			local txFontStyle = dotNetClass "System.Drawing.FontStyle"
			local txFontRegular = dotNetObject "System.Drawing.Font" "Consolas" fontSize
			tx.font = txFontRegular
-- 			tx.text = pcacheConductor.logMsg
			
			msgArr = #()
			msg = pcacheConductor.logMsg as stringStream
			while not eof msg do
			(
				append msgArr (readline msg)
			)
			mCount = msgArr.count
			for i in 1 to mCount do setMsg msgArr[i]
			
			tf.controls.add tx
			
			fn pcacheConductorExit =
			(
				pcacheConductor.logWindow = undefined
				pcacheConductor.logOpen = off
			)
			dotNet.AddEventHandler tf "Closed" pcacheConductorExit
		),
		fn openDialog   =
		(
			if tf == undefined then buildDialog ()
			nw = DotNetObject "NativeWindow"
			nw.AssignHandle (DotNetObject "System.IntPtr" (Windows.GetMaxHWND()))
			pcacheConductor.logWindow.tf.show(nw)
			--pcacheConductor.logWindow.tf.show()
			pcacheConductor.logOpen = on
		),
		fn closeDialog =
		(
			pcacheConductor.logWindow.tf.close()
			pcacheConductor.logOpen = off
		)
	)
	
	fn initLogWindow =
	(
		if logWindow == undefined then logWindow = pcacheConductorLog()
		if logOpen then
		(
			logWindow.BringToFront()
		)
		else
		(
			logWindow.openDialog()
		)
	)
	
	fn apply cacheMode =
	(
		mode = cacheMode
		
		if keyBoard.altPressed then
		(
		-- find a way to properly get the dependents of the Timer objects.
-- 			if selection.count == 1 then
-- 			(
-- 				local theObj = selection[1]
-- 				case mode of
-- 				(
-- 					3:
-- 					(
-- 						if classOf theObj == dummy then
-- 						(
-- 							
-- 						)
-- 						else
-- 						(
-- 							local theMods = getPCacheMods theObj
-- 							if theMods.count != 0 then
-- 							(
-- 								local deps = refs.dependents theObj.modifiers[2].playbackframe.controller
-- 								local dums = for i in deps where classOf i == dummy collect i
-- 								select dums
-- 							)
-- 						)
-- 					)
-- 				)
-- 			)
		)
		else
		(
			initLogWindow()
			pcacheConductor.logWindow.setMsg localtime
			if thePath != "" then pcacheConductor.logWindow.setMsg thePath
			exe()
			pcacheConductor.logWindow.setMsg localtime
			pcacheConductor.logWindow.setMsg "- - - - - - - - - -"
			logMsg = logWindow.getMsg()
		)
	)
	
	on btn_apply pressed do
	(
		if keyboard.altPressed then
		(
			-- assign thePath to PointCache Cache File
		)
		else
		(
			apply 0
		)
	)
	
	on btn_rec pressed do apply 1
	on btn_load pressed do	apply 2
	on btn_loc pressed do apply 3
	on btn_glo pressed do apply 4
	
	on btn_sel pressed do select arr
	
	on btn_log pressed do
	(
		initLogWindow()
	)
	
	on pcacheConductor close do
	(
		if logOpen then 
		(
			pcacheConductor.logWindow.closeDialog()
		)
	)
)
createDialog pcacheConductor

/*
[TO DO]
/- add UI
/- center the LocalTimer on selection ground.
/- add a dotnet texbox to show progress independent from max (to always refresh)
/- add path history rcmenu
/- disable apply if not path set (or if invalid path)
/- test pre-load types
/- skip objects with pcache modifiers
/- connect to local and global timer
/- option for pc2 and xml
/- check for names that has numbers at the end.
/- check for duplicate names.
/- auto-search subfolders on loadcache for multiple selected objects.
	/- search immediate parent, if equal to current folder
	/- if not, search current folder if equal to one of child folders
/- try using windows.processPostedMessages()
/- enable connect timers button even if no path set
X create UI option to skip if pcache exists.
	X warm when overwriting the same cache type
	/ internally handles this automatically
/- Attach Local/Global Messege on log
.. add tooltips
/- separate groupbox for cache type
/- Messagebox when done.
X notify to update animation range when new file opened
  /- add lock to animation range.
  /- fix anim lock function to properly disable

? ALT to select controller instances/dependency objects
- create custom timer viewport icons
- checkbox for process end
- new/load scene - anim timing update

<log>
- on log open, scroll to last part
- on log open, unselect all
/- add timestamps
/- make to format for percent count: [NN.nn], 100% = [100.0]
	/- check how to fix decimal display
	X- use formattedprint
- restore coloring when re-opening

[notes]
- Global Timer has a timer cust attribute with a controller instanced to other objects.
  How do I find the other objects that are using the same instanced controller?
- setIcon could cause crash if index is 0.
*/