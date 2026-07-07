//**************************************
//*  					Part 7  					   	 *
//*					Highway Assignment					 *
//**************************************

//Pre Assignment
Macro "Pre_Assignment" (Args)
	shared prj_dry_run  if prj_dry_run then return(1)
	shared Scen_Dir, feedback_iteration
	shared periods1
	
	starttime = RunMacro("RuntimeLog", {"Highay Pre Assignment ", null})
	RunMacro("HwycadLog", {"8.1 HwyAssignment.rsc", "  ****** Pre Assignment ****** "})
	
	// Input highway layer
	hwy_db = Args.[hwy db]	
	HourlyTable=Args.[Hourly]
	PA_Matrix=Args.[PA Matrix]
    Freight_Matrix = Args.[Freight OD]
	
    // Flags for EE and II trucks
    IISU_include = Args.[IISU_flags]
    IESU_include = Args.[IESU_flags]
    EESU_include = Args.[EESU_flags]
    IIMU_include = Args.[IIMU_flags]
    EIMU_include = Args.[EIMU_flags]
    IEMU_include = Args.[IEMU_flags]
    EEMU_include = Args.[EEMU_flags]

	//auto assignment classes
	auto_assign_classes = Args.[Auto_Assign_Classes]	

    //// This needs to be changed to capture all of the (up to 27) new output matrices (6 for each period) - a complete path spec for each
	OD = {Args.[AM OD Matrix], Args.[MD OD Matrix], Args.[PM OD Matrix], Args.[OP OD Matrix]}

    // Open the highway layer
	layers = GetDBlayers(hwy_db)
	llayer = layers[2]
	nlayer = layers[1]
	db_linklyr = highway_layer + "|" + llayer

	// combine all OD preloads
	intitialization:
	nonhh    = {"IICOM", "IISU", "IIMU","IEAUTO", "IESU","EEMU","EESU"}

	//modes    = {"DA","SR2","SR3"}
	periods1 = {"AM","MD","PM","OP"}
	periods2 = {0,1,2,3}

    // Fill airport trips - TODO: Include airport trips in special generators?
    //RunMacro("Fill Highway Airport Trips", Args)
	
	RunMacro("HwycadLog", {"Add visitor trips ", ""})
	RunMacro("Add Visitor Demand", Args)	   //AUTO by 4 time periods
	
	RunMacro("HwycadLog", {"Add internal truck demand ", null})
	RunMacro("Add Internal Truck Demand", Args)  	  //SUT, MUT by 4 time periods - one matrix
	
	RunMacro("HwycadLog", {"Add internal commercial vehicle demand ", null})
	RunMacro("Add Commercial Vehicle Demand", Args)  //CV by 4 time periods - one matrix
	
	RunMacro("HwycadLog", {"Add external truck demand ", null})
	RunMacro("Add External Truck Demand", Args) 	//SUT, MUT by 4 time periods - four matrices
	
	RunMacro("HwycadLog", {"Add external auto demand ", ""})
	RunMacro("Add External Auto Demand", Args)	   //AUTO by 4 time periods

	////These lines need to be updated too, the reflect the new demand matrices	
	am_od_matrix = OpenMatrix(Args.[AM OD Matrix],)
	pm_od_matrix = OpenMatrix(Args.[PM OD Matrix],)
	md_od_matrix = OpenMatrix(Args.[MD OD Matrix],)
	op_od_matrix = OpenMatrix(Args.[OP OD Matrix],)
	allod={am_od_matrix,md_od_matrix,pm_od_matrix,op_od_matrix}
    
	//add these cores to each of the new OD matrices for the eventual vehicle classes assignment
	labels_vehicle={"Passenger_low","Passenger_med","Passenger_high","Commercial",
					"SingleUnit","MU","Preload_EIMU","Preload_IEMU","Preload_EEMU",
					"Preload_IESU","Preload_EESU","Preload_Pass","HOV_low","HOV_med",
					"HOV_high","HOV2_low","HOV2_med","HOV2_high","HOV3_low","HOV3_med",
					"HOV3_high","Autos_low","Autos_med","Autos_high"}

	/*Other currencies established below are pre-populated with trips from DaySim: "Passenger_SOV_low", 
	"Passenger_SOV_med", "Passenger_SOV_high",  "Passenger_HOV2_low", "Passenger_HOV2_med", 
	"Passenger_HOV2_high", "Passenger_HOV3_low", "Passenger_HOV3_med", "Passenger_HOV3_high", 
	"IICOM", "IISU", "IESU", "EESU", "IIMU", "EEMU", "EIMU", "IEMU", "IEAUTO", "EEAUTO", "Preload_MU", 
	"Preload_SU"*/

	for p=1 to periods1.length do
		
		UpdateProgressBar("Assignment - Processing Matrices for Assignments -"+ periods1[p], )
		RunMacro("HwycadLog", {"Highway Assignment - Processing Matrices for ", periods1[p]})
		
		for i=1 to labels_vehicle.length do
			matrix_cores = GetMatrixCoreNames(allod[p])
				
			for core=1 to matrix_cores.Length do
				if matrix_cores[core]=labels_vehicle[i] then DropMatrixCore(allod[p], labels_vehicle[i])
			end
		
			AddMatrixCore(allod[p], labels_vehicle[i])
		end
                            
        //Matrices mc1, mc2, and mc3 pertain to the SOVs in auto_assign_classes = 2 after the HOVF is applied 
		RunMacro("TCB Init")
        mc1 = RunMacro("TCB Create Matrix Currency", OD[p], "Passenger_low", "Rows", "Cols")
        ok = (mc1 <> null)
        if !ok then goto quit
        
        mc2 = RunMacro("TCB Create Matrix Currency", OD[p], "Passenger_med", "Rows", "Cols")
        ok = (mc2 <> null)
        if !ok then goto quit

        mc3 = RunMacro("TCB Create Matrix Currency", OD[p], "Passenger_high", "Rows", "Cols")
        ok = (mc3 <> null)
        if !ok then goto quit

		//Preloads apply to all auto_assign_classes - mc6 = mc5 + mc4
        mc4 = RunMacro("TCB Create Matrix Currency", OD[p], "IEAUTO", "Rows", "Cols")
        ok = (mc4 <> null)
        if !ok then goto quit

        mc5 = RunMacro("TCB Create Matrix Currency", OD[p], "EEAUTO", "Rows", "Cols")
        ok = (mc5 <> null)
        if !ok then goto quit
        
        mc6 = RunMacro("TCB Create Matrix Currency", OD[p], "Preload_PASS", "Rows", "Cols")
        ok = (mc6 <> null)
        if !ok then goto quit
		       
		//mc7 to mc15 pertain to auto_assign_classes = 3 before the HOVF is applied
        mc7 = RunMacro("TCB Create Matrix Currency", OD[p], "Passenger_SOV_low", "Rows", "Cols")
        ok = (mc7 <> null)
        if !ok then goto quit

        mc8 = RunMacro("TCB Create Matrix Currency", OD[p], "Passenger_SOV_med", "Rows", "Cols")
        ok = (mc8 <> null)
        if !ok then goto quit

        mc9 = RunMacro("TCB Create Matrix Currency", OD[p], "Passenger_SOV_high", "Rows", "Cols")
        ok = (mc9 <> null)
        if !ok then goto quit
        
        mc10 = RunMacro("TCB Create Matrix Currency", OD[p], "Passenger_HOV2_low", "Rows", "Cols")
        ok = (mc10 <> null)
        if !ok then goto quit

        mc11 = RunMacro("TCB Create Matrix Currency", OD[p], "Passenger_HOV2_med", "Rows", "Cols")
        ok = (mc11 <> null)
        if !ok then goto quit

        mc12 = RunMacro("TCB Create Matrix Currency", OD[p], "Passenger_HOV2_high", "Rows", "Cols")
        ok = (mc12 <> null)
        if !ok then goto quit
		
        mc13 = RunMacro("TCB Create Matrix Currency", OD[p], "Passenger_HOV3_low", "Rows", "Cols")
        ok = (mc13 <> null)
        if !ok then goto quit			

        mc14 = RunMacro("TCB Create Matrix Currency", OD[p], "Passenger_HOV3_med", "Rows", "Cols")
        ok = (mc14 <> null)
        if !ok then goto quit			

        mc15 = RunMacro("TCB Create Matrix Currency", OD[p], "Passenger_HOV3_high", "Rows", "Cols")
        ok = (mc15 <> null)
        if !ok then goto quit			
        
		//mc16 to 21 pertain to auto_assign_classes = 3 after the HOVF is applied
        mc16 = RunMacro("TCB Create Matrix Currency", OD[p], "HOV2_low", "Rows", "Cols")
        ok = (mc16 <> null)
        if !ok then goto quit

        mc17 = RunMacro("TCB Create Matrix Currency", OD[p], "HOV2_med", "Rows", "Cols")
        ok = (mc17 <> null)
        if !ok then goto quit

        mc18 = RunMacro("TCB Create Matrix Currency", OD[p], "HOV2_high", "Rows", "Cols")
        ok = (mc18 <> null)
        if !ok then goto quit

        mc19 = RunMacro("TCB Create Matrix Currency", OD[p], "HOV3_low", "Rows", "Cols")
        ok = (mc19 <> null)
        if !ok then goto quit

        mc20 = RunMacro("TCB Create Matrix Currency", OD[p], "HOV3_med", "Rows", "Cols")
        ok = (mc20 <> null)
        if !ok then goto quit

        mc21 = RunMacro("TCB Create Matrix Currency", OD[p], "HOV3_high", "Rows", "Cols")
        ok = (mc21 <> null)
        if !ok then goto quit

		//Matrices mc22, mc23, and mc24 pertain to auto_assign_classes = 2
        mc22 = RunMacro("TCB Create Matrix Currency", OD[p], "HOV_low", "Rows", "Cols")
        ok = (mc22 <> null)
        if !ok then goto quit

        mc23 = RunMacro("TCB Create Matrix Currency", OD[p], "HOV_med", "Rows", "Cols")
        ok = (mc23 <> null)
        if !ok then goto quit

        mc24 = RunMacro("TCB Create Matrix Currency", OD[p], "HOV_high", "Rows", "Cols")
        ok = (mc24 <> null)
        if !ok then goto quit

		//mc25-27 pertain to auto_assign_classes = 1
        mc25 = RunMacro("TCB Create Matrix Currency", OD[p], "Autos_low", "Rows", "Cols")
        ok = (mc25 <> null)
        if !ok then goto quit		

        mc26 = RunMacro("TCB Create Matrix Currency", OD[p], "Autos_med", "Rows", "Cols")
        ok = (mc26 <> null)
        if !ok then goto quit		

        mc27 = RunMacro("TCB Create Matrix Currency", OD[p], "Autos_high", "Rows", "Cols")
        ok = (mc27 <> null)
        if !ok then goto quit		

        //preload EI and IE PASS
        mc6 := nz(mc5)+nz(mc4)
		
        HOVF=Args.HOVF
        HOVF2=1-HOVF
		
		// Passenger not using HOV lane, by vot (low, med, high)
		mc1 := nz(mc7) + HOVF*(nz(mc10) + nz(mc13))
		mc2 := nz(mc8) + HOVF*(nz(mc11) + nz(mc14))
		mc3 := nz(mc9) + HOVF*(nz(mc12) + nz(mc15))
		
		//HOV2
		mc16:=HOVF2*(nz(mc10))
		mc17:=HOVF2*(nz(mc11))
		mc18:=HOVF2*(nz(mc12))
		
		//HOV3+
		mc19:=HOVF2*(nz(mc13))
		mc20:=HOVF2*(nz(mc14))
		mc21:=HOVF2*(nz(mc15))
		
		//HOV = HOV2+HOV3
		mc22 := mc16 + mc19
		mc23 := mc17 + mc20
		mc24 := mc18 + mc21
		
		//All Autos = SOV+HOV2+HOV3
		mc25 := mc1 + mc22
		mc26 := mc2 + mc23
		mc27 := mc3 + mc24
		
		//if only one auto assignment class then add all autos (sov and hov) into passenger class
		///doesn't seem like we need this?
		// if (auto_assign_classes=1) then do
		// 	//passenger = sov+hov2+hov3
		// 	mc1 := mc1 + mc22
		// 	mc2 := mc2 + mc23
		// 	mc3 := mc3 + mc24
		// end
        
        // Commercial Vehicle trips
        mc1 = RunMacro("TCB Create Matrix Currency", OD[p], "Commercial", "Rows", "Cols")
        ok = (mc1 <> null)
        if !ok then goto quit

        mc2 = RunMacro("TCB Create Matrix Currency", OD[p], "IICOM", "Rows", "Cols")
        ok = (mc2 <> null)
        if !ok then goto quit
        
        // Commercial
        mc1 := nz(mc2)

        // Single Unit Vehicle trips
        mc1 = RunMacro("TCB Create Matrix Currency", OD[p], "SingleUnit", "Rows", "Cols")
        ok = (mc1 <> null)
        if !ok then goto quit

        mc2 = RunMacro("TCB Create Matrix Currency", OD[p], "IISU", "Rows", "Cols")
        ok = (mc2 <> null)
        if !ok then goto quit

        mc3 = RunMacro("TCB Create Matrix Currency", OD[p], "IESU", "Rows", "Cols")
        ok = (mc3 <> null)
        if !ok then goto quit

        mc4 = RunMacro("TCB Create Matrix Currency", OD[p], "EESU", "Rows", "Cols")
        ok = (mc4 <> null)
        if !ok then goto quit
            
        mc5 = RunMacro("TCB Create Matrix Currency", OD[p], "Preload_IESU", "Rows", "Cols")
        ok = (mc5 <> null)
        if !ok then goto quit
        
        mc6 = RunMacro("TCB Create Matrix Currency", OD[p], "Preload_EESU", "Rows", "Cols")
        ok = (mc6 <> null)
        if !ok then goto quit        
        
        // II SU
        if(IISU_include[p]=1) then mc1 := nz(mc2)
        else mc1 := 0
        
        //PRELOAD IE SU
        if(IESU_include[p]=1) then mc5 := nz(mc3)
        else mc5 :=0
        
        // PRELOAD EE SU
        if(EESU_include[p]=1) then mc6 := nz(mc4)
        else mc6 := 0
        
        // Multi-Unit Vehicle(II), EI,IE,EE are preloaded trips        
        mc1 = RunMacro("TCB Create Matrix Currency", OD[p], "MU", "Rows", "Cols")
        ok = (mc1 <> null)
        if !ok then goto quit

        mc2 = RunMacro("TCB Create Matrix Currency", OD[p], "IIMU", "Rows", "Cols")
        ok = (mc2 <> null)
        if !ok then goto quit
           
        mc3 = RunMacro("TCB Create Matrix Currency",  OD[p], "EEMU", "Rows", "Cols")
        ok = (mc3 <> null)
        if !ok then goto quit
        
        mc4 = RunMacro("TCB Create Matrix Currency",  OD[p], "EIMU", "Rows", "Cols")
        ok = (mc4 <> null)
        if !ok then goto quit
        
        mc5 = RunMacro("TCB Create Matrix Currency",  OD[p], "IEMU", "Rows", "Cols")
        ok = (mc5 <> null)
        if !ok then goto quit
       
        mc6 = RunMacro("TCB Create Matrix Currency", OD[p], "Preload_EIMU", "Rows", "Cols")
        ok = (mc6 <> null)
        if !ok then goto quit
		mc6 := nz(mc6)

        mc7 = RunMacro("TCB Create Matrix Currency", OD[p], "Preload_IEMU", "Rows", "Cols")
        ok = (mc7 <> null)
        if !ok then goto quit
		mc7 := nz(mc7)        
        
        mc8 = RunMacro("TCB Create Matrix Currency", OD[p], "Preload_EEMU", "Rows", "Cols")
        ok = (mc8 <> null)
        if !ok then goto quit
		mc8 := nz(mc8)        
        
        // IIMU
        if(IIMU_include[p]=1) then mc1 := nz(mc2)
        else mc1 := 0
        
        //preload EIMU
        if(EIMU_include[p]=1) then mc6 := nz(mc4)
        else mc6 := 0

        //preload IEMU
        if(IEMU_include[p]=1) then mc7 := nz(mc5)
        else mc7 := 0
        
        //preload EEMU
        if (EEMU_include[p]=1) then mc8 := nz(mc3)
        else mc8 := 0
        
	end

	ok=1
	
	endtime = RunMacro("RuntimeLog", {"Highay Pre Assignment ", starttime})
	
	quit:
	//CloseMap(temp_map)
	return(ok)
	
