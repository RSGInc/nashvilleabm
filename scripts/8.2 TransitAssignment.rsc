//======================================================================================
//**************************************
//*      					Part 8  					   	        *
//*		               Transit Assignment 								 *
//**************************************

// Edited by: 
// nagendra.dhakar@rsginc.com
// Date: 10/27/2014 

// Changes:
// assignment is performed by time period and sub-modes only

// STEP 8; Perform transit assignment
Macro "TransitAssignment"(Args)
    shared OutDir, Modes, AccessAssgnModes, route_system, MovementTable, Purposes, PurposePeriod, Periods // input files
    shared runtime // output files
    
    //Periods={"AM","MD","PM","OP"} - for four time periods
    //Periods = {"PK","OP"}
    
    RunMacro("TCB Init")

    RunMacro("SetTransitParameters",Args)
    RunMacro("Fill Transit Airport Trips", Args)

// STEP 8.1: Perform Transit Assignment

    for iper=1 to Periods.length do
        for iacc=1 to AccessAssgnModes.length do
            for imode=1 to Modes.length do
                AccessNet="Walk"
                outtnw= OutDir + Periods[iper] + "_" + AccessNet + Modes[imode] + ".tnw"
                inmat = OutDir + Periods[iper] + "TripsByMode.mtx"

				if (imode=1 & iacc=1) then tablename="WLKLOCBUS"
				if (imode=2 & iacc=1) then tablename="WLKBRT"
				if (imode=3 & iacc=1) then tablename="WLKEXPBUS"
				if (imode=4 & iacc=1) then tablename="WLKURBRAIL"
				if (imode=5 & iacc=1) then tablename="WLKCOMRAIL"
				if (imode=1 & iacc=2) then tablename="PNRLOCBUS"
				if (imode=2 & iacc=2) then tablename="PNRBRT"
				if (imode=3 & iacc=2) then tablename="PNREXPBUS"
				if (imode=4 & iacc=2) then tablename="PNRURBRAIL"
				if (imode=5 & iacc=2) then tablename="PNRCOMRAIL"
				if (imode=1 & iacc=3) then tablename="KNRLOCBUS"
				if (imode=2 & iacc=3) then tablename="KNRBRT"
				if (imode=3 & iacc=3) then tablename="KNREXPBUS"
				if (imode=4 & iacc=3) then tablename="KNRURBRAIL"
				if (imode=5 & iacc=3) then tablename="KNRCOMRAIL"                

                Opts = null
                Opts.Input.[Transit RS] = route_system
                Opts.Input.Network = outtnw
                Opts.Input.[OD Matrix Currency] = {inmat, tablename, "Rows", "Cols"} // **TripsByMode.mtx is created in Macro "Format Assignment Inputs"
                Opts.Input.[Movement Set] = {MovementTable, "MovementTable"}
                Opts.Flag.[Do OnOff Report]=1
                Opts.Flag.[Do Aggre Report]=1
                Opts.Output.[Flow Table] = OutDir + Periods[iper]+ AccessAssgnModes[iacc] + Modes[imode] + "Flow.bin"
                Opts.Output.[Walk Flow Table] = OutDir + Periods[iper]+ AccessAssgnModes[iacc] + Modes[imode] + "WalkFlow.bin"
                Opts.Output.[Aggre Table] = OutDir + Periods[iper]+ AccessAssgnModes[iacc] + Modes[imode] + "AggreFlow.bin"
                Opts.Output.[OnOff Table] = OutDir + Periods[iper]+ AccessAssgnModes[iacc] + Modes[imode] + "OnOffFlow.bin"
                Opts.Output.[Movement Table] = OutDir + Periods[iper]+ AccessAssgnModes[iacc] + Modes[imode] + "MOV.bin"

                ret_value = RunMacro("TCB Run Procedure", 2, "Transit Assignment PF", Opts)
                if !ret_value then goto quit
            end
        end
    end

    stime=GetDateAndTime()
    WriteLine(runtime,"\n End Transit Assignment               - "+SubString(stime,1,3)+","+SubString(stime,4,7)+""+SubString(stime,20,5)+" ("+SubString(stime,12,8)+") ")
    Return(1)
quit:
	// RunMacro("TCB Closing", ret_value, True )
    stime=GetDateAndTime()
    WriteLine(runtime,"\n End Transit Assignment               - "+SubString(stime,1,3)+","+SubString(stime,4,7)+""+SubString(stime,20,5)+" ("+SubString(stime,12,8)+") ")
    Return(ret_value)
EndMacro

// STEP 9: Transit reporting
Macro "TransitReport"
    shared runtime
    RunMacro("TCB Init")

// STEP 10.1: Macro to fill the Transit Flow files with PH and PM
    ret_value = RunMacro("Fill_TASN_FLW_File",)
    if !ret_value then goto quit

// STEP 10.2: Macro to run transit summary by route - PH, PM and Boarding by purpose and access types
    ret_value = RunMacro("Rte_PH_PM",)
    if !ret_value then goto quit

    ret_value = RunMacro("Rte_boarding",)
    if !ret_value then goto quit


// STEP 10.3: Macro to output Mode Choice Statistics
    ret_value = RunMacro("TRNSTAT",)
    if !ret_value then goto quit

// STEP 10.4: Macro to output boarding summary at route- and stop-levels
    ret_value = RunMacro("Stop_Level_Summary",)
    stime=GetDateAndTime()
    WriteLine(runtime,"\n End Transit Reporting                - "+SubString(stime,1,3)+","+SubString(stime,4,7)+""+SubString(stime,20,5)+" ("+SubString(stime,12,8)+") ")
    if !ret_value then goto quit


// clean up the output folder - delete temperory files
    if (DeleteTempOutputFiles = 1) then do
        batch_ptr = OpenFile(OutDir + "deletefiles.bat", "w")
        WriteLine(batch_ptr, "REM temp files from percent walk procedure")
        WriteLine(batch_ptr, "del " + OutDir + "*buffer*")
        if (DeleteSummitFiles = 1) then do
			WriteLine(batch_ptr, "del " + OutDir + "*.fta")
        end
        WriteLine(batch_ptr, "REM temp files from the transit assignment")
        WriteLine(batch_ptr, "del " + OutDir + "*OnOffFlow.bin")
        WriteLine(batch_ptr, "del " + OutDir + "*OnOffFlow.dcb")
        WriteLine(batch_ptr, "del " + OutDir + "*MOV.bin")
        WriteLine(batch_ptr, "del " + OutDir + "*MOV.dcb")
        WriteLine(batch_ptr, "del " + OutDir + "*WalkFlow.bin")
        WriteLine(batch_ptr, "del " + OutDir + "*WalkFlow.dcb")
        WriteLine(batch_ptr, "del " + OutDir + "*AggreFlow.bin")
        WriteLine(batch_ptr, "del " + OutDir + "*AggreFlow.dcb")
        WriteLine(batch_ptr, "del " + OutDir + "*LocalFlow.bin")
        WriteLine(batch_ptr, "del " + OutDir + "*LocalFlow.dcb")
        WriteLine(batch_ptr, "del " + OutDir + "*PremiumFlow.bin")
        WriteLine(batch_ptr, "del " + OutDir + "*PremiumFlow.dcb")
        WriteLine(batch_ptr, "del " + OutDir + "*RailFlow.bin")
        WriteLine(batch_ptr, "del " + OutDir + "*RailFlow.dcb")
        CloseFile(batch_ptr)
        RunProgram(OutDir + "deletefiles.bat", )
        PutInRecycleBin(OutDir + "deletefiles.bat")
    end

quit:
    stime=GetDateAndTime()
    WriteLine(runtime,"\n End Transit Reporting                - "+SubString(stime,1,3)+","+SubString(stime,4,7)+""+SubString(stime,20,5)+" ("+SubString(stime,12,8)+") ")
    Return(ret_value)
EndMacro

