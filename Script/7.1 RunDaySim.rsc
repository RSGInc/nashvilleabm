//**************************************
//*					Run DaySim and Format DaySim Outputs					 *
//**************************************
// Author: nagendra.dhakar@rsginc.com
// Updated: 10/29/2015

/*
Script contains following macros that are used in the model

1. Run DaySim - three iterations of DaySim
2. Run DaySim Summaries - only in the last feedback loop
3. FormatAssignmentInputs - formats _trip.tsv into highway and transit od trip matrices

*/

Macro "SetParameters" (Args)
		// Set highway, transit, daysim, and airport parameters
    RunMacro("SetTransitParameters",Args)
    RunMacro("SetHighwayParameters", Args)
    RunMacro("SetDaySimParameters")
		RunMacro("SetAirportParameter")
EndMacro

Macro "Run DaySim" (Args)
    shared Scen_Dir, OutDir, loop
    shared DaySimDir, drive

/*
PURPOSE:
- Run ABM with fixed starting shadow prices

STEPS:
1. set daysim parameters
2. before the first loop, copy roster files to global outputs folder
3. before the first loop, copy starting shadow prices from DaySim root folder
4. run first two iterations of DaySim for long term choice models (work and school) - to stabilize shadow prices
5. run the third iteration of DaySim for all models
6. copy the DaySim trip file (_trip.tsv) to global outputs folder
*/
		
		RunMacro("SetParameters", Args)
    
    // number of daysim iterations
    itercount = 3
    
    path_info = SplitPath(Scen_Dir)
    drive = path_info[1]
    
    // set to outputs in scenario directory
    DaySimDir = Scen_Dir + "DaySim\\"
    
    if loop=1 then do
        // copy roster file to outputs folder
        infile = DaySimDir + "nashville-roster_matrix.csv"
        outfile = OutDir + "nashville-roster_matrix.csv"
        CopyFile(infile,outfile)
        
        // copy roster combination file to outputs folder
        infile = DaySimDir + "nashville_roster.combinations.csv"
        outfile = OutDir + "nashville_roster.combinations.csv"
        CopyFile(infile,outfile)    
    
        // copy shadow_prices.txt to working folder
        infile = DaySimDir + "shadow_prices.txt"
        file_info = GetFileInfo(infile)
        if file_info != null then do
            outfile = DaySimDir + "working\\" + "shadow_prices.txt"
            CopyFile(infile,outfile) 
        end
 
        // copy park_and_ride_shadow_prices.txt to working folder
        infile = DaySimDir + "park_and_ride_shadow_prices.txt"
        file_info = GetFileInfo(infile)
        if file_info != null then do
            outfile = DaySimDir + "working\\" + "park_and_ride_shadow_prices.txt"
            CopyFile(infile,outfile) 
        end
    end

    for i=1 to itercount do
        if i=itercount then do
            config_file = "configuration.xml"
        end
        else do
            config_file = "configuration_workschool.xml"
        end

        // Launch Daysim
        command_line = "cmd /c " + drive + " && cd " + DaySimDir + " && Daysim.exe -c " + config_file
        
        status = RunProgram(command_line,{{"Maximize", "True"}})
        
    end

    // copy _trip.tsv and _tour.tsv files to global output directory 
    infile = DaySimDir + "outputs\\_trip.tsv"
    outfile = OutDir + "_trip.csv"
    CopyFile(infile,outfile)
	
    infile = DaySimDir + "outputs\\_tour.tsv"
    outfile = OutDir + "_tour.csv"
    CopyFile(infile,outfile)	
    
    status = 0
		
		Return(1)

EndMacro

Macro "Run DaySim Summaries" (Args)
    shared Scen_Dir, OutDir, drive, loop
    shared DaySimDir

/*
PURPOSE:
- Generate summaries from DaySim outputs

STEPS:
1. set daysim parameters
2. run R program to generate DaySim summaries - used only in final loop
*/
		
    RunMacro("SetParameters", Args)

		path_info = SplitPath(Scen_Dir)
		drive = path_info[1]
		
		// set to outputs in scenario directory
		DaySimSumDir = Scen_Dir + "DaySimSummaries\\"

		// Launch Daysim
		command_line = "cmd /c " + drive + " && cd " + DaySimSumDir + " && daysim_summaries.cmd"
		
		status = RunProgram(command_line,{{"Maximize", "True"}})
		status = 0
		
		Return(1)