endMacro

Macro "Add Visitor Demand" (Args)
	shared periods1, Scen_Dir
	//SOV_AM, SR2_AM, SR3_AM
	//SOV_MD, SR2_MD, SR3_MD
	//SOV_PM, SR2_PM, SR3_PM
	//SOV_OP, SR2_OP, SR3_OP

	//This line works because these are the DaySim output matrices	
	OD = {Args.[AM OD Matrix], Args.[MD OD Matrix], Args.[PM OD Matrix], Args.[OP OD Matrix]}
	
	//II_Visitor = Args.[II Visitor OD Matrix]
	II_Visitor = Scen_Dir + "outputs\\Visitor_OD.mtx"
	
	cores_source = {"SOV_", "SR2_", "SR3_"} //visitor matrix cored

	//Visitor trips will get added into the general passenger OD matrices corresponding to "high" VOT
	cores_target = {"Passenger_SOV_high","Passenger_HOV2_high","Passenger_HOV3_high"} //OD Tables
	
	for p=1 to periods1.length do				
		for core=1 to cores_source.length do
			mc_target = RunMacro("TCB Create Matrix Currency", OD[p], cores_target[core], "Rows", "Cols")
			mc_source = RunMacro("TCB Create Matrix Currency", II_Visitor, cores_source[core] + periods1[p], "TAZID", "TAZID")
			
			mc_target := mc_target + nz(mc_source)
		end
	end 
	
	mc_target = null
	mc_source = null

endMacro

Macro "Add Internal Truck Demand" (Args)
	shared periods1, Scen_Dir
	//AM_SUT, MD_SUT, PM_SUT, OP_SUT
	//AM_MUT, MD_MUT, PM_MUT, OP_MUT
	
	OD = {Args.[AM OD Matrix], Args.[MD OD Matrix], Args.[PM OD Matrix], Args.[OP OD Matrix]}
	//II_Truck = Args.[II Truck OD Matrix]
	II_Truck = Scen_Dir + "outputs\\Truck_OD.mtx"
	
	cores_source = {"_SUT", "_MUT"} //external truck demand tables
	cores_target = {"IISU", "IIMU"} //OD Tables
	
	for p=1 to periods1.length do				
		for core=1 to cores_source.length do
			mc_target = RunMacro("TCB Create Matrix Currency", OD[p], cores_target[core], "Rows", "Cols")
			mc_source = RunMacro("TCB Create Matrix Currency", II_Truck, periods1[p] + cores_source[core], "Rows", "Cols")
			
			mc_target := nz(mc_source)
		end
	end 
	
	mc_target = null
	mc_source = null

endMacro

Macro "Add Commercial Vehicle Demand" (Args)
	shared periods1, Scen_Dir
	//AM_CV, MD_CV, PM_CV, OP_CV
	
	OD = {Args.[AM OD Matrix], Args.[MD OD Matrix], Args.[PM OD Matrix], Args.[OP OD Matrix]}
	//II_CV = Args.[CV OD Matrix]
	II_CV = Scen_Dir + "outputs\\CV_OD.mtx"
	
	cores_source = {"_CV"} //external truck demand tables
	cores_target = {"IICOM"} //OD Tables
	
	for p=1 to periods1.length do				
		for core=1 to cores_source.length do
			mc_target = RunMacro("TCB Create Matrix Currency", OD[p], cores_target[core], "Rows", "Cols")
			mc_source = RunMacro("TCB Create Matrix Currency", II_CV, periods1[p] + cores_source[core], "Rows", "Cols")
			
			mc_target := nz(mc_source)
		end
	end 
	
	mc_target = null
	mc_source = null
	
endMacro

Macro "Add External Truck Demand" (Args)
	shared periods1, Scen_Dir

	//Nashville_ExtTruck_AM.mtx, Nashville_ExtTruck_MD.mtx, Nashville_ExtTruck_PM.mtx, Nashville_ExtTruck_OP.mtx
	//cores by {SU, MU} and (IE, EI, EE}
	OD = {Args.[AM OD Matrix], Args.[MD OD Matrix], Args.[PM OD Matrix], Args.[OP OD Matrix]}
	
	//Ext_Truck = {Args.[AM ExtTruck Matrix], Args.[MD ExtTruck Matrix], Args.[PM ExtTruck Matrix], Args.[OP ExtTruck Matrix]}
	Ext_Truck = {Scen_Dir + "Inputs\\Nashville_ExtTrucks_AM.mtx", Scen_Dir + "Inputs\\Nashville_ExtTrucks_MD.mtx", Scen_Dir + "Inputs\\Nashville_ExtTrucks_PM.mtx", Scen_Dir + "Inputs\\Nashville_ExtTrucks_OP.mtx"}
	
	cores_source = {"SU_IE", "SU_EI", "SU_EE", "MU_IE", "MU_EI", "MU_EE"} //external truck demand tables
	cores_target = {"IESU", "IESU", "EESU", "IEMU", "EIMU", "EEMU"} //OD Tables
	
	for p=1 to periods1.length do
		od_matrix = OpenMatrix(OD[p],)
		
		matrix_cores = GetMatrixCoreNames(od_matrix)
		for core=1 to matrix_cores.Length do
			if matrix_cores[core]="IEMU" then DropMatrixCore(od_matrix, "IEMU")
			if matrix_cores[core]="EIMU" then DropMatrixCore(od_matrix, "EIMU")
			if matrix_cores[core]="EEMU" then DropMatrixCore(od_matrix, "EEMU")
		end
		
		AddMatrixCore(od_matrix, "IEMU")
		AddMatrixCore(od_matrix, "EIMU")
		AddMatrixCore(od_matrix, "EEMU")
		
		for core=1 to cores_source.length do
			mc_target = RunMacro("TCB Create Matrix Currency", OD[p], cores_target[core], "Rows", "Cols")
			mc_source = RunMacro("TCB Create Matrix Currency", Ext_Truck[p], cores_source[core], "Rows", "Cols")
			
			mc_target := nz(mc_target) + nz(mc_source)
		end
	
	end 
	
	mc_target = null
	mc_source = null
	
endMacro

Macro "Add External Auto Demand" (Args)
	shared periods1, Scen_Dir
	
	OD = {Args.[AM OD Matrix], Args.[MD OD Matrix], Args.[PM OD Matrix], Args.[OP OD Matrix]}
	//Ext_Auto = {Args.[AM ExtAuto Matrix], Args.[MD ExtAuto Matrix], Args.[PM ExtAuto Matrix], Args.[OP ExtAuto Matrix]}
	Ext_Auto = {Scen_Dir + "Inputs\\Nashville_ExtAutos_AM.mtx", Scen_Dir + "Inputs\\Nashville_ExtAutos_MD.mtx", Scen_Dir + "Inputs\\Nashville_ExtAutos_PM.mtx", Scen_Dir + "Inputs\\Nashville_ExtAutos_OP.mtx"}
	
	cores_source = {"AUTO_IE", "AUTO_EI", "AUTO_EE"} //external auto demand tables
	cores_target = {"IEAUTO", "IEAUTO", "EEAUTO"} //OD Tables
	
	for p=1 to periods1.length do				
		for core=1 to cores_source.length do
			mc_target = RunMacro("TCB Create Matrix Currency", OD[p], cores_target[core], "Rows", "Cols")
			mc_source = RunMacro("TCB Create Matrix Currency", Ext_Auto[p], cores_source[core], "Rows", "Cols")
			
			mc_target := nz(mc_target) + nz(mc_source)
		end
	
	end 
	
	mc_target = null
	mc_source = null
	
endMacro

Macro "Traffic Assignment" (Args)// Trip Assignment

	shared Scen_Dir, feedback_iteration
	
	starttime = RunMacro("RuntimeLog", {"Highay Assignment ", null})
	RunMacro("HwycadLog", {"Highway Assignment - Network Settings", null})
    
	periods1={"AM","MD","PM","OP"}
	
	// Input highway layer
	hwy_db = Args.[hwy db]	
	HourlyTable=Args.[Hourly]
	PA_Matrix=Args.[PA Matrix]
    
	////This line needs to be updated to reflect the expanded set of OD demand matrices
	OD = {Args.[AM OD Matrix], Args.[MD OD Matrix], Args.[PM OD Matrix], Args.[OP OD Matrix]}
 	
    // Open the highway layer
	layers = GetDBlayers(hwy_db)
	llayer = layers[2]
	nlayer = layers[1]
	db_linklyr = hwy_db + "|" + llayer   
    
    // network settings
	Opts = null
	Opts.Input.Database = hwy_db
	Opts.Input.Network = Args.[Network File]
    if Args.TruckPreferred = 1 then do
        Opts.Input.[Toll Set] = {hwy_db+"|"+llayer, llayer}
    End
	Opts.Input.[Centroids Set] = {hwy_db+"|"+nlayer, nlayer, "selection", "Select * where ccstyle=99"}
	ok = RunMacro("TCB Run Operation", "Highway Network Setting", Opts, &Ret)
	if !ok then goto quit    
    
	// Create temp maps and matrices  
	temp_map = CreateMap("temp",{{"scope",Scope(Coord(-80000000, 44500000), 200.0, 100.0, 0)}})
	temp_layer = AddLayer(temp_map,llayer,hwy_db,llayer)
	temp_layer = AddLayer(temp_map,nlayer,hwy_db,nlayer)
	