// STEP 10.1: Macro to fill the Transit Flow files with PH and PM
Macro "Fill_TASN_FLW_File"
    shared OutDir, Modes, AccessAssgnModes, Periods

    nfiles=Periods.length*AccessAssgnModes.length*Modes.Length
    dim TransitFlowFile[nfiles]
    k1=1
    for iper=1 to Periods.length do
        for iacc=1 to AccessAssgnModes.length do
			for imode=1 to Modes.length do
			 TransitFlowFile[k1]=Periods[iper]+AccessAssgnModes[iacc]+Modes[imode]+"Flow.bin"     //OPWalkLocalFlow.bin
			 k1=k1+1
			end
        end
    end

	for k = 1 to TransitFlowFile.length do
		vws = GetViewNames()
		if (vws.length > 0) then do
		    for i = 1 to vws.length do
				CloseView(vws[i])
			end
		end

		view_name = OpenTable ("TASN_FLW","FFB",{OutDir + TransitFlowFile[k],})

		on notfound goto PHCalc
		GetField(view_name+".PH")
		goto skip1

PHCalc:
		strct = GetTableStructure(view_name)
		for i = 1 to strct.length do strct[i] = strct[i] + {strct[i][1]} end
		// Add the required fields
		new_struct = strct + {{"PH", "Real", 10, 4, "False",,,,,,, null},
					  {"PM", "Real", 10, 4, "False",,,,,,, null}}

		ModifyTable(view_name, new_struct)
skip1:
	    RunMacro("TCB Init")
	    vws = GetViewNames()
	    for i = 1 to vws.length do CloseView(vws[i]) end

	    view_name = OpenTable ("TASN_FLW","FFB",{OutDir + TransitFlowFile[k],})

	    Opts = null
	    Opts.Input.[Dataview Set] = {OutDir + TransitFlowFile[k], "TASN_FLW"}
	    Opts.Global.Fields = {view_name + ".PH", view_name + ".PM"}
	    Opts.Global.Method = "Formula"
	    Opts.Global.Parameter = {"(BaseIVTT/60)*TransitFlow", "((TO_MP-FROM_MP)*TransitFlow)", "1"}

	    ret_value = RunMacro("TCB Run Operation", 1, "Fill Dataview", Opts)
	    if !ret_value then goto quit
	end
    Return(1)
quit:
    Return(ret_value)
EndMacro


// STEP 10.2: Macro to run transit summary by route - PH, PM by purpose and access types
Macro "Rte_PH_PM"
    shared OutDir, Modes, AccessAssgnModes, route_bin, Periods, PurposePeriod

    Global phpm_view
    Global num_routes, list_num
    Global sumph, sumpm, rtehrpk, rtemipk, rtehrop, rtemiop

	nfiles=Periods.length*AccessAssgnModes.length*Modes.Length
    dim route_id_list[400], route_name_list[400], route_pkhdwy_list[400],route_ophdwy_list[400],route_modeid_list[400]
    dim route_fare_list[400],route_dir_list[400],route_track_list[400],rtehrpk[400],rtemipk[400],rtehrop[400],rtemiop[400],sumph[400], sumpm[400]
    dim Transit_flow_file[nfiles]

    RunMacro("TCB Init")
    vws = GetViewNames()
    for i = 1 to vws.length do CloseView(vws[i]) end

//  These files are the output of Transit Assignment
    k1=1
    for iper=1 to Periods.length do
        for iacc=1 to AccessAssgnModes.length do
			for imode=1 to Modes.length do
				Transit_flow_file[k1]=Periods[iper]+AccessAssgnModes[iacc]+Modes[imode]+"Flow.bin"
				k1=k1+1
			end
        end
    end

//   Initializing matrix to zero
    for mmm=1 to route_id_list.Length do
       rtehrpk[mmm]=0
       rtemipk[mmm]=0
       rtehrop[mmm]=0
       rtemiop[mmm]=0
       sumph[mmm]=0
       sumpm[mmm]=0
    end

    route_info_view = OpenTable("route_info_view","FFB",{route_bin,})
    view_set1 = route_info_view + "|"
    nrec1 = GetRecordCount(route_info_view,null)
    rec1=GetFirstRecord(view_set1, null)
    num_routes = 0
    While rec1 <> null do
            num_routes = num_routes + 1
            route_id_list[num_routes] = route_info_view.Route_ID
            route_name_list[num_routes] = route_info_view.Route_Name
            route_pkhdwy_list[num_routes] = route_info_view.test_HW_PK
            route_ophdwy_list[num_routes] = route_info_view.test_HW_OP
            route_modeid_list[num_routes] = route_info_view.Mode
            route_fare_list[num_routes] = route_info_view.Fare
            route_dir_list[num_routes] = route_info_view.Direction
            route_track_list[num_routes] = route_info_view.Track

            rec1 = GetNextRecord(view_set1, null, null)
    end

    for trn_asn_file = 1 to Transit_flow_file.length do
        TransitFlowFile = OutDir + Transit_flow_file[trn_asn_file]
        trn_flow_view = OpenTable("trn_flow_view","FFB",{TransitFlowFile,})
        view_set = trn_flow_view + "|"
// for each route id add the pax miles and pax hours between stops
        for m = 1 to num_routes do
            rec=GetFirstRecord(view_set, null)
//        route_id_list[m] = S2I(route_id_list[m])
			While rec <> null do
				if (trn_flow_view.ROUTE = route_id_list[m]) then do
					if (trn_asn_file = 5) then do                          // assumes that the 5th file gives the PK time and distance; for Nashville it does
					    rtehrpk[m] = rtehrpk[m] + trn_flow_view.BaseIVTT
					    rtemipk[m] = trn_flow_view.TO_MP
					end
					if (trn_asn_file = 20) then do   // assumes that 20th file gives the OP time and distance; for Nashville it does
					    rtehrop[m] = rtehrop[m] + trn_flow_view.BaseIVTT
					    rtemiop[m] = trn_flow_view.TO_MP
					end
					sumph[m] = sumph[m] + trn_flow_view.PH
					sumpm[m] = sumpm[m] + trn_flow_view.PM
				end
				rec = GetNextRecord(view_set, null, null)
		    end
	    end
	end
    Return(1)
endMacro



// STEP 10.2: Macro to run transit summary by route - Boarding by purpose and access types
Macro "Rte_boarding"
    shared OutDir, Modes, AccessAssgnModes, route_bin, Periods
    // No Transit Trips exist for HBPD purpose
//    Periods                = {"PK","OP"}                            

    nfiles=Periods.length*AccessAssgnModes.length*Modes.Length
    dim title[nfiles],route_id_list[400], route_name_list[400], route_pkhdwy_list[400],route_ophdwy_list[400]
    dim route_modeid_list[400],route_fare_list[400],route_dir_list[400],route_track_list[400],sumon[400,nfiles], sumoff[400,nfiles], TotOn[400], TotOff[400]
    dim OnOff_file[nfiles]

    Global boards_view
    Global num_routes, list_num

//  These files are the output of Transit Assignment
    k1=1
    for iper=1 to Periods.length do
        for iacc=1 to AccessAssgnModes.length do
			for imode=1 to Modes.length do
				OnOff_file[k1] = Periods[iper]+AccessAssgnModes[iacc]+Modes[imode]+"OnOffFlow.bin"
				title[k1]=Periods[iper]+AccessAssgnModes[iacc]+Modes[imode]
				k1=k1+1
			end
        end
    end

//   Initializing matrix to zero
    for mmm=1 to route_id_list.length do
         TotOn[mmm] = 0
         TotOff[mmm] = 0
         for kkk=1 to OnOff_file.length do
           sumon[mmm][kkk]=0
           sumoff[mmm][kkk]=0
         end
    end

    route_info_view = OpenTable("route_info_view","FFB",{route_bin,})
    view_set1 = route_info_view + "|"
    nrec1 = GetRecordCount(route_info_view,null)
    rec1=GetFirstRecord(view_set1, null)
    num_routes = 0
    While rec1 <> null do
            num_routes = num_routes + 1
            route_id_list[num_routes] = route_info_view.Route_ID
            route_name_list[num_routes] = route_info_view.Route_Name
            route_pkhdwy_list[num_routes] = route_info_view.test_HW_PK
            route_ophdwy_list[num_routes] = route_info_view.test_HW_OP
            route_modeid_list[num_routes] = route_info_view.Mode
            route_fare_list[num_routes] = route_info_view.Fare
            route_dir_list[num_routes] = route_info_view.Direction
            route_track_list[num_routes] = route_info_view.Track

            rec1 = GetNextRecord(view_set1, null, null)
    end

    for trn_asn_file = 1 to OnOff_file.length do
        onoff_file = OutDir + OnOff_file[trn_asn_file]
        onoff_view = OpenTable("onoff_view","FFB",{onoff_file,})
        view_set = onoff_view + "|"
