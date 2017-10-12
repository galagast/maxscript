/*
[1.4]
2017-06-16
- added auto-detection of vray renderer regardless of version
[0.10]
2014-02-14
- added another "." for vrmap sequence name
2014-02-21
- trimmed subversion for vrmap name
2014-03-16
- added renderwidth and renderheight defaults for prepass and anim

IR
- show calc phase
- use cam path
- mode (anim prepass)
- on render end - auto save - set path


flow:
1. change IR/LC
2. set path based on filename
3. send ani-prepass to bb
4. revert to previous settings
5. send ani-render to bb - set dependency

*/

persistent global deflickerFrameStart, deflickerFrameEnd
global deflicker, animPrepassRollout, animRenderRollout
try(destroyDialog deflicker)catch()
rollout deflicker "Animation Prepass 1.4" width:425 height:175
(
	local mapPath
	local mapName
	local vr
	
	button btn_ref "R" pos:[400,7] width:20 height:20 tooltip:"Refresh"
	spinner spn_frames "Interp. Frames" pos:[320,10] width:60 type:#integer range:[0,999999,2]
	subRollout animSub "" pos:[5,30] width:415 height:136
	dotNetControl animTabs "System.Windows.Forms.TabControl" pos:[5,5] width:220 height:20
	label lbl "Vray Not Found" pos:[10, 170]
	
	fn isVrayRenderer =
	(
		local theCurrentRenderer = renderers.current
		local theVrayRenderer
		local renderersList = for i in rendererClass.classes where (matchPattern (i as string) pattern:"V_Ray_Adv*") collect i
		
		if renderersList.count != 0 then
		(
			theVrayRenderer = renderersList[1]
		)
	
		classOf theCurrentRenderer == theVrayRenderer
	)
	
	fn refeshUI =
	(
		state = isVrayRenderer()
		try(for i in animPrepassRollout.controls do i.enabled = state)catch()
		try(for i in animRenderRollout.controls do i.enabled = state)catch()
		deflicker.height = if state then 175 else 190
		lbl.visible = not state
	)
	
	fn storeFrameRange =
	(
		if deflickerFrameStart == undefined do deflickerFrameStart = animationRange.start
		if deflickerFrameEnd == undefined do deflickerFrameEnd = animationRange.end
	)
	
	on deflicker open do
	(
		try(destroyDialog deflickerRangeRollout)catch()
		try(destroyDialog animPrepassRollout)catch()
		try(destroyDialog animRenderRollout)catch()
		
		animTabs.TabPages.add "Animation Prepass"
		animTabs.TabPages.add "Animation Rendering"
		storeFrameRange()
		refeshUI()
	)
	
	on btn_ref pressed do
	(
		refeshUI()
	)
	
	on animTabs Selected itm do
	(
		if itm.TabPageIndex == 0 then
		(
-- 			animSub.width = 415
			removeSubrollout deflicker.animSub animRenderRollout
			addSubRollout deflicker.animSub animPrepassRollout
-- 			deflicker.width = 425
-- 			btn_ref.pos = [400,7]
		)
		else
		(
-- 			animSub.width = 250
			removeSubrollout deflicker.animSub animPrepassRollout
			addSubRollout deflicker.animSub animRenderRollout
-- 			deflicker.width = 260
-- 			btn_ref.pos = [235,7]
		)
		refeshUI()
	)
)


