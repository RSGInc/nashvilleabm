//**************************************
//*					Highway Skimming					 *
//**************************************
/*
3 skims:
Terminal
Travel Cost
Truck Travel Cost
Skim_0: read field names and add layers to the map
Skim_1: Build Highway Network
Skim_2: Shortest path using Length for EE trips
Skim_3: Terminal Time
Skim_4: Intrazonal Travel Time
*/
Macro "Highway Skimming" (Args)    // Highway Skimming
	shared  Scen_Dir, loop
   
	starttime = RunMacro("RuntimeLog", {"Highway Skimming - Feedback Loop " + i2s(loop), null})
   	RunMacro("HwycadLog", {"2.1 HwySkimming.rsc", "  ****** Highway Skimming ****** "})

    feedback_iteration = loop
   
    // skim_0:
	RunMacro ("TCB Init")
   
    // Input highway and TAZ files. 
    hwy_db = Args.[hwy db]
	taz_db = Args.[taz]
	layers = GetDBlayers(hwy_db)
    llayer = layers[2]
    nlayer = layers[1]
   
    db_linklyr = hwy_db + "|" + llayer
    db_nodelyr = hwy_db + "|" + nlayer
     
    network_file = Args.[Network File]
    
    //********************************************************************
	//*      Skim_1: Build Highway Network - build it only once          *
	//********************************************************************   
	// skim_1:
	RunMacro("HwycadLog", {"Build highway network", null})
    RunMacro("Build Hwy Network", Args)

    //Add TAZ layer
    layers = GetDBlayers(taz_db)
    tazname = layers[1]
	temp_layer =AddLayer("temp",tazname,taz_db,tazname)
	SetView(tazname)
	
    //**************************************
	//*      Skim_2: Shortest path using Length     *
	//**************************************   
	// skim_2:
	RunMacro("HwycadLog", {"Shortest path using length", null})
    Opts = null
    Opts.Input.Network = network_file
    Opts.Input.[Origin Set] = {db_nodelyr, nlayer, "Selection", "Select * where CCSTYLE=97 or CCSTYLE=98 or CCSTYLE=99"}
    Opts.Input.[Destination Set] = {db_nodelyr, nlayer, "Selection"}
    Opts.Input.[Via Set] = {db_nodelyr, nlayer}
    Opts.Field.Minimize = "Length"
    Opts.Field.Nodes = nlayer + ".ID"
    Opts.Output.[Output Matrix].Label = "EE"
    Opts.Output.[Output Matrix].[File Name] = Scen_Dir + "outputs\\ExtDistSkims.mtx"
    ret_value = RunMacro("TCB Run Procedure", 1, "TCSPMAT", Opts)
    if !ret_value then goto quit 

    //**************************************
	//*      Skim_4: Terminal Time			               
	//**************************************  
	RunMacro("HwycadLog", {"Terminal time", null}) 	
	CreateMatrix({tazname +"|", tazname  + ".ID","TAZ_ID"},{tazname +"|", tazname  + ".ID","TAZ_ID"},
             {{"File Name",Scen_Dir + "//outputs//terminal_time.mtx"},{"Type","Float"},
             {"Tables",{"origin_time","destination_time","total_time"}}})

    dim terminal[4]
    terminal[1]={"CBD",2.5}
    terminal[2]={"URBAN",1.5}
    terminal[3]={"SU",1}
    terminal[4]={"RURAL",0.5}

	for i=1 to terminal.length do 
		//Matrix Index - Create Area Type Matrix Index
		Opts = null
		Opts.Input.[Current Matrix] = Scen_Dir + "\\outputs\\terminal_time.mtx"
		Opts.Input.[Index Type] = "Both"
		Opts.Input.[View Set] = {taz_db+"|"+tazname, tazname, "Selection", "Select * where Predict='"+terminal[i][1]+"'"}
		Opts.Input.[Old ID Field] = {taz_db+"|"+tazname, "ID"}
		Opts.Input.[New ID Field] = {taz_db+"|"+tazname, "ID"}
		Opts.Output.[New Index] = terminal[i][1]
		ret_value = RunMacro("TCB Run Operation", "Add Matrix Index", Opts, &Ret)
		if !ret_value then goto quit
		
		// Terminal Time - Adding Origin Terminal Time
		Opts = null
		Opts.Input.[Matrix Currency] = {Scen_Dir + "\\outputs\\terminal_time.mtx", "origin_time", terminal[i][1], "TAZ_ID"}
		Opts.Global.Method = 1
		Opts.Global.Value = terminal[i][2]
		Opts.Global.[Cell Range] = 2
		Opts.Global.[Matrix Range] = 1
		Opts.Global.[Matrix List] = {"origin_time", "destination_time", "total_time"}
		ret_value = RunMacro("TCB Run Operation", 7, "Fill Matrices", Opts)
		if !ret_value then goto quit
	   
		// Terminal Time - Adding Destination Terminal Time
		Opts = null
		Opts.Input.[Matrix Currency] = {Scen_Dir + "\\outputs\\terminal_time.mtx", "destination_time", "TAZ_ID", terminal[i][1]}
		Opts.Global.Method = 1
		Opts.Global.Value = terminal[i][2]
		Opts.Global.[Cell Range] = 2
		Opts.Global.[Matrix Range] = 1
		Opts.Global.[Matrix List] = {"origin_time", "destination_time", "total_time"}
		ret_value = RunMacro("TCB Run Operation", 7, "Fill Matrices", Opts)
		if !ret_value then goto quit
	end 
	
	// Fill Matrices - Sum the total terminal time
	Opts = null
	Opts.Input.[Matrix Currency] = {Scen_Dir + "\\outputs\\terminal_time.mtx", "total_time", "TAZ_ID", "TAZ_ID"}
	Opts.Global.Method = 11
	Opts.Global.[Cell Range] = 2
	Opts.Global.[Expression Text] = "nz([origin_time])+ nz([destination_time])"
	Opts.Global.[Force Missing] = "Yes"
	ret_value = RunMacro("TCB Run Operation", 11, "Fill Matrices", Opts)
	if !ret_value then goto quit  
   
    //**************************************
	//*      Create TOD Skim Matrices & Add Intrazonal and Terminal 
	//**************************************
    RunMacro("HwycadLog", {"Build TRK skims", null})

    // Build TRK skims
    dim trk_skims[4]

    periods = {"AM","MD","PM","OP"}

	//value-of-time ($/hr)
    ////make this an Arg
	truck_vot = 45

    for i=1 to periods.length do
        period = periods[i]
        trk_skims_fileName = "hwyskim_" + period + "_trk.mtx"
        trk_skims[i]={trk_skims_fileName,"[time_" + period + "_AB_time_" + period + "_BA]",period}

        // for feedback
        RunMacro("Update Highway Network", Args, feedback_iteration, period, truck_vot, "TRK")

        // for feedback
        if feedback_iteration = 1 then skim_field1 = trk_skims[i][2]  
        else skim_field1 = "_MSATime" + trk_skims[i][3]

        skim_field2 = "TCST_" + period  //generalized cost
        skim_fields = {skim_field1,skim_field2}

        RunMacro("Build Hwy Skims", network_file, db_nodelyr, nlayer, trk_skims[i], skim_fields, truck_vot)
        RunMacro("Add Intrazonal & Terminal Times",  trk_skims[i], skim_fields)

		//Added July 7 2026
		if (loop > 1) then do
			//Add a new core "[time_am_AB / time_am_BA]" to truck skims for each period - internal truck model needs this core
			RunMacro("AddCore", trk_skims[i], 1)
		end
		
        RunMacro("SaveAndCopySkims", trk_skims[i])
    end

	RunMacro("HwycadLog", {"Build HOV skims", null})

    // Build HOV skims
    dim hov_skims[4]
    periods = {"AM","MD","PM","OP"}
	vots = {"low","med","high"}

    //value-of-time ($/hr)
    ////Make these Args
    vot_hov = {6,12,24}

    for i=1 to periods.length do
        period = periods[i]
		//vot loop - build a skim for each VOT
		for v =1 to vots.Length do
            vot = vots[v]
            hov_skims_fileName = "hwyskim_" + period + "_hov_" + vot + ".mtx"
            hov_skims[i]={hov_skims_fileName,"[time_" + period + "_AB_time_" + period + "_BA]",period}
			// for feedback
			RunMacro("Update Highway Network", Args, feedback_iteration, period, vot_hov[v], "HOV")

            // for feedback
            if feedback_iteration = 1 then do
                skim_field1 = hov_skims[i][2]  
            end
            else do
                if i <=4 then do
                    skim_field1 = "_MSATime" + hov_skims[i][3] 
                end
                else do // nothing for FF
                    skim_field1 = hov_skims[i][2]  
                end
            end

            skim_field2 = "HCST_" + period  //generalized cost
            skim_fields = {skim_field1,skim_field2}

            RunMacro("Build Hwy Skims", network_file, db_nodelyr, nlayer, hov_skims[i], skim_fields, vot)
            RunMacro("Add Intrazonal & Terminal Times",  hov_skims[i], skim_fields)
            
            //Added July 1 2026
            if (loop > 1) then do
                //Add a new core "[time_am_AB / time_am_BA]" to highway skims for each period - mode choice model needs this core
                RunMacro("AddCore", hov_skims[i], 1)
            end
            
            RunMacro("SaveAndCopySkims", hov_skims[i])

        end
    end

	RunMacro("HwycadLog", {"Build SOV skims", null})

    // Build SOV skims

    //value-of-time ($/hr)
    ////Make these Args from the model spec table
    vot_sov = {4,10,20}

    periods_sov = {"AM","MD","PM","OP","FF"}

    //Array to store file name, time field, and period
    sov_skims_length = periods_sov.Length
    dim sov_skims[sov_skims_length]
	
    for i=1 to sov_skims_length do
        period_sov = periods_sov[i]
        //vot loop
		for v =1 to vots.Length do
            vot = vots[v]
            sov_skims_fileName = "hwyskim_" + period_sov + "_sov_" + vot + ".mtx"
            sov_skims[i]={sov_skims_fileName,"[time_" + period_sov + "_AB_time_" + period_sov + "_BA]", period_sov}

            // Disable HOV links
            net = ReadNetwork(network_file)
            NetOpts = null
            //NetOpts.[Link ID] = link_lyr+".ID"
            NetOpts.[Type] = "Enable"
            NetOpts.[Write to file] = "Yes"
            ChangeLinkStatus(net,, NetOpts) // first enable all links
            //Then disable HOV links
            NetOpts.[Type] = "Disable"
            hov_field = "HOV_m1_"+Args.HYEAR+" = 1"
            NetworkEnableDisableLinkByExpression(net, hov_field, NetOpts)

            // for feedback
            if feedback_iteration = 1 then do
                //Call to the new macro below, which updates the generalized cost fields
                RunMacro("Update Highway Network", Args, feedback_iteration, period_sov, vot_sov[v], "SOV")
                skim_field1 = sov_skims[i][2]
            end
            else do
                if period_sov <> "FF" then do
                    skim_field1 = "_MSATime" + sov_skims[i][3]
                end
                else do//free flow skim
                    //set vot counter to the length, so that there is only one loop of vot
                    v = vots.Length
                    skim_field1 = sov_skims[i][2]
                end
            end

            skim_field2 = "SCST_" + period_sov     //generalized cost
            skim_fields = {skim_field1, skim_field2}
        
            RunMacro("Build Hwy Skims", network_file, db_nodelyr, nlayer, sov_skims[i], skim_fields)
            RunMacro("Add Intrazonal & Terminal Times",  sov_skims[i], skim_fields)
        
            NetOpts.[Type] = "Enable"
            NetworkEnableDisableLinkByExpression(net, hov_field, NetOpts)

            //Modified July 1 2026
            if (loop > 1 and i<=4) then do
                //Add a new core "[time_am_AB / time_am_BA]" to highway skims for each period - mode choice model needs this core
                RunMacro("AddCore", sov_skims[i], 1)
            end
    
 	        RunMacro("HwycadLog", {"Save and copy skims", null})
            RunMacro("SaveAndCopySkims", sov_skims[i])

        end
    end 

	RunMacro("HwycadLog", {"2.1 HwySkimming.rsc", "Finished Highway Skimming"})

	endtime = RunMacro("RuntimeLog", {"Highway Skimming - Feedback Loop " + i2s(loop), starttime})	
    
    ret_value = 1
    quit:
    CloseMap("temp")
    return(ret_value)
