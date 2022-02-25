/*
Material Assigner
v0.8
by Jefferson D. Lim
Central Digital Lab
Manila, Philippines

- This allows saving of material assignments for each object to a text file (config INI file)
using object and material names.
- It will also allow re-assignment of materials using the config file.

The script simply saves the object names and the material name assigned to it to an INI file.
Then using that INI file, the script can re-apply the materials to the objects by name.

It is recommended to have proper object and material names in order
for the script to work flawlessly.

[0.9]
2015-07-17
00 - fixed Auto-lib not loading the lib when double clicking on the list
01 - fixed selection set, not to include ".ini" in the NOMATS name
	- added Locals

[0.8]
2014-02-28
- added Config Lists to easily jump through different config files
2014-03-01
- added CTRL to force loading mtls from the LIB
2014-03-04
- fixed autlib not updating if multiple INI files detected

[0.7]
2014-02-26
- added object name checking from the INI list
- added creation of selection sets for objets without mats applied by the script
- added labels to easily see which files are being used

[0.6]
2014-02-23
- added autodetection for names with ":"

[0.5]
2014-02-05
- reworked UI a bit
- separated config file creation and path
- fixed open/save dialog to default to existing path
- fixed save only selected materials (it was saving the scene materials before)

[0.4]
2014-02-04
- added function to create a material library out of the selected objects

[0.3]
2013-07-04
- prioritzed assignment from existing scene materials

[0.2]
2013-06-17
- sine further adjustments
- removed the matlib, scenemats, meditmats checkboxes and made it automatically
  search for the material in sequence.

[0.1]
2013-06-17
- initial version

*/
try(destroyDialog matAssigner)catch()
rollout matAssigner "Material Assigner v0.8" width:525 height:210
(
	local theObjArr
	local theConf = ""
	local theLib = ""
	local noMats = #()
	local theINI = (getDir #plugcfg + "/matAssigner.ini")
	
	local listINI = ""
	local listNames = #()
	local listPaths = #()
	
	
	
	groupBox grp_list "Config List:" pos:[5,5] width:210 height:195
	
	listBox lb "" pos:[10,20] width:200 height:9
	checkButton btn_lock "L" pos:[10,150] width:30 height:25 enabled:on checked:on toolTip:"Lock editing of Config List."
	button btn_createList "+" pos:[40,150] width:30 height:25 enabled:false toolTip:"Create a new Config List File."
	button btn_openList "..." pos:[70,150] width:30 height:25 enabled:false toolTip:"Open an exisiting Config List File."
	button btn_add "Add" pos:[150,150] width:30 height:25 enabled:false toolTip:"Add the current Config File to the List."
	button btn_del "Del" pos:[180,150] width:30 height:25 enabled:false toolTip:"Remove the selected Config File from the List."
	label lbl_list "" pos:[12,180] width:200 height:15
	
	GroupBox grp_conf "Config File:" pos:[220,5] width:300 height:65 \
		tooltip:"Create the config file for the Object-Material assignments.\n\n[ALT] Explore Config File location."
	button btn_confnew "+" pos:[225,25] width:20 height:20
	edittext edt_conf "" pos:[245,25] width:245 height:17
	button btn_conf "..." pos:[495,25] width:20 height:20 enabled:true \
		tooltip:"Set the Config file.\n\n[ALT] Explore Config File location."
	label lbl_conf "" pos:[250,50] width:265 height:15
	
	GroupBox grp_mats "Material Library:" pos:[220,75] width:300 height:80	
	
	checkbox chk_autoLib "Auto-detect Library" pos:[250,90] width:115 height:15 checked:on \
		tooltip:"Automatically detect if the selected Config File also has a Material Library File on the same directory."
	button btn_libnew "+" pos:[225,110] width:20 height:20 enabled:true \
		tooltip:"Create new Material Library from selection\n\n[ALT] Explore .MAT location."
	edittext edt_lib "" pos:[245,110] width:245 height:17 enabled:true
	button btn_lib "..." pos:[495,110] width:20 height:20 enabled:true
	label lbl_lib "" pos:[250,135] width:265 height:15
	
	button btn_save "Save" pos:[220,160] width:150 height:25 enabled:false \
		tooltip:"Save the Object-Material assignments to the Config File."
	button btn_load "Load" pos:[370,160] width:150 height:25 enabled:false \
		tooltip:"Apply the Materials onto the selected objects based on the Config File definitions.\nThese are name-sensitive data.\n\n[ALT] Explore matAssigner.ini location\n[CTRL] Force to load materials from the Library File."
	progressBar pbar "" pos:[220,190] width:300 height:10
	
	
	fn saveINI =
	(
		setINISetting theINI "Settings" "Config File" edt_conf.text
		setINISetting theINI "Settings" "Material File" edt_lib.text
		setINISetting theINI "Settings" "List Path" listINI
	)
	
	fn loadINI =
	(
		edt_conf.text = getINISetting theINI "Settings" "Config File"
		edt_lib.text = getINISetting theINI "Settings" "Material File"
		listINI = getINISetting theINI "Settings" "List Path"
	)
	
	fn saveMats =
	(
		format "Saving Materials...\n\n"
		local count = theObjArr.count
		for i in 1 to count do
		(
			pbar.color = blue
			local val = (i*1.0/count) * 100.0
			pbar.value = val
			
			local theObj = theObjArr[i]
			format "%\n" theObj.name
			local theObjName = theObj.name
			local theMat = theObj.mat
			if theMat != undefined then
			(
				local theMatName = theObj.material.name
				setINISetting theConf "Material Assignments" theObjName theMatName
				format "  [SAVED] %\n" theMatName
			)
			else
			(
				format "  [OBJ] MAT Not Found\n"
			)
			format "\n"
		)
		if count == 0 then
		(
			pbar.value = 0
		)
		else
		(
			pbar.color = green
			pbar.value = 100
		)
	)
	
	fn applyMat obj mat matname =
	(
		if mat != undefined then
		(
			format "Assigned: %\n" mat.name
			obj.material = mat
			return true
		)
		else
		(
			append noMats obj
			format "MAT Not Found: %\n" matname
			return false
		)
	)
	
	fn loadMats =
	(
		format "Loading Materials...\n\n"
		local theMats = loadTempMaterialLibrary theLib
		if theMats != undefined then
		(
			noMats = #()
			local theIniObjs = getINISetting theConf "Material Assignments"
			local iCount = theIniObjs.count
			
			print theIniObjs
			format "\n"
			
			local count = theObjArr.count			
			for i in 1 to count do
			(
				pbar.color = blue
				local val = (i*1.0/count) * 100.0
				pbar.value = val
				
				local theObj = theObjArr[i]
				format "%\n" theObj.name
				
				-- this is for maya namespaces
				local theNameArr = filterString theObj.name ":"
				local nCount = theNameArr.count
				local theName = if nCount > 1 then theNameArr[nCount] else theObj.name
				local theMatName = getINISetting theConf "Material Assignments" theName
				local matFound = false
				
				if theMatName != "" then
				(
					matFound = true
				)
				else
				(
					-- check the object names from the INI file against selected objects
					for m in 1 to iCount do
					(
						-- this is for maya namespaces
						local checkName1 = matchPattern theIniObjs[m] pattern:("*" + theObj.name + "*") ignoreCase:on
						local checkName2 = matchPattern theObj.name pattern:("*" + theIniObjs[m] + "*") ignoreCase:on
						if checkName1 or checkName2 then
						(
							matFound = true
							theMatName = getINISetting theConf "Material Assignments" theIniObjs[m]
							exit
						)
					)
				)
				if keyboard.controlPressed then
				(
					format "\t"
					applyMat theObj theMats[theMatName] theMatName
				)
				else
				(
					if matFound then
					(
						for m in 1 to 3 do
						(
							case m of
							(
								1: format "  [SCN] "
								2: format "  [MDT] "
								3: format "  [LIB] "
							)
							
							theMat = case m of
							(
								1: sceneMaterials[theMatName]
								2: meditMaterials[theMatName]
								3: theMats[theMatName]
							)
							if (applyMat theObj theMat theMatName) then exit
						)
					)
					else
					(
						append noMats theObj
						format "  [OBJ] MAT Not Found\n"
					)
					format "\n"
				)
			)
			selectionSets["NOMATS: " + getFilenameFile theConf] = noMats
		)
	)
	
	fn check =
	(
		local checkPath = doesFileExist theConf
		local checkLib = doesFileExist theLib
		local checkList = doesFileExist listINI
		
		lbl_conf.text = if checkPath then filenameFromPath theConf else ""
		lbl_lib.text = if checkLib then filenameFromPath theLib else ""
		lbl_list.text = if checkList then filenameFromPath listINI else ""
		
		btn_save.enabled = btn_load.enabled = checkPath and checkLib
		btn_add.enabled = btn_del.enabled = checkList and (not btn_lock.checked)
		
		saveINI()
	)
	
	fn getObjs =
	(
		theObjArr = for i in selection where superClassOf i == geometryClass collect i
	)
	
	on btn_confnew pressed do
	(
		if keyboard.altPressed then
		(
			shellLaunch (getFilenamePath theConf) ""
		)
		else
		(
			local theFile = if doesFileExist theConf then getFilenamePath theConf else "\_config.ini"
			local prePath = getSaveFileName "Config File" filename:theFile types:"Config Files (*.ini)|*.ini|All Files (*.*)|*.*|"
			if prePath != undefined then
			(
				theConf = prePath
				setINISetting theConf "Material Assignments" "OBJECT_NAME" "MATERIAL_NAME"
				edt_conf.text = theConf
			)
			check()
		)
	)
	
	fn autoLib dex =
	(
		local theLibs = getFiles ((getFilenamePath theConf) + "*.mat")
		local count = theLibs.count
		if count >= 1 then
		(
			theLib = theLibs[dex]
			edt_lib.text = theLib
			check()
		)
	)
	
	on btn_conf pressed do
	(
		if keyboard.altPressed then
		(
			shellLaunch (getFilenamePath theConf) ""
		)
		else
		(
			local theFile = if doesFileExist theConf then getFilenamePath theConf else "\_config.ini"
			local prePath = getOpenFileName "Config File" filename:theFile types:"Config Files (*.ini)|*.ini|All Files (*.*)|*.*|"
			if prePath != undefined then
			(
				theConf = prePath
				edt_conf.text = prePath
				
				if chk_autoLib.checked then autoLib 1
			)
		check()
		)		
	)
	
	on edt_conf entered txt do
	(
		theConf = txt
		if chk_autoLib.checked then autoLib 1
		check()
	)
	
	fn getMaterials =
	(
		local sel = selection as array
		local count = sel.count
		local mats = #()
		for i in 1 to count do
		(
			local m = sel[i].material
			if m != undefined do appendIfUnique mats m
		)
		mats
	)
	
	fn setMatLibrary new:off =
	(
		if keyboard.altPressed then
		(
			shellLaunch (getFilenamePath theLib) ""
		)
		else
		(
			local theFile = if doesFileExist theLib then getFilenamePath theLib else "\_library.mat"
			local preLib = getSaveFileName "Material Library File" filename:theFile types:"Material Library Files (*.mat)|*.mat|All Files (*.*)|*.*|"
			if preLib != undefined then
			(
				if new then
				(
					for mat in getMaterials() do append currentmateriallibrary mat
					saveMaterialLibrary theLib
				)
				theLib = preLib
				edt_lib.text = theLib
			)
			check()
		)
	)
	
	on btn_libnew pressed do setMatLibrary new:on	
	on btn_lib pressed do setMatLibrary()
	
	on edt_lib entered txt do
	(
		theLib = txt
		check()
	)
	
	on btn_save pressed do
	(
		if queryBox "Save Material Config?" title:"Material Assigner" then
		(
			clearListener()
			getObjs()
			saveMats()
		)
	)
	
	on btn_load pressed do
	(
		if keyboard.altPressed then
		(
			shellLaunch (getFilenamePath theINI) ""
		)
		else
		(
			clearListener()
			getObjs()
			loadMats()
		)
	)
	
	-----------------------------------------------------------------------------------------------------
	-----------------------------------------------------------------------------------------------------
	-- CONFIG LISTS
	-----------------------------------------------------------------------------------------------------
	-----------------------------------------------------------------------------------------------------
	
	on lb doubleClicked item do
	(
		local dex = lb.selection
		if dex != 0 then
		(
			theConf = listPaths[dex]
			edt_conf.text = theConf
			if chk_autoLib.checked then autoLib item
		)
	)
	
	on btn_lock changed state do
	(
		btn_createList.enabled = btn_openList.enabled = btn_add.enabled = btn_del.enabled = not state
	)
	
	fn saveList =
	(
		delIniSetting listINI "Config List"
		local count = listNames.count
		for i in 1 to count do
		(
			setINISetting listINI "Config List" listNames[i] listPaths[i]
		)
	)
	
	fn checkListPath =
	(
		local thePath = getFilenamePath (matAssigner.listINI)
		local count = thePath.count
		if thePath[count] == @"\" then thePath = subString thePath 1 (count-1)
		isDirectoryWriteable thePath
	)
	
	fn loadList =
	(
		if checkListPath() then
		(
			listNames = #()
			listPaths = #()
			local arr = getINISetting listINI "Config List"
			sort arr
			local count = arr.count
			for i in 1 to count do
			(
				append listNames arr[i]
				append listPaths (getINISetting listINI "Config List" arr[i])
			)
		)
	)
	
	fn updateList =
	(
		lb.items = listNames
	)
	
	fn refreshList =
	(
		saveList()
		loadList()
		updateList()
	)
	
	fn resetList =
	(
		listNames = listPaths = #()
		refreshList()
	)
	
	fn addList =
	(
		append listNames (filenameFromPath theConf)
		append listPaths theConf
		refreshList()
	)
	
	fn delList =
	(
		local dex = lb.selection
		if dex != 0 then
		(
			deleteItem listNames dex
			deleteItem listPaths dex
			refreshList()
		)
	)
	
	on btn_createList pressed do
	(
		if keyboard.altPressed then
		(
			shellLaunch (getFilenamePath listINI) ""
		)
		else
		(
			local theFile = if doesFileExist listINI then getFilenamePath listINI else ""
			local preINI = getSaveFileName "Create Config List File" filename:theFile types:"INI Files (*.ini)|*.ini|All Files (*.*)|*.*|"
			if preINI != undefined then
			(
				listINI = preINI
				setINISetting listINI "Config List" "TEMP" "TEMP"
				delIniSetting listINI "Config List" "TEMP"
				resetList()
				loadList()
				updateList()
			)
		)
		check()
	)
	
	on btn_openList pressed do
	(
		if keyboard.altPressed then
		(
			shellLaunch (getFilenamePath listINI) ""
		)
		else
		(
			local theFile = if doesFileExist listINI then getFilenamePath listINI else ""
			local preINI = getOpenFileName "Open Config List File" filename:theFile types:"INI Files (*.ini)|*.ini|All Files (*.*)|*.*|"
			if preINI != undefined then
			(
				listINI = preINI
				loadList()
				updateList()
			)
		)
		check()
	)
	on btn_add pressed do addList()
	on btn_del pressed do delList()
	
	on matAssigner open do
	(
		loadINI()
		loadList()
		lb.items = listNames
		theConf = edt_conf.text
		theLib = edt_lib.text
		check()
	)
	
	on matAssigner close do
	(
		saveINI() 
	)
)
createDialog matAssigner pos:[540,80]

/*
[to do]
/- fix dialog open history
/- add labels for files loaded (to easily see which files are loaded)
- add history of files loaded?
- add/update to existing INI and LIB

*/