EndMacro


Macro "SetHighwayParameters" (Args)
    shared IDTable, Periods, TimePeriod
    
    IDTable=Args.[IDTable]
    Periods={"AM","MD","PM","OP"}  

/*
    // minutes from midnight
    //OP: 0-359
    //AM: 360-539
    //MD: 540-899
    //PM: 900-1139
    //OP: 1140-1439
*/    
    dim TimePeriod[4]

    TimePeriod[1] = {360,539,9999,9999}    //AM
    TimePeriod[2] = {540,899,9999,9999}    //MD
    TimePeriod[3] = {900,1139,9999,9999}    //PM    
    TimePeriod[4] = {1140,1439,0,359} //OP       
    
EndMacro

Macro "SetAirportParameter"
		shared Scen_Dir
		shared mc_hbo, mc_nhbw, mc_nhbo
		shared purposes, modes, purposesPeriod, AirPeriodFactors
		
    mc_hbo = Scen_Dir + "outputs\\mc_hbo.mtx"
    mc_nhbw = Scen_Dir + "outputs\\mc_nhbw.mtx"
    mc_nhbo = Scen_Dir + "outputs\\mc_nhbo.mtx"
    
    purposes = {"HBO","NHBW","NHBO"}
    modes = {"DA","SR2","SR3"}
		
    purposesPeriod = {"OP","OP","PK"}
		AirPeriodFactors = {0.5,0.5,0.5,0.5}  // corresponding to Periods = {"AM","MD","PM","OP"}, factors to distribute trips from PK and OP periods		
		
EndMacro

Macro "SetDaySimParameters"
    shared OutDir
    shared TripFile, TourFile, TripTourFile, MaxZone
    
    TripFile = OutDir + "_trip.csv" 
	TourFile = OutDir + "_tour.csv"
	TripTourFile = OutDir + "trip_tour.csv"
    MaxZone  = 2900

EndMacro

Macro "JoinDaySimTripTourFiles"
    shared OutDir
    shared TripFile, TourFile, TripTourFile
	
	tripfile_view = OpenTable("triptable","CSV",{TripFile,})
	tourfile_view = OpenTable("tourtable","CSV",{TourFile,})
		
	joinedview = JoinViews("joined", tripfile_view+".tour_id",tourfile_view+".id",)
	view_set = joinedview + "|"
	
	//export joined view - include only selected fields 
	ExportView(view_set, "CSV", TripTourFile,{"half","otaz","dtaz","mode","pathtype","deptm","arrtm","trexpfac","tmodetp"},{{"CSV Header", "True"}})
	
	CloseView(tripfile_view)
	CloseView(tourfile_view)
	CloseView(joinedview)
	
EndMacro

Macro "FormatAssignmentInputs" (Args)

    shared OutDir, IDTable, TripFile, TripFile, TripTourFile, Periods, TimePeriod, MaxZone, AccessAssgnModes
		shared TripRecords, TimePeriod, ArrayTrips, ArrayTransitTrips, Highway, Transit

