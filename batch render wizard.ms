	rollout batchrenderwizard_rollout "Batch Render Wizard"
	(
		fn refreshListView lv =
		(
			theRange = #()
			
			lv.items.clear()

			for v = 1 to batchRenderMgr.numViews do
			(
				renderView = batchRenderMgr.getView v

				li = dotNetObject "System.Windows.Forms.ListViewItem" renderView.name
				--Then we add all the sub-itemswith the desired string values:
				cameraName = "ViewPort"
				if( isKindOf renderView.camera camera) then
					cameraName = renderView.camera.name
				sub_li = li.SubItems.add (cameraName)
				sub_li = li.SubItems.add (renderView.sceneStateName)
				
				renderViewRes = "Default"
				renderViewRange = "Default"
				if( renderView.overridePreset ) then
				(
					renderViewRes = (renderView.width as string) + "x" + (renderView.height as string)
					renderViewRange = (int(renderView.startFrame) as string) + "-" + (int(renderView.endFrame) as string)
				)

				sub_li = li.SubItems.add (renderViewRes)
				sub_li = li.SubItems.add (renderViewRange)

				li.checked = renderView.enabled 
				
				append theRange li--we add the list item to the array
			)
			lv.Items.AddRange theRange--when done, we populate the ListView
			lv.update()
		)
		
		fn initListView lv =
		(
			lv.View = (dotNetClass "System.Windows.Forms.View").Details
			lv.fullRowSelect = true
			layout_def = #("Name", "Camera", "Scene State", "Resolution", "Range")
			columWidth_def = #(150,50,100,80,70)
			for i = 1 to layout_def.count do
			(
				lv.Columns.add layout_def[i] columWidth_def[i] --add column with name
			)
			lv.CheckBoxes = true
			lv.HideSelection = false
		)

		fn updateSelectedItemDisplays mainRollout =
		(
			redrawIndexStart = mainRollout.batchRenderList_lv.Items.count
			redrawIndexEnd = -1
			for s = 0 to mainRollout.batchRenderList_lv.SelectedItems.count - 1 do
			(
				listItem = mainRollout.batchRenderList_lv.SelectedItems.Item[s]
				renderView = batchRenderMgr.getView (listItem.Index +1)
				
				if( mainRollout.batchRenderList_lv.SelectedItems.count == 1 )then
					listItem.text = renderView.name

				renderViewRes = "Default"
				renderViewRange = "Default"
				if( renderView.overridePreset ) then
				(
					renderViewRes = (renderView.width as string) + "x" + (renderView.height as string)
					renderViewRange = (int(renderView.startFrame) as string) + "-" + (int(renderView.endFrame) as string)
				)
				listItem.subItems.Item[3].text = renderViewRes
				listItem.subItems.Item[4].text = renderViewRange
				
				listItem.checked = renderView.enabled 

				if( redrawIndexStart > mainRollout.batchRenderList_lv.SelectedItems.Item[s].index ) then
					redrawIndexStart = mainRollout.batchRenderList_lv.SelectedItems.Item[s].index

				if( redrawIndexEnd < mainRollout.batchRenderList_lv.SelectedItems.Item[s].index ) then
					redrawIndexEnd = mainRollout.batchRenderList_lv.SelectedItems.Item[s].index
			)
			
			mainRollout.batchRenderList_lv.RedrawItems redrawIndexStart redrawIndexEnd false
		)

		multilistbox sceneStateList_mlb "Scene State List" width:200 height:10 across:2 align:#left
		multilistbox cameraList_mlb "Camera List" width:200 height:10 align:#left
		
		edittext nameConvention_edittext "Naming Convention" text:"%scenestate %camera" width:400 across:2 offset:[0,10]
		button generatePermutations_button "Add Permutations" width:150 offset:[-100,10]
		
		label nameConventionHints "%scenestate - Scene state name\n%camera - Camera name" align:#left height:28

		dotNetControl batchRenderList_lv "System.Windows.Forms.ListView" height:250 align:#center CheckBoxes:true offset:[0,10]
		button deleteBatchRenderView_button "Delete" width:150 across:2
		button clearBatchRenderList_button "Clear List" width:150 
		
		group "Batch Render Settings"	
		(
			edittext batchRenderName_edittext "Batch Render Name" enabled:false across:2
			label batchRenderRenameError_label "" align:#left offset:[5,0]

			checkbox overridePresets_chk "Override Presets"  enabled:false
			spinner width_spn "Width" range:[1,8192,renderWidth] width:70 type:#integer align:#left across:2 enabled:false
			spinner height_spn "Height" range:[1,8192,renderHeight] width:70 type:#integer align:#left enabled:false offset:[-280,0]
			
			spinner startFrame_spn "Start Frame" range:[-8192,8192,rendStart] width:90 type:#integer align:#left across:2 enabled:false
			spinner endFrame_spn "End Frame" range:[-8192,8192,rendEnd] width:90 type:#integer align:#left enabled:false offset:[-230,0]
		)

		edittext fileLocation_edittext "Render Output Location" text:(maxFilePath + "RENDERS\\") width:380 across:4 offset:[0,10]
		button fileLocation_browse "..." width:30 pos:[400,fileLocation_edittext.pos.y]
		dropdownlist outputFileType_drp items:#(".png",".jpg") width:50 align:#left pos:[440,fileLocation_edittext.pos.y]
		
		button startBatchRenderList_button "Start Batch Render" width:150 height:150 align:#right offset:[0,10]
		
		multilistbox additionalFileLocations_mlb "Additional Output Locations" width:480 height:5 offset:[0,-130]
		edittext newAdditionalFileLocation_edittext "New Output Location" text:(maxFilePath + "RENDERS\\") width:380
		button browseAdditionalFileLocation_btn "..." width:30 pos:[400,newAdditionalFileLocation_edittext.pos.y]
		button addAdditionalFileLocation_btn "+" width:30 pos:[440,newAdditionalFileLocation_edittext.pos.y] tooltip:"Add new output location"
		
		on batchrenderwizard_rollout open do
		(
			sceneStateNames = #()
			for s =1 to scenestatemgr.getCount() do
			(
				append sceneStateNames (scenestatemgr.GetSceneState s)
			)
			sceneStateList_mlb.items = sceneStateNames

			cameraNames = #()
			for c in cameras do
			(
				if (not (isKindOf c Targetobject)) then
				(
					append cameraNames c.name
					append cameraList c
				)
			)
			cameraList_mlb.items = cameraNames
			
			initListView batchRenderList_lv
			refreshListView batchRenderList_lv
		)
		
		on generatePermutations_button pressed do
		(
			for c in cameraList_mlb.selection do
			(
				for s in sceneStateList_mlb.selection do
				(
					batchRenderMgr.CreateView cameraList[c]
					
					renderView = batchRenderMgr.GetView batchRenderMgr.numViews
					renderView.sceneStateName = sceneStateList_mlb.items[s]
					
					renderViewName = nameConvention_edittext.text
					renderViewName = substituteString renderViewName "%scenestate" sceneStateList_mlb.items[s]
					renderViewName = substituteString renderViewName "%camera" cameraList[c].name
					
					print (batchRenderMgr.findView renderViewName )
					if(batchRenderMgr.findView renderViewName <=0) then
						renderView.name = renderViewName
					else
						print renderViewName + " already exists. Skipping file rename."
					
					renderView.outputFilename = fileLocation_edittext.text + "\\" + renderView.name + outputFileType_drp.selected 
				)
				
			)
			refreshListView batchRenderList_lv
		)
		
		on deleteBatchRenderView_button pressed do
		(
			for s = 1 to batchRenderList_lv.SelectedItems.count do
			(
				batchRenderMgr.DeleteView (batchRenderMgr.findView batchRenderList_lv.SelectedItems.item[s-1].text)
			)
			
			refreshListView batchRenderList_lv
		)
		
		on clearBatchRenderList_button pressed do
		(
			while batchRenderMgr.numViews > 0 do
			(
				batchRenderMgr.deleteView 1
			)
			batchRenderList_lv.clear()
			initListView batchRenderList_lv
			refreshListView batchRenderList_lv
		)
		
		on startBatchRenderList_button pressed do
		(
			batchRenderMgr.Render()
			
			-- Highlight the first file that gets rendered
			firstEnabledViewIndex = -1
			for v = 1 to batchRenderMgr.numViews do
			(
				renderView = batchRenderMgr.getView v
				if( renderView.enabled and firstEnabledViewIndex == -1) then
					firstEnabledViewIndex = v
			)
			
			if( firstEnabledViewIndex > -1 ) then
				--shellLaunch "explorer.exe" ("/select," + fileLocation_edittext.text + (batchRenderMgr.GetView firstEnabledViewIndex).name + outputFileType_drp.selected )
			shellLaunch "explorer.exe" fileLocation_edittext.text
			else
				messageBox "No renders were selected."
		)
		
		on fileLocation_browse pressed do
		(
			savePath = getSavePath caption:"Pick render location..." initialDir:fileLocation_edittext.text
			if( savePath != undefined ) then
			(
				fileLocation_edittext.text = savePath
				
				for v = 1 to batchRenderMgr.numViews do
				(
					renderView = batchRenderMgr.getView v
					renderView.outputFilename = fileLocation_edittext.text + "\\" + renderView.name + outputFileType_drp.selected 
				)
			)
		)
		
		on browseAdditionalFileLocation_btn pressed do
		(
			savePath = getSavePath caption:"Pick render location..." initialDir:newAdditionalFileLocation_edittext.text
			if( savePath != undefined ) then
			(
				newAdditionalFileLocation_edittext.text = savePath
			)
		)

		on addAdditionalFileLocation_btn pressed do
		(
			tempList = #()
			if( additionalFileLocations_mlb.items.count > 0 ) then
				tempList = copy additionalFileLocations_mlb.items #noMap
			appendIfUnique tempList newAdditionalFileLocation_edittext.text
			additionalFileLocations_mlb.items = tempList
		)
		
		on batchRenderList_lv ColumnClick e do (
		)
		
		on batchRenderList_lv ItemSelectionChanged e do (
			batchRenderRenameError_label.text = ""
			if( batchRenderList_lv.SelectedItems.count == 0) then
			(
				batchRenderName_edittext.text = ""
				batchRenderName_edittext.enabled = false
				overridePresets_chk.enabled = false

				overridePresets_chk.checked = false

				width_spn.enabled = false
				height_spn.enabled = false
				startFrame_spn.enabled = false
				endFrame_spn.enabled = false
				
				width_spn.value = renderWidth
				height_spn.value = renderHeight
				
				if( rendTimeType == 1) then
				(
					startFrame_spn.value = currentTime
					endFrame_spn.value = currentTime
				)
				else if( rendTimeType == 2) then
				(
					startFrame_spn.value = animationRange.start
					endFrame_spn.value = animationRange.end
				)
				else
				(
					startFrame_spn.value = rendStart
					endFrame_spn.value = rendEnd
				)
			)
			else if(batchRenderList_lv.SelectedItems.count >= 1) then
			(
				if( batchRenderList_lv.SelectedItems.count == 1 ) then
				(
					batchRenderName_edittext.text = batchRenderList_lv.SelectedItems.Item[0].text
					batchRenderName_edittext.enabled = true
				)
				else
				(
					batchRenderName_edittext.text = "(multiple items selected)"
					batchRenderName_edittext.enabled = false
				)
				
				overridePresets_chk.enabled = true
				
				currentTriState = -1	-- -1 Represents uninitialized
				for s = 0 to batchRenderList_lv.SelectedItems.count - 1 do
				(
					selectedRender = batchRenderMgr.GetView (batchRenderList_lv.SelectedItems.Item[s].index + 1)
					if(currentTriState == -1) then
					(
						if(selectedRender.overridePreset) then
							currentTriState=1
						else
							currentTriState=0
					)
					else
					(
						if(selectedRender.overridePreset) then
						(
							if(currentTriState != 1) then
								currentTriState = 2
						)
						else
						(
							if(currentTriState != 0) then
								currentTriState = 2
						)
					)
				)
				overridePresets_chk.triState = currentTriState
				
				if( currentTriState == 1 or currentTriState == 2) then
				(
					width_spn.enabled = true
					height_spn.enabled = true
					startFrame_spn.enabled = true
					endFrame_spn.enabled = true

					sharedWidth = true
					sharedHeight = true
					sharedStartFrame = true
					sharedEndFrame = true

					firstSelectedRender = batchRenderMgr.GetView (batchRenderList_lv.SelectedItems.Item[0].index + 1)
					
					for s = 0 to batchRenderList_lv.SelectedItems.count - 1 do
					(
						currentRenderView = batchRenderMgr.GetView (batchRenderList_lv.SelectedItems.Item[s].index + 1)
						if( firstSelectedRender.width != currentRenderView.width or currentRenderView.overridePreset == false ) then
							sharedWidth = false
						if( firstSelectedRender.height != currentRenderView.height or currentRenderView.overridePreset == false ) then
							sharedHeight = false
						if( firstSelectedRender.startFrame != currentRenderView.startFrame or currentRenderView.overridePreset == false ) then
							sharedStartFrame = false
						if( firstSelectedRender.endFrame != currentRenderView.endFrame or currentRenderView.overridePreset == false ) then
							sharedEndFrame = false
					)
					
					if( sharedWidth ) then
					(
						width_spn.value = firstSelectedRender.width
					)
					else
						width_spn.Indeterminate = true
				)
				else
				(
					width_spn.enabled = false
					height_spn.enabled = false
					startFrame_spn.enabled = false
					endFrame_spn.enabled = false

					width_spn.value = renderWidth
					height_spn.value = renderHeight
					
					if( rendTimeType == 1) then
					(
						startFrame_spn.value = currentTime
						endFrame_spn.value = currentTime
					)
					else if( rendTimeType == 2) then
					(
						startFrame_spn.value = animationRange.start
						endFrame_spn.value = animationRange.end
					)
					else
					(
						startFrame_spn.value = rendStart
						endFrame_spn.value = rendEnd
					)
				)
			)
		)
		
		on batchRenderList_lv ItemChecked e do (
			if((e.item.index + 1) <= batchRenderMgr.numViews) then
				(batchRenderMgr.getView (e.item.index + 1)).enabled = e.item.checked
		)
		
		on batchRenderName_edittext changed newText do
		(
			batchRenderRenameError_label.text = ""
			if (batchRenderMgr.FindView newText == 0) then
			(
				(batchRenderMgr.GetView (batchRenderList_lv.SelectedItems.Item[0].index + 1)).name = newText
				updateSelectedItemDisplays batchrenderwizard_rollout
			)
			else if( batchRenderMgr.FindView newText != (batchRenderList_lv.SelectedItems.Item[0].index + 1) ) then
			(
				batchRenderRenameError_label.text = "Scene State with the same name already exists"
			)
		)

		on overridePresets_chk changed newChecked do
		(
			for s = 0 to batchRenderList_lv.SelectedItems.count - 1 do
			(
				(batchRenderMgr.GetView (batchRenderList_lv.SelectedItems.Item[s].index + 1)).overridePreset = newChecked
			)
			
			width_spn.enabled = newChecked
			height_spn.enabled = newChecked
			startFrame_spn.enabled = newChecked
			endFrame_spn.enabled = newChecked
			
			updateSelectedItemDisplays batchrenderwizard_rollout
		)
		
		on width_spn changed newValue do
		(
			for s = 0 to batchRenderList_lv.SelectedItems.count - 1 do
			(
				renderView = batchRenderMgr.GetView (batchRenderList_lv.SelectedItems.Item[s].index + 1)
				renderView.overridePreset = true
				renderView.width = newValue
			)
			overridePresets_chk.checked = true

			updateSelectedItemDisplays batchrenderwizard_rollout
		)

		on height_spn changed newValue do
		(
			for s = 0 to batchRenderList_lv.SelectedItems.count - 1 do
			(
				(batchRenderMgr.GetView (batchRenderList_lv.SelectedItems.Item[s].index + 1)).height = newValue
			)
			updateSelectedItemDisplays batchrenderwizard_rollout
		)

		on startFrame_spn changed newValue do
		(
			for s = 0 to batchRenderList_lv.SelectedItems.count - 1 do
			(
				renderView = batchRenderMgr.GetView (batchRenderList_lv.SelectedItems.Item[s].index + 1)
				renderView.startFrame = newValue
				if( renderView.endFrame < newValue ) then
					renderView.endFrame = newValue
			)
			updateSelectedItemDisplays batchrenderwizard_rollout
		)

		on endFrame_spn changed newValue do
		(
			for s = 0 to batchRenderList_lv.SelectedItems.count - 1 do
			(
				renderView = batchRenderMgr.GetView (batchRenderList_lv.SelectedItems.Item[s].index + 1)
				renderView.endFrame = newValue
				if( renderView.startFrame > newValue ) then
					renderView.startFrame = newValue
			)
			updateSelectedItemDisplays batchrenderwizard_rollout
		)
		
		on batchrenderwizard_rollout resized newSize do
		(
			if( newSize.x < 800 ) then
				batchrenderwizard_rollout.width = 800
			if( newSize.y < 400 ) then
				batchrenderwizard_rollout.height = 400
			
			oldHeight = batchRenderList_lv.height
			
			batchRenderList_lv.width = batchrenderwizard_rollout.width - 28
			batchRenderList_lv.height = batchrenderwizard_rollout.height - (800 - 250)

			heightDelta = batchRenderList_lv.height - oldHeight
			
			for c in batchrenderwizard_rollout.controls do
			(
				if ( c != batchRenderList_lv and c.pos.y > batchRenderList_lv.pos.y ) then
				(
					if( isKindOf c GroupStartControl ) then
					(
					)
					else
					(
						c.pos.y += heightDelta
					)
				)
			)
		)
	)

	try( DestroyDialog batchrenderwizard_rollout ) catch ()
	wizardDialog = CreateDialog batchrenderwizard_rollout 800 800 style:#(#style_titlebar, #style_sysmenu, #style_resizing)