// for each route id add the boardings
        for m = 1 to num_routes do
			rec=GetFirstRecord(view_set, null)
			While rec <> null do
			    if (onoff_view.ROUTE = route_id_list[m]) then do
					sumon[m][trn_asn_file] = sumon[m][trn_asn_file] + onoff_view.On
					TotOn[m] = TotOn[m] + onoff_view.On
					sumoff[m][trn_asn_file] = sumoff[m][trn_asn_file] + onoff_view.Off
					TotOff[m] = TotOff[m] + onoff_view.Off
				end
				rec = GetNextRecord(view_set, null, null)
			end
		end
    end

// Create boarding table

    boards_info = {
		{"Route_ID", "Integer", 8, null, "Yes"},
		{"Route_Name", "String", 25, null, "No"},
		{"MODE", "Integer", 5, null, "No"},
		{"PK_HEAD", "Integer", 5, null, "No"},
		{"OP_HEAD", "Integer", 5, null, "No"},
		{"TRACK", "Integer", 5, null, "No"},
        {"PK_MILES", "Real", 10, 2, "No"},
        {"PK_MINUTES", "Real", 10, 2, "No"},
        {"OP_MILES", "Real", 10, 2, "No"},
        {"OP_MINUTES", "Real", 10, 2, "No"},
	{"ON_TOTAL", "Integer", 8, 0, "No"},
        {title[1], "Real", 5, 1, "No"},
        {title[2], "Real", 5, 1, "No"},
        {title[3], "Real", 5, 1, "No"},
        {title[4], "Real", 5, 1, "No"},
        {title[5], "Real", 5, 1, "No"},
        {title[6], "Real", 5, 1, "No"},
        {title[7], "Real", 5, 1, "No"},
        {title[8], "Real", 5, 1, "No"},
        {title[9], "Real", 5, 1, "No"},
        {title[10], "Real", 5, 1, "No"},
        {title[11], "Real", 5, 1, "No"},
        {title[12], "Real", 5, 1, "No"},
        {title[13], "Real", 5, 1, "No"},
        {title[14], "Real", 5, 1, "No"},
        {title[15], "Real", 5, 1, "No"},
        {title[16], "Real", 5, 1, "No"},
        {title[17], "Real", 5, 1, "No"},
        {title[18], "Real", 5, 1, "No"},
        {title[19], "Real", 5, 1, "No"},
        {title[20], "Real", 5, 1, "No"},
        {title[21], "Real", 5, 1, "No"},
        {title[22], "Real", 5, 1, "No"},
        {title[23], "Real", 5, 1, "No"},
        {title[24], "Real", 5, 1, "No"},
        {title[25], "Real", 5, 1, "No"},
        {title[26], "Real", 5, 1, "No"},
        {title[27], "Real", 5, 1, "No"},
        {title[28], "Real", 5, 1, "No"},
        {title[29], "Real", 5, 1, "No"},
        {title[30], "Real", 5, 1, "No"},
        {"PAX_HOURS", "Integer", 8, 0, "No"},
	{"PAX_MILES", "Integer", 8, 0, "No"}
	}

    boards_name = "BOARDINGS"
    boards_file = OutDir + "TrnSummary.asc"

    on notfound do goto skip end

    tmp = GetViews ()
    if (tmp <> null) then do
		views = tmp [1]
		for k = 1 to views.length do
			if (views [k] = boards_name) then CloseView (views [k])
		end
    end
skip:
    boards_view = CreateTable (boards_name, boards_file, "FFA", boards_info)

// Populate Boardings
    
    SetView(boards_view)
    for k = 1 to num_routes do
        boards_values = {
            {"Route_ID", route_id_list[k]},
	    {"Route_Name", route_name_list[k]},
	    {"MODE", route_modeid_list[k]},
	    {"PK_HEAD", route_pkhdwy_list[k]},
	    {"OP_HEAD", route_ophdwy_list[k]},
	    {"TRACK", route_track_list[k]},
	    {"PK_MILES", rtemipk[k]},
	    {"PK_MINUTES", rtehrpk[k]},
	    {"OP_MILES", rtemiop[k]},
	    {"OP_MINUTES", rtehrop[k]},
	    {"ON_TOTAL", TotOn[k]},
	    {title[1], sumon[k][1]},
	    {title[2], sumon[k][2]},
	    {title[3], sumon[k][3]},
	    {title[4], sumon[k][4]},
            {title[5], sumon[k][5]},
            {title[6], sumon[k][6]},
            {title[7], sumon[k][7]},
            {title[8], sumon[k][8]},
            {title[9], sumon[k][9]},
            {title[10], sumon[k][10]},
            {title[11], sumon[k][11]},
            {title[12], sumon[k][12]},
            {title[13], sumon[k][13]},
            {title[14], sumon[k][14]},
            {title[15], sumon[k][15]},
            {title[16], sumon[k][16]},
            {title[17], sumon[k][17]},
            {title[18], sumon[k][18]},
            {title[19], sumon[k][19]},
            {title[20], sumon[k][20]},
            {title[21], sumon[k][21]},
            {title[22], sumon[k][22]},
            {title[23], sumon[k][23]},
            {title[24], sumon[k][24]},
            {title[25], sumon[k][25]},
            {title[26], sumon[k][26]},
            {title[27], sumon[k][27]},
            {title[28], sumon[k][28]},
            {title[29], sumon[k][29]},
            {title[30], sumon[k][30]},
	    {"PAX_HOURS", sumph[k]},
	    {"PAX_MILES", sumpm[k]}
        }
        AddRecord (boards_view,boards_values)
    end
	CloseView(boards_name)

	on notfound do
	   goto quit
	end

    tmp = GetViews ()
    if (tmp <> null) then do
        views = tmp [1]
        for k = 1 to views.length do  CloseView (views [k]) end
    end
    Return(1)
quit:
    PutInRecycleBin(OutDir + "TrnSummary.AX")
    Return(0)
EndMacro



// STEP 10.3: Macro to output Mode Choice Statistics
Macro "TRNSTAT"
    shared OutDir, DwellTimebyMode, DeleteTempOutputFiles, DeleteSummitFiles, modetable, Periods, PurposePeriod   // input files
    shared stat_file // output files

    nfiles=Periods.length
    nchoice=19  //18 options for mode choice
    maxmode=14 // maximum mode number in the network
    dim ModeChoiceFiles[nfiles]
    dim Flows[nfiles+1,nchoice]       //dim1 is purpose and dim2 is mode
    dim modename[maxmode],pkbrd[maxmode],opbrd[maxmode],totbrd[maxmode]  //assuming max of 10 modes
    dim modenum[400],pkbrdrte[400],opbrdrte[400],totbrdrte[400]  //assuming max of 400 routes
    dim totrte[nfiles+1],tot[nfiles+1],xfer[nfiles+1],xferr[nfiles+1] // 2 Periods+1
    k1=1
    for iper=1 to Periods.length do
        ModeChoiceFiles[k1]=Periods[iper]+"TripsByMode.mtx"
        k1=k1+1
    end
    for iper=1 to (nfiles+1) do
        tot[iper]=0
        totrte[iper]=0
        xfer[iper]=0
        xferr[iper]=0
        for imde=1 to nchoice do
			Flows[iper][imde]=0
        end
    end

    for i=1 to pkbrd.Length do
        pkbrd[i]=0
        opbrd[i]=0
        totbrd[i]=0
    end
    for i=1 to totbrdrte.Length do
        pkbrdrte[i]=0
        opbrdrte[i]=0
        totbrdrte[i]=0
    end

