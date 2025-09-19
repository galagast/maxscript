/*

Instance Placer
version: 0.09.4 - 2008-10-28
written by: Jefferson D. Lim - Terabyte/Shirogumi


feature:
- place an object from a collection over a target surface

usage:
1. create a collection of objects using "Add" or "List"

2. (if there is no selected object) select an object (as target surface)
   - or alternatively use the "Pick Target Surface" button

3. press "Place Object" and hover over to your target surface to start placing objects

4. right click to finish/cancel placing objects


notes:
- you can press [shift+LMB click] while placing an object over a surface to rotate it +90 degrees
  or [alt+LMB click] for +45 degress. [ctrl+LMB click] for random z rotation
- you can also click, then hold + drag the mouse when placing an object over a surface to rotate it by mouse
  - the display of the rotation guide often causes instant crashing at times.. :(

*/

try(destroydialog instplacer)catch()
rollout instplacer "Instance Placer" width:155 height:320
(
	local instArray = #()			-- collection of objects to distribrute
	local surfObj					-- object whose surface to track and place [instArray] objects
	local instObj					-- chosen [instArray item] object to place on [surfObj]
	local last = 0					-- used to properly keep track of the size of [lb] (listBox)
	local lastTM					-- transform of instObj stored before adding custom rotation
	local lastPOS					-- position of mouse before rotating an object, used to get angle value
	local lastSIGN					-- an atempt to get a sensible rotation direction
	local trackON = false			-- mouseTrack function is On/off
	local tracing = false			-- mouseTrack funciton is ON, and is not/tracing and object (a ray is detected to trace on)
	local rotOffset = (quat 0 0 0 1)-- rotation to use as an offset (random/set values)

	fn geoFilt obj =
	(
		superclassof obj == geometryClass \
		and finditem instArray obj == 0 \
		and obj != surfObj
	)

	checkButton chk_place "Place Object" pos:[5,2] width:145 height:27 enabled:false
	groupBox grp_list "Object List" pos:[5,30] width:145 height:60
	pickbutton btn_add "Add" pos:[10,45] width:45 height:20 filter:geoFilt
	button btn_list "List" pos:[55,45] width:45 height:20
	button btn_del "Delete" pos:[100,45] width:45 height:20	tooltip:"Delete Selected. [CTRL] Delete All."
	listBox lb "" pos:[10,65] width:135 height:1
	
	GroupBox grp_ops "Options:" pos:[5,95] width:145 height:135
	GroupBox grp_seq "" pos:[5,155] width:145 height:100	
	checkbox chk_surf "Use" pos:[10,112] width:135 height:15 enabled:false
	pickbutton btn_surf "Pick Target Surface" pos:[10,130] width:115 height:25 filter:geoFilt
	button btn_clear "X" pos:[125,130] width:20 height:25 enabled:false
	checkbox chk_seq "Continuous Creation" pos:[10,165] width:130 height:15
	radiobuttons rd_seq "" pos:[10,180] width:84 height:48 enabled:false labels:#("Constant","Sequential", "Random")
	checkbox chk_ranrot "Randomize Z Rotation" pos:[10,235] width:130 height:15

	GroupBox grp_obj "" pos:[5,255] width:145 height:60
	checkbox chk_auto "Auto-Select" pos:[10,265]
	checkbox chk_link "Link to Surface Object" pos:[10,280]
	checkbox chk_disp "Display Rotation Guide" pos:[10,295]
		
	fn enableUI state =
	(
		count = instplacer.controls.count
		for i in 3 to count do
		(
			instplacer.controls[i].enabled = state
		)
		if state then
		(
			chk_surf.enabled = btn_clear.enabled = if btn_surf.object != undefined then true else false
			rd_seq.enabled = chk_seq.checked
		)
	)
	
	fn initUI h =
	(
		offset = (h*13)
		grp_list.height += offset
		lb.height += offset
		instplacer.height += offset
		count = instplacer.controls.count
		for i in 7 to count do
		(
			instplacer.controls[i].pos.y += offset
		)
		lb.visible = if lb.height == 6 then false else true
	)

	fn initBtn =
	(
		chk_place.enabled = if lb.selection != 0 then true else false
	)
	
	fn offBtn =
	(
		chk_place.checked = false
		chk_place.text = "Place Object"
		tracing = false
		enableUI true
	)
	
	fn initList =
	(
		count = instArray.count
		num = count - last		
		initUI (num)
		last = count
		list = for i in instArray collect i.name
		lb.items = list
		grp_list.text = if count == 0 then "Object List" else "Object List :" + count as string
		initBtn()
	)
	
	fn getScreenCoords Pos ScreenSize P3:false=
	(
		p = Pos * viewport.getTM()
		screen_origin = mapScreenToView [0,0] (p.z) ScreenSize
		end_screen = mapScreenToView ScreenSize (p.z) ScreenSize
		world_size = screen_origin-end_screen
		x_aspect = ScreenSize.x/(abs world_size.x)
		y_aspect = ScreenSize.y/(abs world_size.y)
		screen_coords = point2 ((x_aspect*(p.x- screen_origin.x))) ((-(y_aspect*(p.y-screen_origin.y))))
		if P3 then [screen_coords.x, screen_coords.y, 0] else screen_coords
	)
	
	fn instanceLbObject =
	(
		dex =
		case rd_seq.state of
		(
			1:
			(
				if lb.selection == 0 then 1 else lb.selection
			)
			2:
			(
				lb.selection + (if lb.selection == lb.items.count then -(lb.items.count-1) else 1)
			)
			3:
			(
				random 1 lb.items.count
			)
		)
		lb.selection = dex
		instObj = instance instArray[dex]
		if chk_ranrot.checked do rotOffset += ((eulerangles 0 0 (random 0 360)) as quat)
	)
	
	fn drawRotation lastPOS screenPOS mousePOS rot =
	(
		gw.wMarker screenpos #plusSign
		
		dMin = 30 -- inner radius
		dMax = 80 -- outer radius
		
		PA = normalize (lastPOS - screenPOS)
		PB = normalize (mousePOS - screenPOS)
		
		dPointAMin = ( PA * dMin ) + screenPOS
		dPointAMax = ( PA * dMax ) + screenPOS
		dPointBMin = ( PB * dMin ) + screenPOS
		dPointBMax = ( PB * dMax ) + screenPOS
		
		--gw.wMarker dPointAMin #diamond
		--gw.wMarker dPointBMin #diamond
		
		gw.wPolyline #(dPointAMin, dPointAMax) false rgb:#(yellow, yellow)
		gw.wPolyline #(dPointBMin, dPointBMax) false rgb:#(yellow, yellow)
		
		dN1 = normalize (lastPOS - screenpos)
		dN2 = [1,0,0]
		dRot = (acos (dot dN1 dN2))
		if (cross dN1 dN2).z > 0 then dRot = ((360 - dRot) * lastSIGN)
								
		segs = abs (rot/5)
		gw.setColor #line yellow
		
		/*
		dCurveAMin = #(dPointAMin)
		for i in 1 to segs do
		(
			f = ( i * 5 ) + dRot
			tx = cos f
			ty = sin f
			dPnt = ([tx, ty, 0] * dMin) + screenPOS
			append dCurveAMin dPnt
			--gw.wMarker dPnt #smalldiamond
		)
		append dCurveAMin dPointBMin
		gw.wPolyline dCurveAMin false
		*/
		
		dCurveAMax = #(dPointAMax)
		for i in 1 to segs do
		(
			f = ( i * 5 ) + dRot
			tx = cos f
			ty = sin f
			dPnt = ([tx, ty, 0] * dMax) + screenPOS
			append dCurveAMax dPnt
			--gw.wMarker dPnt #smalldiamond
		)
		
		append dCurveAMax dPointBMax
		gw.wPolyline dCurveAMax false
		
		gw.wText (screenPOS + [10,10,0]) (rot as string) color:yellow
		
		gw.enlargeUpdateRect #whole
		gw.updateScreen()
	)
	
	fn mouseTrk msg ir obj faceNum shift ctrl alt =
	(
		trackON = true
		leftMouseDown = ((mouse.buttonStates) as array)[1] == 1
		
		if ir != undefined and instObj != undefined and not leftMouseDown and lastTM == undefined then
		(
			instObj.dir = ir.dir
			instObj.rotation += rotOffset
			instObj.pos = ir.pos + ir.dir
			tracing = true
		)
		else tracing = false
		
		lb.enabled = not tracing
	
		if msg == #mouseAbort do (trackON = tracing = false; lastTM = lastPOS = lastSIGN = undefined; offBtn(); delete instObj; return 0)
		if msg == #mouseMove do
		(	
			if leftMouseDown do
			(
				screenpos = getScreenCoords instObj.pos (getViewSize()) p3:true
				mousepos = [mouse.pos.x, mouse.pos.y, 0]
				dist = distance mousepos screenpos
				
				if dist > 10 do
				(
					if lastTM == undefined do
					(
						lastTM = instObj.transform						
						lastPOS = mousepos
						--gw.setTransform(Matrix3 1)
					)
					N1 = normalize (lastPOS - screenpos)
					N2 = normalize (mousepos - screenpos)
					rot = (acos (dot N1 N2))
					if (cross N1 N2).z < 0 then rot = 360 - rot
					
					if lastSIGN == undefined do
					(
						lastSIGN = if rot > 180 then -1 else 1
					)
					
					rot =
					(					
						case of
						(
							shift: rot - (mod rot 90)
							alt: rot - (mod rot 45)
							default: rot
						)					
					)
					
					
					(
					if chk_disp.checked do drawRotation lastPOS screenPOS mousePOS rot
					)
					
					in coordsys lastTM instObj.rotation = rotOffset + ((eulerangles 0 0 rot) as quat)
				)
			)

		)
		if msg == #mousePoint do
		(	
			case of
			(				
				shift: rotOffset += ((eulerangles 0 0 90) as quat)				
				alt: rotOffset += ((eulerangles 0 0 45) as quat)
				ctrl: rotOffset += ((eulerangles 0 0 (random 0 360)) as quat)
				default:
				(					
					lastTM = lastPOS = lastSIGN = undefined
					if chk_seq.checked and chk_surf.checked and chk_surf.enabled then
					(
						instanceLbObject()						
					)
					else
					(						
						tracing = false
						offBtn()
						return 0
					)
					
				)
			)
		)
		#continue
	)

	fn saveSettings =
	(
		setINISetting (getDir #plugcfg + "\\instplacer.ini") "Settings" "Continuous" (if chk_seq.checked then "1" else "0")
		setINISetting (getDir #plugcfg + "\\instplacer.ini") "Settings" "Continuous Item" (rd_seq.state as string)
		setINISetting (getDir #plugcfg + "\\instplacer.ini") "Settings" "Random Rotation" (if chk_ranrot.checked then "1" else "0")
		setINISetting (getDir #plugcfg + "\\instplacer.ini") "Settings" "Auto-Select" (if chk_auto.checked then "1" else "0")
		setINISetting (getDir #plugcfg + "\\instplacer.ini") "Settings" "Link" (if chk_link.checked then "1" else "0")
		setINISetting (getDir #plugcfg + "\\instplacer.ini") "Settings" "Display" (if chk_disp.checked then "1" else "0")
	)
	
	on instplacer open do
	(
		initUI -1
		
		xpos = getINISetting (getDir #plugcfg + "\\instplacer.ini") "Settings" "X Position"
		ypos = getINISetting (getDir #plugcfg + "\\instplacer.ini") "Settings" "Y Position"
		if xpos != "" and ypos != "" do setdialogpos instplacer [xpos as integer, ypos as integer]
		
		chk_seq.checked = rd_seq.enabled = if (getINISetting (getDir #plugcfg + "\\instplacer.ini") "Settings" "Continuous") == "1" then true else false		
		rd_state = (getINISetting (getDir #plugcfg + "\\instplacer.ini") "Settings" "Continuous Item") as integer
		
		rd_seq.state = if rd_state == undefined or rd_state == 0 then 1 else rd_state
		chk_ranrot.checked = if (getINISetting (getDir #plugcfg + "\\instplacer.ini") "Settings" "Random Rotation") == "1" then true else false		
		
		chk_auto.checked = if (getINISetting (getDir #plugcfg + "\\instplacer.ini") "Settings" "Auto-Select") == "1" then true else false
		chk_link.checked = if (getINISetting (getDir #plugcfg + "\\instplacer.ini") "Settings" "Link") == "1" then true else false
		chk_disp.checked = if (getINISetting (getDir #plugcfg + "\\instplacer.ini") "Settings" "Display") == "1" then true else false
	)
	
	on instplacer moved pos do
	(
		setINISetting (getDir #plugcfg + "\\instplacer.ini") "Settings" "X Position" (pos.x as string)
		setINISetting (getDir #plugcfg + "\\instplacer.ini") "Settings" "Y Position" (pos.y as string)
	)
	
	fn initInstArray =
	(		
		try(deleteAllChangeHandlers id:#instplacer_instArray)catch()
		when instArray deleted id:#instplacer_instArray handleAt:#redrawViews obj  do
		(
			instArray = for i in instArray where isValidNode i collect i
			initList()
		)
	)
	
	on btn_add picked obj do
	(
		if obj != undefined do
		(
			append instArray obj
			initInstArray()	
			initList()
		)
	)
	
	on btn_del pressed do
	(
		if keyboard.controlPressed then
		(
			instArray = #()
		)
		else
		(
			try(deleteitem instArray (lb.selection))catch()
		)
		initInstArray()
		initList()
	)
	
	on btn_list pressed do
	(
		obj_arr = selectbyname title:"Select Objects" filter:geoFilt showHidden:true
		if obj_arr != undefined and obj_arr.count != 0 do
		(
			for o in obj_arr do
			(
				append instArray o				
			)
			initInstArray()
			initList()
		)
	)
	
	on lb selected val do
	(
		/*
		if not getToolbtnState #select then 
		(
			max select
			setfocus instplacer.lb
		)
		*/
		initBtn()
		
		if chk_place.checked and not tracing and isvalidnode instObj then
		(
			delete instObj
			instObj = instance instArray[val]
			if chk_link.checked do instObj.parent = surfObj
		)
	)
	
	fn clearSurf =
	(
		surfObj = undefined
		btn_surf.text = "Pick Target Surface"
		chk_surf.checked = chk_surf.enabled = btn_clear.enabled = false
	)
	
	on btn_surf picked obj do
	(
		surfObj = obj
		chk_surf.checked = chk_surf.enabled = btn_clear.enabled = true
		btn_surf.text = obj.name
		
		try(deleteAllChangeHandlers id:#instplacer_surf_obj)catch()
		when obj deleted id:#instplacer_surf_obj handleAt:#redrawViews do clearSurf()
	)
	
	on btn_clear pressed do	clearSurf()
	
	on chk_seq changed state do
	(
		rd_seq.enabled = state
		saveSettings()
	)
	
	on rd_seq changed state do saveSettings()
	on chk_ranrot changed state do saveSettings()
		
	-- redefined initSurf function
	fn initSurf =
	(
		surfObj = undefined
		check_surf = (chk_surf.checked and chk_surf.enabled and (isvalidnode btn_surf.object))
		
		if check_surf then
		(			
			surfObj = btn_surf.object
		)
		else
		(
			if selection[1] != undefined and (geofilt selection[1]) then
			(
				surfObj = selection[1]				
			)
			else
			(				

				chk_place.text = "Pick Target Surface"
				surfObj = pickObject filter:geoFilt forceListenerFocus:false				
				if surfObj == #escape then surf = undefined
			)
		)
	)
	
	fn InstPlacer =
	(
		initSurf()
		enableUI false
		if surfObj != undefined and finditem instArray surfObj == 0 then
		(
			chk_place.text = "Surface: " + surfObj.name
			instanceLbObject()
			if chk_link.checked do instObj.parent = surfObj
			
			if chk_ranrot.checked do rotOffset += ((eulerangles 0 0 (random 0 360)) as quat)
			mouseTrack trackCallback:mouseTrk on:surfObj --snap:#3d
			
			true
		)
		else
		(			
			offBtn()
			false
		)

	)
	
	fn startInstPlacer =
	(		
		if InstPlacer() and chk_seq.checked and trackON do ( chk_place.checked = true; startInstPlacer() )
	)
	
	on chk_place changed state do
	(	
		if state then
		(			
			startInstPlacer()
			if chk_auto.checked then try(select instObj)catch()
		)
		else
		(
			enableUI true
			if not tracing and isvalidnode instObj do
			(
				delete instObj
				offBtn()
			)
		)
	)
	
	on chk_auto changed state do saveSettings()
	on chk_link changed state do saveSettings()
	on chk_disp changed state do saveSettings()
)
createdialog instplacer style:#(#style_toolwindow,#style_sysmenu)

/*
[history]
0.9.4	
081027	- reviewed script
		- script clean-up
		- fixed (target surface / selected / no selection) detection before placing
		- fixed rotation dragging
		- removed <last selected button> <rotation +/- 90 buttons>
		- added rotation drag display (too much usage leads to crash)
		- added delete detection for objects list [instArr]
		
0.9
080917	- auto pick object when placing with no selection
080918	- fixed drag rotations, more intuitive
080919	- added rotation drag display
080920 	- ?

0.8 
080916	- constant on continuous creation
		- rotation drag feature
		- change instance object while placing (click on list)
		
0.7
080915	- added single target surface
		- added random rotation
		- added continuous placement
		
0.6
080906	- added ini saving to plugcfg
		- added auto select and link to surface
		- added rotation on ctrl or alt
		- added UI updates

		
[to do]
- undo
	- object creation
	  - tried to add this, but max crashes when undo
	- rotation
- alignment
	- centered
	- bounding box min,max
	- x, y, z
	- good for planting trees, option to plant by axis + divergence
- thumnail view of instance objects
- collapsable UI options
- work with groups
- work with heirarchies
- paint mode?
- "reference" "instance" "copy" options
/- update list on delete node
/- add option to display rotation drag guide
  - figure out what's causing the crash
/- add realtime tracking of any objects (aka autoGrid)
  /- semi-autogrid workaround
     /- picking a targetobject first before proceeding to placement
  /- offset from current rotation when rotation dragging
/- drag rotation display line
/- offset from center rotation drag
/- link to target surface
/- update UI size on list add
/- single target object
/- random rotation
/- sequential placement
  /- random
- rotation guide - try to use splines instead
- after in continues creation, auto select doesnt work
- offset from surface

*/