//**************************************
//*					Format DaySim Outputs					 *
//**************************************
// Author: nagendra.dhakar@rsginc.com
// Updated: 08/04/2015

Macro "DaySim" (Args)
    RunMacro("SetTransitParameters",Args)
    RunMacro("Run DaySim", Args)
    RunMacro("Run DaySim Summaries", Args)
    RunMacro("SetHighwayParameters", Args)
    RunMacro("SetDaySimParameters")
    RunMacro("FormatAssignmentInputs", Args)
    
    Return(1)
EndMacro

Macro "Run DaySim" (Args)
    shared Scen_Dir, OutDir, loop
    shared DaySimDir, drive
    
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

    // copy _trip.tsv file to global output directory 
    infile = DaySimDir + "outputs\\_trip.tsv"
    outfile = OutDir + "_trip.tsv"
    CopyFile(infile,outfile)
    
    status = 0

EndMacro

Macro "Run DaySim Summaries" (Args)
    shared Scen_Dir, OutDir, drive, loop
    shared DaySimDir
    
    if loop >2 then do
        path_info = SplitPath(Scen_Dir)
        drive = path_info[1]
        
        // set to outputs in scenario directory
        DaySimSumDir = Scen_Dir + "DaySimSummaries\\"

        // Launch Daysim
        command_line = "cmd /c " + drive + " && cd " + DaySimSumDir + " && daysim_summaries.cmd"
        
        status = RunProgram(command_line,{{"Maximize", "True"}})
        
        status = 0
    end 

EndMacro


Macro "SetHighwayParameters" (Args)
    shared IDTable, PeriodsHwy, TimePeriod
    
    IDTable=Args.[IDTable]
    PeriodsHwy={"AM","MD","PM","OP"}  

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

Macro "SetDaySimParameters"
    shared OutDir
    shared TripFile, MaxZone
    
    TripFile = OutDir + "_trip.tsv"    
    MaxZone  = 2900

EndMacro

Macro "FormatAssignmentInputs" (Args)

    shared OutDir, IDTable, TripFile, PeriodsHwy, TimePeriod, MaxZone, Periods, AccessAssgnModes
   
    TransitModes = {"Local", "UrbRail", "ExpBus", "ComRail", "Brt"}
    TransitMatrix_cores = {"WLKLOCBUS", "WLKURBRAIL", "WLKEXPBUS", "WLKCOMRAIL", "WLKBRT", "PNRLOCBUS", "PNRBRT", "PNREXPBUS", "PNRURBRAIL", "PNRCOMRAIL", "KNRLOCBUS", "KNRBRT", "KNREXPBUS", "KNRURBRAIL", "KNRCOMRAIL"}
    class = {"SOV","HOV"}

    // set switches
    Highway = 1
    Transit = 1
    
    dim ArrayTrips[PeriodsHwy.Length, class.Length+1, MaxZone, MaxZone] // 4-dimensional array
    dim ArrayTransitTrips[Periods.Length, TransitMatrix_cores.Length, MaxZone, MaxZone] // for time being
    //dim ArrayTransitTrips[Periods.Length, AccessAssgnModes.Length, TransitModes.Length, MaxZone, MaxZone] // for time being
 
    // Load daysim trip file to an array
    readfile = OpenFile(TripFile, "r")
    TripRecords = ReadArray(readfile)
    CloseFile(readfile)
    
    // Read daysim trip file
    UpdateProgressBar("Reading trip array ... ", )
    RunMacro("Read Trips", OutDir, TripRecords, TimePeriod, ArrayTrips, ArrayTransitTrips, Highway, Transit) 
    
    for p=1 to PeriodsHwy.length do
        UpdateProgressBar("Reading trip table: "+ PeriodsHwy[p], )
        
        //  ---------------- Highway Assignment Matrix
        if Highway = 1 then do
            
            // create a temp matrix
            mat_cores = {"IICOM", "IISU", "IIMU","IEAUTO", "IESU", "EEAUTO", "EESU","Passenger_SOV","Passenger_HOV","Commercial","SingleUnit","MU","Preload_MU", "Preload_SU", "Preload_Pass", "PersonTrips"}
            outMat = "temp_" + PeriodsHwy[p]+"OD.mtx"
            RunMacro("Create a new matrix", OutDir, IDTable, outMat, mat_cores)
            
            // Fill trips from daysim output - only for "Passenger_SOV"
            RunMacro("Fill Matrix", OutDir, outMat, MaxZone, "Passenger_SOV", ArrayTrips[p][1])
            
            // Fill trips from daysim output - only for "Passenger_HOV"
            RunMacro("Fill Matrix", OutDir, outMat, MaxZone, "Passenger_HOV", ArrayTrips[p][2])
            
            // Fill trips from daysim output - only for "Passenger_HOV"
            RunMacro("Fill Matrix", OutDir, outMat, MaxZone, "PersonTrips", ArrayTrips[p][3])
            
        end
        
        // ----------------- Transit Assignment Matrix
        
        if Transit = 1 then do
            if (p=1 or p=3) then do
                outMat = Periods[1] + "TripsByMode.mtx"
                RunMacro("Create a new matrix", OutDir, IDTable, outMat, TransitMatrix_cores)
                
                // Fill trips from daysim output - for every core
                for core=1 to TransitMatrix_cores.Length do
                    RunMacro("Fill Matrix", OutDir, outMat, MaxZone, TransitMatrix_cores[core], ArrayTransitTrips[1][core])
                end
            end
            else do
                outMat = Periods[2] + "TripsByMode.mtx"
                RunMacro("Create a new matrix", OutDir, IDTable, outMat, TransitMatrix_cores)
                
                // Fill trips from daysim output - for every core
                for core=1 to TransitMatrix_cores.Length do
                    RunMacro("Fill Matrix", OutDir, outMat, MaxZone, TransitMatrix_cores[core], ArrayTransitTrips[2][core])
                end
            end            
            
        end 
        
    end
    