//        DwellTime={0.15,0.15,0.15,0.15,0.15,0.15,0.20,0.20,0.20,0.20,0.00,0.15}
    modename[1]="         Local"
    modename[2]="         Rover"
    modename[3]="           FTA"
    modename[4]="     New Local"
    modename[5]=" Project Local"
    modename[6]="   Express Bus"
    modename[7]="  Commuter Bus"
    modename[8]="  Existing BRT"
    modename[9]="       New BRT"
    modename[10]="   New UrbRail"
    modename[11]="       Shuttle"
    modename[12]="       ComRail"
    modename[13]="      New  FG "
    modename[14]="      Prj  FG "

    stat_file1 = OutDir + "TrnSummary.asc"
    sfile = OpenFile(stat_file,"w+")
    sfile1 = OpenFile(stat_file1,"r")

    stime=GetDateAndTime()
    WriteLine(sfile,"\n Created On: "+SubString(stime,1,3)+","+SubString(stime,4,7)+""+SubString(stime,20,5)+" ("+SubString(stime,12,8)+")\n Nashville Transit Assignment Summary")
    WriteLine(sfile,"\n Alternative: "+SubString(InDir,1,100)+" \n\n\n")

    dim DwellTimebyMode[100]
    ModeTable=OpenTable("modetable","dBASE",{modetable,})
    fields=GetTableStructure(ModeTable)

    view_set=ModeTable+"|"
    rec=GetFirstRecord(view_set,null)
    i=1
    while rec!=null do
       values=GetRecordValues(ModeTable,,)
       Dwell1=ModeTable.PK_Dwell
       Dwell2=ModeTable.OP_Dwell
       imde=ModeTable.MODE_ID

       DwellTimebyMode[i] = {imde,Dwell1,Dwell2}
       i=i+1
       rec=GetNextRecord(view_set, null, null)
    end

    for k = 1 to ModeChoiceFiles.length do
        vws = GetViewNames()
        for i = 1 to vws.length do
			CloseView(vws[i])
		end
		on notfound goto skip

    skip:

        mat = OpenMatrix(OutDir+ModeChoiceFiles[k],)
        stat_array = MatrixStatistics(mat, )
        Flows[k][1] = stat_array.[DA].Sum
        Flows[k][2] = stat_array.[SR2].Sum
        Flows[k][3] = stat_array.[SR3].Sum
        Flows[k][4] = stat_array.[WLKLOCBUS].Sum
        Flows[k][5] = stat_array.[WLKBRT].Sum
        Flows[k][6] = stat_array.[WLKEXPBUS].Sum
        Flows[k][7] = stat_array.[WLKURBRAIL].Sum
        Flows[k][8] = stat_array.[WLKCOMRAIL].Sum
        Flows[k][9] = stat_array.[PNRLOCBUS].Sum
        Flows[k][10] = stat_array.[PNRBRT].Sum
        Flows[k][11] = stat_array.[PNREXPBUS].Sum
        Flows[k][12] = stat_array.[PNRURBRAIL].Sum
        Flows[k][13] = stat_array.[PNRCOMRAIL].Sum
        Flows[k][14] = stat_array.[KNRLOCBUS].Sum
        Flows[k][15] = stat_array.[KNRBRT].Sum
        Flows[k][16] = stat_array.[KNREXPBUS].Sum
        Flows[k][17] = stat_array.[KNRURBRAIL].Sum
        Flows[k][18] = stat_array.[KNRCOMRAIL].Sum
        Flows[k][19] = Flows[k][1]+Flows[k][2]+Flows[k][3]+Flows[k][4]+Flows[k][5]+Flows[k][6]+Flows[k][7]+Flows[k][8]+Flows[k][9]+
                       Flows[k][10]+Flows[k][11]+Flows[k][12]+Flows[k][13]+Flows[k][14]+Flows[k][15]+Flows[k][16]+Flows[k][17]+Flows[k][18]
        Flows[3][1] = Flows[3][1] + Flows[k][1]
        Flows[3][2] = Flows[3][2] + Flows[k][2]
        Flows[3][3] = Flows[3][3] + Flows[k][3]
        Flows[3][4] = Flows[3][4] + Flows[k][4]
        Flows[3][5] = Flows[3][5] + Flows[k][5]
        Flows[3][6] = Flows[3][6] + Flows[k][6]
        Flows[3][7] = Flows[3][7] + Flows[k][7]
        Flows[3][8] = Flows[3][8] + Flows[k][8]
        Flows[3][9] = Flows[3][9] + Flows[k][9]
        Flows[3][10] = Flows[3][10] + Flows[k][10]
        Flows[3][11] = Flows[3][11] + Flows[k][11]
        Flows[3][12] = Flows[3][12] + Flows[k][12]
        Flows[3][13] = Flows[3][13] + Flows[k][13]
        Flows[3][14] = Flows[3][14] + Flows[k][14]
        Flows[3][15] = Flows[3][15] + Flows[k][15]
        Flows[3][16] = Flows[3][16] + Flows[k][16]
        Flows[3][17] = Flows[3][17] + Flows[k][17]
        Flows[3][18] = Flows[3][18] + Flows[k][18]
        Flows[3][19] = Flows[3][19] + Flows[k][19]

        if k=1 then do
			WriteLine(sfile,"TRIPS BY TOD AND MODE (MODE CHOICE MODEL RESULTS)")
			WriteLine(sfile,"==================================================================================================================================================================================================================|============")
			WriteLine(sfile," Per    DriveAlo  ShrRide 2  ShrRide 3+  WalkLocal  WalkBrt  WalkExpBus  WalkUrbRail  WalkComRail  PnRLocal  PnRBrt  PnRExpBus  PnRUrbRail  PnRComRail  KnRLocal  KnRBrt  KnRExpBus  KnRUrbRail  KnrComRail | Total Trips")
			WriteLine(sfile,"==================================================================================================================================================================================================================|============")
        end
        WriteLine(sfile,Lpad(Periods[k],5)+"   "+Format(Flows[k][1],",0000000")+"  "+Format(Flows[k][2],",0000000")+"     "+Format(Flows[k][3],",000000")
                                                               +"     "+Format(Flows[k][4],",00000")+"     "+Format(Flows[k][5],",00000")+"     "+Format(Flows[k][6],",00000")
                                                               +"     "+Format(Flows[k][7],",00000")+"     "+Format(Flows[k][8],",00000")+"     "+Format(Flows[k][9],",00000")
                                                               +"     "+Format(Flows[k][10],",00000")+"     "+Format(Flows[k][11],",00000")+"     "+Format(Flows[k][12],",00000")
                                                               +"     "+Format(Flows[k][13],",00000")+"     "+Format(Flows[k][14],",00000")+"     "+Format(Flows[k][15],",00000")
                                                               +"     "+Format(Flows[k][16],",00000")+"     "+Format(Flows[k][17],",00000")+"     "+Format(Flows[k][18],",00000")
                                                               +" |   "+Format(Flows[k][19],",0000000"))
    end
    WriteLine(sfile,"==================================================================================================================================================================================================================|============")
    WriteLine(sfile,"TOTAL       "+Format(Flows[3][1],",0000000")+"  "+Format(Flows[3][2],",0000000")+"   "+Format(Flows[3][3],",0000000")
                          +"     "+Format(Flows[3][4],",00000")+"     "+Format(Flows[3][5],",00000")+"     "+Format(Flows[3][6],",00000")
                          +"     "+Format(Flows[3][7],",00000")+"     "+Format(Flows[3][8],",00000")+"     "+Format(Flows[3][9],",00000")
                          +"     "+Format(Flows[3][10],",00000")+"     "+Format(Flows[3][11],",00000")+"     "+Format(Flows[3][12],",00000")
                          +"     "+Format(Flows[3][13],",00000")+"     "+Format(Flows[3][14],",00000")+"     "+Format(Flows[3][15],",00000")
                          +"     "+Format(Flows[3][16],",00000")+"     "+Format(Flows[3][17],",00000")+"     "+Format(Flows[3][18],",00000")
                          +" |   "+Format(Flows[3][19],",0000000"))

    While !FileAtEOF(sfile1) do
        linei=ReadLine(sfile1)
        mode=R2I(value(SubString(linei,34,5)))
        if (mode=0) then mode=14
        route=R2I(value(SubString(linei,51,3)))
        if (route=0) then route=199

        pkbrd[mode] = pkbrd[mode] + value(SubString(linei,102,5)) + value(SubString(linei,107,5)) + value(SubString(linei,112,5)) + value(SubString(linei,117,5)) + value(SubString(linei,122,5)) + 
                                      value(SubString(linei,127,5)) + value(SubString(linei,132,5)) + value(SubString(linei,137,5)) + value(SubString(linei,142,5)) + value(SubString(linei,147,5)) + 
                                      value(SubString(linei,152,5)) + value(SubString(linei,157,5)) + value(SubString(linei,162,5)) + value(SubString(linei,167,5)) + value(SubString(linei,172,5))
        opbrd[mode] = opbrd[mode] + value(SubString(linei,177,5)) + value(SubString(linei,182,5)) + value(SubString(linei,187,5)) + value(SubString(linei,192,5)) + value(SubString(linei,197,5)) + 
                                      value(SubString(linei,202,5)) + value(SubString(linei,207,5)) + value(SubString(linei,212,5)) + value(SubString(linei,217,5)) + value(SubString(linei,222,5)) + 
                                      value(SubString(linei,227,5)) + value(SubString(linei,232,5)) + value(SubString(linei,237,5)) + value(SubString(linei,242,5)) + value(SubString(linei,247,5))

        totbrd[mode] = totbrd[mode] + value(SubString(linei, 94,8))
        modenum[route]=mode
        
        pkbrdrte[route] = pkbrdrte[route] + value(SubString(linei,102,5)) + value(SubString(linei,107,5)) + value(SubString(linei,112,5)) + value(SubString(linei,117,5)) + value(SubString(linei,122,5)) + 
                                              value(SubString(linei,127,5)) + value(SubString(linei,132,5)) + value(SubString(linei,137,5)) + value(SubString(linei,142,5)) + value(SubString(linei,147,5)) + 
                                              value(SubString(linei,152,5)) + value(SubString(linei,157,5)) + value(SubString(linei,162,5)) + value(SubString(linei,167,5)) + value(SubString(linei,172,5))
        opbrdrte[route] = opbrdrte[route] + value(SubString(linei,177,5)) + value(SubString(linei,182,5)) + value(SubString(linei,187,5)) + value(SubString(linei,192,5)) + value(SubString(linei,197,5)) + 
                                              value(SubString(linei,202,5)) + value(SubString(linei,207,5)) + value(SubString(linei,212,5)) + value(SubString(linei,217,5)) + value(SubString(linei,222,5)) + 
                                              value(SubString(linei,227,5)) + value(SubString(linei,232,5)) + value(SubString(linei,237,5)) + value(SubString(linei,242,5)) + value(SubString(linei,247,5))        
        
        totbrdrte[route] = totbrdrte[route] + value(SubString(linei, 94,8))

        tot[1] = tot[1] + value(SubString(linei,102,5)) + value(SubString(linei,107,5)) + value(SubString(linei,112,5)) + value(SubString(linei,117,5)) + value(SubString(linei,122,5)) + 
                          value(SubString(linei,127,5)) + value(SubString(linei,132,5)) + value(SubString(linei,137,5)) + value(SubString(linei,142,5)) + value(SubString(linei,147,5)) + 
                          value(SubString(linei,152,5)) + value(SubString(linei,157,5)) + value(SubString(linei,162,5)) + value(SubString(linei,167,5)) + value(SubString(linei,172,5))
        
        tot[2] = tot[2] + value(SubString(linei,177,5)) + value(SubString(linei,182,5)) + value(SubString(linei,187,5)) + value(SubString(linei,192,5)) + value(SubString(linei,197,5)) + 
                          value(SubString(linei,202,5)) + value(SubString(linei,207,5)) + value(SubString(linei,212,5)) + value(SubString(linei,217,5)) + value(SubString(linei,222,5)) + 
                          value(SubString(linei,227,5)) + value(SubString(linei,232,5)) + value(SubString(linei,237,5)) + value(SubString(linei,242,5)) + value(SubString(linei,247,5))

        tot[3] = tot[3] + value(SubString(linei, 94,8))
        
        totrte[1] = totrte[1] + value(SubString(linei,102,5)) + value(SubString(linei,107,5)) + value(SubString(linei,112,5)) + value(SubString(linei,117,5)) + value(SubString(linei,122,5)) + 
                                value(SubString(linei,127,5)) + value(SubString(linei,132,5)) + value(SubString(linei,137,5)) + value(SubString(linei,142,5)) + value(SubString(linei,147,5)) + 
                                value(SubString(linei,152,5)) + value(SubString(linei,157,5)) + value(SubString(linei,162,5)) + value(SubString(linei,167,5)) + value(SubString(linei,172,5))
        totrte[2] = totrte[2] + value(SubString(linei,177,5)) + value(SubString(linei,182,5)) + value(SubString(linei,187,5)) + value(SubString(linei,192,5)) + value(SubString(linei,197,5)) + 
                                value(SubString(linei,202,5)) + value(SubString(linei,207,5)) + value(SubString(linei,212,5)) + value(SubString(linei,217,5)) + value(SubString(linei,222,5)) + 
                                value(SubString(linei,227,5)) + value(SubString(linei,232,5)) + value(SubString(linei,237,5)) + value(SubString(linei,242,5)) + value(SubString(linei,247,5))

        totrte[3] = totrte[3] + value(SubString(linei, 94,8))
    end
    CloseFile(sfile1)

    WriteLine(sfile,"\n\n\nTRANSIT BOARDINGS BY MODE (TRANSIT ASSIGNMENT RESULTS)")
    WriteLine(sfile,"=================================================================|=========")
    WriteLine(sfile," Mode         Mode Name      Dwell Time         PK         OP    |    Total")
    WriteLine(sfile,"=================================================================|=========")
    for k=1 to maxmode do
		if (totbrd[k] > 0) then do
			WriteLine(sfile,"   "+Format(k,"00")+"    "+modename[k]+"            "+Format(DwellTimebyMode[k][2],"0.00")+"      "+Format(pkbrd[k],",00000")+"      "+
			Format(opbrd[k],",00000")+"   |   "+Format(totbrd[k],",00000"))
		end
    end
    WriteLine(sfile,"==============================================================================================================================|=========")
    WriteLine(sfile,"        TOTAL                                "+Format(tot[1],",00000")+"      "+Format(tot[2],",00000")+"   |   "+Format(tot[3],",00000"))

    WriteLine(sfile,"\n\n\nTRANSFER RATES BY TOD")
    WriteLine(sfile,"=======================================")
    WriteLine(sfile," Period    Transfers   (Rate)")
    WriteLine(sfile,"=======================================")
    
    for k=1 to 2 do
		xfer[k]=(tot[k]-(Flows[k][4]+Flows[k][5]+Flows[k][6]+Flows[k][7]+Flows[k][8]+Flows[k][9]+Flows[k][10]+Flows[k][11]+Flows[k][12]+Flows[k][13]+Flows[k][14]+Flows[k][15]+Flows[k][16]+Flows[k][17]+Flows[k][18]))
		xferr[k]=(tot[k]/(Flows[k][4]+Flows[k][5]+Flows[k][6]+Flows[k][7]+Flows[k][8]+Flows[k][9]+Flows[k][10]+Flows[k][11]+Flows[k][12]+Flows[k][13]+Flows[k][14]+Flows[k][15]+Flows[k][16]+Flows[k][17]+Flows[k][18])-1)*100
		WriteLine(sfile,"   "+LPad(Periods[k],5)+"       "+Format(xfer[k],",00000")+" ("+Format(xferr[k],"00.00")+"%) ")
    end
    xfer[3]=(tot[3]-(Flows[3][4]+Flows[3][5]+Flows[3][6]+Flows[3][7]+Flows[3][8]+Flows[3][9]+Flows[3][10]+Flows[3][11]+Flows[3][12]+Flows[3][13]+Flows[3][14]+Flows[3][15]+Flows[3][16]+Flows[3][17]+Flows[3][18]))
    xferr[3]=(tot[3]/(Flows[3][4]+Flows[3][5]+Flows[3][6]+Flows[3][7]+Flows[3][8]+Flows[3][9]+Flows[3][10]+Flows[3][11]+Flows[3][12]+Flows[3][13]+Flows[3][14]+Flows[3][15]+Flows[3][16]+Flows[3][17]+Flows[3][18])-1)*100
    WriteLine(sfile,"=======================================")
    WriteLine(sfile,"  TOTAL                 "+Format(xfer[k],",00000")+" ("+Format(xferr[k],"00.00")+"%) ")

    WriteLine(sfile,"\n\n\nTRANSIT BOARDINGS BY ROUTE (TRANSIT ASSIGNMENT RESULTS)")
    WriteLine(sfile,"=====================================================|=========")
    WriteLine(sfile," Route   Mode     Route Name         PK         OP   |    Total")
    WriteLine(sfile,"=====================================================|=========")
    for k=1 to 400 do
		if (totbrdrte[k] > 0) then do
			WriteLine(sfile,"   "+Format(k,"000")+"     "+Format(modenum[k],"00")+"        Rte "+Format(k,"000")+"       "+Format(pkbrdrte[k],",00000")+"       "+Format(opbrdrte[k],",0000")+"   |   "+Format(totbrdrte[k],",00000"))
		end
    end
    WriteLine(sfile,"===================================================================================================================|=========")
    WriteLine(sfile,"        TOTAL                     "+Format(totrte[1],",00000")+"      "+Format(totrte[2],",00000")+"   |   "+Format(totrte[3],",00000"))

    // Now dump the transit summary file in the report
    stat_file2 = OutDir + "TrnSummary.asc"
    sfile2 = OpenFile(stat_file2,"r")
    WriteLine(sfile,"\n\n\nTRANSIT BOARDINGS BY INDIVIDUAL ROUTES (DISAGGREGATE RESULTS)")
    WriteLine(sfile,"======================================================================================================================================================================================"+
    			"============================================================================================================================================================================="+
    			"============================================================================================================================================================================="+
    			"====================================================================================================================")
    WriteLine(sfile," RTE_ID              RTE_NAME          MODE HDPK HDOP  RTE  PK_MILES   PK_TIME  OP_MILES   OP_TIME  TOT_ON 1_WL 1_WB 1_WE 1_WU 1_WC 1_PL 1_PB 1_PE 1_PU 1_PC 1_KL 1_KB 1_KE 1_KU 1_KC 2_WL"+
    			" 2_WB 2_WE 2_WU 2_WC 2_PL 2_PB 2_PE 2_PU 2_PC 2_KL 2_KB 2_KE 2_KU 2_KC 3_WL 3_WB 3_WE 3_WU 3_WC 3_PL 3_PB 3_PE 3_PU 3_PC 3_KL 3_KB 3_KE 3_KU 3_KC 4_WL 4_WB 4_WE 4_WU 4_WC 4_PL 4_PB"+
    			" 4_PE 4_PU 4_PC 4_KL 4_KB 4_KE 4_KU 4_KC 5_WL 5_WB 5_WE 5_WU 5_WC 5_PL 5_PB 5_PE 5_PU 5_PC 5_KL 5_KB 5_KE 5_KU 5_KC 6_WL 6_WB 6_WE 6_WU 6_WC 6_PL 6_PB 6_PE 6_PU 6_PC 6_KL 6_KB 6_KE 6_KU 6_KC"+
    			" 7_WL 7_WB 7_WE 7_WU 7_WC 7_PL 7_PB 7_PE 7_PU 7_PC 7_KL 7_KB 7_KE 7_KU 7_KC  TOT_PH  TOT_PM")
    WriteLine(sfile,"======================================================================================================================================================================================"+
    			"============================================================================================================================================================================="+
    			"============================================================================================================================================================================="+
    			"====================================================================================================================")
    While !FileAtEOF(sfile2) do
        linei=ReadLine(sfile2)
        WriteLine(sfile,linei)
    end
    CloseFile(sfile2)
    stime=GetDateAndTime()
    WriteLine(sfile,"\n\n\n END TRANSIT REPORTING - "+SubString(stime,1,3)+","+SubString(stime,4,7)+""+SubString(stime,20,5)+" ("+SubString(stime,12,8)+") ")
    CloseFile(sfile)

    Return(1)