/*    
    // Runs AM traffic assignment -preload
	RunMacro("HwycadLog", {"Highway Assignment - Preload Assignment for AM", null})
	UpdateProgressBar("Assignment - Preload Assignments", )
	ok = RunMacro("PreloadAssignment", Args, Args.[AM OD Matrix],"AM")
	if !ok then goto quit 

    // Runs MD traffic assignment -preload
	RunMacro("HwycadLog", {"Highway Assignment - Preload Assignment for MD", null})
	ok = RunMacro("PreloadAssignment", Args, Args.[MD OD Matrix],"MD")
	if !ok then goto quit 

    // Runs PM traffic assignment -preload
	RunMacro("HwycadLog", {"Highway Assignment - Preload Assignment for PM", null})
	ok = RunMacro("PreloadAssignment", Args, Args.[PM OD Matrix],"PM")
	if !ok then goto quit 
	  
    // Runs OP traffic assignment -preload
	RunMacro("HwycadLog", {"Highway Assignment - Preload Assignment for OP", null})
	ok = RunMacro("PreloadAssignment", Args, Args.[OP OD Matrix],"OP")
	if !ok then goto quit 

	//update the network for preload
	UpdateProgressBar("Assignment - Update the network for the preload trips", )
	
	for p=1 to periods1.length do
		preload_flow=Scen_Dir+ "outputs\\Assignment_Preload_"+periods1[p]+".bin"
		
		Opts = null
		Opts.Input.Database = hwy_db
		Opts.Input.Network = Args.[Network File]
        if Args.TruckPreferred=1 then do
            Opts.Input.[Toll Set] = {hwy_db+"|"+llayer, llayer}
        End
		Opts.Input.[Update Link Source Sets] = {{{hwy_db+"|"+llayer, preload_flow, {"ID"}, {"ID1"}}, "Network_Preload"+periods1[p]}}
		Opts.Global.[Update Network Fields].Links = {{"[Preload"+periods1[p]+"AB/BA PCE]", {"Network_Preload"+periods1[p]+".AB_Flow_PCE", "Network_Preload"+periods1[p]+".BA_Flow_PCE", , , "False"}}}
		Opts.Global.[Update Network Fields].Formulas = {}
		Opts.Flag.[Centroids in Network] = 1
		Opts.Flag.[Use Link Types] = "False"
		
		ok = RunMacro("TCB Run Operation", "Highway Network Setting", Opts, &Ret)
		if !ok then goto quit
	
	end
*/ 
    // Runs AM traffic assignment
	RunMacro("HwycadLog", {"Highway Assignment - General Assignment for AM", null})
    ok = RunMacro("GeneralAssignment", Args, Args.[AM OD Matrix],"AM")
	if !ok then goto quit 

    // Runs MD traffic assignment
	RunMacro("HwycadLog", {"Highway Assignment - General Assignment for MD", null})
    ok = RunMacro("GeneralAssignment", Args, Args.[MD OD Matrix],"MD")
	if !ok then goto quit 

    // Runs PM traffic assignment
	RunMacro("HwycadLog", {"Highway Assignment - General Assignment for PM", null})
    ok = RunMacro("GeneralAssignment", Args, Args.[PM OD Matrix],"PM")
	if !ok then goto quit 
	  
    // Runs OP traffic assignment
	RunMacro("HwycadLog", {"Highway Assignment - General Assignment for OP", null})
    ok = RunMacro("GeneralAssignment", Args, Args.[OP OD Matrix],"OP")
	if !ok then goto quit 
 
	endtime = RunMacro("RuntimeLog", {"Highay Assignment ", starttime})
	
	quit:
	CloseMap(temp_map)
	Return(ok)
    
endMacro

//preload IEAUTO, IESU, EEAUTO, EESU, IEMU, EIMU, EEMU

Macro "PreloadAssignment"(Args, allod, periods1) 
	shared Scen_Dir

	UpdateProgressBar("Assignment - Preload Assignments "+periods1, )
   
 	layers = GetDBlayers(Args.[hwy db])
    llayer = layers[2]
    nlayer = layers[1]
    hwy_db = Args.[hwy db]
    db_linklyr = hwy_db + "|" + llayer
    db_nodelyr = hwy_db + "|" + nlayer

    exclude_hov={db_linklyr, llayer, "hov", "Select * where HOV_m1_"+Args.HYEAR+" = 1"}
    
    // the exclusion set should not have links that are not in the network file, therefore add network link set condition as well.
    if Args.TruckProhibit =1 then query="Select * where (Lanes>0 and Assignment_LOC=1) and (HOV_m1_"+Args.HYEAR+" = 1|TRUCKNET=2)"
    else query="Select * where HOV_m1_"+Args.HYEAR+" = 1"

    exclude_hov_truck={db_linklyr, llayer, "hov_truck", query}
    
    SetView(llayer)    
    num_select = SelectByQuery("truck","Several",query,)
    if num_select=0 then exclude_hov_truck=null
    
	/*
	qry="Select * where HOV<>null and lanes>0"
	
	if Args.HYEAR<>"base" then do 
		n=SelectByQuery("HOV", "Several", qry,)
		if periods1="AM" or periods1="PM" then HOVSET={Args.[hwy db]+"|"+llayer, llayer, "HOV", "Select * where HOV<>null and lanes>0"}
	end
	*/    

    trucktoll = "PEN_FACTYPE"
    if Args.TruckPreferred =1 then do
        trucktoll = "TCST"
    end

	//21 MU-EI - now 29
	//22 MU-IE - now 30
	//23 MU-EE - now 31
	//24 SU-IE - now 32
	//25 SU-EE - now 33
	//26 PASS-EE - now 34 
	Opts = null
    Opts.Input.Database = Args.[hwy db]
    Opts.Input.Network = Args.[Network File]
    Opts.Input.[OD Matrix Currency] = {allod, , , }
    Opts.Input.[Exclusion Link Sets] = {exclude_hov_truck,exclude_hov_truck,exclude_hov_truck,exclude_hov_truck,exclude_hov_truck,exclude_hov}
    Opts.Field.[Turn Attributes] = { , , , , , }
    Opts.Field.[Vehicle Classes] = {29, 30, 31, 32, 33, 34}
    Opts.Field.[Fixed Toll Fields] = {trucktoll, trucktoll, trucktoll, trucktoll, trucktoll, "SCST"}
    Opts.Field.[PCE Fields] = {"None", "None", "None", "None", "None", "None"}
    Opts.Field.[VDF Fld Names] = {"[time_FF_AB_time_FF_BA]", "[capacity_"+Lower(periods1)+"_AB_capacity_"+Lower(periods1)+"_BA]", "alpha", "beta", "None"}
    Opts.Global.[Load Method] = "BFW"
    Opts.Global.[Loading Multiplier] = 1
    Opts.Global.[N Conjugate] = 2
    Opts.Global.Convergence =  Args.[Hwy Assn Convg]
    Opts.Global.Iterations = Args.[max_feedback]
    Opts.Global.[T2 Iterations] = 100
    Opts.Global.[Number of Classes] = 6
    Opts.Global.[Class PCEs] = {2.5, 2.5, 2.5, 1.5, 1.5, 1}
    Opts.Global.[Class VOIs] = {1, 1, 1, 1, 1, 1}
    Opts.Global.[VDF DLL] = "C:\\Program Files\\TransCAD 9.0\\bpr.vdf"
    Opts.Global.[VDF Defaults] = {, , 0.15, 4, 0}
    Opts.Output.[Flow Table] = Scen_Dir+ "outputs\\Assignment_Preload_"+periods1+".bin"
 
 	if Args.crit_flag=1 then do
		Opts.Output.[Critical Matrix].Label = periods1+" Crit Matrix"
		Opts.Output.[Critical Matrix].[File Name] = Scen_Dir + "outputs\\Crit_"+periods1+"_preload.mtx"
		Opts.Global.[Critical Query File] = Args.[selectlinks]
	end
    
    ret_value = RunMacro("TCB Run Procedure", "MMA", Opts, &Ret)
    if !ret_value then goto quit

	quit:
	Return(ret_value)
endMacro


Macro "GeneralAssignment"(Args, allod, periods1) 
    Shared Scen_Dir, loop
	
	//auto assignment classes
	auto_assign_classes = Args.[Auto_Assign_Classes]
	
    feedback_iteration = loop
    
 	hwy_db = Args.[hwy db]
 	layers = GetDBlayers(Args.[hwy db])
    llayer = layers[2]
    nlayer = layers[1]
    db_linklyr = hwy_db + "|" + llayer
    db_nodelyr = hwy_db + "|" + nlayer
    
	query_hov = "Select * where (Lanes>0 and Assignment_LOC=1) and (HOV_m1_"+Args.HYEAR+" = 1)"
    exclude_hov={db_linklyr, llayer, "hov", query_hov}
    
    // the exclusion set should not have links that are not in the network file, therefore add network link set condition as well.
    if Args.TruckProhibit =1 then query_truck="Select * where (Lanes>0 and Assignment_LOC=1) and (HOV_m1_"+Args.HYEAR+" = 1|TRUCKNET=2)"
    else query_truck=query_hov

    exclude_truck={db_linklyr, llayer, "hov_truck", query_truck}    
    
    SetView(llayer)    
    num_select = SelectByQuery("truck","Several",query_truck,)
    if num_select=0 then exclude_truck=null    
    
	//Truck toll for internal trips can now be TCST, since it incorporates TRUCKCOST if Args.TruckPreferred = 1
    trucktoll = "TCST"

    /*if Args.TruckPreferred =1 then do
		//Update TRUCKCOST to be TRUCKCOST + TCST
        trucktoll = "TRUCKCOST"
    end*/
 
	/*
 	SetView(llayer)
	qry="Select * where HOV<>null and lanes>0"
	if Args.HYEAR<>"base" then do 
		n=SelectByQuery("HOV", "Several", qry,)
		HOVSET={Args.[hwy db]+"|"+llayer, llayer, "HOV", "Select * where HOV<>null and lanes>0"}
	end*/ 	
	
	//The new composition of allod is:

	/*	#1 to #7 are raw matrices from DaySim used to populate #26 to #34
		1.	IICOM
		2.	IISU
		3.	IIMU
		4.	IEAUTO
		5.	IESU
		6.	EEAUTO
		7.	EESU

		#8 - #16 are raw matrices from DaySim pertain to auto_assign_classes = 3 before the HOVF is applied
		8.	Passenger_SOV_low
		9.	Passenger_SOV_med
		10.	Passenger_SOV_high
		11.	Passenger_HOV2_low
		12.	Passenger_HOV2_med
		13.	Passenger_HOV2_high
		14.	Passenger_HOV3_low
		15.	Passenger_HOV3_med
		16.	Passenger_HOV3_high

		#17 and #18 are raw matrices from DaySim
		17.	Preload_MU
		18.	Preload_SU

		19.	PersonTrips (= 1*Passenger_SOV_low + 1*Passenger_SOV_med + 1*Passenger_SOV_high + 2*Passenger_HOV2_low + 
            2*Passenger_HOV2_med + Passenger_HOV2_high + 3.5*Passenger_HOV3_low + 3.5*Passenger_HOV3_med + 3.5*Passenger_HOV3_high)

		#20 to #22 are raw matrices from DaySim used to populate #29 to #31
		20.	IEMU
		21.	EIMU
		22.	EEMU

		#23 - #25 pertain to the SOVs in auto_assign_classes = 2 or 3 after the HOVF is applied
		23.	Passenger_low
		24.	Passenger_med
		25.	Passenger_high

		#26 to #34 are assignment matrices derived from DaySim outputs
		26.	Commercial (= nz(IICOM))
		27.	SingleUnit (= nz(IISU))
		28.	MU (= nz(IIMU))
		29.	Preload_EIMU (= nz(EIMU))
		30.	Preload_IEMU (= nz(IEMU))
		31.	Preload_EEMU (= nz(EEMU))
		32.	Preload_IESU (= nz(IESU))
		33.	Preload_EESU (= nz(EESU))
		34.	Preload_Pass (= IEAUTO + EEAUTO)

		#35 to 37 pertain to auto_assign_classes = 2
		35.	HOV_low
		36.	HOV_med
		37.	HOV_high

		#38 to #43 pertain to auto_assign_classes = 3 after the HOVF is applied
		38.	HOV2_low
		39.	HOV2_med
		40.	HOV2_high
		41.	HOV3_low
		42.	HOV3_med
		43.	HOV3_high

		#44 to #46 pertain to auto_assign_classes = 1
		44.	Autos_low
		45.	Autos_med
		46.	Autos_high */
 
	assign_cost = "PEN_FACTYPE"
	scst_cost = "SCST" + periods1
	hcst_cost = "HCST" + periods1
	
	if (auto_assign_classes=1) then do 
		//17 pass (= sov+hov2+hov3) - now 44 to 46
		//18 com  - now 26
		//19 su - now 27
		//20 MU - now 28
		//21 MU-EI - now 29
		//22 MU-IE - now 30
		//23 MU-EE - now 31
		//24 SU-IE - now 32
		//25 SU-EE - now 33
		//26 PASS-EE - now 34
		assign_num_classes = 12
		//Exclude 44 to 46 and 34 from the hov lane (but we didn't reduce the number of GP lanes)
		assign_exclusion_link_sets = { 	exclude_hov,
										exclude_hov,
										exclude_hov, 
										exclude_hov, 
										exclude_truck, 
										exclude_truck, 
										exclude_truck, 
										exclude_truck, 
										exclude_truck, 
										exclude_truck, 
										exclude_truck, 
										exclude_hov}
		assign_turn_Attributes = { , , , , , , , , , , , }
		assign_veh_classes = {44, 45, 46, 26, 27, 28, 29, 30, 31, 32, 33, 34}
		assign_toll_fields = {	scst_cost,
								scst_cost,
								scst_cost, 
								scst_cost, 
								//trucktoll includes Toll_TRK or TRUCKCOST
								trucktoll, 
								trucktoll,
								//Uses the facility type penalty only for external truck traffic, not tolls 
								assign_cost, 
								assign_cost, 
								assign_cost, 
								assign_cost, 
								assign_cost, 
								scst_cost}
		assign_pce_fields = {"None", "None", "None", "None", "None", "None", "None", "None", "None", "None", "None", "None"}
		assign_class_pces = {	1,
								1,
								1, 
								1, 
								1.5, 
								2.5, 
								2.5, 
								2.5, 
								2.5, 
								1.5, 
								1.5, 
								1}
		assign_class_vois = {1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1}
	end

	if (auto_assign_classes=2) then do
		//17 pass (= sov) now 23 to 25
		//18 com  - now 26
		//19 su - now 27
		//20 MU - now 28
		//21 MU-EI - now 29
		//22 MU-IE - now 30
		//23 MU-EE - now 31
		//24 SU-IE - now 32
		//25 SU-EE - now 33
		//26 PASS-EE - now 34
		//27 HOV (= hov2+hov3) now 35 to 37
		assign_num_classes = 15
		assign_exclusion_link_sets = {	exclude_hov,
										exclude_hov,
										exclude_hov, 
										exclude_hov, 
										exclude_truck,
										exclude_truck, 
										exclude_truck, 
										exclude_truck, 
										exclude_truck, 
										exclude_truck, 
										exclude_truck, 
													,
													,	
													,
													}
		assign_turn_Attributes = { , , , , , , , , , , , , , , }
		assign_veh_classes = {23, 24, 25, 26, 27, 28, 29, 30, 31, 32, 33, 34, 35, 36, 37}
		assign_toll_fields = {	scst_cost,
								scst_cost,
								scst_cost, 
								scst_cost, 
								trucktoll, 
								trucktoll, 
								assign_cost, 
								assign_cost, 
								assign_cost, 
								assign_cost, 
								assign_cost, 
								hcst_cost,
								hcst_cost,
								hcst_cost, 
								hcst_cost}
		assign_pce_fields = {"None", "None", "None", "None", "None", "None", "None", "None", "None", "None", "None", "None", "None", "None", "None"}
		assign_class_pces = {	1, 
								1,
								1,
								1, 
								1.5, 
								2.5, 
								1, 
								2.5, 
								2.5, 
								2.5, 
								1.5, 
								1.5, 
								1,
								1,
								1}
		assign_class_vois = {1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1}
	end

	if (auto_assign_classes=3) then do
		//17 pass (= sov) now 23 to 25
		//18 com  - now 26
		//19 su - now 27
		//20 MU - now 28
		//21 MU-EI - now 29
		//22 MU-IE - now 30
		//23 MU-EE - now 31
		//24 SU-IE - now 32
		//25 SU-EE - now 33
		//26 PASS-EE - now 34 
		//28 HOV2 - now 38 to 40
		//29 HOV3 - now 41 to 43

		assign_num_classes = 18
		assign_exclusion_link_sets = {	exclude_hov,
										exclude_hov,
										exclude_hov, 
										exclude_hov, 
										exclude_truck,
										exclude_truck, 
										exclude_truck, 
										exclude_truck, 
										exclude_truck, 
										exclude_truck, 
										exclude_truck, 
													,
													,	
													,
													,
													,
													,
													}
		assign_turn_Attributes = { , , , , , , , , , , , , , , , , , }
		assign_veh_classes = {23, 24, 25, 26, 27, 28, 29, 30, 31, 32, 33, 34, 38, 39, 40, 41, 42, 43}
		assign_toll_fields = {	scst_cost,
								scst_cost,
								scst_cost, 
								scst_cost, 
								trucktoll, 
								trucktoll, 
								assign_cost, 
								assign_cost, 
								assign_cost, 
								assign_cost, 
								assign_cost, 
								hcst_cost,
								hcst_cost,
								hcst_cost, 
								hcst_cost, 
								hcst_cost, 
								hcst_cost, 
								hcst_cost}
		assign_pce_fields = {"None", "None", "None", "None", "None", "None", "None", "None", "None", "None", "None", "None", "None", "None", "None", "None", "None", "None"}
		assign_class_pces = {	1, 
								1,
								1,
								1, 
								1.5, 
								2.5, 
								1, 
								2.5, 
								2.5, 
								2.5, 
								1.5, 
								1.5, 
								1,
								1,
								1,
								1,
								1,
								1}
		assign_class_vois = {1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1}
	end
	
	UpdateProgressBar(periods1+" Assignment ", )

	Opts = null
    Opts.Input.Database = Args.[hwy db]
    Opts.Input.Network = Args.[Network File]
    Opts.Input.[OD Matrix Currency] = {allod, , , }
    Opts.Input.[Exclusion Link Sets] = assign_exclusion_link_sets
    Opts.Field.[Turn Attributes] = assign_turn_Attributes
    Opts.Field.[Vehicle Classes] = assign_veh_classes
    Opts.Field.[Fixed Toll Fields] = assign_toll_fields
    Opts.Field.[PCE Fields] = assign_pce_fields
    Opts.Field.[VDF Fld Names] = {"[time_FF_AB_time_FF_BA]", "[capacity_"+Lower(periods1)+"_AB_capacity_"+Lower(periods1)+"_BA]", "alpha", "beta", "None"}
    Opts.Global.[Load Method] = "BFW"
    Opts.Global.[Loading Multiplier] = 1
    Opts.Global.[N Conjugate] = 2
    Opts.Global.Convergence = Args.[Hwy Assn Convg]
    Opts.Global.Iterations = Args.[max_feedback]
    Opts.Global.[T2 Iterations] = 100
    Opts.Global.[Number of Classes] = assign_num_classes
    Opts.Global.[Class PCEs] = assign_class_pces
    Opts.Global.[Class VOIs] = assign_class_vois
    Opts.Global.[VDF DLL] = "C:\\Program Files\\TransCAD 9.0\\bpr.vdf"
    Opts.Global.[VDF Defaults] = { , , 0.15, 4, 0}

    Opts.Output.[Flow Table] = Scen_Dir+ "outputs\\Assignment_"+periods1+".bin"
    
    if Args.crit_flag=1 then do
		Opts.Output.[Critical Matrix].Label = periods1+" Crit Matrix"
		Opts.Output.[Critical Matrix].[File Name] = Scen_Dir + "outputs\\Crit_"+periods1+".mtx"
		Opts.Global.[Critical Query File] = Args.[selectlinks]
	end    
    
    // for feedback
    Opts.Field.[MSA Flow] = "_MSAFlow" + periods1
    Opts.Field.[MSA Cost] = "_MSATime" + periods1
    Opts.Global.[MSA Iteration] = feedback_iteration    
    
    ok = RunMacro("TCB Run Procedure", "MMA", Opts, &Ret)
    Return(ok)