endMacro

Macro "Read Trips" (OutDir, TripRecords, TimePeriod, ArrayTrips, ArrayTransitTrips, Highway, Transit)
    
    count1=0
    count2=0
    count3=0
    
    for rec=1 to TripRecords.Length do
         //split string - tab delimited
        values = ParseString(TripRecords[rec],"\t")
        
        Half = StringToint(values[7]) // 1-outbound, 2-inbound
        OTaz = StringToInt(values[15])
        DTaz = StringToInt(values[17])
        Mode = StringToInt(values[18])
        PathType = StringToInt(values[19])
        DeptTime = StringToReal(values[21])
        ArrTime = StringToReal(values[22])
        Trip = 0
        
        if (Half = 1) then TripTime = ArrTime
        else TripTime = DeptTime
        
        if OTaz >0 then do
            for tod =1 to TimePeriod.Length do
                if ((TripTime >= TimePeriod[tod][1] and TripTime <= TimePeriod[tod][2] ) or (TripTime >= TimePeriod[tod][3] and TripTime <= TimePeriod[tod][4])) then do
                    
                    if (Mode = 6 and PathType > 2) then do // transit trip
                    
                        if Transit = 1 then do
                            Trip=1
                            
                            // subtract 2 as sub-transit starts at 3 (local bus)
                            // for now only "Walk" as an access assign mode
                            
                            if (tod = 1 or tod = 3) then do  // 1- PK, (AM and PM) 2- OP (MD and OP)
                                if (tod = 3) then do
                                    // transpose for PM period
                                    OTaz = StringToInt(values[17])
                                    DTaz = StringToInt(values[15])                                
                                end
                                ArrayTransitTrips[1][PathType-2][OTaz][DTaz] = NullToZero(ArrayTransitTrips[1][PathType-2][OTaz][DTaz]) + Trip
                            end
                            else do
                                ArrayTransitTrips[2][PathType-2][OTaz][DTaz] = NullToZero(ArrayTransitTrips[2][PathType-2][OTaz][DTaz]) + Trip
                            end                            
                                 
                        end
                    end
                        
                    else do             // highway trip
                        if Highway = 1 then do
                            Trip = 0
                            
                            // person trip to vehicle trip factors: hov2 (2) and hov3+ (3.5)
                            //SOV
                            if (Mode = 3) then do
                                Trip = 1
                                ArrayTrips[tod][1][OTaz][DTaz] = NullToZero(ArrayTrips[tod][1][OTaz][DTaz]) + Trip
                                ArrayTrips[tod][3][OTaz][DTaz] = NullToZero(ArrayTrips[tod][3][OTaz][DTaz]) + 1
                            end
                            
                            //HOV
                            if (Mode = 4) then do
                                Trip = 1/2
                                ArrayTrips[tod][2][OTaz][DTaz] = NullToZero(ArrayTrips[tod][2][OTaz][DTaz]) + Trip
                                ArrayTrips[tod][3][OTaz][DTaz] = NullToZero(ArrayTrips[tod][3][OTaz][DTaz]) + 1
                            end                            

                            //HOV
                            if (Mode = 5) then do
                                Trip = 1/3.5
                                ArrayTrips[tod][2][OTaz][DTaz] = NullToZero(ArrayTrips[tod][2][OTaz][DTaz]) + Trip
                                ArrayTrips[tod][3][OTaz][DTaz] = NullToZero(ArrayTrips[tod][3][OTaz][DTaz]) + 1
                            end 

                            break // go to the next record in the trip file
                        end                         
                    end
                
                end
                
            end
    
        end
    end
    
    test=0
     
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