quit:
    Return(0)
EndMacro


//STEP 10.4: Stop level boarding summary
Macro "Stop_Level_Summary"
    shared InDir, OutDir, highway_dbd, route_system // input files
    shared all_boards_file // output files

   // Inputs
	Dir = InDir
	net_file = highway_dbd                   // highway network
	route_file = route_system                // transit network
   // Outputs
	all_boards_file = OutDir + "ALL_BOARDINGS.dbf"

	tmp = GetViews ()
	if (tmp <> null) then do
		views = tmp [1]
		for k = 1 to views.length do
			if (views [k] = all_boards_name) then
				CloseView (views [k])
		end
	end
	// -- create a table to store the ON/OFF Boards Information for all Buses/Premium Services

	all_boards_info = {
		{"Route_ID", "Integer", 8, null, "Yes"},
		{"Route_Name", "String", 25, null, "Yes"},
		{"MODE", "Integer", 8, null, "No"},
		{"HW_PK", "Real", 8, 2, "No"},
		{"HW_OP", "Real", 8, 2, "No"},
		{"STOP_ID", "Integer", 8, null, "No"},
		{"NODE_ID", "Integer", 8, null, "No"},
		{"STOP_NAME", "String", 25, null, "No"},
		{"MILEPOST", "Real", 10, 4, "No"},
		{"PEAK_IVTT", "Real", 10, 4, "No"},
		{"OFPK_IVTT", "Real", 10, 4, "No"},
		{"PWLK_ON", "Real", 10, 2, "No"},
		{"PWLK_OF", "Real", 10, 2, "No"},
		{"PPNR_ON", "Real", 10, 2, "No"},
		{"PPNR_OF", "Real", 10, 2, "No"},
		{"PKNR_ON", "Real", 10, 2, "No"},
		{"PKNR_OF", "Real", 10, 2, "No"},
		{"OPWLK_ON", "Real", 10, 2, "No"},
		{"OPWLK_OF", "Real", 10, 2, "No"},
		{"OPPNR_ON", "Real", 10, 2, "No"},
		{"OPPNR_OF", "Real", 10, 2, "No"},
		{"OPKNR_ON", "Real", 10, 2, "No"},
		{"OPKNR_OF", "Real", 10, 2, "No"},
		{"PEAK_ON", "Real", 10, 2, "No"},
		{"PEAK_OFF", "Real", 10, 2, "No"},
		{"PEAK_RIDES", "Real", 10, 2, "No"},
		{"OFPK_ON", "Real", 10, 2, "No"},
		{"OFPK_OFF", "Real", 10, 2, "No"},
		{"OFPK_RIDES", "Real", 10, 2, "No"}
	}

	all_boards_name = "ALL_BOARDINGS"
	all_boards_view = CreateTable (all_boards_name, all_boards_file, "DBASE", all_boards_info)

	// Get the scope of a geographic file
	info = GetDBInfo(net_file)
	scope = info[1]

	// Create a map using this scope
	CreateMap(net, {{"Scope", scope},{"Auto Project", "True"}})
	layers = GetDBLayers(net_file)
	node_lyr = addlayer(net, layers[1], net_file, layers[1])
	link_lyr = addlayer(net, layers[2], net_file, layers[2])
	rtelyr = AddRouteSystemLayer(net, "Vehicle Routes", route_file, )
	RunMacro("Set Default RS Style", rtelyr, "TRUE", "TRUE")
	SetLayerVisibility(node_lyr, "True")
	SetIcon(node_lyr + "|", "Font Character", "Caliper Cartographic|4", 36)
	SetIcon("Route Stops|", "Font Character", "Caliper Cartographic|4", 36)
	SetLayerVisibility(link_lyr, "True")
	solid = LineStyle({{{1, -1, 0}}})
	SetLineStyle(link_lyr+"|", solid)
	SetLineColor(link_lyr+"|", ColorRGB(0, 0, 32000))
	SetLineWidth(link_lyr+"|", 0)
	SetLayerVisibility("Route Stops", "False")