EndMacro


Macro "PostProcessor" (Args)

	shared Scen_Dir, feedback_iteration, loop
	starttime = RunMacro("RuntimeLog", {"Highway Post Processing ", null})
	RunMacro("HwycadLog", {"8.1 HwyAssignment.rsc", "  ****** Highway Post Processor ****** "})

	//crit analysis result. 
	if Args.crit_flag=1 then do
		ret_value=RunMacro("Crit Link Result",Args, Scen_Dir)
		if !ret_value then goto quit
	end    
    
	// Input highway layer
	hwy_db = Args.[hwy db]
		
	//auto assignment classes
	auto_assign_classes = Args.[Auto_Assign_Classes]

	//assignment results table
	result=Args.[Assignment Result]
		
	layers = GetDBlayers(hwy_db)
	llayer = layers[2]
	nlayer = layers[1]
	
	db_linklyr = highway_layer + "|" + llayer
	
	temp_map = CreateMap("temp",{{"scope",Scope(Coord(-80000000, 44500000), 200.0, 100.0, 0)}})
	temp_layer = AddLayer(temp_map,llayer,hwy_db,llayer)
	temp_layer = AddLayer(temp_map,nlayer,hwy_db,nlayer)
   	
	UpdateProgressBar("Post Process ", )
	CreateTable("Assignment Result", result, "FFB", {
		{"ID", "Integer", 9, null, "No"},
		{"CNT", "String", 9, null, "No"},
		{"FCLASS", "Integer", 9, null, "No"},
		{"NAME", "String", 20, null, "No"},
		{"Leng","Real",8,2,"No"},
		
		{"COUNT", "Integer", 9, null, "No"},
		{"COUNT_PASS", "Integer", 9, null, "No"},
		{"COUNT_SU", "Integer", 9, null, "No"},
		{"COUNT_MU", "Integer", 9, null, "No"},
		{"COUNT_COM", "Integer", 9, null, "No"},
		
		{"VOL_TOT","Real",8,2,"No"},
		{"VOL_AB","Real",8,2,"No"},
		{"VOL_BA","Real",8,2,"No"},
		
		{"VOL_AM","Real",8,2,"No"},
		{"VOL_AM_AB","Real",8,2,"No"},
		{"VOL_AM_BA","Real",8,2,"No"},
		
		{"VOL_MD","Real",8,2,"No"},
		{"VOL_MD_AB","Real",8,2,"No"},
		{"VOL_MD_BA","Real",8,2,"No"},
		
		{"VOL_PM","Real",8,2,"No"},
		{"VOL_PM_AB","Real",8,2,"No"},
		{"VOL_PM_BA","Real",8,2,"No"},
		
		{"VOL_OP","Real",8,2,"No"},
		{"VOL_OP_AB","Real",8,2,"No"},
		{"VOL_OP_BA","Real",8,2,"No"},	

		{"VOL_PASS","Real",8,2,"No"},
		{"VOL_PASS_AB","Real",8,2,"No"},
		{"VOL_PASS_BA","Real",8,2,"No"},
		{"VOL_PASS_LOW","Real",8,2,"No"},
		{"VOL_PASS_LOW_AB","Real",8,2,"No"},
		{"VOL_PASS_LOW_BA","Real",8,2,"No"},
		{"VOL_PASS_MED","Real",8,2,"No"},
		{"VOL_PASS_MED_AB","Real",8,2,"No"},
		{"VOL_PASS_MED_BA","Real",8,2,"No"},
		{"VOL_PASS_HIGH","Real",8,2,"No"},
		{"VOL_PASS_HIGH_AB","Real",8,2,"No"},
		{"VOL_PASS_HIGH_BA","Real",8,2,"No"},
		
		{"VOL_PASS_AM","Real",8,2,"No"},
		{"VOL_PASS_AM_AB","Real",8,2,"No"},
		{"VOL_PASS_AM_BA","Real",8,2,"No"},
		{"VOL_PASS_LOW_AM","Real",8,2,"No"},
		{"VOL_PASS_LOW_AM_AB","Real",8,2,"No"},
		{"VOL_PASS_LOW_AM_BA","Real",8,2,"No"},
		{"VOL_PASS_MED_AM","Real",8,2,"No"},
		{"VOL_PASS_MED_AM_AB","Real",8,2,"No"},
		{"VOL_PASS_MED_AM_BA","Real",8,2,"No"},
		{"VOL_PASS_HIGH_AM","Real",8,2,"No"},
		{"VOL_PASS_HIGH_AM_AB","Real",8,2,"No"},
		{"VOL_PASS_HIGH_AM_BA","Real",8,2,"No"},
		
		{"VOL_PASS_MD","Real",8,2,"No"},
		{"VOL_PASS_MD_AB","Real",8,2,"No"},
		{"VOL_PASS_MD_BA","Real",8,2,"No"},
		{"VOL_PASS_LOW_MD","Real",8,2,"No"},
		{"VOL_PASS_LOW_MD_AB","Real",8,2,"No"},
		{"VOL_PASS_LOW_MD_BA","Real",8,2,"No"},
		{"VOL_PASS_MED_MD","Real",8,2,"No"},
		{"VOL_PASS_MED_MD_AB","Real",8,2,"No"},
		{"VOL_PASS_MED_MD_BA","Real",8,2,"No"},
		{"VOL_PASS_HIGH_MD","Real",8,2,"No"},
		{"VOL_PASS_HIGH_MD_AB","Real",8,2,"No"},
		{"VOL_PASS_HIGH_MD_BA","Real",8,2,"No"},
		
		{"VOL_PASS_PM","Real",8,2,"No"},
		{"VOL_PASS_PM_AB","Real",8,2,"No"},
		{"VOL_PASS_PM_BA","Real",8,2,"No"},
		{"VOL_PASS_LOW_PM","Real",8,2,"No"},
		{"VOL_PASS_LOW_PM_AB","Real",8,2,"No"},
		{"VOL_PASS_LOW_PM_BA","Real",8,2,"No"},
		{"VOL_PASS_MED_PM","Real",8,2,"No"},
		{"VOL_PASS_MED_PM_AB","Real",8,2,"No"},
		{"VOL_PASS_MED_PM_BA","Real",8,2,"No"},
		{"VOL_PASS_HIGH_PM","Real",8,2,"No"},
		{"VOL_PASS_HIGH_PM_AB","Real",8,2,"No"},
		{"VOL_PASS_HIGH_PM_BA","Real",8,2,"No"},
		
		{"VOL_PASS_OP","Real",8,2,"No"},
		{"VOL_PASS_OP_AB","Real",8,2,"No"},
		{"VOL_PASS_OP_BA","Real",8,2,"No"},
		{"VOL_PASS_LOW_OP","Real",8,2,"No"},
		{"VOL_PASS_LOW_OP_AB","Real",8,2,"No"},
		{"VOL_PASS_LOW_OP_BA","Real",8,2,"No"},
		{"VOL_PASS_MED_OP","Real",8,2,"No"},
		{"VOL_PASS_MED_OP_AB","Real",8,2,"No"},
		{"VOL_PASS_MED_OP_BA","Real",8,2,"No"},
		{"VOL_PASS_HIGH_OP","Real",8,2,"No"},
		{"VOL_PASS_HIGH_OP_AB","Real",8,2,"No"},
		{"VOL_PASS_HIGH_OP_BA","Real",8,2,"No"},

		{"VOL_HOV2","Real",8,2,"No"},
		{"VOL_HOV2_AB","Real",8,2,"No"},
		{"VOL_HOV2_BA","Real",8,2,"No"},
		{"VOL_HOV2_LOW","Real",8,2,"No"},
		{"VOL_HOV2_LOW_AB","Real",8,2,"No"},
		{"VOL_HOV2_LOW_BA","Real",8,2,"No"},
		{"VOL_HOV2_MED","Real",8,2,"No"},
		{"VOL_HOV2_MED_AB","Real",8,2,"No"},
		{"VOL_HOV2_MED_BA","Real",8,2,"No"},
		{"VOL_HOV2_HIGH","Real",8,2,"No"},
		{"VOL_HOV2_HIGH_AB","Real",8,2,"No"},
		{"VOL_HOV2_HIGH_BA","Real",8,2,"No"},
		
		{"VOL_HOV2_AM","Real",8,2,"No"},
		{"VOL_HOV2_AM_AB","Real",8,2,"No"},
		{"VOL_HOV2_AM_BA","Real",8,2,"No"},
		{"VOL_HOV2_LOW_AM","Real",8,2,"No"},
		{"VOL_HOV2_LOW_AM_AB","Real",8,2,"No"},
		{"VOL_HOV2_LOW_AM_BA","Real",8,2,"No"},
		{"VOL_HOV2_MED_AM","Real",8,2,"No"},
		{"VOL_HOV2_MED_AM_AB","Real",8,2,"No"},
		{"VOL_HOV2_MED_AM_BA","Real",8,2,"No"},
		{"VOL_HOV2_HIGH_AM","Real",8,2,"No"},
		{"VOL_HOV2_HIGH_AM_AB","Real",8,2,"No"},
		{"VOL_HOV2_HIGH_AM_BA","Real",8,2,"No"},
		
		{"VOL_HOV2_MD","Real",8,2,"No"},
		{"VOL_HOV2_MD_AB","Real",8,2,"No"},
		{"VOL_HOV2_MD_BA","Real",8,2,"No"},
		{"VOL_HOV2_LOW_MD","Real",8,2,"No"},
		{"VOL_HOV2_LOW_MD_AB","Real",8,2,"No"},
		{"VOL_HOV2_LOW_MD_BA","Real",8,2,"No"},
		{"VOL_HOV2_MED_MD","Real",8,2,"No"},
		{"VOL_HOV2_MED_MD_AB","Real",8,2,"No"},
		{"VOL_HOV2_MED_MD_BA","Real",8,2,"No"},
		{"VOL_HOV2_HIGH_MD","Real",8,2,"No"},
		{"VOL_HOV2_HIGH_MD_AB","Real",8,2,"No"},
		{"VOL_HOV2_HIGH_MD_BA","Real",8,2,"No"},
		
		{"VOL_HOV2_PM","Real",8,2,"No"},
		{"VOL_HOV2_PM_AB","Real",8,2,"No"},
		{"VOL_HOV2_PM_BA","Real",8,2,"No"},
		{"VOL_HOV2_LOW_PM","Real",8,2,"No"},
		{"VOL_HOV2_LOW_PM_AB","Real",8,2,"No"},
		{"VOL_HOV2_LOW_PM_BA","Real",8,2,"No"},
		{"VOL_HOV2_MED_PM","Real",8,2,"No"},
		{"VOL_HOV2_MED_PM_AB","Real",8,2,"No"},
		{"VOL_HOV2_MED_PM_BA","Real",8,2,"No"},
		{"VOL_HOV2_HIGH_PM","Real",8,2,"No"},
		{"VOL_HOV2_HIGH_PM_AB","Real",8,2,"No"},
		{"VOL_HOV2_HIGH_PM_BA","Real",8,2,"No"},
		
		{"VOL_HOV2_OP","Real",8,2,"No"},
		{"VOL_HOV2_OP_AB","Real",8,2,"No"},
		{"VOL_HOV2_OP_BA","Real",8,2,"No"},
		{"VOL_HOV2_LOW_OP","Real",8,2,"No"},
		{"VOL_HOV2_LOW_OP_AB","Real",8,2,"No"},
		{"VOL_HOV2_LOW_OP_BA","Real",8,2,"No"},
		{"VOL_HOV2_MED_OP","Real",8,2,"No"},
		{"VOL_HOV2_MED_OP_AB","Real",8,2,"No"},
		{"VOL_HOV2_MED_OP_BA","Real",8,2,"No"},
		{"VOL_HOV2_HIGH_OP","Real",8,2,"No"},
		{"VOL_HOV2_HIGH_OP_AB","Real",8,2,"No"},
		{"VOL_HOV2_HIGH_OP_BA","Real",8,2,"No"},
		
		{"VOL_HOV3","Real",8,2,"No"},
		{"VOL_HOV3_AB","Real",8,2,"No"},
		{"VOL_HOV3_BA","Real",8,2,"No"},
		{"VOL_HOV3_LOW","Real",8,2,"No"},
		{"VOL_HOV3_LOW_AB","Real",8,2,"No"},
		{"VOL_HOV3_LOW_BA","Real",8,2,"No"},
		{"VOL_HOV3_MED","Real",8,2,"No"},
		{"VOL_HOV3_MED_AB","Real",8,2,"No"},
		{"VOL_HOV3_MED_BA","Real",8,2,"No"},
		{"VOL_HOV3_HIGH","Real",8,2,"No"},
		{"VOL_HOV3_HIGH_AB","Real",8,2,"No"},
		{"VOL_HOV3_HIGH_BA","Real",8,2,"No"},
		
		{"VOL_HOV3_AM","Real",8,2,"No"},
		{"VOL_HOV3_AM_AB","Real",8,2,"No"},
		{"VOL_HOV3_AM_BA","Real",8,2,"No"},
		{"VOL_HOV3_LOW_AM","Real",8,2,"No"},
		{"VOL_HOV3_LOW_AM_AB","Real",8,2,"No"},
		{"VOL_HOV3_LOW_AM_BA","Real",8,2,"No"},
		{"VOL_HOV3_MED_AM","Real",8,2,"No"},
		{"VOL_HOV3_MED_AM_AB","Real",8,2,"No"},
		{"VOL_HOV3_MED_AM_BA","Real",8,2,"No"},
		{"VOL_HOV3_HIGH_AM","Real",8,2,"No"},
		{"VOL_HOV3_HIGH_AM_AB","Real",8,2,"No"},
		{"VOL_HOV3_HIGH_AM_BA","Real",8,2,"No"},
		
		{"VOL_HOV3_MD","Real",8,2,"No"},
		{"VOL_HOV3_MD_AB","Real",8,2,"No"},
		{"VOL_HOV3_MD_BA","Real",8,2,"No"},
		{"VOL_HOV3_LOW_MD","Real",8,2,"No"},
		{"VOL_HOV3_LOW_MD_AB","Real",8,2,"No"},
		{"VOL_HOV3_LOW_MD_BA","Real",8,2,"No"},
		{"VOL_HOV3_MED_MD","Real",8,2,"No"},
		{"VOL_HOV3_MED_MD_AB","Real",8,2,"No"},
		{"VOL_HOV3_MED_MD_BA","Real",8,2,"No"},
		{"VOL_HOV3_HIGH_MD","Real",8,2,"No"},
		{"VOL_HOV3_HIGH_MD_AB","Real",8,2,"No"},
		{"VOL_HOV3_HIGH_MD_BA","Real",8,2,"No"},
		
		{"VOL_HOV3_PM","Real",8,2,"No"},
		{"VOL_HOV3_PM_AB","Real",8,2,"No"},
		{"VOL_HOV3_PM_BA","Real",8,2,"No"},
		{"VOL_HOV3_LOW_PM","Real",8,2,"No"},
		{"VOL_HOV3_LOW_PM_AB","Real",8,2,"No"},
		{"VOL_HOV3_LOW_PM_BA","Real",8,2,"No"},
		{"VOL_HOV3_MED_PM","Real",8,2,"No"},
		{"VOL_HOV3_MED_PM_AB","Real",8,2,"No"},
		{"VOL_HOV3_MED_PM_BA","Real",8,2,"No"},
		{"VOL_HOV3_HIGH_PM","Real",8,2,"No"},
		{"VOL_HOV3_HIGH_PM_AB","Real",8,2,"No"},
		{"VOL_HOV3_HIGH_PM_BA","Real",8,2,"No"},
		
		{"VOL_HOV3_OP","Real",8,2,"No"},
		{"VOL_HOV3_OP_AB","Real",8,2,"No"},
		{"VOL_HOV3_OP_BA","Real",8,2,"No"},
		{"VOL_HOV3_LOW_OP","Real",8,2,"No"},
		{"VOL_HOV3_LOW_OP_AB","Real",8,2,"No"},
		{"VOL_HOV3_LOW_OP_BA","Real",8,2,"No"},
		{"VOL_HOV3_MED_OP","Real",8,2,"No"},
		{"VOL_HOV3_MED_OP_AB","Real",8,2,"No"},
		{"VOL_HOV3_MED_OP_BA","Real",8,2,"No"},
		{"VOL_HOV3_HIGH_OP","Real",8,2,"No"},
		{"VOL_HOV3_HIGH_OP_AB","Real",8,2,"No"},
		{"VOL_HOV3_HIGH_OP_BA","Real",8,2,"No"},
		
		{"VOL_COM","Real",8,2,"No"},
		{"VOL_COM_AB","Real",8,2,"No"},
		{"VOL_COM_BA","Real",8,2,"No"},
		
		{"VOL_COM_AM","Real",8,2,"No"},
		{"VOL_COM_AM_AB","Real",8,2,"No"},
		{"VOL_COM_AM_BA","Real",8,2,"No"},
		
		{"VOL_COM_MD","Real",8,2,"No"},
		{"VOL_COM_MD_AB","Real",8,2,"No"},
		{"VOL_COM_MD_BA","Real",8,2,"No"},
		
		{"VOL_COM_PM","Real",8,2,"No"},
		{"VOL_COM_PM_AB","Real",8,2,"No"},
		{"VOL_COM_PM_BA","Real",8,2,"No"},
		
		{"VOL_COM_OP","Real",8,2,"No"},
		{"VOL_COM_OP_AB","Real",8,2,"No"},
		{"VOL_COM_OP_BA","Real",8,2,"No"},

		{"VOL_SU","Real",8,2,"No"},
		{"VOL_SU_AB","Real",8,2,"No"},
		{"VOL_SU_BA","Real",8,2,"No"},
		
		{"VOL_SU_AM","Real",8,2,"No"},
		{"VOL_SU_AM_AB","Real",8,2,"No"},
		{"VOL_SU_AM_BA","Real",8,2,"No"},
		
		{"VOL_SU_MD","Real",8,2,"No"},
		{"VOL_SU_MD_AB","Real",8,2,"No"},
		{"VOL_SU_MD_BA","Real",8,2,"No"},
		
		{"VOL_SU_PM","Real",8,2,"No"},
		{"VOL_SU_PM_AB","Real",8,2,"No"},
		{"VOL_SU_PM_BA","Real",8,2,"No"},
		
		{"VOL_SU_OP","Real",8,2,"No"},
		{"VOL_SU_OP_AB","Real",8,2,"No"},
		{"VOL_SU_OP_BA","Real",8,2,"No"},
		
		{"VOL_MU","Real",8,2,"No"},
		{"VOL_MU_AB","Real",8,2,"No"},
		{"VOL_MU_BA","Real",8,2,"No"},
		
		{"VOL_MU_AM","Real",8,2,"No"},
		{"VOL_MU_AM_AB","Real",8,2,"No"},
		{"VOL_MU_AM_BA","Real",8,2,"No"},
		
		{"VOL_MU_MD","Real",8,2,"No"},
		{"VOL_MU_MD_AB","Real",8,2,"No"},
		{"VOL_MU_MD_BA","Real",8,2,"No"},
		
		{"VOL_MU_PM","Real",8,2,"No"},
		{"VOL_MU_PM_AB","Real",8,2,"No"},
		{"VOL_MU_PM_BA","Real",8,2,"No"},
		
		{"VOL_MU_OP","Real",8,2,"No"},
		{"VOL_MU_OP_AB","Real",8,2,"No"},
		{"VOL_MU_OP_BA","Real",8,2,"No"},
		
		{"SPD_AMAB","Real",8,2,"No"},
		{"SPD_AMBA","Real",8,2,"No"},
		{"SPD_MDAB","Real",8,2,"No"},
		{"SPD_MDBA","Real",8,2,"No"},
		{"SPD_PMAB","Real",8,2,"No"},
		{"SPD_PMBA","Real",8,2,"No"},
		{"SPD_OPAB","Real",8,2,"No"},
		{"SPD_OPBA","Real",8,2,"No"},
		
		{"VMT_TOT","Real",8,2,"No"},
		{"VMT_AB","Real",8,2,"No"},
		{"VMT_BA","Real",8,2,"No"},
		
		{"VMT_AM","Real",8,2,"No"},
		{"VMT_AMAB","Real",8,2,"No"},
		{"VMT_AMBA","Real",8,2,"No"},
		
		{"VMT_MD","Real",8,2,"No"},
		{"VMT_MDAB","Real",8,2,"No"},
		{"VMT_MDBA","Real",8,2,"No"},
		
		{"VMT_PM","Real",8,2,"No"},
		{"VMT_PMAB","Real",8,2,"No"},
		{"VMT_PMBA","Real",8,2,"No"},
		
		{"VMT_OP","Real",8,2,"No"},
		{"VMT_OPAB","Real",8,2,"No"},
		{"VMT_OPBA","Real",8,2,"No"},
		
		{"SPD_INRIXAM_AB","Real",8,2,"No"},
		{"SPD_INRIXAM_BA","Real",8,2,"No"},
		{"SPD_INRIXMD_AB","Real",8,2,"No"},
		{"SPD_INRIXMD_BA","Real",8,2,"No"},
		{"SPD_INRIXPM_AB","Real",8,2,"No"},
		{"SPD_INRIXPM_BA","Real",8,2,"No"},
		{"SPD_INRIXOP_AB","Real",8,2,"No"},
		{"SPD_INRIXOP_BA","Real",8,2,"No"},
		
		{"MODAREA", "String", 25, null, "No"},
		{"MODCLASS", "String", 25, null, "No"},
        
		{"VHT_TOT", "Real",8,2,"No"},
		{"SPD_VMT_SUM", "Real",8,2,"No"},
		
		{"VC_AMAB", "Real",8,2,"No"},
		{"VC_AMBA", "Real",8,2,"No"},
		{"VC_AM", "Real",8,2,"No"},
		
		{"VC_MDAB", "Real",8,2,"No"},
		{"VC_MDBA", "Real",8,2,"No"},
		{"VC_MD", "Real",8,2,"No"},
		
		{"VC_PMAB", "Real",8,2,"No"},
		{"VC_PMBA", "Real",8,2,"No"},
		{"VC_PM", "Real",8,2,"No"},
		
		{"VC_OPAB", "Real",8,2,"No"},
		{"VC_OPBA", "Real",8,2,"No"},
		{"VC_OP", "Real",8,2,"No"},
		
		{"VC_DLY", "Real",8,2,"No"},
		
		{"LOS_AMAB", "String", 2, null, "No"},
		{"LOS_AMBA", "String", 2, null, "No"},
		{"LOS_AM", "String", 2, null, "No"},
		
		{"LOS_MDAB", "String", 2, null, "No"},
		{"LOS_MDBA", "String", 2, null, "No"},
		{"LOS_MD", "String", 2, null, "No"},
		
		{"LOS_PMAB", "String", 2, null, "No"},
		{"LOS_PMBA", "String", 2, null, "No"},
		{"LOS_PM", "String", 2, null, "No"},
		
		{"LOS_OPAB", "String", 2, null, "No"},
		{"LOS_OPBA", "String", 2, null, "No"},
		{"LOS_OP", "String", 2, null, "No"},
		
		{"LOS",  "String", 2, null, "No"},

		{"Pct_FF_Min1",  "Real",8,4,"No"},
		{"Pct_FF_Min2",  "Real",8,4,"No"},
		{"Pct_FF_Min",  "Real",8,4,"No"},
		
		{"Pct_FF_AMAB", "Real",8,4,"No"},
		{"Pct_FF_AMBA", "Real",8,4,"No"},
		{"Pct_FF_AM", "Real",8,4,"No"},
		
		{"Pct_FF_MDAB", "Real",8,4,"No"},
		{"Pct_FF_MDBA", "Real",8,4,"No"},
		{"Pct_FF_MD", "Real",8,4,"No"},
		
		{"Pct_FF_PMAB", "Real",8,4,"No"},
		{"Pct_FF_PMBA", "Real",8,4,"No"},
		{"Pct_FF_PM", "Real",8,4,"No"},
		
		{"Pct_FF_OPAB", "Real",8,4,"No"},
		{"Pct_FF_OPBA", "Real",8,4,"No"},
		{"Pct_FF_OP", "Real",8,4,"No"},

		{"MU_VHT_AMAB","Real",8,2,"No"},
		{"MU_VHT_AMBA","Real",8,2,"No"},
		{"MU_VHT_MDAB","Real",8,2,"No"},
		{"MU_VHT_MDBA","Real",8,2,"No"},
		{"MU_VHT_PMAB","Real",8,2,"No"},
		{"MU_VHT_PMBA","Real",8,2,"No"},
		{"MU_VHT_OPAB","Real",8,2,"No"},
		{"MU_VHT_OPBA","Real",8,2,"No"},
		{"MU_VHT_TOT","Real",8,2,"No"}        
		})
	
	SetView(llayer)
	qry="Select * where Assignment_Loc=1"   //keep all links used in assignment
	//qry="Select * where Assignment_Loc=1 and (County='47037' or County='47119' or County='47147' or County='47149' or County='47165' or County='47187' or County='47189')"
	n=SelectByQuery("Selection", "Several", qry,)
	if n=0 then goto quit
	
	//basic 1-5
	//counts 6,7,8
	//class count 9,10,11
	//inrix 12-19
	//misc 20,21,22
	v_network=GetDataVectors(llayer+"|Selection",
		{
		"ID","County","RTE_NME","FUNC_CLASS","Length",
		
		"AADT2010","AADTDUAL2010","IS_RL_COUNT_VOL",
		
		"PASS","SU","MU",
		
		"INRIXAM_AB",
		"INRIXAM_BA",
		"INRIXMD_AB",
		"INRIXMD_BA",
		"INRIXPM_AB",
		"INRIXPM_BA",
		"INRIXOP_AB",
		"INRIXOP_BA",
		
		"REL_COM",
		"MOD_AREA",
		"MOD_CLASS"
		},{{"Sort Order", {{"ID", "Ascending"}}}} )
	
	// reads aadt to array
	dim newAADT[v_network[8].length]
	for i=1 to v_network[8].length do // # of records in the network
		if v_network[8][i]=1 then do //if it's a real count, and assignment_loc=1 then do
			if v_network[7][i]<>null then newAADT[i]=v_network[7][i] else newAADT[i]=v_network[6][i] //writes the new aadt to the array
		end
	end
	
	AADT=ArrayToVector(newAADT)

	
	AddRecords("Assignment Result", null, null, {{"Empty Records", v_network[1].length}})
	SetDataVectors("Assignment Result|", {
		{"ID", v_network[1]},
		{"CNT", v_network[2]},
		{"NAME", v_network[3]},
		{"FCLASS", v_network[4]},
		{"Leng", v_network[5]},
		{"COUNT",AADT},
		
		{"COUNT_PASS", v_network[9]},
		{"COUNT_SU", v_network[10]},
		{"COUNT_MU", v_network[11]},
		{"SPD_INRIXAM_AB",v_network[12]},
		{"SPD_INRIXAM_BA",v_network[13]},
		{"SPD_INRIXMD_AB",v_network[14]},
		{"SPD_INRIXMD_BA",v_network[15]},
		{"SPD_INRIXPM_AB",v_network[16]},
		{"SPD_INRIXPM_BA",v_network[17]},
		{"SPD_INRIXOP_AB",v_network[18]},
		{"SPD_INRIXOP_BA",v_network[19]},
		{"COUNT_COM",v_network[20]},
		{"MODAREA",v_network[21]},
		{"MODCLASS",v_network[22]}
		
		}, )
	
	//open assignment result tables	
	OpenTable("AM Assignment Result","FFB",{Scen_Dir + "outputs\\Assignment_AM.bin",})
	OpenTable("MD Assignment Result","FFB",{Scen_Dir + "outputs\\Assignment_MD.bin",})
	OpenTable("PM Assignment Result","FFB",{Scen_Dir + "outputs\\Assignment_PM.bin",})
	OpenTable("OP Assignment Result","FFB",{Scen_Dir + "outputs\\Assignment_OP.bin",})
	
	//Match these to the field identifiers in the output table above
	vehicles={"PASS_LOW","PASS_MED","PASS_HIGH","HOV2_LOW","HOV2_MED","HOV2_HIGH","HOV3_LOW","HOV3_MED","HOV3_HIGH","COM","SU","MU"}

	//These are the field identifiers coming out of the raw assignment output table
	vehicle_names={"Passenger_low","Passenger_med","Passenger_high","HOV2_low","HOV2_med","HOV2_high","HOV3_low","HOV3_med","HOV3_high","Commercial","SingleUnit","MU"}

	periods={"AM","MD","PM","OP"}
	
	for p=1 to periods.length do
		
		//Step 1: update the MU/SU fields in the final assignment result with preload MU/SU and IIMU/IISU
		Opts = null
		Opts.Input.[Dataview Set] = {{result, Scen_Dir + "outputs\\Assignment_"+periods[p]+".bin", {"ID"}, {"ID1"}}, "Assignment Result+"+periods[p]+" Assignment"}
		Opts.Global.Fields = {	"VOL_MU_"+periods[p]+"_AB",
								"VOL_MU_"+periods[p]+"_BA",
								"VOL_SU_"+periods[p]+"_AB",
								"VOL_SU_"+periods[p]+"_BA",
								"VOL_PASS_"+periods[p]+"_AB",
								"VOL_PASS_"+periods[p]+"_BA"}
		Opts.Global.Method = "Formula"
		Opts.Global.Parameter = {	"nz(AB_FLOW_PRELOAD_EIMU)+nz(AB_FLOW_PRELOAD_IEMU)+nz(AB_FLOW_PRELOAD_EEMU)+nz(VOL_MU_"+periods[p]+"_AB)",
									"nz(BA_FLOW_PRELOAD_EIMU)+nz(BA_FLOW_PRELOAD_IEMU)+nz(BA_FLOW_PRELOAD_EEMU)+nz(VOL_MU_"+periods[p]+"_BA)",
									"nz(AB_FLOW_PRELOAD_IESU)+nz(AB_FLOW_PRELOAD_EESU)+nz(VOL_SU_"+periods[p]+"_AB)",
									"nz(BA_FLOW_PRELOAD_IESU)+nz(BA_FLOW_PRELOAD_EESU)+nz(VOL_SU_"+periods[p]+"_BA)",
									"nz(AB_FLOW_PRELOAD_Pass)+nz(VOL_PASS_"+periods[p]+"_AB)",
									"nz(BA_FLOW_PRELOAD_Pass)+nz(VOL_PASS_"+periods[p]+"_BA)"}
		ret_value = RunMacro("TCB Run Operation", "Fill Dataview", Opts, &Ret)
		if !ret_value then goto quit

		//Step 2: Flow by Vehicle Type
		for v=1 to vehicles.length do
			Opts = null
			Opts.Input.[Dataview Set] = {{result, Scen_Dir + "outputs\\Assignment_" + periods[p] + ".bin", {"ID"}, {"ID1"}}, "Assignment Result+" + periods[p] + " Assignment"}
			Opts.Global.Fields = {	"VOL_"+vehicles[v]+"_"+periods[p]+"_AB", 
									"VOL_"+vehicles[v]+"_"+periods[p]+"_BA", 
									"VOL_"+vehicles[v]+"_"+periods[p]}
			Opts.Global.Method = "Formula"

			//It would be better if these could be read off the vehicles list but it wasn't working
			if v=1 or v=4 or v=7 then veh_vot = "LOW"
				else if v=2 or v=5 or v=8 then veh_vot = "MED"
					else if v=3 or v=6 or v=9 then veh_vot = "HIGH"
						else veh_vot = ""

			//For PASS vehicles (v<4), the filling varies according to auto_assign_classes
			if (v<4 and auto_assign_classes = 1) then do
				Opts.Global.Parameter = {	"nz(AB_Flow_Autos_"+veh_vot+")",
											"nz(BA_Flow_Autos_"+veh_vot+")", 
											"nz(VOL_"+vehicles[v]+"_"+periods[p]+"_AB)+nz(VOL_"+vehicles[v]+"_"+periods[p]+"_BA)"}
			end

			if (v<4 and auto_assign_classes <> 1) then do
				Opts.Global.Parameter = {	"nz(AB_Flow_"+vehicle_names[v]+")",
											"nz(BA_Flow_"+vehicle_names[v]+")", 
											"nz(VOL_"+vehicles[v]+"_"+periods[p]+"_AB)+nz(VOL_"+vehicles[v]+"_"+periods[p]+"_BA)"}
			end								

			//For HOV2 vehicles (v>3 & v<7), we fill from the HOV field into the HOV2 field if auto_assign_classes = 2
			if (v>3 and v<7 and auto_assign_classes=2) then do
				Opts.Global.Parameter = {	"nz(AB_Flow_HOV_"+veh_vot+")",
											"nz(BA_Flow_HOV_"+veh_vot+")",
											"nz(VOL_"+vehicles[v]+"_"+periods[p]+"_AB)+nz(VOL_"+vehicles[v]+"_"+periods[p]+"_BA)"}
			end
			//Or we fill all of the fields if auto_assign_classes = 3
			if (v>3 and v<7 and auto_assign_classes=3) then do
				Opts.Global.Parameter = {	"nz(AB_Flow_"+vehicle_names[v]+")",
											"nz(BA_Flow_"+vehicle_names[v]+")", 
											"nz(VOL_"+vehicles[v]+"_"+periods[p]+"_AB)+nz(VOL_"+vehicles[v]+"_"+periods[p]+"_BA)"}
			end	
			//Or we zero out the HOV fields
			if (v>3 and v<7 and auto_assign_classes=1) then do
				Opts.Global.Parameter = {"0", "0", "0"}
			end										

			//For HOV3 vehicles (v>6 & v<10), we fill all fields directly from the corresponding field in the assignment output when auto_assign_classes = 3
			if (v>6 and v<10 and auto_assign_classes=3) then do
				Opts.Global.Parameter = {	"nz(AB_Flow_"+vehicle_names[v]+")",
											"nz(BA_Flow_"+vehicle_names[v]+")", 
											"nz(VOL_"+vehicles[v]+"_"+periods[p]+"_AB)+nz(VOL_"+vehicles[v]+"_"+periods[p]+"_BA)"}
			end
			//otherwise we zero it out
			if (v>6 and v<10 and auto_assign_classes<>3) then do
				Opts.Global.Parameter = {"0", "0", "0"}
			end

			//Trucks and commercial vehicles (v>9) are unaffected by auto_assign_classes
			if v>9 then do
				Opts.Global.Parameter = {	"nz(VOL_"+vehicles[v]+"_"+periods[p]+"_AB)+nz(AB_Flow_"+vehicle_names[v]+")",
											"nz(VOL_"+vehicles[v]+"_"+periods[p]+"_BA)+nz(BA_Flow_"+vehicle_names[v]+")", 
											"nz(VOL_"+vehicles[v]+"_"+periods[p]+"_AB)+nz(VOL_"+vehicles[v]+"_"+periods[p]+"_BA)"}			
			end

			ret_value = RunMacro("TCB Run Operation", "Fill Dataview", Opts, &Ret)
			if !ret_value then goto quit

		end
		
		//step 3: Speed by TOD
		Opts = null
		Opts.Input.[Dataview Set] = {{result, Scen_Dir+ "outputs\\Assignment_"+periods[p]+".bin", {"ID"}, {"ID1"}}, "Assignment Result+"+periods[p]+" Assignment"}
		Opts.Global.Fields = {"SPD_"+periods[p]+"AB","SPD_"+periods[p]+"BA"}
		Opts.Global.Method = "Formula"
		Opts.Global.Parameter = {"AB_Speed","BA_Speed"}
		ret_value = RunMacro("TCB Run Operation", "Fill Dataview", Opts, &Ret)
		if !ret_value then goto quit

	end
	
	//step 4 Daily VOL by vehicle class
	for v=1 to vehicles.length do
		Opts = null
		Opts.Input.[Dataview Set] = {result, "Assignment Result"}
		Opts.Global.Fields = {"VOL_"+vehicles[v]+"_AB","VOL_"+vehicles[v]+"_BA","VOL_"+vehicles[v]}
		Opts.Global.Method = "Formula"
		Opts.Global.Parameter = {	"nz(VOL_"+vehicles[v]+"_AM_AB)+nz(VOL_"+vehicles[v]+"_MD_AB)+nz(VOL_"+vehicles[v]+"_PM_AB)+nz(VOL_"+vehicles[v]+"_OP_AB)",
									"nz(VOL_"+vehicles[v]+"_AM_BA)+nz(VOL_"+vehicles[v]+"_MD_BA)+nz(VOL_"+vehicles[v]+"_PM_BA)+nz(VOL_"+vehicles[v]+"_OP_BA)",
									"nz(VOL_"+vehicles[v]+"_AB)+nz(VOL_"+vehicles[v]+"_BA)"}
		ret_value = RunMacro("TCB Run Operation", "Fill Dataview", Opts, &Ret)
		if !ret_value then goto quit
	end

	//Step 4A: Daily Vol by vehicle type (PASS, HOV2, HOV3) with directions, without regard to period or VOT
	types = {"PASS","HOV2","HOV3"}

	for n=1 to types.length do
		Opts = null
		Opts.Input.[Dataview Set] = {result, "Assignment Result"}
		Opts.Global.Fields = {"VOL_"+types[n]+"_AB","VOL_"+types[n]+"_BA","VOL_"+types[n]}
		Opts.Global.Method = "Formula"
		Opts.Global.Parameter = {	"nz(VOL_"+types[n]+"_LOW_AB)+nz(VOL_"+types[n]+"_MED_AB)+nz(VOL_"+types[n]+"_HIGH_AB)",
									"nz(VOL_"+types[n]+"_LOW_BA)+nz(VOL_"+types[n]+"_MED_BA)+nz(VOL_"+types[n]+"_HIGH_BA)",
									"nz(VOL_"+types[n]+"_LOW)+nz(VOL_"+types[n]+"_MED)+nz(VOL_"+types[n]+"_HIGH)"}
		ret_value = RunMacro("TCB Run Operation", "Fill Dataview", Opts, &Ret)
		if !ret_value then goto quit
	end
	
	//Step 4B: Daily Vol by vehicle type (PASS, HOV2, HOV3) without direction or VOT, by period
	for n=1 to types.length do
		for p=1 to periods.length do
			Opts = null
			Opts.Input.[Dataview Set] = {result, "Assignment Result"}
			Opts.Global.Fields = {"VOL_"+types[n]+"_"+periods[p]+"_AB","VOL_"+types[n]+"_"+periods[p]+"_BA","VOL_"+types[n]+"_"+periods[p]}
			Opts.Global.Method = "Formula"
			Opts.Global.Parameter = {"nz(VOL_"+types[n]+"_"+periods[p]+"_AB)+nz(VOL_"+types[n]+"_LOW_"+periods[p]+"_AB)+nz(VOL_"+types[n]+"_MED_"+periods[p]+"_AB)+nz(VOL_"+types[n]+"_HIGH_"+periods[p]+"_AB)",
									 "nz(VOL_"+types[n]+"_"+periods[p]+"_BA)+nz(VOL_"+types[n]+"_LOW_"+periods[p]+"_BA)+nz(VOL_"+types[n]+"_MED_"+periods[p]+"_BA)+nz(VOL_"+types[n]+"_HIGH_"+periods[p]+"_BA)",
									"nz(VOL_"+types[n]+"_LOW_"+periods[p]+")+nz(VOL_"+types[n]+"_MED_"+periods[p]+")+nz(VOL_"+types[n]+"_HIGH_"+periods[p]+")"}
			ret_value = RunMacro("TCB Run Operation", "Fill Dataview", Opts, &Ret)
			if !ret_value then goto quit
		end
	end

	//Step 5 All vehicle Vol by Time of day
	for p=1 to periods.length do
		Opts = null
		Opts.Input.[Dataview Set] = {result, "Assignment Result"}
		Opts.Global.Fields = {"VOL_"+periods[p]+"_AB","VOL_"+periods[p]+"_BA","VOL_"+periods[p]}
		Opts.Global.Method = "Formula"
		Opts.Global.Parameter = {
			"nz(VOL_PASS_"+periods[p]+"_AB)+nz(VOL_HOV2_"+periods[p]+"_AB)+nz(VOL_HOV3_"+periods[p]+"_AB)+nz(VOL_COM_"+periods[p]+"_AB)+nz(VOL_SU_"+periods[p]+"_AB)+nz(VOL_MU_"+periods[p]+"_AB)",
			"nz(VOL_PASS_"+periods[p]+"_BA)+nz(VOL_HOV2_"+periods[p]+"_BA)+nz(VOL_HOV3_"+periods[p]+"_BA)+nz(VOL_COM_"+periods[p]+"_BA)+nz(VOL_SU_"+periods[p]+"_BA)+nz(VOL_MU_"+periods[p]+"_BA)",
			"nz(VOL_"+periods[p]+"_AB)+nz(VOL_"+periods[p]+"_BA)"
			}
		ret_value = RunMacro("TCB Run Operation", "Fill Dataview", Opts, &Ret)
		if !ret_value then goto quit
	end
	
	//Step 5A All vehicle Daily Volume
	Opts = null
	Opts.Input.[Dataview Set] = {result, "Assignment Result"}
	Opts.Global.Fields = {"VOL_AB","VOL_BA","VOL_TOT"}
	Opts.Global.Method = "Formula"
	Opts.Global.Parameter = {
		"nz(VOL_AM_AB)+nz(VOL_MD_AB)+nz(VOL_PM_AB)+nz(VOL_OP_AB)",
		"nz(VOL_AM_BA)+nz(VOL_MD_BA)+nz(VOL_PM_BA)+nz(VOL_OP_BA)",
		"nz(VOL_AB)+nz(VOL_BA)"		
	}
	ret_value = RunMacro("TCB Run Operation", "Fill Dataview", Opts, &Ret)
	if !ret_value then goto quit
		
	//Step 6 Total VMT
	Opts = null
	Opts.Input.[Dataview Set] = {result, "Assignment Result"}
	Opts.Global.Fields = {
		
		"VMT_AMAB",
		"VMT_AMBA",
		"VMT_AM",
		
		"VMT_MDAB",
		"VMT_MDBA",
		"VMT_MD",
		
		"VMT_PMAB",
		"VMT_PMBA",
		"VMT_PM",
		
		"VMT_OPAB",
		"VMT_OPBA",
		"VMT_OP",
		
		"VMT_AB",
		"VMT_BA",
		"VMT_TOT",
        
		"VHT_TOT",
		"SPD_VMT_SUM"        
        
		}
	Opts.Global.Method = "Formula"
	Opts.Global.Parameter = {
		"VOL_AM_AB*Leng",
		"VOL_AM_BA*Leng",
		"VOL_AM*Leng",
		
		"VOL_MD_AB*Leng",
		"VOL_MD_BA*Leng",
		"VOL_MD*Leng",
		
		"VOL_PM_AB*Leng",
		"VOL_PM_BA*Leng",
		"VOL_PM*Leng",
		
		"VOL_OP_AB*Leng",
		"VOL_OP_BA*Leng",
		"VOL_OP*Leng",
		
		"VOL_AB*Leng",
		"VOL_BA*Leng",
		"VOL_TOT*Leng",    
		"nz(VOL_AM_AB*Leng/SPD_AMAB)+nz(VOL_AM_BA*Leng/SPD_AMBA)+nz(VOL_MD_AB*Leng/SPD_MDAB)+nz(VOL_MD_BA*Leng/SPD_MDBA)+nz(VOL_PM_AB*Leng/SPD_PMAB)+nz(VOL_PM_BA*Leng/SPD_PMBA)+nz(VOL_OP_AB*Leng/SPD_OPAB)+nz(VOL_OP_BA*Leng/SPD_OPBA)",
		"nz(SPD_AMAB*VMT_AMAB)+nz(SPD_AMAB*VMT_AMBA)+nz(SPD_MDAB*VMT_MDAB)+nz(SPD_MDAB*VMT_MDBA)+nz(SPD_PMAB*VMT_PMAB)+nz(SPD_PMAB*VMT_PMBA)+nz(SPD_OPAB*VMT_OPAB)+nz(SPD_OPAB*VMT_OPBA)"      
		}
    ret_value = RunMacro("TCB Run Operation", "Fill Dataview", Opts, &Ret)
	if !ret_value then goto quit
    
	//Step 7: Volume over Capacity and Level of Service
	UpdateProgressBar("Update the LOS ", )
	Opts = null
	Opts.Input.[Dataview Set] = {{Args.[hwy db]+"|"+llayer, result, {"ID"}, {"ID"}}, "Network+Assignment Result"}
	Opts.Global.Fields = {
		"VC_AMAB",
		"VC_AMBA",
		"VC_AM",
		
		"VC_MDAB",
		"VC_MDBA",
		"VC_MD",
		
		"VC_PMAB",
		"VC_PMBA",
		"VC_PM",
		
		"VC_OPAB",
		"VC_OPBA",
		"VC_OP",
		"VC_Dly",

		"LOS_AMAB",
		"LOS_AMBA",
		"LOS_AM",
		
		"LOS_MDAB",
		"LOS_MDBA",
		"LOS_MD",
		
		"LOS_PMAB",
		"LOS_PMBA",
		"LOS_PM",
		
		"LOS_OPAB",
		"LOS_OPBA",
		"LOS_OP",
		"LOS",
		
		"Pct_FF_Min1",
		"Pct_FF_Min2",
		"Pct_FF_Min",
		
		"Pct_FF_AMAB",
		"Pct_FF_AMBA",
		"Pct_FF_AM",
		
		"Pct_FF_MDAB",
		"Pct_FF_MDBA",
		"Pct_FF_MD",
		
		"Pct_FF_PMAB",
		"Pct_FF_PMBA",
		"Pct_FF_PM",
		
		"Pct_FF_OPAB",
		"Pct_FF_OPBA",
		"Pct_FF_OP",
		
		"MU_VHT_AMAB",
		"MU_VHT_AMBA",
		"MU_VHT_MDAB",
		"MU_VHT_MDBA",
		"MU_VHT_PMAB",
		"MU_VHT_PMBA",
		"MU_VHT_OPAB",
		"MU_VHT_OPBA",
		
		"MU_VHT_TOT"
		}
	Opts.Global.Method = "Formula"
	Opts.Global.Parameter = {
		"if VOL_AM_AB/capacity_am_AB<>null then VOL_AM_AB/capacity_am_AB else 0",
		"if VOL_AM_BA/capacity_am_BA<>null then VOL_AM_BA/capacity_am_BA else 0",
		"max(VC_AMAB,VC_AMBA)",
		
		"if VOL_MD_AB/capacity_md_AB<>null then VOL_MD_AB/capacity_md_AB else 0",
		"if VOL_MD_BA/capacity_md_BA<>null then VOL_MD_BA/capacity_md_BA else 0",
		"max(VC_MDAB,VC_MDBA)",
		
		"if VOL_PM_AB/capacity_pm_AB<>null then VOL_PM_AB/capacity_pm_AB else 0",
		"if VOL_PM_BA/capacity_pm_BA<>null then VOL_PM_BA/capacity_pm_BA else 0",
		"max(VC_PMAB,VC_PMBA)",
		
		"if VOL_OP_AB/capacity_op_AB<>null then VOL_OP_AB/capacity_op_AB else 0",
		"if VOL_OP_BA/capacity_op_BA<>null then VOL_OP_BA/capacity_op_BA else 0",
		"max(VC_OPAB,VC_OPBA)",
		
		"VOL_TOT/(nz(capacity_daily_AB)+nz(capacity_daily_BA))",
		
		"if VC_AMAB>=1 then 'F' else if VC_AMAB>=0.85 then 'E' else if VC_AMAB>=0.7 then 'D' else 'C'",
		"if VC_AMBA>=1 then 'F' else if VC_AMBA>=0.85 then 'E' else if VC_AMBA>=0.7 then 'D' else 'C'",
		"if VC_AM>=1 then 'F' else if VC_AM>=0.85 then 'E' else if VC_AM>=0.7 then 'D' else 'C'",
		
		"if VC_MDAB>=1 then 'F' else if VC_MDAB>=0.85 then 'E' else if VC_MDAB>=0.7 then 'D' else 'C'",
		"if VC_MDBA>=1 then 'F' else if VC_MDBA>=0.85 then 'E' else if VC_MDBA>=0.7 then 'D' else 'C'",
		"if VC_MD>=1 then 'F' else if VC_MD>=0.85 then 'E' else if VC_MD>=0.7 then 'D' else 'C'",
		
		"if VC_PMAB>=1 then 'F' else if VC_PMAB>=0.85 then 'E' else if VC_PMAB>=0.7 then 'D' else 'C'",
		"if VC_PMBA>=1 then 'F' else if VC_PMBA>=0.85 then 'E' else if VC_PMBA>=0.7 then 'D' else 'C'",
		"if VC_PM>=1 then 'F' else if VC_PM>=0.85 then 'E' else if VC_PM>=0.7 then 'D' else 'C'",
		
		"if VC_OPAB>=1 then 'F' else if VC_OPAB>=0.85 then 'E' else if VC_OPAB>=0.7 then 'D' else 'C'",
		"if VC_OPBA>=1 then 'F' else if VC_OPBA>=0.85 then 'E' else if VC_OPBA>=0.7 then 'D' else 'C'",
		"if VC_OP>=1 then 'F' else if VC_OP>=0.85 then 'E' else if VC_OP>=0.7 then 'D' else 'C'",
		"if VC_Dly>=1 then 'F' else if VC_Dly>=0.85 then 'E' else if VC_Dly>=0.7 then 'D' else 'C'",
		
		"if spd_ff_ab<>null then min(min(spd_amab/spd_ff_ab, spd_mdab/spd_ff_ab),min(spd_pmab/spd_ff_ab, spd_opab/spd_ff_ab)) else null",
		"if spd_ff_ba<>null then min(min(spd_amba/spd_ff_ba, spd_mdba/spd_ff_ba),min(spd_pmba/spd_ff_ba, spd_opba/spd_ff_ba)) else null",
		"if Pct_FF_Min1=null then Pct_FF_Min2 else if Pct_FF_Min2=null then Pct_FF_Min1 else min(Pct_FF_Min1,Pct_FF_Min2)",
		
		"if spd_ff_ab<>null then spd_amab/spd_ff_ab else null",
		"if spd_ff_ba<>null then spd_amba/spd_ff_ba else null",
		"if Pct_FF_AMAB=null then Pct_FF_AMBA else if Pct_FF_AMBA=null then Pct_FF_AMAB else min(Pct_FF_AMAB,Pct_FF_AMBA)",
		
		"if spd_ff_ab<>null then spd_mdab/spd_ff_ab else null",
		"if spd_ff_ba<>null then spd_mdba/spd_ff_ba else null",
		"if Pct_FF_MDAB=null then Pct_FF_MDBA else if Pct_FF_MDBA=null then Pct_FF_MDAB else min(Pct_FF_MDAB,Pct_FF_MDBA)",
		
		"if spd_ff_ab<>null then spd_pmab/spd_ff_ab else null",
		"if spd_ff_ba<>null then spd_pmba/spd_ff_ba else null",
		"if Pct_FF_PMAB=null then Pct_FF_PMBA else if Pct_FF_PMBA=null then Pct_FF_PMAB else min(Pct_FF_PMAB,Pct_FF_PMBA)",
		
		"if spd_ff_ab<>null then spd_opab/spd_ff_ab else null",
		"if spd_ff_ba<>null then spd_opba/spd_ff_ba else null",
		"if Pct_FF_OPAB=null then Pct_FF_OPBA else if Pct_FF_OPBA=null then Pct_FF_OPAB else min(Pct_FF_OPAB,Pct_FF_OPBA)",
		
		"nz(VOL_MU_AM_AB*Leng/SPD_AMAB)",
		"nz(VOL_MU_AM_BA*Leng/SPD_AMBA)",
		"nz(VOL_MU_MD_AB*Leng/SPD_MDAB)",
		"nz(VOL_MU_MD_BA*Leng/SPD_MDBA)",
		"nz(VOL_MU_PM_AB*Leng/SPD_PMAB)",
		"nz(VOL_MU_PM_BA*Leng/SPD_PMBA)",
		"nz(VOL_MU_OP_AB*Leng/SPD_OPAB)",
		"nz(VOL_MU_OP_BA*Leng/SPD_OPBA)",
		"nz(VOL_MU_AM_AB*Leng/SPD_AMAB)+nz(VOL_MU_AM_BA*Leng/SPD_AMBA)+nz(VOL_MU_MD_AB*Leng/SPD_MDAB)+nz(VOL_MU_MD_BA*Leng/SPD_MDBA)+nz(VOL_MU_PM_AB*Leng/SPD_PMAB)+nz(VOL_MU_PM_BA*Leng/SPD_PMBA)+nz(VOL_MU_OP_AB*Leng/SPD_OPAB)+nz(VOL_MU_OP_BA*Leng/SPD_OPBA)"
		}
	
	ret_value= RunMacro("TCB Run Operation", "Fill Dataview", Opts, &Ret)
	if !ret_value then goto quit    
    
	CloseMap(temp_map)
	runmacro("G30 File Close All")
	CopyFile(Scen_Dir+ "outputs\\assignment_result.bin",Scen_Dir+ "outputs\\assignment_result_"+String(loop)+".bin")
	CopyFile(Scen_Dir+ "outputs\\assignment_result.DCB",Scen_Dir+ "outputs\\assignment_result_"+String(loop)+".DCB")

    hwy_asm = OpenTable("hwy_asm","FFB",{Scen_Dir+ "outputs\\assignment_result_"+String(loop)+".bin"})
  	ExportView(hwy_asm+"|", "CSV", Scen_Dir+ "outputs\\assignment_result_"+String(loop)+".csv",,{{"CSV Header","TRUE"}})

	endtime = RunMacro("RuntimeLog", {"Highway Post Processing ", starttime})
	
	ret_value=1
	quit:
	return(ret_value)
