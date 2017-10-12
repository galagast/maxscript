/*
Vray - Render Preview
Version 1.4
by Jefferson D. Lim
Glasskite - WLP

[1.4]
2017-06-16
- added auto-detection of vray renderer regardless of version

[1.1]
2015-10-13
- remove default internal render size
- improved checking

[0.2]
2014-03-26
- rearranged UI
- 

[0.1]
2014-03-19
- initial build
2014-03-26

*/
try(destroyDialog vrayAnimPrepassPreview)catch()
rollout vrayAnimPrepassPreview "Vray - Render Preview 1.4" width:270 height:145
(
	local mapPath = ""
	local mapName = ""
	local vr
	
	GroupBox grp_rend "Render Dialog:" pos:[5,0] width:260 height:50
	button btn_dialog "Open Render Dialog" pos:[10,15] width:190 height:30
	button btn_dialogx "Close" pos:[200,15] width:60 height:30
	GroupBox grp_ops "Settings:" pos:[5,55] width:260 height:85
	checkButton chk_IM "1" pos:[10,70] width:30 height:30 highlightColor:green enabled:off
	button btn_IM "Prepass: Irradiance Map" pos:[40,70] width:205 height:30
	checkbutton chk_IM_half "H" pos:[245,70] width:15 height:15 checked:true tooltip:"Prepass at Half the Render Size"
	checkbutton chk_IM_view "V" pos:[245,85] width:15 height:15 checked:true tooltip:"Show Calculation Phase"
	checkButton chk_PRE "2" pos:[10,105] width:30 height:30 highlightColor:green enabled:off
	button btn_PRE "Render Preview" pos:[40,105] width:205 height:30
	checkbutton chk_PRE_half "H" pos:[245,105] width:15 height:15 checked:false tooltip:"Render at Half the Render Size"
	checkbutton chk_PRE_view "V" pos:[245,120] width:15 height:15 checked:false tooltip:"Show Calculation Phase"
	
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
	
	fn getFileName tpye =
	(
		mapName = ""
		if maxFileName != "" then
		(
			theName = getFilenameFile maxFileName
			mapName = theName + (if type == "LC" then ".vrlmap" else ".vrmap")
		)
		mapName
	)
	
	fn setColors num =
	(
		chk_IM.checked = chk_PRE.checked = off
		case num of
		(
			1: chk_IM.checked = on
			2: chk_PRE.checked = on
		)
	)
	
	on vrayAnimPrepassPreview open do
	(
		state = isVrayRenderer()
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
			local lastWidth = renderWidth
			local lastHeight = renderHeight
			renderWidth = if chk_IM_half.checked then lastWidth/2 else lastWidth
			renderHeight = if chk_IM_half.checked then lastHeight/2 else lastHeight
			rendSaveFile = off
			vr.output_saveRawFile = off
			
			-- Global Switches
			vr.options_displacement = off
			vr.options_dontRenderImage = on			
			vr.options_limitDepth = on -- reflection/refraction depth
			vr.options_maxDepth = 4
			vr.options_filterMaps = off
			vr.options_transpMaxLevels = 20
			vr.options_glossyEffects = off
			
			-- indirect illumination
			vr.gi_on = on
			vr.gi_primary_type = 0 -- iradiance map
			vr.gi_secondary_type = 3 -- light cache
			
			-- irradiance map
			vr.gi_irradmap_preset = 4 -- medium anim
			vr.gi_irradmap_subdivs = 200 -- hsph. subdivs
			vr.gi_irradmap_interpSamples = 30 -- interp. samples
			vr.gi_irradmap_showCalcPhase = chk_IM_view.checked
			vr.gi_irradmap_detail_on = off
			vr.gi_irradmap_multipleViews = off -- use camera path
			vr.adv_irradmap_mode = 0
			vr.adv_irradmap_dontDelete = on
			vr.adv_irradmap_autoSave = on
			vr.adv_irradmap_switchToSavedMap = on
			
			vr.adv_irradmap_autoSaveFileName = mapPath + "TEST.vrmap"
			
			-- light cache
			vr.lightcache_showCalcPhase = if chk_IM_view.checked then 1 else 0
			vr.lightcache_multipleViews = off -- camera path
			vr.lightcache_mode = 0
			vr.lightcache_autoSave = off
			vr.lightcache_switchToSavedMap = off
			
			-- DMC sampler
			vr.dmc_importanceSampling
			vr.dmc_earlyTermination_amount = 0.85 -- adaptive amount
			vr.dmc_earlyTermination_threshold = 0.02 -- noise threshold
			vr.dmc_earlyTermination_minSamples = 8 -- min samples
			vr.dmc_subdivs_mult = 0.9 -- global subdivs multiplier
			
			-- render elements
			mgr = maxOps.GetRenderElementMgr #Production
			mgr.SetElementsActive off
			
			setColors 1
			
			max quick render
			
			renderWidth = lastWidth
			renderHeight = lastHeight
			
			if state then renderSceneDialog.open()
		)
		else
		(
			local code = "11"
			code[1] = if check1 then "1" else "0"
			code[2] = if check2 then "1" else "0"
			
			local noVray = "* Renderer is not set to Vray 3.3."
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
	
	on btn_PRE pressed do
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
			local lastWidth = renderWidth
			local lastHeight = renderHeight
			renderWidth = if chk_PRE_half.checked then lastWidth/2 else lastWidth
			renderHeight = if chk_PRE_half.checked then lastHeight/2 else lastHeight
			rendSaveFile = off
			vr.output_saveRawFile = off
			
			-- Global Switches
			vr.options_displacement = on
			vr.options_dontRenderImage = off
			vr.options_limitDepth = on -- reflection/refraction depth
			vr.options_maxDepth = 4
			vr.options_filterMaps = on
			vr.options_transpMaxLevels = 40
			vr.options_glossyEffects = on
			
			-- indirect illumination
			vr.gi_on = on
			vr.gi_primary_type = 0 -- irraidance map
			vr.gi_secondary_type = 3 -- light cache
			
			-- irradiance map
			vr.gi_irradmap_preset = 4 -- medium anim
			vr.gi_irradmap_subdivs = 200 -- hsph. subdivs
			vr.gi_irradmap_interpSamples = 30 -- interp. samples
			vr.gi_irradmap_showCalcPhase = chk_PRE_view.checked
			vr.gi_irradmap_detail_on = off
			vr.gi_irradmap_multipleViews = off -- use camera path
			vr.adv_irradmap_mode = 2
			vr.adv_irradmap_dontDelete = on
			vr.adv_irradmap_autoSave = off
			vr.adv_irradmap_switchToSavedMap = off
			
			vr.adv_irradmap_loadFileName = mapPath + "TEST.vrmap"
			
			-- light cache
			vr.lightcache_showCalcPhase = if chk_PRE_view.checked then 1 else 0
			vr.lightcache_multipleViews = off -- camera path
			vr.lightcache_mode = 0
			vr.lightcache_autoSave = off
			vr.lightcache_switchToSavedMap = off
			
			-- DMC sampler
			vr.dmc_importanceSampling
			vr.dmc_earlyTermination_amount = 0.85 -- adaptive amount
			vr.dmc_earlyTermination_threshold = 0.02 -- noise threshold
			vr.dmc_earlyTermination_minSamples = 8 -- min samples
			vr.dmc_subdivs_mult = 0.9 -- global subdivs multiplier
			
			-- render elements
			mgr = maxOps.GetRenderElementMgr #Production
			mgr.SetElementsActive on
			
			setColors 2
			
			max quick render
			
			renderWidth = lastWidth
			renderHeight = lastHeight
			
			if state then renderSceneDialog.open()
			
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
)
createDialog vrayAnimPrepassPreview pos:[605,80]

/*
[to do]

[notes]

*/