endMacro    

//Calculate the generalized cost (SCST or HCST) and update those network fields
Macro "Update Highway Network" (Args, Iteration, Period, VOT, Mode)
	shared  Scen_Dir, loop

    // Input highway and TAZ files. 
    hwy_db = Args.[hwy db]
	layers = GetDBlayers(hwy_db)
    llayer = layers[2]
    nlayer = layers[1]
	network_file = Args.[Network File]
	
	flowTable = Scen_Dir + "outputs\\Assignment_" + Period + ".bin"
	
	//set cost field as per feedback iteration. If first, set to travel time. Else, set to MSA cost.
	if Iteration = 1 then do
		field_cost_ab = "time_" + Period + "_AB"
		field_cost_ba = "time_" + Period + "_BA"
		dataview_set = {hwy_db+"|"+llayer, "sovtime" + Period}
	end
	else do
		field_cost_ab = "AB_MSA_Cost"
		field_cost_ba = "BA_MSA_Cost"
		dataview_set = {{hwy_db+"|"+llayer, flowTable, {"ID"}, {"ID1"}}, "hovtime" + Period}
	end

    //first part of the fields to be updated
	if Mode = "SOV" then field_part = "SCST_" + Period
	if Mode= "HOV" then field_part = "HCST_" + Period
    if Mode= "TRK" then field_part = "TCST_" + Period
	
    //Update the generalized cost field for all of the time-of-day runs
    if Period <> "FF" then do
        //The Dataview Set is a joined view of the link layer and the flow table, based on link ID
        //Update Cost field in highway database
        Opts.Input.[Dataview Set] = dataview_set   
        Opts.Global.Fields = {field_part + "_AB", field_part + "_BA"}   //fields to fill (SCST, HCST, or TCST)
        Opts.Global.Method = "Formula"
        //Fill with the generalized costs (min.), calculated from the Toll_... fields
        //Make sure the truck cost includes the existing value in these fields that was previouisly calculated from TRUCKCOST
        if Mode= "TRK" then do
            Opts.Global.Parameter = {   field_part + "_AB +" + field_cost_ab + "+ ((Toll_"+ Mode + "_" +Period+"_AB/100)/"+String(VOT)+"*60)", 
                                        field_part + "_BA +" + field_cost_ba + "+ ((Toll_"+ Mode + "_" +Period+"_BA/100)/"+String(VOT)+"*60)"} 
        end
        else do
            Opts.Global.Parameter = {   field_cost_ab + "+ ((Toll_"+ Mode + "_" +Period+"_AB/100)/"+String(VOT)+"*60)", 
                                        field_cost_ba + "+ ((Toll_"+ Mode + "_" +Period+"_BA/100)/"+String(VOT)+"*60)"}
        end

        ret_value = RunMacro("TCB Run Operation", "Fill Dataview", Opts, &Ret)
        if !ret_value then goto quit	
        
        //Update the network file
        Opts = null
        Opts.Input.Database = hwy_db
        Opts.Input.Network = network_file
        Opts.Input.[Link Set] = {hwy_db+"|"+llayer, llayer}
        Opts.Global.[Fields Indices] = field_part
        Opts.Global.Options.[Link Fields] = { {llayer+"." + field_part +"_AB", llayer+"." + field_part +"_BA"} }
        Opts.Global.Options.Constants = {1}
        ret_value = RunMacro("TCB Run Operation",  "Update Network Field", Opts) 
        if !ret_value then goto quit
    end
	
	quit:
    return(ret_value)
	 