on notfound default
	SetView("Vehicle Routes")
	n1 = SelectByQuery("RailRoutes", "Several", "Select * where Mode>0",)   // modify this selection to output for the modes that you want the boarding summary (for now include all transit)
//	n1 = SelectByQuery("RailRoutes", "Several", "Select * where Mode>6 & Mode<>11",)   // modify this selection to output for the modes that you want the boarding summary (for now include only premium modes)
	routes_view = GetView()


// ----- Set the paths for the TASN_FLOW files
	PurpPeriods      = {"HBWPK","HBOOP","HBSchOP","HBShpOP","NHBOOP","NHBWPK"}                        // Periods defined in the transit assignment model
        Modes            = {"Local","Brt","ExpBus","UrbRail","ComRail"}      // List of transit modes
        AccessAssgnModes = {"Walk","PnR","KnR"}                              // List of access modes for mode choice model
        Periods = {"PK","OP"}

	// open flow views to get travel times...only using rail flows as it all routes exist in them
	pk_flow_view = OpenTable("pk_flow_view", "FFB", {OutDir + "PKWalkComRailFlow.bin",})
	op_flow_view = OpenTable("op_flow_view", "FFB", {OutDir + "OPWalkComRailFlow.bin",})

	Dim all_peak_ons[2,5,3]
	Dim all_peak_offs[2,5,3]
	Dim all_offpeak_ons[2,5,3]
	Dim all_offpeak_offs[2,5,3]
    
	for i = 1 to Periods.length do
		for j = 1 to Modes.length do
			for k = 1 to AccessAssgnModes.length do
				all_peak_ons[i][j][k] = 0
				all_peak_offs[i][j][k] = 0
				all_offpeak_ons[i][j][k] = 0
				all_offpeak_offs[i][j][k] = 0
			end
		end
	end

	//open the on-off tables to get boardings by stop
	Dim path_ONOS[2,5,3]
	Dim tasn_view[2,5,3]

	counter = 0
	for i = 1 to Periods.length do
		for j = 1 to Modes.length do
			for k = 1 to AccessAssgnModes.length do
				counter = counter + 1
				path_ONOS[i][j][k] = OutDir + "\\" + Periods[i] + AccessAssgnModes[k] + Modes[j] + "OnOffFlow.bin"
				tasn_view[i][j][k] = OpenTable("tasn_view" + I2S(counter),"FFB",{path_ONOS[i][j][k],})
			end
		end
	end
	counter = 0
        SetView(routes_view)

	rec = 0
	nrec = GetRecordCount (routes_view, "RailRoutes")
	CreateProgressBar ("Processing Vehicle Route" + String(nrec) + " Transit Routes", "True")

	routes_rec = GetFirstRecord (routes_view + "|RailRoutes", {{"Route_Name", "Ascending"}})

	while routes_rec <> null do
		rec = rec + 1
		percent = r2i (rec * 100 / nrec)

		cancel = UpdateProgressBar ("Processing Vehicle Route " + String (rec) + " of " + String (nrec) + " Transit Routes", percent)

		if cancel = "True" then do
			DestroyProgressBar ()
			Return (1)
		end

		peak_boards_flag = 0
		offpeak_boards_flag = 0
		peak_boards = 0
		offpeak_boards = 0

		SetView(routes_view)
		route_id = routes_view.Route_ID
		route_name = routes_view.Route_Name
		mode = routes_view.Mode
		peak_headway = routes_view.test_HW_PK
		offpeak_headway = routes_view.test_HW_OP

		stop_layer = "Route Stops"
		SetView("Route Stops")

		select = "Select * where Route_ID = " + String(route_id)
		stop_selection = SelectByQuery ("Stops", "Several", select, )

		num_stops = GetRecordCount ("Route Stops", "Stops")
		stop_rec = GetFirstRecord ("Route Stops" + "|Stops", {{"Milepost", "Ascending"}})

		while stop_rec <> null do
			stop_id = stop_layer.ID
			node_id = stop_layer.NearNode
			milepost = stop_layer.Milepost

			// --- get the milepost distances and travel times
			if (peak_headway = 0) then do
				for i = 1 to 1 do
					for j = 1 to Modes.length do
						for k = 1 to AccessAssgnModes.length do
							all_peak_ons[i][j][k] = 0
							all_peak_offs[i][j][k] = 0
						end
					end
				end
				peak_on = 0
				peak_off = 0
				peak_boards = 0
			end else do
				peak_on = 0
				peak_off = 0
				for i = 1 to 1 do	//PurpPeriods.length do
					for j = 1 to Modes.length do
						for k = 1 to AccessAssgnModes.length do
							pboards = RunMacro("Get Boardings", route_id, stop_id, tasn_view[i][j][k])
							all_peak_ons[i][j][k] = all_peak_ons[i][j][k] + pboards[1]
							all_peak_offs[i][j][k] = all_peak_offs[i][j][k] + pboards[2]
							peak_on = peak_on + pboards[1]
							peak_off = peak_off + pboards[2]
						end
					end
				end

				if peak_boards_flag = 0 then do
					peak_boards = peak_on
					peak_boards_flag = 1
				end else do
					peak_boards = peak_boards + peak_on - peak_off
				end
				peak_ttime = RunMacro("Get Run Time", route_id, stop_id, pk_flow_view)
			end    // -- end of process for summarizing peak boards


			if (offpeak_headway = 0) then do
				for i = 2 to 2 do
					for j = 1 to Modes.length do
						for k = 1 to AccessAssgnModes.length do
							all_offpeak_ons[i][j][k] = 0
							all_offpeak_offs[i][j][k] = 0
						end
					end
				end
				offpeak_on = 0
				offpeak_off = 0
				offpeak_boards = 0
			end else do
				offpeak_on = 0
				offpeak_off = 0
				for i = 2 to 2 do	//PurpPeriods.length do
					for j = 1 to Modes.length do
						for k = 1 to AccessAssgnModes.length do
							opboards = RunMacro("Get Boardings", route_id, stop_id, tasn_view[i][j][k])
							all_offpeak_ons[i][j][k] = all_offpeak_ons[i][j][k] + opboards[1]
							all_offpeak_offs[i][j][k] = all_offpeak_offs[i][j][k] + opboards[2]
							offpeak_on = offpeak_on + opboards[1]
							offpeak_off = offpeak_off + opboards[2]
						end
					end
				end

				if offpeak_boards_flag = 0 then do
					offpeak_boards = offpeak_on
					offpeak_boards_flag = 1
				end else do
					offpeak_boards = offpeak_boards + offpeak_on - offpeak_off
				end
				offpeak_ttime = RunMacro("Get Run Time", route_id, stop_id, op_flow_view)
			end  // -- end of processing off-peak boards

			SetView(all_boards_view)

			all_board_values = {
				{"Route_ID", route_id},
				{"Route_Name", route_name},
				{"MODE", mode},
				{"HW_PK", peak_headway},
				{"HW_OP", offpeak_headway},
				{"STOP_ID", stop_id},
				{"NODE_ID", node_id},
				{"MILEPOST", milepost},
				{"PEAK_IVTT", peak_ttime},
				{"OFPK_IVTT", offpeak_ttime},
				{"PWLK_ON", all_peak_ons[1][1][1]+all_peak_ons[1][2][1]+all_peak_ons[1][3][1]},
				{"PWLK_OF", all_peak_offs[1][1][1]+all_peak_offs[1][2][1]+all_peak_offs[1][3][1]},
				{"PPNR_ON", all_peak_ons[1][1][2]+all_peak_ons[1][2][2]+all_peak_ons[1][3][2]},
				{"PPNR_OF", all_peak_offs[1][1][2]+all_peak_offs[1][2][2]+all_peak_offs[1][3][2]},
				{"PKNR_ON", all_peak_ons[1][1][3]+all_peak_ons[1][2][3]+all_peak_ons[1][3][3]},
				{"PKNR_OF", all_peak_offs[1][1][3]+all_peak_offs[1][2][3]+all_peak_offs[1][3][3]},
				{"OPWLK_ON", all_offpeak_ons[2][1][1]+all_offpeak_ons[2][2][1]+all_offpeak_ons[2][3][1]},
				{"OPWLK_OF", all_offpeak_offs[2][1][1]+all_offpeak_offs[2][2][1]+all_offpeak_offs[2][3][1]},
				{"OPPNR_ON", all_offpeak_ons[2][1][2]+all_offpeak_ons[2][2][2]+all_offpeak_ons[2][3][2]},
				{"OPPNR_OF", all_offpeak_offs[2][1][2]+all_offpeak_offs[2][2][2]+all_offpeak_offs[2][3][2]},
				{"OPKNR_ON", all_offpeak_ons[2][1][3]+all_offpeak_ons[2][2][3]+all_offpeak_ons[2][3][3]},
				{"OPKNR_OF", all_offpeak_offs[2][1][3]+all_offpeak_offs[2][2][3]+all_offpeak_offs[2][3][3]},
				{"PEAK_ON", peak_on},
				{"PEAK_OFF", peak_off},
				{"PEAK_RIDES", peak_boards},
				{"OFPK_ON", offpeak_on},
				{"OFPK_OFF", offpeak_off},
				{"OFPK_RIDES", offpeak_boards}
			}

			AddRecord (all_boards_view, all_board_values)

			// reset all the values for the next stop
			for i = 1 to Periods.length do
				for j = 1 to Modes.length do
					for k = 1 to AccessAssgnModes.length do
						all_peak_ons[i][j][k] = 0
						all_peak_offs[i][j][k] = 0
						all_offpeak_ons[i][j][k] = 0
						all_offpeak_offs[i][j][k] = 0
					end
				end
			end

			SetView(stop_layer)
			stop_rec = GetNextRecord ("Route Stops" + "|Stops", null, {{"Milepost", "Ascending"}})
		end		//end for stops

		SetView(routes_view)
		routes_rec = GetNextRecord (routes_view + "|RailRoutes", null, {{"Route_Name", "Ascending"}})
	end

