	-- Sorter copied from http://forums.cgsociety.org/showpost.php?p=6001914&postcount=349
	if gListViewItemComparerAssembly == undefined then
    (
    	global gListViewItemComparerAssembly
    )
    
    fn gNewListViewItemComparer forceRecompile:false =
    (
    	if (forceRecompile or 
    		(classof gListViewItemComparerAssembly) != dotNetObject or 
    		((gListViewItemComparerAssembly.GetType()).ToString()) != "System.Reflection.Assembly") do
    	(
    		sb =  "using System;\n"
    		sb += "using System.Windows.Forms;\n"
    		sb += "using System.Collections;\n"
    		sb += "class gpgxListViewItemComparer : IComparer\n"
    		sb += "{\n"
    		sb += "	public int column;\n"
    		sb += "	public bool reversed;\n"
    		sb += "	public gpgxListViewItemComparer()\n"
    		sb += "	{\n"
    		sb += "		column = 0;\n"
    		sb += "		reversed = false;\n"
    		sb += "	}\n"
    		sb += "	public gpgxListViewItemComparer(int col, bool rev)\n"
    		sb += "	{\n"
    		sb += "		column = col;\n"
    		sb += "		reversed = rev;\n"
    		sb += "	}\n"
    		sb += "	public int Compare(object x, object y)\n"
    		sb += "	{\n"
    		sb += "		int ret = 0;\n"
    		sb += "		ListViewItem lvx = (ListViewItem)x;\n"
    		sb += "		ListViewItem lvy = (ListViewItem)y;\n"
    		sb += "		if (column >= 0 && column < lvx.SubItems.Count && column < lvy.SubItems.Count)\n"
    		sb += "			ret = String.Compare(lvx.SubItems[column].Text, lvy.SubItems[column].Text);\n"
    		sb += "		return reversed ? -ret : ret;\n"
    		sb += "	}\n"
    		sb += "}\n"
    
    		csharpProvider = dotnetobject "Microsoft.CSharp.CSharpCodeProvider"
    		compilerParams = dotnetobject "System.CodeDom.Compiler.CompilerParameters"
    		
    		-- Need to add referenced assemblies that the code snippet is 'using'
    		compilerParams.ReferencedAssemblies.Add("System.dll");
    		compilerParams.ReferencedAssemblies.Add("System.Windows.Forms.dll");
    		
    		compilerParams.GenerateInMemory = true
    		compilerResults = csharpProvider.CompileAssemblyFromSource compilerParams #(sb)
    		
    		if (compilerResults.Errors.Count > 0 ) then
    		(
    			errs = stringstream ""
    			for i = 0 to (compilerResults.Errors.Count-1) do
    			(
    				err = compilerResults.Errors.Item[i]
    				format "Error:% Line:% Column:% %\n" err.ErrorNumber err.Line \											  
    													 err.Column err.ErrorText to:errs 
    			)
    			MessageBox (errs as string) title: "Errors encountered while compiling C# code"
    			format "%\n" errs
    			gListViewItemComparerAssembly = undefined
    			return undefined
    		)
    		else
    		(
    			gListViewItemComparerAssembly = compilerResults.CompiledAssembly
    		)
    	)
    	gListViewItemComparerAssembly.CreateInstance "gpgxListViewItemComparer"
    )
	
	rollout batchrenderwizard_rollout "Batch Render Wizard"
	(
		fn arrayToFileProperty sourceStringArray targetFilePropertyName =
		(
			propertyString = ""
			separator = ";"
			for i in sourceStringArray do
			(
				propertyString = propertyString + i + separator
			)
			
			fileProperties.addProperty #custom targetFilePropertyName propertyString
		)
		
		fn filePropertyToArray sourceFilePropertyName =
		(
			separator = ";"
			
			returnItems = #()
			filePropertyIndex = fileProperties.findProperty #custom sourceFilePropertyName
			if ( filePropertyIndex  > 0 ) then
			(
				returnItems = filterString (fileProperties.getPropertyValue #custom filePropertyIndex) separator
			)
			
			return returnItems
		)
		
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
			columWidth_def = #(300,100,150,80,70)
			for i = 1 to layout_def.count do
			(
				lv.Columns.add layout_def[i] columWidth_def[i] --add column with name
			)
			lv.CheckBoxes = true
			lv.HideSelection = false
			
			--lv.ListViewItemSorter = gNewListViewItemComparer()
		)

		fn updateSelectedItemDisplays mainRollout =
		(
			--redrawIndexStart = mainRollout.batchRenderList_lv.Items.count
			--redrawIndexEnd = -1
			redrawIndexStart=0
			redrawIndexEnd = mainRollout.batchRenderList_lv.Items.count - 1
			for s = 0 to mainRollout.batchRenderList_lv.SelectedItems.count - 1 do
			(
				listItem = mainRollout.batchRenderList_lv.SelectedItems.Item[s]
				if ( batchRenderMgr.FindView listItem.text ) > 0 then
				(
					--renderView = batchRenderMgr.getView (listItem.Index +1)
					renderView = batchRenderMgr.getView (batchRenderMgr.FindView listItem.text)
					
					if( mainRollout.batchRenderList_lv.SelectedItems.count == 1 ) then
						listItem.text = renderView.name

					renderViewCameraName = ""
					if renderView.camera != undefined then
						renderViewCameraName = renderView.camera.name
					listItem.subItems.Item[1].text = renderViewCameraName
					listItem.subItems.Item[2].text = renderView.sceneStateName
					
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

					if( redrawIndexStart > listItem.index ) then
						redrawIndexStart = listItem.index

					if( redrawIndexEnd < listItem.index ) then
						redrawIndexEnd = listItem.index
				)
				else
				(
					print ("Cannot find render view " + listItem.text)
				)
			)
			
			mainRollout.batchRenderList_lv.RedrawItems redrawIndexStart redrawIndexEnd false
		)
		
		fn updateEnabledViews mainRollout =
		(
			enabledViews = 0
			for v = 1 to batchRenderMgr.numViews do
			(
				renderView = batchRenderMgr.getView v
				if renderView.enabled then
					enabledViews += 1
			)
			mainRollout.startBatchRenderList_button.caption = "Start Batch Render (" + enabledViews as string + ")"
		)

		fn updateSavedAdditionalLocations locationListBox =
		(
			arrayToFileProperty (arrayToString locationListBox.items) "BatchRenderAdditionalCopyLocations" 
		)
		
		fn loadSavedAdditionalLocations locationListBox =
		(
			locationListBox.items = filePropertyToArray "BatchRenderAdditionalCopyLocations"
		)
				
		fn addRenderViewLocationHistory historyCmbControl newLocation =
		(
			historyItems = filePropertyToArray "RenderViewLocationHistory"
			appendIfUnique historyItems newLocation
			arrayToFileProperty historyItems "RenderViewLocationHistory"

			historyCmbControl.items = historyItems
			historyCmbControl.selection = findItem historyItems newLocation
		)
		
		fn removeRenderViewLocationFromHistory historyCmbControl locationToDelete =
		(
			historyItems = filePropertyToArray "RenderViewLocationHistory"
			locationToDeleteIndex = findItem historyItems locationToDelete
			if( locationToDeleteIndex > 0 ) then
			(
				deleteItem historyItems locationToDeleteIndex
				arrayToFileProperty historyItems "RenderViewLocationHistory"
			)

			historyCmbControl.items = historyItems
		)
		
		multilistbox sceneStateList_mlb "Scene State List" width:200 height:10 across:2 align:#left
		multilistbox cameraList_mlb "Camera List" width:200 height:10 align:#left
		
		edittext nameConvention_edittext "Naming Convention" text:"%scenestate %camera" width:400 across:3 offset:[0,10]
		edittext nextRunningNumber_edittext "Running Number" text:"001" width:130 offset:[150,10]
		button generatePermutations_button "Add Permutations" width:150 offset:[0,10]
		
		label nameConventionHints "%scenestate - Scene state name\n%camera - Camera name\n%# - Running number" align:#left height:42

		dotNetControl batchRenderList_lv "System.Windows.Forms.ListView" height:250 align:#center CheckBoxes:true offset:[0,10]
		checkbox applySelectedRenderView_chk "Apply selected scene state and camera to current viewport" checked:true

		button selectAllRenderList_button "Select All" width:150 across:3
		button duplicateBatchRenderView_button "Duplicate" width:150
		button deleteBatchRenderView_button "Delete" width:150
		
		group "Batch Render Settings"	
		(
			edittext batchRenderName_edittext "Batch Render Name" enabled:false across:2
			label batchRenderRenameError_label "" align:#left offset:[5,0]
			
			dropdownlist camera_drp "Camera" width:200 align:#left across:2 
			dropdownlist scenestate_drp "SceneState" width:200 align:#left offset:[-150,0]

			checkbox overridePresets_chk "Override Presets"  enabled:false
			spinner width_spn "Width" range:[1,8192,renderWidth] width:70 type:#integer align:#left across:2 enabled:false
			spinner height_spn "Height" range:[1,8192,renderHeight] width:70 type:#integer align:#left enabled:false offset:[-280,0]
			
			spinner startFrame_spn "Start Frame" range:[-8192,8192,rendStart] width:90 type:#integer align:#left across:2 enabled:false
			spinner endFrame_spn "End Frame" range:[-8192,8192,rendEnd] width:90 type:#integer align:#left enabled:false offset:[-230,0]
		)

		edittext fileLocation_edittext "Render Output Location" text:(maxFilePath + "RENDERS\\") width:520 across:4 offset:[0,0]
		button fileLocation_browse "..." width:30 pos:[540,fileLocation_edittext.pos.y]
		dropdownlist outputFileType_drp items:#(".png",".jpg") width:50 align:#left pos:[580,fileLocation_edittext.pos.y]
		
		button startBatchRenderList_button "Start Batch Render" width:150 height:150 align:#right
		
		dropdownlist fileLocationHistory_cmb width:405 offset:[118,-130] across:2
		button removeFromFileLocationHistory_btn "-" width:20 pos:[540,fileLocationHistory_cmb.pos.y]

		edittext newAdditionalFileLocation_edittext "New Additional Location" width:520 offset:[0,10]
		button browseAdditionalFileLocation_btn "..." width:30 pos:[540,newAdditionalFileLocation_edittext.pos.y]
		button addAdditionalFileLocation_btn "+" width:20 pos:[580,newAdditionalFileLocation_edittext.pos.y] tooltip:"Add new output location"

		multilistbox additionalFileLocations_mlb "Additional Locations for Copies" width:480 height:5 offset:[0,-5]
		button removeAdditionalFileLocation_btn "-" width:20 offset:[110,-75]
		
		on batchrenderwizard_rollout open do
		(
			sceneStateNames = #()
			for s =1 to scenestatemgr.getCount() do
			(
				append sceneStateNames (scenestatemgr.GetSceneState s)
			)
			sort sceneStateNames
			sceneStateList_mlb.items = sceneStateNames
			sceneStateDropdown = #("")
			join sceneStateDropdown sceneStateNames
			scenestate_drp.items = sceneStateDropdown

			cameraNames = #()
			for c in cameras do
			(
				if (not (isKindOf c Targetobject)) then
				(
					append cameraNames c.name
				)
			)
			sort cameraNames
			cameraList_mlb.items = cameraNames
			cameraDropdown = #("")
			join cameraDropdown cameraNames
			camera_drp.items = cameraDropdown
			
			initListView batchRenderList_lv
			refreshListView batchRenderList_lv
			
			if batchRenderMgr.numViews >= 1 then
			(
				fileLocation_edittext.text = getFilenamePath (batchRenderMgr.getView 1).outputFilename
			)
			
			renderViewNamingConventionIndex = fileProperties.findProperty #custom "RenderViewNamingConvention"
			if renderViewNamingConventionIndex == 0 then
			(
				fileProperties.addProperty #custom "RenderViewNamingConvention" "%scenestate %camera"
				renderViewNamingConventionIndex = fileProperties.findProperty #custom "RenderViewNamingConvention"
			)

			renderNamingConvention = fileProperties.getPropertyValue #custom renderViewNamingConventionIndex
			nameConvention_edittext.text = renderNamingConvention

			updateEnabledViews batchrenderwizard_rollout

			addRenderViewLocationHistory fileLocationHistory_cmb fileLocation_edittext.text

			loadSavedAdditionalLocations additionalFileLocations_mlb
		)
		

		on generatePermutations_button pressed do
		(
			for c in cameraList_mlb.selection do
			(
				for s in sceneStateList_mlb.selection do
				(
					renderViewCamera = getNodeByName cameraList_mlb.items[c]
					batchRenderMgr.CreateView renderViewCamera
					
					renderView = batchRenderMgr.GetView batchRenderMgr.numViews
					renderView.sceneStateName = sceneStateList_mlb.items[s]
					
					renderViewName = nameConvention_edittext.text
					renderViewName = substituteString renderViewName "%scenestate" sceneStateList_mlb.items[s]
					renderViewName = substituteString renderViewName "%camera" renderViewCamera.name

					if( findString renderViewName "%#" != undefined ) then
					(
						trimmedString = trimLeft (trimRight nextRunningNumber_edittext.text)
						
						-- TODO Validate string first
						
						renderViewName = substituteString renderViewName "%#" trimmedString

						expectedLength = trimmedString.count
						currentRunningNumber = trimmedString as integer
						currentRunningNumber += 1
						nextRunningNumber = currentRunningNumber as string
						
						while nextRunningNumber.count < expectedLength do
						(
							nextRunningNumber = "0" + nextRunningNumber
						)
						
						nextRunningNumber_edittext.text = nextRunningNumber
					)
					
					print (batchRenderMgr.findView renderViewName )
					if(batchRenderMgr.findView renderViewName <=0) then
						renderView.name = renderViewName
					else
						print renderViewName + " already exists. Skipping file rename."
					
					renderView.outputFilename = fileLocation_edittext.text + "\\" + renderView.name + outputFileType_drp.selected 
				)
			)
			refreshListView batchRenderList_lv
			updateEnabledViews batchrenderwizard_rollout
		)
		
		on duplicateBatchRenderView_button pressed do
		(
			for s = 1 to batchRenderList_lv.SelectedItems.count do
			(
				batchRenderMgr.DuplicateView (batchRenderMgr.findView batchRenderList_lv.SelectedItems.item[s-1].text)
			)
			
			refreshListView batchRenderList_lv
			updateEnabledViews batchrenderwizard_rollout
		)
		
		on deleteBatchRenderView_button pressed do
		(
			for s = 1 to batchRenderList_lv.SelectedItems.count do
			(
				batchRenderMgr.DeleteView (batchRenderMgr.findView batchRenderList_lv.SelectedItems.item[s-1].text)
			)
			
			refreshListView batchRenderList_lv
			updateEnabledViews batchrenderwizard_rollout
		)
		
		on selectAllRenderList_button pressed do
		(
			for i = 0 to batchRenderList_lv.Items.count - 1 do
			(
				batchRenderList_lv.Items.Item[i].selected = true
			)
			setFocus batchRenderList_lv
		)
		
		on startBatchRenderList_button pressed do
		(
			addRenderViewLocationHistory fileLocationHistory_cmb fileLocation_edittext.text

			batchRenderMgr.Render()
			
			-- Copy to destination folders
			copyCommand = "copy "
			
			-- Highlight the first file that gets rendered
			firstEnabledViewIndex = -1
			outputFiles = #()
			for v = 1 to batchRenderMgr.numViews do
			(
				renderView = batchRenderMgr.getView v
				if( renderView.enabled ) then
				(
					if( firstEnabledViewIndex == -1) then
						firstEnabledViewIndex = v
				
					startFrame = currentTime
					endFrame = currentTime
					multipleFrames = false
					
					if( renderView.overridePreset == true ) then
					(
						startFrame = renderView.startFrame
						endFrame = renderView.endFrame
						multipleFrames = true
					)
					else
					(
						if( rendTimeType == 2) then
						(
							startFrame = animationRange.start
							endFrame = animationRange.end
							multipleFrames = true
						)
						else if( rendTimeType == 3 ) then
						(
							startFrame = rendStart
							endFrame = rendEnd
							multipleFrames = true
						)
					)
					
					if ( not multipleFrames ) then
					(
						-- Make sure all files exist first
						if doesFileExist renderView.outputFilename == true then
						(
							append outputFiles ("\"" + renderView.outputFilename + "\"")
						)
					)
					else
					(
						for f = (startFrame as integer)/TicksPerFrame to (endFrame as integer)/TicksPerFrame do
						(
							
							expectedLength = 4
							frameNumber = f as string
							
							while frameNumber.count < expectedLength do
							(
								frameNumber = "0" + frameNumber
							)

							filenameToCopy = (getFilenamePath renderView.outputFilename) + (getFilenameFile renderView.outputFilename) + frameNumber + (getFilenameType renderView.outputFilename)
							
							-- Make sure all files exist first
							if doesFileExist filenameToCopy == true then
							(
								append outputFiles ("\"" + filenameToCopy + "\"")
							)
						)
					)
				)
			)
			
			for i in additionalFileLocations_mlb.items do
			(
				destination = " \"" + i + "\""
				-- Make sure i is a valid folder destination
				for f in outputFiles do
				(
					print (copyCommand + f + destination)
					DOSCommand (copyCommand + f + destination)
				)
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
		
		on fileLocationHistory_cmb selected newItemIndex do
		(
			if (fileLocationHistory_cmb.selected != undefined ) then
				fileLocation_edittext.text = fileLocationHistory_cmb.selected
		)
		
		on removeFromFileLocationHistory_btn pressed do
		(
			if( fileLocationHistory_cmb.selection > 0 ) then
				removeRenderViewLocationFromHistory fileLocationHistory_cmb fileLocationHistory_cmb.selected
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
			appendIfUnique tempList (newAdditionalFileLocation_edittext.text)
			additionalFileLocations_mlb.items = tempList
			
			newAdditionalFileLocation_edittext.text = ""
			
			updateSavedAdditionalLocations additionalFileLocations_mlb
		)

		on removeAdditionalFileLocation_btn pressed do
		(
			itemsToRemove = #()
			for s in additionalFileLocations_mlb.selection do
			(
				append itemsToRemove additionalFileLocations_mlb.items[s]
			)
			print itemsToRemove
			
			itemList = copy additionalFileLocations_mlb.items #noMap
			for i in itemsToRemove do
			(
				itemIndex = findItem itemList i
				if( itemIndex != 0 ) then		-- should never happen!
					deleteItem itemList itemIndex
				else
					print "Unable to remove item: " + i
			)
			additionalFileLocations_mlb.items = itemList
		)
		
		on batchRenderList_lv ColumnClick e do (
			newSorter = false
			if( batchRenderList_lv.ListViewItemSorter == undefined ) then
			(
				batchRenderList_lv.ListViewItemSorter = gNewListViewItemComparer()
				batchRenderList_lv.ListViewItemSorter.Reversed = false

				newSorter = true
			)
			
    		if (batchRenderList_lv.ListViewItemSorter.Column != e.Column or newSorter) then
    		(
    			batchRenderList_lv.ListViewItemSorter.Column = e.Column
    			batchRenderList_lv.ListViewItemSorter.Reversed = false
				batchRenderList_lv.Sort()
    		)
    		else
    		(
				if( batchRenderList_lv.ListViewItemSorter.Reversed == false ) then
				(
					batchRenderList_lv.ListViewItemSorter.Reversed = true
					batchRenderList_lv.Sort()
				)
				else
				(
					batchRenderList_lv.ListViewItemSorter = undefined
					refreshListView batchRenderList_lv
				)
    		)
		)
		
		on batchRenderList_lv ItemSelectionChanged e do (
			batchRenderRenameError_label.text = ""
			if( batchRenderList_lv.SelectedItems.count == 0) then
			(
				batchRenderName_edittext.text = ""
				batchRenderName_edittext.enabled = false
				
				sceneState_drp.selection = 1
				camera_drp.selection = 1
				
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
				--firstSelectedRender = batchRenderMgr.GetView (batchRenderList_lv.SelectedItems.Item[0].index + 1)
				firstSelectedRender = batchRenderMgr.GetView (batchRenderMgr.FindView batchRenderList_lv.SelectedItems.Item[0].text)

				if( batchRenderList_lv.SelectedItems.count == 1 ) then
				(
					batchRenderName_edittext.text = firstSelectedRender.name
					batchRenderName_edittext.enabled = true
					
					if applySelectedRenderView_chk.checked then
					(
						if (sceneStateMgr.FindSceneState firstSelectedRender.sceneStateName) > 0 then
							sceneStateMgr.restore firstSelectedRender.sceneStateName (sceneStateMgr.GetParts firstSelectedRender.sceneStateName)
						
						if (firstSelectedRender.camera != undefined ) then
							viewport.setCamera firstSelectedRender.camera
					)
				)
				else
				(
					batchRenderName_edittext.text = "(multiple items selected)"
					batchRenderName_edittext.enabled = false
				)

				sharedSceneState = true
				sharedCamera = true
				for s = 0 to batchRenderList_lv.SelectedItems.count - 1 do
				(
					--currentRenderView = batchRenderMgr.GetView (batchRenderList_lv.SelectedItems.Item[s].index + 1)
					currentRenderView = batchRenderMgr.GetView (batchRenderMgr.FindView batchRenderList_lv.SelectedItems.Item[s].text)
					if( firstSelectedRender.sceneStateName != currentRenderView.sceneStateName ) then
						sharedSceneState = false
					if( firstSelectedRender.camera != currentRenderView.camera ) then
						sharedCamera = false
				)
				
				if( sharedCamera ) then
				(
					sceneState_drp.selection = finditem sceneState_drp.items firstSelectedRender.sceneStateName
				)
				else
					sceneState_drp.selection = 0

				if( sharedCamera and firstSelectedRender.camera != undefined) then
				(
					camera_drp.selection = finditem camera_drp.items firstSelectedRender.camera.name
				)
				else
					camera_drp.selection = 0
				
				overridePresets_chk.enabled = true
				
				currentTriState = -1	-- -1 Represents uninitialized
				for s = 0 to batchRenderList_lv.SelectedItems.count - 1 do
				(
					--selectedRender = batchRenderMgr.GetView (batchRenderList_lv.SelectedItems.Item[s].index + 1)
					selectedRender = batchRenderMgr.GetView (batchRenderMgr.FindView batchRenderList_lv.SelectedItems.Item[s].text)
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

					
					for s = 0 to batchRenderList_lv.SelectedItems.count - 1 do
					(
						--currentRenderView = batchRenderMgr.GetView (batchRenderList_lv.SelectedItems.Item[s].index + 1)
						currentRenderView = batchRenderMgr.GetView (batchRenderMgr.FindView batchRenderList_lv.SelectedItems.Item[s].text)
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
					
					if( sharedHeight ) then
					(
						height_spn.value = firstSelectedRender.height
					)
					else
						height_spn.Indeterminate = true

					if( sharedStartFrame ) then
					(
						startFrame_spn.value = firstSelectedRender.startFrame
					)
					else
						startFrame_spn.Indeterminate = true

					if( sharedEndFrame ) then
					(
						endFrame_spn.value = firstSelectedRender.endFrame
					)
					else
						endFrame_spn.Indeterminate = true
					
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
			--if((e.item.index + 1) <= batchRenderMgr.numViews) then
				--(batchRenderMgr.getView (e.item.index + 1)).enabled = e.item.checked

			(batchRenderMgr.getView (batchRenderMgr.findView e.item.text)).enabled = e.item.checked
			
			updateEnabledViews batchrenderwizard_rollout
		)
		
		on nameConvention_edittext changed newText do
		(
			fileProperties.addProperty #custom "RenderViewNamingConvention" newText
		)
		
		on batchRenderName_edittext changed newText do
		(
			batchRenderRenameError_label.text = ""
			if (batchRenderMgr.FindView newText == 0) then
			(
				--renderView = batchRenderMgr.GetView (batchRenderList_lv.SelectedItems.Item[0].index + 1)
				renderView = batchRenderMgr.GetView (batchRenderMgr.FindView batchRenderList_lv.SelectedItems.Item[0].text)
				renderView.name = newText
				batchRenderList_lv.SelectedItems.Item[0].text = newText
				renderView.outputFilename = substituteString renderView.outputFilename (getFilenameFile renderView.outputFilename) renderView.name
				
				--updateSelectedItemDisplays batchrenderwizard_rollout
			)
			else if( batchRenderMgr.FindView newText != (batchRenderList_lv.SelectedItems.Item[0].index + 1) ) then
			(
				batchRenderRenameError_label.text = "Render View with the same name already exists"
			)
		)
		
		on sceneState_drp selected newSelectionIndex do
		(
			if( (stricmp sceneState_drp.selected "") != 0  ) then
			(
				if (sceneStateMgr.findSceneState sceneState_drp.items[newSelectionIndex]) > 0 then
				(
					for s = 0 to batchRenderList_lv.SelectedItems.count - 1 do
					(
						(batchRenderMgr.GetView (batchRenderMgr.FindView batchRenderList_lv.SelectedItems.Item[s].text)).sceneStateName = sceneState_drp.items[newSelectionIndex]
					)
					
					if applySelectedRenderView_chk.checked then
						sceneStateMgr.restore sceneState_drp.items[newSelectionIndex] (sceneStateMgr.GetParts sceneState_drp.items[newSelectionIndex])
					
					updateSelectedItemDisplays batchrenderwizard_rollout
				)
				else
				(
					print "Cannot find Scene State: " + sceneState_drp.items[newSelectionIndex]
				)
			)
		)
		
		on camera_drp selected newSelectionIndex do
		(
			if( (stricmp camera_drp.selected "") != 0 ) then
			(
				selectedCamera = getNodeByName camera_drp.items[newSelectionIndex]
				if selectedCamera != undefined then
				(
					for s = 0 to batchRenderList_lv.SelectedItems.count - 1 do
					(
						(batchRenderMgr.GetView (batchRenderMgr.FindView batchRenderList_lv.SelectedItems.Item[s].text)).camera = selectedCamera
					)
					
					if applySelectedRenderView_chk.checked then
						viewport.setCamera selectedCamera
				
					updateSelectedItemDisplays batchrenderwizard_rollout
				)
				else
				(
					print "Cannot find Camera: " + camera_drp.items[newSelectionIndex]
				)
			)
		)
		
		on overridePresets_chk changed newChecked do
		(
			for s = 0 to batchRenderList_lv.SelectedItems.count - 1 do
			(
				(batchRenderMgr.GetView (batchRenderMgr.FindView batchRenderList_lv.SelectedItems.Item[s].text)).overridePreset = newChecked
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
				renderView = batchRenderMgr.GetView (batchRenderMgr.FindView batchRenderList_lv.SelectedItems.Item[s].text)
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
				(batchRenderMgr.GetView (batchRenderMgr.FindView batchRenderList_lv.SelectedItems.Item[s].text)).height = newValue
			)
			updateSelectedItemDisplays batchrenderwizard_rollout
		)

		on startFrame_spn changed newValue do
		(
			for s = 0 to batchRenderList_lv.SelectedItems.count - 1 do
			(
				renderView = batchRenderMgr.GetView (batchRenderMgr.FindView batchRenderList_lv.SelectedItems.Item[s].text)
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
				renderView = batchRenderMgr.GetView (batchRenderMgr.FindView batchRenderList_lv.SelectedItems.Item[s].text)
				renderView.endFrame = newValue
				if( renderView.startFrame > newValue ) then
					renderView.startFrame = newValue
			)
			updateSelectedItemDisplays batchrenderwizard_rollout
		)
		
		on batchrenderwizard_rollout resized newSize do
		(
			minimumWidth = 800
			minimumHeight = 400
			standardHeight = 890
			
			if( newSize.x < minimumWidth ) then
				batchrenderwizard_rollout.width = minimumWidth
			if( newSize.y < minimumHeight ) then
				batchrenderwizard_rollout.height = minimumHeight
			
			oldHeight = batchRenderList_lv.height
			
			batchRenderList_lv.width = batchrenderwizard_rollout.width - 28
			batchRenderList_lv.height = batchrenderwizard_rollout.height - (standardHeight - 250)

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
	wizardDialog = CreateDialog batchrenderwizard_rollout 800 890 style:#(#style_titlebar, #style_sysmenu, #style_resizing)