endMacro

Macro "Build Hwy Network" (Args)
    shared  Scen_Dir, loop

    // Input highway and TAZ files. 
    hwy_db = Args.[hwy db]
	layers = GetDBlayers(hwy_db)
    llayer = layers[2]
    nlayer = layers[1]
   
    db_linklyr = hwy_db + "|" + llayer
    db_nodelyr = hwy_db + "|" + nlayer
    
    temp_map = CreateMap("temp",{{"scope", Scope(Coord(-80000000, 44500000), 200.0, 100.0, 0)}})
    temp_layer = AddLayer(temp_map,llayer,hwy_db,llayer)
    temp_layer = AddLayer(temp_map,nlayer,hwy_db,nlayer)
    
    network_file = Args.[Network File]    
    
    if loop = 1 then do
        Opts = null
        Opts.Input.[Link Set] = {db_linklyr , llayer, "Selection", "Select * where Lanes>0 and Assignment_LOC=1"}
        Opts.Global.[Network Label] = "Based on "+db_linklyr
        //Opts.Global.[Network Options].[Node Id] = nlayer+".ID"
        Opts.Global.[Network Options].[Turn Penalties] = "Yes"
        Opts.Global.[Network Options].[Keep Duplicate Links] = "FALSE"
        Opts.Global.[Network Options].[Ignore Link Direction] = "FALSE"
        Opts.Global.[Network Options].[Time Units] = "Minutes"
        Opts.Global.[Link Options] = {{"Length", {llayer+".Length", llayer+".Length", , , "False"}}, 
        {"WalkTime", {llayer+".WalkTime", llayer+".WalkTime", , , "False"}}, 
        {"[capacity_am_AB_capacity_am_BA]", {llayer+".capacity_am_AB", llayer+".capacity_am_BA", , , "False"}}, 
        {"[capacity_pm_AB_capacity_pm_BA]", {llayer+".capacity_pm_AB", llayer+".capacity_pm_BA", , , "False"}}, 
        {"[capacity_op_AB_capacity_op_BA]", {llayer+".capacity_op_AB", llayer+".capacity_op_BA", , , "False"}}, 
        {"[capacity_md_AB_capacity_md_BA]", {llayer+".capacity_md_AB", llayer+".capacity_md_BA", , , "False"}}, 
        {"[capacity_daily_AB_capacity_daily_BA]", {llayer+".capacity_daily_AB", llayer+".capacity_daily_BA", , , "False"}}, 
        {"[SPD_FF_AB_SPD_FF_BA]", {llayer+".SPD_FF_AB", llayer+".SPD_FF_BA", , , "False"}}, 
        {"[SPD_AM_AB_SPD_AM_BA]", {llayer+".SPD_AM_AB", llayer+".SPD_AM_BA", , , "False"}}, 
        {"[SPD_MD_AB_SPD_MD_BA]", {llayer+".SPD_MD_AB", llayer+".SPD_MD_BA", , , "False"}}, 
        {"[SPD_PM_AB_SPD_PM_BA]", {llayer+".SPD_PM_AB", llayer+".SPD_PM_BA", , , "False"}}, 
        {"[SPD_OP_AB_SPD_OP_BA]", {llayer+".SPD_OP_AB", llayer+".SPD_OP_BA", , , "False"}}, 
        {"[time_FF_AB_time_FF_BA]", {llayer+".time_FF_AB", llayer+".time_FF_BA", , , "False"}}, 
        {"[time_AM_AB_time_AM_BA]", {llayer+".time_AM_AB", llayer+".time_AM_BA", , , "False"}}, 
        {"[time_MD_AB_time_MD_BA]", {llayer+".time_MD_AB", llayer+".time_MD_BA", , , "False"}}, 
        {"[time_PM_AB_time_PM_BA]", {llayer+".time_PM_AB", llayer+".time_PM_BA", , , "False"}}, 
        {"[time_OP_AB_time_OP_BA]", {llayer+".time_OP_AB", llayer+".time_OP_BA", , , "False"}},
        {"Toll_SOV_AM", {llayer+".Toll_SOV_AM_AB", llayer+".Toll_SOV_AM_BA", , , "False"}}, 
        {"Toll_SOV_MD", {llayer+".Toll_SOV_MD_AB", llayer+".Toll_SOV_MD_BA", , , "False"}}, 
        {"Toll_SOV_PM", {llayer+".Toll_SOV_PM_AB", llayer+".Toll_SOV_PM_BA", , , "False"}}, 
        {"Toll_SOV_OP", {llayer+".Toll_SOV_OP_AB", llayer+".Toll_SOV_OP_BA", , , "False"}},
        {"Toll_HOV_AM", {llayer+".Toll_HOV_AM_AB", llayer+".Toll_HOV_AM_BA", , , "False"}}, 
        {"Toll_HOV_MD", {llayer+".Toll_HOV_MD_AB", llayer+".Toll_HOV_MD_BA", , , "False"}}, 
        {"Toll_HOV_PM", {llayer+".Toll_HOV_PM_AB", llayer+".Toll_HOV_PM_BA", , , "False"}}, 
        {"Toll_HOV_OP", {llayer+".Toll_HOV_OP_AB", llayer+".Toll_HOV_OP_BA", , , "False"}},
        {"Toll_TRK_AM", {llayer+".Toll_TRK_AM_AB", llayer+".Toll_TRK_AM_BA", , , "False"}}, 
        {"Toll_TRK_MD", {llayer+".Toll_TRK_MD_AB", llayer+".Toll_TRK_MD_BA", , , "False"}}, 
        {"Toll_TRK_PM", {llayer+".Toll_TRK_PM_AB", llayer+".Toll_TRK_PM_BA", , , "False"}}, 
        {"Toll_TRK_OP", {llayer+".Toll_TRK_OP_AB", llayer+".Toll_TRK_OP_BA", , , "False"}}, 
		{"SCST_AM", {llayer+".SCST_AM_AB", llayer+".SCST_AM_BA", , , "False"}},
		{"SCST_MD", {llayer+".SCST_MD_AB", llayer+".SCST_MD_BA", , , "False"}},
		{"SCST_PM", {llayer+".SCST_PM_AB", llayer+".SCST_PM_BA", , , "False"}},
		{"SCST_OP", {llayer+".SCST_OP_AB", llayer+".SCST_OP_BA", , , "False"}},
		{"HCST_AM", {llayer+".HCST_AM_AB", llayer+".HCST_AM_BA", , , "False"}},
		{"HCST_MD", {llayer+".HCST_MD_AB", llayer+".HCST_MD_BA", , , "False"}},
		{"HCST_PM", {llayer+".HCST_PM_AB", llayer+".HCST_PM_BA", , , "False"}},
		{"HCST_OP", {llayer+".HCST_OP_AB", llayer+".HCST_OP_BA", , , "False"}},
		{"TCST_AM", {llayer+".TCST_AM_AB", llayer+".TCST_AM_BA", , , "False"}},
		{"TCST_MD", {llayer+".TCST_MD_AB", llayer+".TCST_MD_BA", , , "False"}},
		{"TCST_PM", {llayer+".TCST_PM_AB", llayer+".TCST_PM_BA", , , "False"}},
		{"TCST_OP", {llayer+".TCST_OP_AB", llayer+".TCST_OP_BA", , , "False"}}, 
        {"HOV_m1_"+Args.HYEAR, {llayer+".HOV_m1_"+Args.HYEAR, llayer+".HOV_m1_"+Args.HYEAR, , , "False"}}, //
        {"alpha", {llayer+".alpha", llayer+".alpha", , , "False"}}, 
        {"beta", {llayer+".beta", llayer+".beta", , , "False"}},
        {"TRUCKNET", {llayer+".TRUCKNET", llayer+".TRUCKNET", , , "False"}},
        {"TRUCKCOST", {llayer+".TRUCKCOST", llayer+".TRUCKCOST", , , "False"}},
		{"RiverX", {llayer+".RiverX", llayer+".RiverX", , , "False"}},
		{"PEN_FACTYPE", {llayer+".PEN_FACTYPE", llayer+".PEN_FACTYPE", , , "False"}}}
        Opts.Global.[Length Units] = "Miles"
        Opts.Global.[Time Units] = "Minutes"
        Opts.Output.[Network File] = network_file
        ret_value = RunMacro("TCB Run Operation", "Build Highway Network", Opts, &Ret)
        if !ret_value then goto quit 
	
        // centroids
        Opts = null
        Opts.Input.Database = hwy_db
        Opts.Input.Network = network_file
        Opts.Input.[Centroids Set] = {hwy_db+"|"+nlayer, nlayer, "selection", "Select * where ccstyle=97 or ccstyle=98 or ccstyle=99"}
        Opts.Input.[Toll Set] = {db_linklyr , llayer}
        ret_value = RunMacro("TCB Run Operation", "Highway Network Setting", Opts, &Ret)
        if !ret_value then goto quit 
    
    end
    quit:
    return(ret_value)