endMacro

Macro "Crit Link Result" (Args,Scen_Dir) 

	//Output Files
	CRIT_TT=Args.[Crit TT]
	
	// Input Files, for both preload and normal assignment
	view_CRIT_PRE_AM = OpenTable("Crit_Preload_AM", "FFB", {Scen_Dir + "outputs\\Assignment_Preload_AM.BIN"})
	view_CRIT_PRE_MD = OpenTable("Crit_Preload_MD", "FFB", {Scen_Dir + "outputs\\Assignment_Preload_MD.BIN"})
	view_CRIT_PRE_PM = OpenTable("Crit_Preload_PM", "FFB", {Scen_Dir + "outputs\\Assignment_Preload_PM.BIN"})
	view_CRIT_PRE_OP = OpenTable("Crit_Preload_OP", "FFB", {Scen_Dir + "outputs\\Assignment_Preload_OP.BIN"})
	
	view_CRIT_AM = OpenTable("Crit_AM","FFB", {Scen_Dir + "outputs\\Assignment_AM.bin"})
	view_CRIT_MD = OpenTable("Crit_MD","FFB", {Scen_Dir + "outputs\\Assignment_MD.bin"})
	view_CRIT_PM = OpenTable("Crit_PM","FFB", {Scen_Dir + "outputs\\Assignment_PM.bin"})
	view_CRIT_OP = OpenTable("Crit_OP","FFB", {Scen_Dir + "outputs\\Assignment_OP.bin"})
	
	//Getting Input file structure
	STRU_CRIT_PRE_AM=GetTableStructure(view_CRIT_PRE_AM) //30+ 8i  30 basic fields + 8 fields per query
	STRU_CRIT_PRE_MD=GetTableStructure(view_CRIT_PRE_MD) //30+ 8i 
	STRU_CRIT_PRE_PM=GetTableStructure(view_CRIT_PRE_PM) //30+ 8i
	STRU_CRIT_PRE_OP=GetTableStructure(view_CRIT_PRE_OP) //30+ 8i
	
	STRU_CRIT_AM=GetTableStructure(view_CRIT_AM) //34+ 12i 34 basic fields + 12 fields per query
	STRU_CRIT_MD=GetTableStructure(view_CRIT_MD) //34+ 12i
	STRU_CRIT_PM=GetTableStructure(view_CRIT_PM) //34+ 12i
	STRU_CRIT_OP=GetTableStructure(view_CRIT_OP) //34+12i
	
	// Calulating Number of Querries
	NUM_QUERRY=(STRU_CRIT_PRE_AM.length-30)/8

	dim flow_AB_fields[NUM_QUERRY]
	dim flow_BA_fields[NUM_QUERRY]
	dim flow_TOT_fields[NUM_QUERRY]
	

	field_num=STRU_CRIT_AM.length
	
	
	//get the field names
	for i=1 to NUM_QUERRY do
		flow_BA_fields[i]=STRU_CRIT_AM[field_num][1]
		
		field_num=field_num-1
		flow_AB_fields[i]=STRU_CRIT_AM[field_num][1]
		
		field_num=field_num-1
	end
	
	dim vol_ab[NUM_QUERRY]
	dim vol_ba[NUM_QUERRY]
	dim vol_tot[NUM_QUERRY]
	
	//reading crit link assignment result, preload, and normal, sort by ID
	for i=1 to NUM_QUERRY do
		v_temp1=GetDataVector(view_CRIT_PRE_AM+"|", flow_AB_fields[i], {{"Sort Order", {{"ID1", "Ascending"}}}}) 
		v_temp2=GetDataVector(view_CRIT_PRE_MD+"|", flow_AB_fields[i], {{"Sort Order", {{"ID1", "Ascending"}}}})
		v_temp3=GetDataVector(view_CRIT_PRE_PM+"|", flow_AB_fields[i], {{"Sort Order", {{"ID1", "Ascending"}}}})
		v_temp4=GetDataVector(view_CRIT_PRE_OP+"|", flow_AB_fields[i], {{"Sort Order", {{"ID1", "Ascending"}}}})		
		v_temp5=GetDataVector(view_CRIT_AM+"|", flow_AB_fields[i], {{"Sort Order", {{"ID1", "Ascending"}}}})
		v_temp6=GetDataVector(view_CRIT_MD+"|", flow_AB_fields[i]	, {{"Sort Order", {{"ID1", "Ascending"}}}})
		v_temp7=GetDataVector(view_CRIT_PM+"|", flow_AB_fields[i]	, {{"Sort Order", {{"ID1", "Ascending"}}}})
		v_temp8=GetDataVector(view_CRIT_OP+"|", flow_AB_fields[i]	, {{"Sort Order", {{"ID1", "Ascending"}}}})
		vol_ab[i]=nz(v_temp1)+nz(v_temp2)+nz(v_temp3)+nz(v_temp4)+nz(v_temp5)+nz(v_temp6)+nz(v_temp7)+nz(v_temp8)
		
		v_temp1=GetDataVector(view_CRIT_PRE_AM+"|", flow_BA_fields[i], {{"Sort Order", {{"ID1", "Ascending"}}}}) 
		v_temp2=GetDataVector(view_CRIT_PRE_MD+"|", flow_BA_fields[i], {{"Sort Order", {{"ID1", "Ascending"}}}})
		v_temp3=GetDataVector(view_CRIT_PRE_PM+"|", flow_BA_fields[i], {{"Sort Order", {{"ID1", "Ascending"}}}})
		v_temp4=GetDataVector(view_CRIT_PRE_OP+"|", flow_BA_fields[i]	, {{"Sort Order", {{"ID1", "Ascending"}}}})
		v_temp5=GetDataVector(view_CRIT_AM+"|", flow_BA_fields[i]	, {{"Sort Order", {{"ID1", "Ascending"}}}})
		v_temp6=GetDataVector(view_CRIT_MD+"|", flow_BA_fields[i]	, {{"Sort Order", {{"ID1", "Ascending"}}}})
		v_temp7=GetDataVector(view_CRIT_PM+"|", flow_BA_fields[i]	, {{"Sort Order", {{"ID1", "Ascending"}}}})
		v_temp8=GetDataVector(view_CRIT_OP+"|", flow_BA_fields[i]	, {{"Sort Order", {{"ID1", "Ascending"}}}})
		vol_ba[i]=nz(v_temp1)+nz(v_temp2)+nz(v_temp3)+nz(v_temp4)+nz(v_temp5)+nz(v_temp6)+nz(v_temp7)+nz(v_temp8)
		
		vol_tot[i]=nz(vol_ab[i])+nz(vol_ba[i])
	end
	
		v_ID=GetDataVector(view_CRIT_PRE_AM+"|", "ID1"	, {{"Sort Order", {{"ID1", "Ascending"}}}})  //ID
	
	
	// create the crit link result table, ID, 3 more records for each field, TOT, AB, BA
	STRU_RESULT={{"ID1", "Integer", 9, null, "Yes"}}
	for i=1 to NUM_QUERRY do
		
		subs=ParseString(flow_AB_fields[i],"_", opts)
		flow_TOT_fields[i]=subs[3]+"_Tot"
		
		STRU_RESULT=STRU_RESULT+{{flow_TOT_fields[i], "Real", 9, 2, "No"}}
		STRU_RESULT=STRU_RESULT+{{flow_AB_fields[i], "Real", 9, 2, "No"}}
		STRU_RESULT=STRU_RESULT+{{flow_BA_fields[i], "Real", 9, 2, "No"}}
	end
	
	table=Args.[CRIT TT]
	
	crit_table=CreateTable("crit_table", table,"FFB",STRU_RESULT)
	AddRecords(crit_table, null, null, {{"Empty Records", vol_tot[1].length}})
	
	//set data vector for the ID field
	SetDataVector(crit_table+"|","ID1", v_ID, )
	
	//set data vector for each query
	counter=1
	v_temp_ab=null
	v_temp_ba=null
	v_temp_tot=null
	
	for i=1 to NUM_QUERRY do
		v_temp_ab=vol_ab[i]
		v_temp_ba=vol_ba[i]
		v_temp_tot=vol_tot[i]
		
		SetDataVectors(crit_table+"|", 
		{
			{flow_AB_fields[i],v_temp_ab},
			{flow_BA_fields[i],v_temp_ba}, 
			{flow_TOT_fields[i],v_temp_tot}
		}
		,)
		
	end
	
	
	
	ret_value=1
	
	quit:
	return(ret_value)
	
endMacro