//--- Invoke the Macro to Generate a Print file for Boardings Summary
	DestroyProgressBar ()
	CloseMap()
	tmp = GetViews ()
	if (tmp <> null) then do
		views = tmp [1]
		for k = 1 to views.length do
			if (views [k] = all_boards_name) then
				CloseView (views [k])
		end
	end
        Return(1)

endMacro



// ---------------------------------------
//   Macro to Summarize Boardings
// ---------------------------------------
Macro "Get Boardings" (route_id, stop_id, view_name)
	dim boards[2]
	SetView(view_name)

	selection = "Select * where ROUTE = " + String(route_id) + " and STOP = " + String(stop_id)
	record_selection = SelectByQuery ("Select Record", "Several", selection,)
	num_select = GetRecordCount (view_name, "Select Record")

	if (num_select > 1) then
		ShowMessage("More than one record Selected...PROBLEM HERE")
	else if (num_select = 0) then do		// --- no records are found in the boardings file
			boards[1] = 0.0
			boards[2] = 0.0
	end else do
		selected_record = GetFirstRecord (view_name + "|Select Record", null)
		boards[1] = view_name.On
		boards[2] = view_name.Off
	end
	Return(boards)
endMacro


//--------------------------------------------------------------------------
//  Macro to Get run time to a particular stop on a route from previous stop
//--------------------------------------------------------------------------
Macro "Get Run Time" (route_id, stop_id, view_name)
	SetView(view_name)

	selection = "Select * where ROUTE = " + String(route_id) + " and To_Stop = " + String(stop_id)
	record_selection = SelectByQuery ("Select Record", "Several", selection,)
	num_select = GetRecordCount (view_name, "Select Record")

	if (num_select > 1) then
		ShowMessage("More than one record Selected...PROBLEM HERE")
	else if (num_select = 0) then do		// --- no records are found in the boardings file
			rtime = 0.0000
	end else do
		selected_record = GetFirstRecord (view_name + "|Select Record", null)
		rtime = view_name.BaseIVTT
	end
	Return(rtime)