endMacro

//**************************************
//*    Create TOD Skim Matrices     
//**************************************     
Macro "Build Hwy Skims"(network_file, db_nodelyr, nlayer, skim, SkimFields, vot)    
    shared Scen_Dir

    Opts = null
    Opts.Input.Network = network_file
    Opts.Input.[Origin Set] = {db_nodelyr, nlayer, "Selection", "Select * where CCSTYLE=97 or CCSTYLE=98 or CCSTYLE=99"}
    Opts.Input.[Destination Set] = {db_nodelyr, nlayer, "Selection"}
    Opts.Input.[Via Set] = {db_nodelyr, nlayer}
    Opts.Field.Minimize = SkimFields[1]
	Opts.Field.[Skim Fields] = {{"RiverX","All"},{SkimFields[2],"All"}}
    Opts.Field.Nodes = nlayer + ".ID"
    Opts.Output.[Output Matrix].Label = "Shortest Path"
    Opts.Output.[Output Matrix].[File Name] = Scen_Dir + "outputs\\" + skim[1]
    ret_value = RunMacro("TCB Run Procedure","TCSPMAT", Opts, &Ret)
    if !ret_value then goto quit

    // Add Matrix Core "Shortest Path - "+SkimField. After adding new skim "RiverX", output matrix core name was different. 
	// So, this step was added to add a consistent core name and avoid breaking the model code.
    Opts = null
    Opts.Input.[Input Matrix] = Scen_Dir + "outputs\\" + skim[1]
    Opts.Input.[New Core] = "Shortest Path - " + SkimFields[1]
    ret_value = RunMacro("TCB Run Operation", "Add Matrix Core", Opts, &Ret)
    if !ret_value then goto quit
	
	// set the new matrix core to skimmed field
	m = OpenMatrix(Scen_Dir + "outputs\\" + skim[1],)
	mc1 = CreateMatrixCurrency(m, SkimFields[1],,, )
	mc2 = CreateMatrixCurrency(m, "Shortest Path - "+SkimFields[1],,, )
    mc2 := mc1

    //add taz index
    Opts = null
    Opts.Input.[Current Matrix] = Scen_Dir + "outputs\\" + skim[1]
    Opts.Input.[Index Type] = "Both"
    Opts.Input.[View Set] = {db_nodelyr, nlayer, "Selection", "Select * where CCSTYLE=99"}
    Opts.Input.[Old ID Field] = {db_nodelyr, "ID"}
    Opts.Input.[New ID Field] = {db_nodelyr, "ID"}
    Opts.Output.[New Index] = "TAZ_ID"
    ret_value = RunMacro("TCB Run Operation", "Add Matrix Index", Opts, &Ret)
    if !ret_value then goto quit

    //add external station index
    Opts = null
    Opts.Input.[Current Matrix] = Scen_Dir + "outputs\\" + skim[1]
    Opts.Input.[Index Type] = "Both"
    Opts.Input.[View Set] = {db_nodelyr, nlayer, "Selection", "Select * where CCSTYLE=97 or CCSTYLE=98"}
    Opts.Input.[Old ID Field] = {db_nodelyr, "ID"}
    Opts.Input.[New ID Field] = {db_nodelyr, "ID"}
    Opts.Output.[New Index] = "ee"
    ret_value = RunMacro("TCB Run Operation", "Add Matrix Index", Opts, &Ret)
    if !ret_value then goto quit
    
    // calculate the intrazonal travel time for tazs
    Opts = null
    Opts.Input.[Matrix Currency] = {Scen_Dir + "outputs\\" + skim[1], "Shortest Path - "+SkimFields[1], "TAZ_ID", "TAZ_ID"}
    Opts.Global.Factor = 0.5
    Opts.Global.Neighbors = 3
    Opts.Global.Operation = 1
    Opts.Global.[Treat Missing] = 2
    ret_value = RunMacro("TCB Run Procedure", "Intrazonal", Opts, &Ret)
    if !ret_value then goto quit     	

    mc = RunMacro("TCB Create Matrix Currency", Scen_Dir + "outputs\\" + skim[1], "Shortest Path - "+SkimFields[1], "ee", "ee")
    ret_value = (mc <> null)
    if !ret_value then goto quit

    FillMatrix(mc,,, {"Copy", 0}, {{"Diagonal", "Yes"}})
    quit:
    return(ret_value)