// Add airport trips (post MC) to PA matrix
Macro "Fill Highway Airport Trips" (Args)
    shared Scen_Dir
    
    PA_Matrix=Args.[PA Matrix]
    mc_hbo = Scen_Dir + "outputs\\mc_hbo.mtx"
    mc_nhbw = Scen_Dir + "outputs\\mc_nhbw.mtx"
    mc_nhbo = Scen_Dir + "outputs\\mc_nhbo.mtx"
    
    purposes = {"HBO","NHBW","NHBO"}
    modes = {"DA","SR2","SR3"}
    
    for p=1 to purposes.Length do
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

// Fill daysim person trips to PA matrix - for MOE generation process
Macro "Fill Person Trips" (Args)
    shared Scen_Dir, loop
    
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
    if (loop >1) then do
        // delete the core
        DropMatrixCore(m, "DaySimPersonTrips")
    end
    
    AddMatrixCore(m, "DaySimPersonTrips")
    mc5 = RunMacro("TCB Create Matrix Currency", PA_Matrix, "DaySimPersonTrips",,)
    
    // add all daysim person trips
    mc5 :=nz(mc1)+nz(mc2)+nz(mc3)+nz(mc4)    
    
EndMacro

// Add airport trips (post MC) to *TripsByMode matrices
Macro "Fill Transit Airport Trips" (Args)
    shared Scen_Dir, OutDir, Modes, AccessAssgnModes, Periods // input files

    
    mc_hbo = Scen_Dir + "outputs\\mc_hbo.mtx"
    mc_nhbw = Scen_Dir + "outputs\\mc_nhbw.mtx"
    mc_nhbo = Scen_Dir + "outputs\\mc_nhbo.mtx"
    
    Purposes = {"HBO","NHBW","NHBO"}
    PurposesPeriod = {"OP","OP","PK"}
    
    for ipurp=1 to Purposes.length do
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
                
                mc1 = RunMacro("TCB Create Matrix Currency", OutDir + PurposesPeriod[ipurp]+"TripsByMode.mtx", tablename,,)

                if Purposes[ipurp] = "HBO" then do
                    mc2 = RunMacro("TCB Create Matrix Currency", mc_hbo, tablename,,)
                end
                
                if Purposes[ipurp] = "NHBW" then do
                    mc2 = RunMacro("TCB Create Matrix Currency", mc_nhbw, tablename,,)
                end
                
                if Purposes[ipurp] = "NHBO" then do
                    mc2 = RunMacro("TCB Create Matrix Currency", mc_nhbo, tablename,,)
                end

                mc1 := nz(mc1) + nz(mc2)                

            end
        end 
    end

EndMacro