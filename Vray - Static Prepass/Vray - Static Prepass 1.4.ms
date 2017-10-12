/*
Vray - Static Prepass
Version 1.1
by Jefferson D. Lim
Glasskite - WLP

- Automates the process of creating a static prepass render of GI for Vray

[1.4]
2017-06-16
- added auto-detection of vray renderer regardless of version

[1.1]
2015-10-13
- remove default internal render size
- improved checking

[0.3]
2014-03-26
- added half res checkbuttons
- added show calc checkbuttons
- rearranged UI

[0.2]
2014-03-18
- added render controls (removed)
- added preview

[0.1]
2014-03-18
- initial build

*/
try(destroyDialog vrayStaticPrepass)catch()
rollout vrayStaticPrepass "Vray - Staic Prepass 1.4" width:270 height:245
(
	local mapPath = ""
	local mapName = ""
	local vr
	
	GroupBox grp_rend "Render Dialog:" pos:[5,5] width:260 height:50
	
	button btn_dialog "Open Render Dialog" pos:[10,20] width:190 height:30
	button btn_dialogx "Close" pos:[200,20] width:60 height:30 tooltip:"Close the Render Dialog"
	button btn_prepass "Prepass" pos:[5,190]  width:130 height:50 enabled:false tooltip:"Pick Process 1 or 2, then press this to generate the Cache"
	button btn_preview "Preview" pos:[135,190] width:130 height:50 enabled:false tooltip:"Equivalent to pressing F9 to render a preview"
	
	GroupBox grp_ops "Process:" pos:[5,60] width:260 height:125
	checkbutton chk_LC "1" pos:[10,75] width:30 height:30 enabled:false highlightColor:(color 0 255 0) checked:true
	checkButton chk_LC_half "H" pos:[245,75] width:15 height:15 checked:true tooltip:"Prepass at Half the Render Size"
	checkButton chk_LC_view "V" pos:[245,90] width:15 height:15 checked:true tooltip:"Show Calculation Phase"
	checkbutton chk_IM "2" pos:[10,110] width:30 height:30 enabled:false highlightColor:(color 0 255 0) checked:true
	checkButton chk_IM_half "H" pos:[245,110] width:15 height:15 checked:true tooltip:"Prepass at Half the Render Size"
	checkButton chk_IM_view "V" pos:[245,125] width:15 height:15 checked:true tooltip:"Show Calculation Phase"
	checkbutton chk_final "3" pos:[10,145] width:30 height:30 enabled:false highlightColor:(color 0 255 0) checked:true
	button btn_LC "Prepass: LC + LC" pos:[40,75] width:205 height:30
	button btn_IM "Prepass: IM + LC" pos:[40,110] width:205 height:30
	button btn_final "Final" pos:[40,145] width:220 height:30
	
	fn fixLabels ui offset:3 =
	(
		for p in ui.controls where classOf p == LabelControl do
		(
			adjust = (ui.width/2)+offset
			txtSize = getTextExtent p.text
			p.pos.x = adjust-txtSize.x
		)
	)
	
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
	
	fn getFilePath =
	(
		mapPath = ""
		if maxFilePath != "" then
		(
			mapPath = pathConfig.convertPathToAbsolute (maxFilePath + @"..\cache\ir\")
		)
		mapPath
	)
	
	fn getFileName type =
	(
		mapName = ""
		if maxFileName != "" then
		(
			theName = getFilenameFile maxFileName
			mapName = theName + (if type == "LC" then ".vrlmap" else ".vrmap")
		)
		mapName
	)
	
	on vrayStaticPrepass open do
	(
		fixLabels vrayStaticPrepass offset:0
		state = isVrayRenderer()
		btn_LC.enabled = btn_IM.enabled = btn_final.enabled = state
		chk_LC.checked = chk_IM.checked = chk_final.checked = off
	)
	
	fn setColors num =
	(
		chk_LC.checked = chk_IM.checked = chk_final.checked = off
		case num of
		(
			1: chk_LC.checked = on
			2: chk_IM.checked = on
			3: chk_final.checked = on
		)
-- 		btn_LC.highlightColor = btn_IM.highlightColor = btn_final.highlightColor = gray
-- 		case num of
-- 		(
-- 			1: btn_LC.highlightColor = green
-- 			2: btn_IM.highlightColor = green
-- 			3: btn_final.highlightColor = green
-- 		)
	)
	
	on btn_LC pressed do
	(
		getFilePath()
		local check1 = isVrayRenderer()
		local check2 = makeDir mapPath
		
		if check1 and check2 then
		(
			state = renderSceneDialog.isOpen()
			if state then renderSceneDialog.close()
			
			-- common parameters
-- 			local lastWidth = renderWidth
-- 			local lastHeight = renderHeight
-- 			renderWidth = if chk_LC_half.checked then lastWidth/2 else lastWidth
-- 			renderHeight = if chk_LC_half.checked then lastHeight/2 else lastHeight
			rendSaveFile = off
			vr.output_saveRawFile = off
			
			-- Global Switches
			vr.options_displacement = off
			vr.options_dontRenderImage = on			
			vr.options_limitDepth = on -- reflection/refraction depth
			vr.options_maxDepth = 4
			vr.options_filterMaps = off
			vr.options_transpMaxLevels = 20
			vr.options_overrideMtl_on = off
			vr.options_glossyEffects = off
			
			-- indirect illumination
			vr.gi_on = on
			vr.gi_primary_type = 3 -- light cache
			vr.gi_secondary_type = 3 -- light cache
			
			-- light cache
			vr.lightcache_showCalcPhase = if chk_LC_view.checked then 1 else 0
			vr.lightcache_multipleViews = off -- camera path
			vr.lightcache_mode = 1
			vr.lightcache_autoSave = on
			vr.lightcache_switchToSavedMap = on
			
			mapName = getFileName "LC"
			vr.lightcache_autoSaveFileName = mapPath + mapName
			
			-- DMC sampler
			vr.dmc_importanceSampling
			vr.dmc_earlyTermination_amount = 0.85 -- adaptive amount
			vr.dmc_earlyTermination_threshold = 0.02 -- noise threshold
			vr.dmc_earlyTermination_minSamples = 8 -- min samples
			vr.dmc_subdivs_mult = 0.9 -- global subdivs multiplier
			
			-- render elements
			mgr = maxOps.GetRenderElementMgr #Production
			mgr.SetElementsActive off
			
-- 			renderWidth = lastWidth
-- 			renderHeight = lastHeight
			
			if state then renderSceneDialog.open()
			setColors 1
			btn_preview.enabled = off
			btn_prepass.enabled = on
		)
		else
		(
			local code = "11"
			code[1] = if check1 then "1" else "0"
			code[2] = if check2 then "1" else "0"
			
			local noVray = "* Renderer is not set to Vray 2.5."
			local noDir = "* Unable to create directory for gi path, please save your scene."
			local txt = case code of
			(
				"10": noDir
				"01": noVray
				"00": noVray + "\n" + noDir
			)
			messageBox txt
		)
	)
	
	on btn_IM pressed do
	(
		getFilePath()
		local check1 = isVrayRenderer()
		local check2 = makeDir mapPath
		
		if check1 and check2 then
		(
			state = renderSceneDialog.isOpen()
			if state then renderSceneDialog.close()
			
			-- common parameters
			rendTimeType = 1 -- single
-- 			local lastWidth = renderWidth
-- 			local lastHeight = renderHeight
-- 			renderWidth = if chk_IM_half.checked then lastWidth/2 else lastWidth
-- 			renderHeight = if chk_IM_half.checked then lastHeight/2 else lastHeight
			rendSaveFile = off
			vr.output_saveRawFile = off
			
			-- Global Switches
			vr.options_displacement = off
			vr.options_dontRenderImage = on			
			vr.options_limitDepth = on -- reflection/refraction depth
			vr.options_maxDepth = 4
			vr.options_filterMaps = off
			vr.options_transpMaxLevels = 20
			vr.options_overrideMtl_on = off
			vr.options_glossyEffects = off
			
			-- indirect illumination
			vr.gi_on = on
			vr.gi_primary_type = 0 -- irraidance map
			vr.gi_secondary_type = 3 -- light cache
			
			-- irradiance map
			vr.gi_irradmap_preset = 2 -- low
			vr.gi_irradmap_subdivs = 200 -- hsph. subdivs
			vr.gi_irradmap_interpSamples = 30 -- interp. samples
			vr.gi_irradmap_showCalcPhase = chk_IM_view.checked
			vr.gi_irradmap_detail_on = off
			vr.gi_irradmap_multipleViews = on -- use camera path
			vr.adv_irradmap_mode = 0
			vr.adv_irradmap_dontDelete = on
			vr.adv_irradmap_autoSave = on
			vr.adv_irradmap_switchToSavedMap = on

			mapName = getFileName "IM"
			vr.adv_irradmap_autoSaveFileName = mapPath + mapName
			
			-- light cache
			vr.lightcache_showCalcPhase = if chk_LC_view.checked then 1 else 0
			vr.lightcache_multipleViews = off -- camera path
			vr.lightcache_mode = 2
			vr.lightcache_autoSave = off
			vr.lightcache_switchToSavedMap = off
			
			mapName = getFileName "LC"
			vr.lightcache_loadFileName = mapPath + mapName
			
			-- DMC sampler
			vr.dmc_importanceSampling
			vr.dmc_earlyTermination_amount = 0.85 -- adaptive amount
			vr.dmc_earlyTermination_threshold = 0.02 -- noise threshold
			vr.dmc_earlyTermination_minSamples = 8 -- min samples
			vr.dmc_subdivs_mult = 0.9 -- global subdivs multiplier
			
			-- render elements
			mgr = maxOps.GetRenderElementMgr #Production
			mgr.SetElementsActive off
			
-- 			renderWidth = lastWidth
-- 			renderHeight = lastHeight
			
			if state then renderSceneDialog.open()
			setColors 2
			btn_preview.enabled = off
			btn_prepass.enabled = on
		)
		else
		(
			local code = "11"
			code[1] = if check1 then "1" else "0"
			code[2] = if check2 then "1" else "0"
			
			local noVray = "* Renderer is not set to Vray 2.5."
			local noDir = "* Unable to create directory for gi path, please save your scene."
			local txt = case code of
			(
				"10": noDir
				"01": noVray
				"00": noVray + "\n" + noDir
			)
			messageBox txt
		)
	)
	
	on btn_final pressed do
	(
		getFilePath()
		local check1 = isVrayRenderer()
		local check2 = makeDir mapPath
		
		if check1 and check2 then
		(	
			state = renderSceneDialog.isOpen()
			if state then renderSceneDialog.close()
			
			-- common parameters
			rendTimeType = 2 -- range
			rendSaveFile = on
			vr.output_saveRawFile = on
			
			-- Global Switches
			vr.options_displacement = on
			vr.options_dontRenderImage = off		
			vr.options_limitDepth = on -- reflection/refraction depth
			vr.options_maxDepth = 4
			vr.options_filterMaps = on
			vr.options_transpMaxLevels = 40
			vr.options_overrideMtl_on = off
			vr.options_glossyEffects = on
			
			-- indirect illumination
			vr.gi_on = on
			vr.gi_primary_type = 0 -- irradiance map
			vr.gi_secondary_type = 3 -- light cache
			
			-- irradiance map
			vr.gi_irradmap_preset = 2 -- low
			vr.gi_irradmap_subdivs = 200 -- hsph. subdivs
			vr.gi_irradmap_interpSamples = 30 -- interp. samples
			vr.gi_irradmap_showCalcPhase = false
			vr.gi_irradmap_detail_on = off
			vr.gi_irradmap_multipleViews = off -- use camera path
			vr.adv_irradmap_mode = 2 -- from file
			vr.adv_irradmap_dontDelete = on
			vr.adv_irradmap_autoSave = off
			vr.adv_irradmap_switchToSavedMap = off
			
			mapName = getFileName "IM"
			vr.adv_irradmap_loadFileName = mapPath + mapName
			
			-- light cache
			vr.lightcache_showCalcPhase = 0
			vr.lightcache_multipleViews = off -- camera path
			vr.lightcache_mode = 2
			vr.lightcache_autoSave = off
			vr.lightcache_switchToSavedMap = off
			
			mapName = getFileName "LC"
			vr.lightcache_loadFileName = mapPath + mapName
			
			-- DMC sampler
			vr.dmc_importanceSampling
			vr.dmc_earlyTermination_amount = 0.85 -- adaptive amount
			vr.dmc_earlyTermination_threshold = 0.02 -- noise threshold
			vr.dmc_earlyTermination_minSamples = 8 -- min samples
			vr.dmc_subdivs_mult = 0.9 -- global subdivs multiplier
			
			-- render elements
			mgr = maxOps.GetRenderElementMgr #Production
			mgr.SetElementsActive on
			
			if state then renderSceneDialog.open()
			setColors 3
			btn_preview.enabled = on
			btn_prepass.enabled = off
		)
		else
		(
			local code = "11"
			code[1] = if check1 then "1" else "0"
			code[2] = if check2 then "1" else "0"
			
			local noVray = "* Renderer is not set to Vray 2.5."
			local noDir = "* Unable to create directory for gi path, please save your scene."
			local txt = case code of
			(
				"10": noDir
				"01": noVray
				"00": noVray + "\n" + noDir
			)
			messageBox txt
		)
	)
	
	on btn_dialog pressed do
	(
		renderSceneDialog.open()
	)
	
	on btn_dialogx pressed do
	(
		renderSceneDialog.close()
	)
	
	fn getPrePassRenderSize size =
	(
		local code = "00"
		code[1] = if chk_LC.checked then "1" else "0"
		code[2] = if chk_IM.checked then "1" else "0"
			
		case code of
		(
			"10": if chk_LC_half.checked then size/2 else size
			"01": if chk_IM_half.checked then size/2 else size
		)
	)
	
	on btn_preview pressed do
	(
		state = renderSceneDialog.isOpen()
		if state then renderSceneDialog.close()
		mgr = maxOps.GetRenderElementMgr #Production
		
		oldTime = rendTimeType
		oldSave = rendSaveFile
		oldRaw = vr.output_saveRawFile
		oldEle = mgr.GetElementsActive()
		
		rendTimeType = 1 -- single
		rendSaveFile = off
		vr.output_saveRawFile = off
		mgr.SetElementsActive on
		
		max quick render
		
		rendTimeType = oldTime
		rendSaveFile = oldSave
		vr.output_saveRawFile = oldRaw
		mgr.SetElementsActive oldEle
		
		if state then renderSceneDialog.open()
	)
	
	on btn_prepass pressed do
	(
		state = renderSceneDialog.isOpen()
		if state then renderSceneDialog.close()
		
		local lastTimeType = rendTimeType
		local lastWidth = renderWidth
		local lastHeight = renderHeight
		
		rendTimeType = 1
		renderWidth = getPrePassRenderSize lastWidth
		renderHeight = getPrePassRenderSize lastHeight
		
		max quick render
		
		rendTimeType = lastTimeType
		renderWidth = lastWidth
		renderHeight = lastHeight
		
		if state then renderSceneDialog.open()
	)
)
createDialog vrayStaticPrepass pos:[335,80]

/*
[to do]
- check if output vr maps are valid/existing
- set vray settings
- render to memory VFB off
- add undo

[notes]
- unable to set checkbutton highlightColors!!

*/