/*
PURPOSE:
- Format DaySim trip file (_trip.tsv) into TransCAD matrices for highway and transit assignment

STEPS:
1. set highway and transit parameters
2. read trip file (_trip.tsv) into an array
3. segment the trip array into highway and transit OD trip arrays
4. for each time period, create a trip matrix with required cores and fill corresponding trips
5. free-up memory by setting arrays to null
*/
		
		RunMacro("SetParameters", Args)
   
    TransitModes = {"Local", "UrbRail", "ExpBus", "ComRail", "Brt"}
    TransitMatrix_cores = {"WLKLOCBUS", "WLKURBRAIL", "WLKEXPBUS", "WLKCOMRAIL", "WLKBRT", "PNRLOCBUS", "PNRBRT", "PNREXPBUS", "PNRURBRAIL", "PNRCOMRAIL", "KNRLOCBUS", "KNRBRT", "KNREXPBUS", "KNRURBRAIL", "KNRCOMRAIL"}
    class = {"SOV","HOV"}

    // set switches
    Highway = 1
    Transit = 1
		
		// Load daysim trip file to an array
		UpdateProgressBar("Reading trips into an array ... ", )
		//join DaySim trip file and tour file
		RunMacro("JoinDaySimTripTourFiles")

		readfile = OpenFile(TripTourFile, "r")
		TripRecords = ReadArray(readfile)
		CloseFile(readfile)		
		
    for p=1 to Periods.length do
		
			perc = RealToInt(100*(p/Periods.length)) // percentage completion
			UpdateProgressBar("Creating highway and transit trip matrices for: "+ Periods[p], perc)

			dim ArrayTrips[class.Length+1, MaxZone, MaxZone] // 4-dimensional array
			dim ArrayTransitTrips[TransitMatrix_cores.Length, MaxZone, MaxZone] // for time being
			
			// Read daysim trip file
			RunMacro("Read Trips", p) 
			
			//  ---------------- Highway Assignment Matrix
			if Highway = 1 then do
					
					// create a temp matrix
					mat_cores = {"IICOM", "IISU", "IIMU","IEAUTO", "IESU", "EEAUTO", "EESU","Passenger_SOV","Passenger_HOV","Commercial","SingleUnit","MU","Preload_MU", "Preload_SU", "Preload_Pass", "PersonTrips"}
					outMat = "temp_" + Periods[p]+"OD.mtx"
					RunMacro("Create a new matrix", OutDir, IDTable, outMat, mat_cores)
					
					// Fill trips from daysim output - "Passenger_SOV"
					RunMacro("Fill Matrix", OutDir, outMat, MaxZone, "Passenger_SOV", ArrayTrips[1])
					
					// Fill trips from daysim output - "Passenger_HOV"
					RunMacro("Fill Matrix", OutDir, outMat, MaxZone, "Passenger_HOV", ArrayTrips[2])
					
					// Fill trips from daysim output - "PersonTrips"
					RunMacro("Fill Matrix", OutDir, outMat, MaxZone, "PersonTrips", ArrayTrips[3])
					
			end
			
			// ----------------- Transit Assignment Matrix
			
			if Transit = 1 then do
					outMat = Periods[p] + "TripsByMode.mtx"
					RunMacro("Create a new matrix", OutDir, IDTable, outMat, TransitMatrix_cores)
					
					// Fill trips from daysim output - by transit submode
					for core=1 to TransitMatrix_cores.Length do
							RunMacro("Fill Matrix", OutDir, outMat, MaxZone, TransitMatrix_cores[core], ArrayTransitTrips[core])
					end           
					
			end 
        
    end
    		
		// free up memory
		UpdateProgressBar("Freeing up memory ... ", )
		TripRecords=null
    ArrayTrips=null
    ArrayTransitTrips=null	
		
		Return(1)
		
endMacro

Macro "Read Trips" (tod)
    shared TripRecords, TimePeriod, ArrayTrips, ArrayTransitTrips, Highway, Transit

