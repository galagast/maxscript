/*
Tera Cleaner
Version: 1.3
by Jefferson D. Lim

[1.3]
- added cleaning of emtpy layers
- added icons for layers

[1.2]
- updated remRet

[1.1]
- updated UI
- postmessages

[1.0]
2015-08-03
- Initial Build


*/
try(destroyDialog teraCleaner)catch()
rollout teraCleaner "Tera Cleaner 1.3" width:260 height:335
(
	local activeArr = #()
	local note = "* Please make sure to SAVE or have a BAKCUP of your scene prior to running the cleaner operations just in case the scene gets corrupted due to the deletions."
	
	button btn_ref "Refresh" pos:[5,5] width:250 height:25 align:#left
	
	GroupBox grp_search "Search:" pos:[5,30] width:250 height:220 align:#left
	
	label lbl_anim "Anim Layers:" pos:[15,50] align:#left
	label _lbl_anim "0" pos:[170,50] align:#left
	button btn_anim "x" pos:[225,45] width:25 height:25 align:#left
	
	label lbl_animca "Anim Layers Custom Attributes:" pos:[15,75] align:#left
	label _lbl_animca "0" pos:[170,75] align:#left
	button btn_animca "x" pos:[225,70] width:25 height:25 align:#left
	
	label lbl_ca "Global Custom Attributes:" pos:[15,100] align:#left
	label _lbl_ca "0" pos:[170,100] align:#left
	button btn_ca "x" pos:[225,95] width:25 height:25 align:#left
	
	label lbl_bip "Track View Biped:" pos:[15,125] align:#left
	label _lbl_bip "0" pos:[170,125] align:#left
	button btn_bip "x" pos:[225,120] width:25 height:25 align:#left
	
	label lbl_ray "Raytrace Engine Globals:" pos:[15,150] align:#left
	label _lbl_ray "0" pos:[170,150] align:#left
	button btn_ray "x" pos:[225,145] width:25 height:25 align:#left
	
	label lbl_mo "Max MotionClip Manager:" pos:[15,175]  align:#left
	label _lbl_mo "0" pos:[170,175] align:#left
	button btn_mo "x" pos:[225,170] width:25 height:25 align:#left
	
	label lbl_ret "Retimer Manager:" pos:[15,200] align:#left
	label _lbl_ret "0" pos:[170,200] align:#left
	button btn_ret "x" pos:[225,195] width:25 height:25 align:#left
	
	label lbl_layers "Empty Layers:" pos:[15,225] align:#left
	label _lbl_layers "0" pos:[170,225] align:#left
	button btn_layers "x" pos:[225,220] width:25 height:25 align:#left
	
	progressBar pb "" pos:[5,255] width:250 height:10 align:#left
	
	label _lbl_warn "" pos:[10,270] width:245 height:55 align:#left
	

	
	fn fixLabels ui offset:3 =
	(
		for p in ui.controls where classOf p == LabelControl do
		(
			if (p.name)[1] != "_" then
			(
				adjust = (ui.width/2)+offset
				txtSize = getTextExtent p.text
				p.pos.x = adjust-txtSize.x
			)
		)
	)
	
	fn countAnimLayers =
	(
		try(rootscene.Anim_Layer_Control_Manager.AnimLayers.count)catch(0)
	)
	
	fn getActiveAnimLayers =
	(
		local activeDex = #()
		for i in objects do
		(
			local arr = AnimLayerManager.getNodesLayers i
			if arr.count != 0 then for j in arr do append activeDex j
		)
		activeDex
	)
	
	fn countAnimCa =
	(
		try(custAttributes.count rootscene.Anim_Layer_Control_Manager)catch(0)
	)
	
	fn countCAs =
	(
		custAttributes.count rootscene
	)
	
	fn emptyLayers remove:off =
	(
		local layerEmpty = #()
		local layerCount = layerManager.count
		for i in 0 to layerCount-1 do
		(
			local theLayer = layerManager.getLayer i
			if theLayer != undefined then
			(
				local theName = theLayer.name
				local theObject = ILayerManager.getLayerObject i
				local hasNodes = layerManager.doesLayerHierarchyContainNodes theName
				if not hasNodes then
				(
					append layerEmpty theName
				)
			)
		)
		
		local count = layerEmpty.count
		if remove then
		(
			for i in count to 1 by -1 do
			(
				layerManager.deleteLayerHierarchy layerEmpty[i]
			)
		)
		
		count
	)
	
	fn initUI =
	(
		fixLabels teraCleaner offset:35
		
		local animCount = countAnimLayers()
		activeArr = getActiveAnimLayers()
		_lbl_anim.text = activeArr.count as string + "/" + animCount as string
		btn_anim.tooltip = "Found:\n" + activeArr.count as string + " Active\n\nTotal:\n" + animCount as string + " Animation Layer(s)\n\n[CTRL] Force delete all."
		btn_anim.enabled = animCount != 0
		
		local animcaCount = countAnimCa()
		_lbl_animca.text = animcaCount as string
		btn_animca.enabled = animcaCount != 0
		
		local caCount = countCAs()
		_lbl_ca.text = caCount as string
		btn_ca.enabled = caCount != 0
		
		local tv = trackViewNodes[#Biped]
		_lbl_bip.text = if tv != undefined then "1" else "0"
		btn_bip.enabled = tv != undefined
		
		local tv = trackViewNodes[#Raytrace_Engine_Globals]
		_lbl_ray.text = if tv != undefined then "1" else "0"
		btn_ray.enabled = tv != undefined
		
		local tv = trackViewNodes[#Max_MotionClip_Manager]
		_lbl_mo.text = if tv != undefined then "1" else "0"
		btn_mo.enabled = tv != undefined
		
		local tv = trackViewNodes[#Retimer_Manager]
		local retCount = RetimerMan.numRetimers
		local state = tv != undefined or retCount != 0
		_lbl_ret.text = if state then retCount as string else "0"
		btn_ret.tooltip = if state then "Found:\n" + retCount as string + " retimer(s)" else ""
		btn_ret.enabled = state
		
		local layersCount = emptyLayers()
		_lbl_layers.text = layersCount as string
		btn_layers.enabled = layersCount != 0
		
		_lbl_warn.text = note
	)
	
	----------------------------------------------------------
	--	              REMOVAL Functions                     --
	----------------------------------------------------------
	
	fn remAnimLayers =
	(
		if keyboard.controlPressed then
		(
			try(rootscene.Anim_Layer_Control_Manager.AnimLayers = #())catch(format "*** % ***\n" (getCurrentException()))
		)
		else
		(
			for i in countAnimLayers() to 1 by -1 do
			(
				if findItem activeArr i == 0 then
				(
					deleteItem rootscene.Anim_Layer_Control_Manager.AnimLayers i
				)
			)
		)
		initUI()
	)
	
	fn remAnimLayersCA =
	(
		local theDef = 1
		while theDef !=undefined do
		(
			local theRoot = rootscene.Anim_Layer_Control_Manager
			theDef = custAttributes.getdef theRoot 1
			custAttributes.delete theRoot theDef
		)
		initUI()
	)
	
	fn remCAs =
	(
		local theDef = 1
		while theDef !=undefined do
		(
			local theRoot = rootscene
			theDef = custAttributes.getdef theRoot 1
			custAttributes.delete theRoot theDef
		)
		initUI()
	)

	fn remBip =
	(
		try(deleteTrackViewNode trackViewNodes trackViewNodes[#Biped])catch()
		initUI()
	)
	
	fn remRay =
	(
		try(deleteTrackViewNode trackViewNodes trackViewNodes[#Raytrace_Engine_Globals])catch()
		initUI()
	)
	
	fn remMo =
	(
		t = trackViewNodes
		try(deleteTrackViewController t t[#Max_MotionClip_Manager].controller)catch()
		initUI()
	)
	
	fn updateUI state =
	(
		local cons = teraCleaner.controls
		local count = cons.count
		for i in 1 to count-2 do
		(
			cons[i].enabled = state
		)
	)
	
	fn remRet =
	(
-- 		RetimerMan.BakeAndDeleteLocalRetimers()
		local count = RetimerMan.numRetimers
		local saving = autosave.Enable
		autosave.Enable = off
		format "Found % Retimer(s)\n" count
		updateUI off
		pb.color = green
		for i in count to 1 by -1 do
		(
			if keyboard.escPressed then exit
			if mod i 10 == 0 then
			(
				windows.processPostedMessages()
				_lbl_warn.text = "Deleting Retimers... (" + i as string + " of " + count as string + ")"
				_lbl_warn.text += "\nHold [ESC] to stop."
			)
			pb.value = (count - i)*100.0/count
			RetimerMan.DeleteRetimer i
		)
-- 		t = trackViewNodes
-- 		try(deleteTrackViewController t t[#Retimer_Manager].controller)catch(format "*** % ***\n" (getCurrentException()))
		autosave.Enable = on
		updateUI on
		_lbl_warn.text = note
		pb.color = blue
		initUI()
	)
	
	fn remLayers =
	(
		emptyLayers remove:on
		initUI()
	)
	
	----------------------------------------------------------
	--	                   UI Functions                     --
	----------------------------------------------------------
	
	on btn_ref pressed do initUI()
	on teraCleaner open do initUI()
	
	on btn_anim pressed do undo "Remove TrackView Anim Layers" on remAnimLayers()
	on btn_animca pressed do undo "Remove TrackView Anim Layers Custom Atttributes" on remAnimLayersCA()
	on btn_ca pressed do undo "Remove Global Custom Attribures" on remCAs()
	on btn_bip pressed do undo "Remove TrackView Biped" on remBip()
	on btn_ray pressed do undo "Remove TrackView Raytrace Engine Globals" on remRay()
	on btn_Mo pressed do undo "Remove TrackView Max MotionClip Manager" on remMo()
	on btn_Ret pressed do undo off remRet()
	on btn_layers pressed do undo "Remove Empty Layers" on remLayers()
	on chk_sublayers changed state do setCheckboxIcon chk_sublayers state
)
createDialog teraCleaner

/*
TO DO
- select objects with animation layers (for collpasing)
*/