endMacro


// STEP 11: Create a daily trip table using the mode choice outputs and a total transit trip table
Macro "AggregateTripTables"
// Note: Daily Trip Table in PA format - with only I-I trips
    shared OutDir, IDTable  // input files
    shared runtime // output files

    RunMacro("TCB Init")

    zonefile=OpenTable("zonedata","FFB",{IDTable,})
    CreateMatrix({zonefile+"|","ID","Rows"}, {zonefile+"|","ID","Columns"},
                 {{"File Name",OutDir + "FinalTripTables.mtx"}, {"Type" ,"Double"}, {"Tables" ,{"Total Auto Trips", "Total Transit Trips"}}})

    Opts = null
    Opts.Input.[Matrix Currency] = { OutDir + "FinalTripTables.mtx", "Total Auto Trips", , }
    Opts.Input.[Core Currencies] = { {OutDir + "PKTripsByMode.mtx", "DA", , },
                                     {OutDir + "PKTripsByMode.mtx", "SR2", , },
                                     {OutDir + "PKTripsByMode.mtx", "SR3", , },
                                     {OutDir + "OPTripsByMode.mtx", "DA", , },
                                     {OutDir + "OPTripsByMode.mtx", "SR2", , },
                                     {OutDir + "OPTripsByMode.mtx", "SR3", , } }
    Opts.Global.Method = 7
    Opts.Global.[Cell Range] = 2
    Opts.Global.[Matrix K] = {1, 0.5, 1/3.5, 1, 0.5, 1/3.5}
    Opts.Global.[Force Missing] = "Yes"
    ret_value = RunMacro("TCB Run Operation", "Fill Matrices", Opts)
    if !ret_value then goto quit

    Opts = null
    Opts.Input.[Matrix Currency] = { OutDir + "FinalTripTables.mtx", "Total Transit Trips", ,  }
    Opts.Input.[Core Currencies] = { {OutDir + "PKTripsByMode.mtx", "WLKLOCBUS", , },
                                     {OutDir + "PKTripsByMode.mtx", "WLKBRT", , },
                                     {OutDir + "PKTripsByMode.mtx", "WLKEXPBUS", , },
                                     {OutDir + "PKTripsByMode.mtx", "WLKURBRAIL", , },
                                     {OutDir + "PKTripsByMode.mtx", "WLKCOMRAIL", , },
                                     {OutDir + "PKTripsByMode.mtx", "PNRLOCBUS", , },
                                     {OutDir + "PKTripsByMode.mtx", "PNRBRT", , },
                                     {OutDir + "PKTripsByMode.mtx", "PNREXPBUS", , },
                                     {OutDir + "PKTripsByMode.mtx", "PNRURBRAIL", , },
                                     {OutDir + "PKTripsByMode.mtx", "PNRCOMRAIL", , },
                                     {OutDir + "PKTripsByMode.mtx", "KNRLOCBUS", , },
                                     {OutDir + "PKTripsByMode.mtx", "KNRBRT", , },
                                     {OutDir + "PKTripsByMode.mtx", "KNREXPBUS", , },
                                     {OutDir + "PKTripsByMode.mtx", "KNRURBRAIL", , },
                                     {OutDir + "PKTripsByMode.mtx", "KNRCOMRAIL", , },
                                     {OutDir + "OPTripsByMode.mtx", "WLKLOCBUS", , },
                                     {OutDir + "OPTripsByMode.mtx", "WLKBRT", , },
                                     {OutDir + "OPTripsByMode.mtx", "WLKEXPBUS", , },
                                     {OutDir + "OPTripsByMode.mtx", "WLKURBRAIL", , },
                                     {OutDir + "OPTripsByMode.mtx", "WLKCOMRAIL", , },
                                     {OutDir + "OPTripsByMode.mtx", "PNRLOCBUS", , },
                                     {OutDir + "OPTripsByMode.mtx", "PNRBRT", , },
                                     {OutDir + "OPTripsByMode.mtx", "PNREXPBUS", , },
                                     {OutDir + "OPTripsByMode.mtx", "PNRURBRAIL", , },
                                     {OutDir + "OPTripsByMode.mtx", "PNRCOMRAIL", , },
                                     {OutDir + "OPTripsByMode.mtx", "KNRLOCBUS", , },
                                     {OutDir + "OPTripsByMode.mtx", "KNRBRT", , },
                                     {OutDir + "OPTripsByMode.mtx", "KNREXPBUS", , },
                                     {OutDir + "OPTripsByMode.mtx", "KNRURBRAIL", , },
                                     {OutDir + "OPTripsByMode.mtx", "KNRCOMRAIL", , } }
    Opts.Global.Method = 7
    Opts.Global.[Cell Range] = 2
    Opts.Global.[Matrix K] = {1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1}
    Opts.Global.[Force Missing] = "Yes"
    ret_value = RunMacro("TCB Run Operation", "Fill Matrices", Opts)
    if !ret_value then goto quit
    Return(1)
quit:
    Return(0)
EndMacro