/*
PURPOSE:
- Save trips into highway and transit arrays with segmentation by sub-mode and origin and destination

STEPS:
1. Goes through each trip record
2. Trip time is trip arriavl time if the trip is in first of the tour, otherwise trip deptarture time
3. Identify time period of the trip, and then highway trip or transit trip
4. for highway save in [da/sr2/sr3][origin][destination] - 3*2900*2900
5. for transit save as [walk/pnr/knr by submode][origin][destination] - 15*2900*2900
*/

    for rec=1 to TripRecords.Length do
				
				perc = RealToInt(100*(rec/TripRecords.Length)) // percentage completion
				UpdateProgressBar("Segmenting trips by time period and sub-mode: " + string(rec) + " of " + string(TripRecords.Length), perc)
				
         //split string - tab delimited
		values = ParseString(TripRecords[rec],",")
        //values = ParseString(TripRecords[rec],"\t")
        
		//with updated file - trip_tour
        Half = StringToInt(values[1]) // 1-outbound, 2-inbound
        OTaz = StringToInt(values[2])
        DTaz = StringToInt(values[3])
        Mode = StringToInt(values[4])
        PathType = StringToInt(values[5])
        DeptTime = StringToReal(values[6])
        ArrTime = StringToReal(values[7])
		TripExpFactor = StringToReal(values[8])
		TransitAccess = StringToInt(values[9]) //tmodetp - from tour file		
		
		//with only trip file - old method
        //Half = StringToInt(values[7]) // 1-outbound, 2-inbound
        //OTaz = StringToInt(values[15])
        //DTaz = StringToInt(values[17])
        //Mode = StringToInt(values[18])
        //PathType = StringToInt(values[19])
        //DeptTime = StringToReal(values[21])
        //ArrTime = StringToReal(values[22])
		//TripExpFactor = StringToReal(values[28])
		//TransitAccess = StringToInt(values[50]) //tmodetp - from tour file
        Trip = 0
        
        if (Half = 1) then TripTime = ArrTime
        else TripTime = DeptTime
        
        if OTaz >0 then do

						if ((TripTime >= TimePeriod[tod][1] and TripTime <= TimePeriod[tod][2] ) or (TripTime >= TimePeriod[tod][3] and TripTime <= TimePeriod[tod][4])) then do
								
								if (Mode = 6 and PathType > 2) then do // transit trip
								
										if Transit = 1 then do
												Trip=TripExpFactor
												
												if (TransitAccess=6) then do //Walk Transit
													// subtract 2 as sub-transit starts at 3 (local bus)
													transit_index = PathType-2
												end
												else do //PNR Transit	
													if (PathType=3) then transit_index=6
													if (PathType=4) then transit_index=9
													if (PathType=5) then transit_index=8
													if (PathType=6) then transit_index=10
													if (PathType=7) then transit_index=7
												end											
												
												//No KNR currently
												
												ArrayTransitTrips[transit_index][OTaz][DTaz] = NullToZero(ArrayTransitTrips[transit_index][OTaz][DTaz]) + Trip                          
														 
										end
								end
										
								else do             // highway trip
										if Highway = 1 then do
												Trip = 0
												
												// person trip to vehicle trip factors: hov2 (2) and hov3+ (3.5)
												//SOV
												if (Mode = 3) then do
														Trip = TripExpFactor
														ArrayTrips[1][OTaz][DTaz] = NullToZero(ArrayTrips[1][OTaz][DTaz]) + Trip
														ArrayTrips[3][OTaz][DTaz] = NullToZero(ArrayTrips[3][OTaz][DTaz]) + 1
												end
												
												//HOV
												if (Mode = 4) then do
														Trip = TripExpFactor/2
														ArrayTrips[2][OTaz][DTaz] = NullToZero(ArrayTrips[2][OTaz][DTaz]) + Trip
														ArrayTrips[3][OTaz][DTaz] = NullToZero(ArrayTrips[3][OTaz][DTaz]) + 1
												end                            

												//HOV
												if (Mode = 5) then do
														Trip = TripExpFactor/3.5
														ArrayTrips[2][OTaz][DTaz] = NullToZero(ArrayTrips[2][OTaz][DTaz]) + Trip
														ArrayTrips[3][OTaz][DTaz] = NullToZero(ArrayTrips[3][OTaz][DTaz]) + 1
												end 

										end                         
								end
                
            end
    
        end
    end
     
endMacro

Macro "Fill Matrix" (OutDir, inMatFile, MaxZone, MatrixCore, ArrayValues)

    // open a matrix
    mat = OpenMatrix(OutDir + inMatFile, "True")
    
    // Create matrix currency
    mat_curr = CreateMatrixCurrency(mat, MatrixCore, "Rows", "Cols",)
    
    // create range of rows and cols
    dim rows_ind[MaxZone]
    dim cols_ind[MaxZone]
    
    for i=1 to MaxZone do
        rows_ind[i]=i
        cols_ind[i]=i
    end
    
    // set matrix values
    operation = {"Copy",ArrayValues}
    SetMatrixValues(mat_curr,rows_ind,cols_ind,operation,)
    
    // set null values to zero
    mat_curr := nz(mat_curr)
    
    // set matrix and currency to null
    mat=null
    mat_curr=null

endMacro