rollout animPrepassRollout "V-Ray Animation Prepass" width:400 height:110
(
	GroupBox grp_prepass "Animation Prepass" pos:[5,0] width:390 height:100
	button btn_path "Get Base Path..." pos:[10,20] width:90 height:20 \
		tooltip:"Set Base Path location based on\ncurrent 3dsMax file path."
	edittext edt_path "" pos:[100,22] width:288
	button btn_name "Set Vrmap Name" pos:[10,45] width:90 height:20 \
		tooltip:"Set Vrmap Name based on\ncurrent 3dsMax file name."
	edittext edt_name "" pos:[100,47] width:288
	button btn_prepass "Apply" pos:[300,70] width:90 height:25 \
		tooltip:\
		(
			"Apply Animation (Prepass) Irradiance Map Mode" + \
			"\n" + \
			"\nDon't Render Final Image: ON" + \
			"\nTurn OFF all save outputs" + \
			"\nRender Elements OFF" + \
			"\nGI: On" + \
			"\n" + \			
			"\nPrimary: Irradiance Map" + \
			"\nUse Camera Path: ON" + \
			"\nMode: Animation (prepass)" + \
			"\nDon't Delete: ON" + \
			"\nAuto-Save: ON" + \
			"\nSwitch to Saved Map: OFF" + \
			"\nAuto-Save Filename: SET" +\
			"\n" + \
			"\nSecondary: Light Cache" + \
			"\nUse Camera Path: ON" + \
			"\nMode: Single Frame" + \
			"\nAuto-Save: OFF" + \
			"\n"
		)
	
	fn getFilePath =
	(
		deflicker.mapPath = ""
		if maxFilePath != "" then
		(
			thePath = pathConfig.convertPathToAbsolute (maxFilePath + @"..\cache\gi\")
			deflicker.mapPath = thePath
		)
		deflicker.mapPath
	)
	
	fn getFileName =
	(
		deflicker.mapName = ""
		if maxFileName != "" then
		(
			theName = getFilenameFile maxFileName
			nameArr = filterString theName "."
			theName2 = ""
			for i in 1 to nameArr.count-1 do theName2 += nameArr[i] + "."
			deflicker.mapName = theName2 + ".vrmap"
		)
		deflicker.mapName
	)
	
	on animPrepassRollout open do
	(
-- 		if deflicker != undefined then
		(
			if deflicker.mapPath == undefined then edt_path.text = getFilePath() else edt_path.text = deflicker.mapPath
			if deflicker.mapName == undefined then edt_name.text = getFileName() else edt_name.text = deflicker.mapName
		)
	)
	
	on animPrepassRollout close do
	(
		
	)
	
	on edt_path entered txt do
	(
		deflicker.mapPath = txt
	)
	
	on edt_name entered txt do
	(
		deflicker.mapName = txt
	)
	
	on btn_path pressed do
	(
		if keyboard.altPressed then
		(
			try(shellLaunch deflicker.mapPath "")catch()
		)
		else
		(
			edt_path.text = getFilePath()
		)
	)
	
	on btn_name pressed do
	(
		edt_name.text = getFileName()
	)
	
	fn applyPrepass =
	(
		vr = deflicker.vr
		rendTimeType = 2
		rendSaveFile = off
-- 		renderWidth = 640
-- 		renderHeight = 360
		vr.output_saveRawFile = off
		
		vr.options_limitDepth = on
		vr.options_maxDepth = 4
		vr.options_filterMaps = off
		vr.options_transpMaxLevels = 25
		vr.options_glossyEffects = off
		
		vr.options_dontRenderImage = on
		vr.gi_on = on
		vr.gi_primary_type = 0 -- irradiance map
		vr.gi_secondary_type = 3 -- light cache
		
		vr.gi_irradmap_multipleViews = on --use camera path
		vr.gi_irradmap_interpFrames = deflicker.spn_frames.value
		
		vr.adv_irradmap_mode = 6
		vr.adv_irradmap_dontDelete = on
		vr.adv_irradmap_autoSave = on
		vr.adv_irradmap_switchToSavedMap = off
		
		vr.lightcache_multipleViews = on
		vr.lightcache_mode = 0
		vr.lightcache_autoSave = off
		
		mgr = maxOps.GetRenderElementMgr #Production
		mgr.SetElementsActive off
		
		if makeDir deflicker.mapPath then
		(
			vr.adv_irradmap_autoSaveFileName = deflicker.mapPath + deflicker.mapName
			return true
		)
		else
		(
			messageBox "Unable to create directory for gi path."
			return false
		)
	)
	
	on btn_prepass pressed do
	(
		state = renderSceneDialog.isOpen()
		if state then renderSceneDialog.close()
		if applyPrepass() then
		(
			fr = deflicker.spn_frames.value
			animationRange = (interval (deflickerFrameStart-fr) (deflickerFrameEnd+fr))
			-- render
		)
		if state then renderSceneDialog.open()
	)
)

rollout deflickerRangeRollout "Frame Range" width:130 height:95
(
	groupBox grp_range "Stored Frame Range:" pos:[5,0] width:120 height:90
	label lbl_tstart "Start:" pos:[40,20] width:30 height:15
	label lbl_start "0" pos:[80,20] width:30 height:15
	label lbl_tend "End:" pos:[46,40] width:25 height:15
	label lbl_end "100" pos:[80,40] width:30 height:15
	button btn_update "Update" pos:[10,60] width:110 height:25
	
	fn setLabel =
	(
		lbl_start.text = deflickerFrameStart as string
		lbl_end.text = deflickerFrameEnd as string
		
	)
	
	fn updateRange =
	(
		deflickerFrameStart = animationRange.start
		deflickerFrameEnd = animationRange.end
	)
	
	on deflickerRangeRollout open do
	(
		setLabel()
	)
	
	on btn_update pressed do
	(
		updateRange()
		setLabel()
	)
)

rollout animRenderRollout "V-Ray Animation Rendering" width:235 height:100
(
	GroupBox grp_render "Animation Rendering" pos:[5,0] width:225 height:95
	label lbl_samples "Interpolation Samples:" pos:[30,20] width:110 height:15
	spinner spn_samples "" pos:[145,20] width:80 type:#integer range:[1,10000,20]
-- 	label lbl_frames "Interpolation Frames:" pos:[34,40] width:110 height:15
-- 	spinner spn_frames "" pos:[145,40] width:80 range:[0,10000,2] type:#integer
	button btn_restore "Restore Frame Range" pos:[10,60] width:125 height:25
	button btn_range "[]" pos:[135,60] width:15 height:25 tooltip:"Setup Stored Frame Range"
	button btn_render "Apply" pos:[155,60] width:70 height:25 \
		tooltip:\
		(
			"Apply Animation (Rendering) Irradiance Map Mode" + \
			"\n" + \
			"\nDon't Render Final Image: OFF" + \
			"\nTurn ON all save outputs" + \
			"\nRender Elements ON" + \
			"\nGI: On" + \
			"\n" + \			
			"\nPrimary: Irradiance Map" + \
			"\nInterpolation Sample: 20" + \
			"\nUse Camera Path: ON" + \
			"\nMode: Animation (rendering)" + \
			"\nDon't Delete: ON" + \
			"\nAuto-Save: ON" + \
			"\nSwitch to Saved Map: OFF" + \
			"\nAuto-Save Filename: SET" + \
			"\n" + \
			"\nSecondary: None" + \
			"\n"
		)
	
	
	fn leadingZero n i =
	(
		local n = n as string
		while n.count < i do
			n = "0" + n
		n
	)
	
	fn applyRender =
	(
		vr = deflicker.vr
		rendTimeType = 2
-- 		renderWidth = 960
-- 		renderHeight = 540
		rendSaveFile = if rendOutputFilename == "" then off else on
		vr.output_saveRawFile = on
		
		vr.options_limitDepth = on
		vr.options_maxDepth = 4
		vr.options_filterMaps = on
		vr.options_transpMaxLevels = 50
		vr.options_glossyEffects = on
		
		vr.options_dontRenderImage = off		
		vr.gi_on = on
		vr.gi_primary_type = 0 -- irradiance map
		vr.gi_secondary_type = 0 -- light cache
		
		vr.gi_irradmap_multipleViews = off --use camera path
		vr.gi_irradmap_interpFrames = deflicker.spn_frames.value
		
		vr.adv_irradmap_mode = 7
		vr.adv_irradmap_dontDelete = on
		vr.adv_irradmap_autoSave = off
		vr.adv_irradmap_switchToSavedMap = off
		
		mgr = maxOps.GetRenderElementMgr #Production
		mgr.SetElementsActive on
		
		if makeDir deflicker.mapPath then
		(
-- 			theFile = deflicker.mapPath + ("*" + (leadingZero (deflickerFrameStart.frame as integer) 4) as string + ".vrmap")
-- 			preFile = (sort (getFiles theFile))[1]
-- 			
-- 			vr.adv_irradmap_loadFileName =\
-- 			if preFile != undefined then 
-- 			(
-- 				print preFile
-- 				preFile
-- 			)
-- 			else
-- 			(
-- 				messageBox "Unable to find vrmap files.\nPlease set manually.."
-- 			)
			
			vr.adv_irradmap_loadFileName = deflicker.mapPath + deflicker.mapName
			return true
		)
		else
		(
			messageBox "Unable to create directory for gi path."
			return false
		)
	)
	
	on animRenderRollout open do
	(
		
		vr = deflicker.vr
		try(spn_samples.value = vr.gi_irradmap_interpSamples)catch()
-- 		try(vr.gi_irradmap_interpSamples = 20)catch()
		try(spn_frames.value = vr.gi_irradmap_interpFrames)catch()
	)
	
	on spn_samples changed val do
	(
		vr = deflicker.vr
		vr.gi_irradmap_interpSamples = val
	)
	
	on spn_frames changed val do
	(
		vr = deflicker.vr
		vr.gi_irradmap_interpFrames = val
	)
	
	on btn_restore pressed do
	(
		undo "Restore Animation Range" on
		(
			animationRange = (interval deflickerFrameStart deflickerFrameEnd)
		)
	)
	
	on btn_range pressed do
	(
		createDialog deflickerRangeRollout modal:on
	)
	
	on btn_render pressed do
	(
		undo "Apply Animation Redering" on
		(
			state = renderSceneDialog.isOpen()
			if state then renderSceneDialog.close()
			if applyRender() then
			(
-- 				fr = deflicker.spn_frames.value
				animationRange = (interval (deflickerFrameStart) (deflickerFrameEnd))
				-- render
			)
			if state then renderSceneDialog.open()
		)
	)
	
)

createDialog deflicker pos:[655,80]
addSubRollout deflicker.animSub animPrepassRollout
-- deflicker.refeshUI()

/*
macroScript animPrepass
	category:"Glasskite"
	buttonText:"Animation Pre-pass"
	tooltip:"Animation Pre-pass"
(
	-- check for vray
	-- on isEnabled return 
	on execute do animPrePassToggle()
)

to do
/-  off render elements on anim prepass?
- off saving output
- 

*/