endMacro

//**************************************
//*    Add Intrazonal and Terminal   
//**************************************  
Macro "Add Intrazonal & Terminal Times"(skim, SkimFields)
    shared Scen_Dir  

    //Sum Peak Skim and terminal time. 
    Opts = null
    Opts.Input.[Matrix Currency] = {Scen_Dir + "outputs\\" + skim[1], "Shortest Path - "+SkimFields[1], "TAZ_ID", "TAZ_ID"}
    Opts.Input.[Core Currencies] = {{Scen_Dir + "outputs\\" + skim[1], "Shortest Path - "+SkimFields[1], "TAZ_ID", "TAZ_ID"}, {Scen_Dir + "outputs\\terminal_time.mtx", "total_time", "TAZ_ID", "TAZ_ID"}}
    Opts.Global.Method = 7 
    Opts.Global.[Cell Range] = 2
    Opts.Global.[Matrix K] = {1, 1}
    Opts.Global.[Force Missing] = "No"
    ret_value = RunMacro("TCB Run Operation", "Fill Matrices", Opts)
    if !ret_value then goto quit
            
    //Add Matrix Core "Length"
    Opts = null
    Opts.Input.[Input Matrix] = Scen_Dir + "outputs\\" + skim[1]
    Opts.Input.[New Core] = "Length"
    ret_value = RunMacro("TCB Run Operation", "Add Matrix Core", Opts, &Ret)
    if !ret_value then goto quit
    
    //Merge Matrices
    Opts = null
    Opts.Input.[Target Currency] = {Scen_Dir + "outputs\\" + skim[1], "Length", "Origin", "Destination"}
    Opts.Input.[Source Currencies] = {{Scen_Dir +  "outputs\\ExtDistSkims.mtx", "Length", "Origin", "Destination"}}
    Opts.Global.[Missing Option].[Force Missing] = "No"
    ret_value = RunMacro("TCB Run Operation", "Merge Matrices", Opts, &Ret)
    if !ret_value then goto quit
    
    //Intrazonal for length matrix
    Opts = null
    Opts.Input.[Matrix Currency] = {Scen_Dir + "outputs\\" + skim[1], "Length", "Origin", "Destination"}
    Opts.Global.Factor = 1
    Opts.Global.Neighbors = 3
    Opts.Global.Operation = 1
    Opts.Global.[Treat Missing] = 1
    ret_value = RunMacro("TCB Run Procedure", "Intrazonal", Opts, &Ret)
    if !ret_value then goto quit
          
    quit:
    return(ret_value)