Macro "Create a new matrix" (OutDir, IDTable, outMatFile, matrix_cores)
    
    IDTable_view = OpenTable("equivalancy", "FFB", {IDTable})
    
    // create a matrix
    mat =CreateMatrix({IDTable_view+"|", "NewID", "Rows"},
     {IDTable_view+"|", "NewID", "Cols"},
     {{"File Name", OutDir + outMatFile}, {"Type", "Float"},
     {"Tables",matrix_cores},{"Compression",1}, {"Do Not Initialize", "True"}})
    
    // Loop by core
    for c = 1 to matrix_cores.length do
      mc_rev = CreateMatrixCurrency(mat, matrix_cores[c],"Rows","Cols",)
      mc_rev:=nz(mc_rev)
    end
    
    // null out the matrix and currency handles
    mc_rev = null
    mat  = null
    
    // Close view
    CloseView(IDTable_view)

endMacro

Macro "Fill Highway Airport Trips" (Args)
    shared Scen_Dir
		shared mc_hbo, mc_nhbw, mc_nhbo,purposes, modes 

/*
PURPOSE:
- Add airport trips (post MC) to PA matrix

STEPS:
0. Set airport parameters
1. for each of the three purposes, get the trips from airport model mode choice output and add to PA matrix
*/

		RunMacro("SetParameters", Args)
		
    PA_Matrix=Args.[PA Matrix]

/*		
    mc_hbo = Scen_Dir + "outputs\\mc_hbo.mtx"
    mc_nhbw = Scen_Dir + "outputs\\mc_nhbw.mtx"
    mc_nhbo = Scen_Dir + "outputs\\mc_nhbo.mtx"
    
    purposes = {"HBO","NHBW","NHBO"}
    modes = {"DA","SR2","SR3"}
*/
    
    for p=1 to purposes.Length do
		
				perc = RealToInt(100*p/purposes.Length)
				UpdateProgressBar("Fill Airport Highway Trips: " + string(p) + " of " + string(purposes.Length), perc)
				
        for m=1 to modes.Length do
            core = purposes[p]+"_"+modes[m]
            
            RunMacro("TCB Init")
            
            mc1 = RunMacro("TCB Create Matrix Currency", PA_Matrix, core,,)
            
            if purposes[p] = "HBO" then do
                mc2 = RunMacro("TCB Create Matrix Currency", mc_hbo, modes[m],,)
            end
            
            if purposes[p] = "NHBW" then do
                mc2 = RunMacro("TCB Create Matrix Currency", mc_nhbw, modes[m],,)
            end
            
            if purposes[p] = "NHBO" then do
                mc2 = RunMacro("TCB Create Matrix Currency", mc_nhbo, modes[m],,)
            end 
            
            mc1 := nz(mc2)
            
        end
    end

EndMacro

Macro "Fill Person Trips" (Args)
    shared Scen_Dir, loop

/*
PURPOSE:
- Fill daysim person trips to PA matrix - for MOE generation process

STEPS:
0. Set airport parameters
1. For each time period, access DaySim person trip core in the temp OD matrix created in "FormatAssignmentInputs" macro.
2. If loop is after first, then delete "DaySimPersonTrips" core and add a new one
3. add the aggregated trips from all time periods
*/

		UpdateProgressBar("Fill DaySim Person Trips to PA matrix" , )
		
    PA_Matrix=Args.[PA Matrix]

    //add daysim person trips
		OD = {Args.[AM OD Matrix], Args.[MD OD Matrix], Args.[PM OD Matrix], Args.[OP OD Matrix]}    

    // temp matrix
    FileInfo = GetFileInfo(OD[1])
    temp_am = Scen_Dir + "outputs\\temp_" + FileInfo[1]
    mc1 = RunMacro("TCB Create Matrix Currency", temp_am, "PersonTrips",,)
    
    FileInfo = GetFileInfo(OD[2])
    temp_md = Scen_Dir + "outputs\\temp_" + FileInfo[1]
    mc2 = RunMacro("TCB Create Matrix Currency", temp_md, "PersonTrips",,)

    FileInfo = GetFileInfo(OD[3])
    temp_pm = Scen_Dir + "outputs\\temp_" + FileInfo[1]
    mc3 = RunMacro("TCB Create Matrix Currency", temp_pm, "PersonTrips",,)

    FileInfo = GetFileInfo(OD[4])
    temp_op = Scen_Dir + "outputs\\temp_" + FileInfo[1]
    mc4 = RunMacro("TCB Create Matrix Currency", temp_op, "PersonTrips",,)

    // add a core to PA matrix = "DaySimPersonTrips"
    m = OpenMatrix(PA_Matrix, )
		
		matrix_cores = GetMatrixCoreNames(m)
		
		for core=1 to matrix_cores.Length do
			if matrix_cores[core]="DaySimPersonTrips" then DropMatrixCore(m, "DaySimPersonTrips")
		end
    
    AddMatrixCore(m, "DaySimPersonTrips")
    mc5 = RunMacro("TCB Create Matrix Currency", PA_Matrix, "DaySimPersonTrips",,)
    
    // add all daysim person trips
    mc5 :=nz(mc1)+nz(mc2)+nz(mc3)+nz(mc4)    
    
EndMacro

Macro "Fill Transit Airport Trips" (Args)
    shared Scen_Dir, OutDir, Modes, AccessAssgnModes, Periods // input files
		shared mc_hbo, mc_nhbw, mc_nhbo,purposes, purposesPeriod, AirPeriodFactors 

/*
PURPOSE:
- Add airport trips (post MC) to *TripsByMode matrices

STEPS:
0. Set airport parameters
1. for each of the three purposes, get transit trips from airport model mode choice output and add to PA matrix
2. transit assignment now include four time periods but airport model is still with two time periods, so use
	 factors to devide trips into four time periods
*/
		
		RunMacro("SetParameters", Args)

/*		
    mc_hbo = Scen_Dir + "outputs\\mc_hbo.mtx"
    mc_nhbw = Scen_Dir + "outputs\\mc_nhbw.mtx"
    mc_nhbo = Scen_Dir + "outputs\\mc_nhbo.mtx"
    
    purposes = {"HBO","NHBW","NHBO"}
    purposesPeriod = {"OP","OP","PK"}
		AirPeriodFactors = {0.5,0.5,0.5,0.5}  // corresponding to Periods = {"AM","MD","PM","OP"}, factors to distribute trips from PK and OP periods
*/
 
    for ipurp=1 to purposes.length do
		
				perc = RealToInt(100*ipurp/purposes.length)
				UpdateProgressBar("Fill Airport Highway Trips: " + string(ipurp) + " of " + string(purposes.length), perc)		
		
        for iacc=1 to AccessAssgnModes.length do
            for imode=1 to Modes.length do
            
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
							
							RunMacro("TCB Init")
							
							if purposes[ipurp] = "HBO" then do
									mc2 = RunMacro("TCB Create Matrix Currency", mc_hbo, tablename,,)
							end
							
							if purposes[ipurp] = "NHBW" then do
									mc2 = RunMacro("TCB Create Matrix Currency", mc_nhbw, tablename,,)
							end
							
							if purposes[ipurp] = "NHBO" then do
									mc2 = RunMacro("TCB Create Matrix Currency", mc_nhbo, tablename,,)
							end
							
							if (purposesPeriod[ipurp]="PK") then do
								//AM
								mc1 = RunMacro("TCB Create Matrix Currency", OutDir + Periods[1]+"TripsByMode.mtx", tablename,,)
								mc1 := nz(mc1) + AirPeriodFactors[1]*nz(mc2)
								//PM 																																																				// todo - transpose?
								mc3 = RunMacro("TCB Create Matrix Currency", OutDir + Periods[3]+"TripsByMode.mtx", tablename,,)
								mc3 := nz(mc3) + AirPeriodFactors[3]*nz(mc2)								
							end
							else do  //OP
								//MD
								mc1 = RunMacro("TCB Create Matrix Currency", OutDir + Periods[2]+"TripsByMode.mtx", tablename,,)
								mc1 := nz(mc1) + AirPeriodFactors[2]*nz(mc2)
								//OP
								mc3 = RunMacro("TCB Create Matrix Currency", OutDir + Periods[4]+"TripsByMode.mtx", tablename,,)
								mc3 := nz(mc3) + AirPeriodFactors[4]*nz(mc2)							
							
							end           

            end
        end 
    end

EndMacro