endMacro

Macro "AddCore" (HwySkims,CoreCount)
    shared Scen_Dir, loop

    // add core to skims except ff
    for i=1 to CoreCount do
        inMat = Scen_Dir + "outputs\\" + HwySkims[1]
        m = OpenMatrix(inMat,)
        
        coreName = "Shortest Path - [time_" + HwySkims[3] + "_AB_time_" + HwySkims[3] + "_BA]"
        
        AddMatrixCore(m, coreName)
        
        mc1 = CreateMatrixCurrency(m, "Shortest Path - _MSATime" + HwySkims[3],,, )
        mc2 = CreateMatrixCurrency(m, coreName,,, )
        
        // set the new core to MSA time core
        mc2 := mc1
    end

endMacro

Macro "SaveAndCopySkims" (HwySkims)
    shared Scen_Dir, loop

    directory = Scen_Dir + "outputs\\Skims_iter" + string(loop)
    info = GetDirectoryInfo(directory, "Directory")
    
    if info = null then do
        CreateDirectory(directory)
    end
    
    // save by loop numbers
    for i=1 to HwySkims.Length do

        inMat = Scen_Dir + "outputs\\" + HwySkims[1]
        file_info = SplitPath(inMat)
        
        // save skims
        outMat = directory + "\\" + file_info[3] + "_" + string(loop) + ".mtx"
        CopyFile(inMat, outMat)  
        
    end

endMacro
