/*
 Transit Skimming
*/
Macro "Transit Skimming" (Args)

    RunMacro("SetTransitParameters",Args)  
    RunMacro("PrepareInputs")
    RunMacro("BuildDriveConnectors")
    RunMacro("BuildTransitPaths")
    RunMacro("ProcessTransitSkimsforMC", Args)
    //RunMacro("CopyTransitSkims", Args)

    Return(1)
EndMacro


// 04/24/2013 - Incorporated the Transit Model code from the MTA Model
Macro "SetTransitParameters" (Args)
UpdateProgressBar("SetTransitParameters",)
    shared scen_data_dir
    shared InDir, OutDir
    shared Periods, PeriodsHwy, Modes, AccessModes, AccessAssgnModes, Purposes, PurposePeriod
    shared TransitTimeFactor, WalkSpeed, TransitOnlyLinkDefaultSpeed, WalkBufferDistance
    shared DwellTimebyMode, DeleteTempOutputFiles, DeleteSummitFiles
    shared ValueofTime, AutoOperatingCost, AOCC_PNR, PNR_TerminalTime, MaxPNR_DriveTime
    shared highway_dbd, highway_link_bin, highway_node_bin, zone_dbd, zone_bin, tpen, route_system
    shared route_stop, route_bin, route_stop_bin, SpeedFactorTable, IDTable, TerminalTimeMtx
    shared modetable, modexfertable, MovementTable // input files
    shared mc_network_file, opnet_file, pknet_file, opskim_file, pkskim_file, OutZData, op_pnr_time_mat 
    shared pk_pnr_time_mat, OutMarketSegment, stat_file, runtime // output files

//  Set paths
    RunMacro("TCB Init")

    InDir               = scen_data_dir                                             // path of the input folder
    OutDir              = scen_data_dir + "outputs\\"                                // path of the output folder

//  Files Input to the Transit Model
    zone_dbd            = Args.[taz]                                          // TAZ layer
    parts = SplitPath(zone_dbd)
    zone_bin            = parts[1] + parts[2] + parts[3] + ".bin"                  // TAZ layer bin file
    route_system        = Args.[rs_file]                                           // input rts file
    parts = SplitPath(route_system)
    route_stop          = parts[1] + parts[2] + parts[3] + "S.dbd"                  // associated stop layer
    route_stop_bin      = parts[1] + parts[2] + parts[3] + "S.bin"                  // stop layer bin file
    route_bin           = parts[1] + parts[2] + parts[3] + "R.bin"                  // route layer bin file

    highway_dbd         = Args.[hwy db]                                      // highway layer
    parts = SplitPath(highway_dbd)
    highway_link_bin    = parts[1] + parts[2] + parts[3] + ".bin"                   // highway link layer bin file
    highway_node_bin    = parts[1] + parts[2] + parts[3] + "_.bin"                  // highway node layer bin file
    tpen                = Args.[Turn Penalty]                                       // turning penalty file
    TerminalTimeMtx     = OutDir + "terminal_time.mtx"                              // terminal time matrix (output of the highway model)
    SpeedFactorTable    = Args.[SpeedFactorTable]                                   // auto speed adjustment table
    modetable           = Args.[Modetable]                                          // transit mode definitions
    modexfertable       = Args.[Modexfertable]                                      // transfer fare and penalty
    IDTable             = Args.[IDTable]                                            // dummy zone ids used in the mode choice model
    MovementTable       = Args.[MovementTable]                                      // route-to-route transfer table template

    //  Output Files
    mc_network_file     = OutDir + "Network_MC.net"
    opnet_file          = OutDir + "NetworkC_OP.net"
    pknet_file          = OutDir + "NetworkC_PK.net"
//    opskim_file         = OutDir + "hwyskim_md2.mtx"
//    pkskim_file         = OutDir + "hwyskim_am2.mtx"
    op_pnr_time_mat     = OutDir + "PNR_Time_OP.mtx"
    pk_pnr_time_mat     = OutDir + "PNR_Time_PK.mtx"
    OutZData            = OutDir + "ZoneDataMC.asc"
    OutMarketSegment    = OutDir + "hhauto.dat"
    stat_file           = Args.[Transit Statistics]                                 // file to write transit statistics
//  ************************************************************************************************************************************

//  Define Parameters for Testing
/*    Periods                     = {"PK"}                                       // Periods defined in the transit model
    PeriodsHwy                  = {"AM"}                                       // Highway Time of Day Periods used in Transit
    Modes                       = {"ExpBus"}   // List of transit modes
    AccessModes                 = {"Walk"}                                  // List of access modes for building paths
    AccessAssgnModes            = {"Walk"}                              // List of access modes for mode choice model
    Purposes                    = {"HBW"}              // List of purposes defined in the model
*/ 

//  Define Parameters
    Periods                     = {"PK","OP"}                                       // Periods defined in the transit model
    PeriodsHwy                  = {"AM","MD"}                                       // Highway Time of Day Periods used in Transit
    Modes                       = {"Local","Brt", "ExpBus", "UrbRail", "ComRail"}   // List of transit modes
    AccessModes                 = {"Walk","Drive"}                                  // List of access modes for building paths
    AccessAssgnModes            = {"Walk","PnR","KnR"}                              // List of access modes for mode choice model
    //AccessAssgnModes            = {"Walk"}                              // List of access modes for mode choice model - for time being (DaySim Model)
    Purposes                    = {"HBW","HBO","HBPD","HBSch","HBShp","NHBO","NHBW"}              // List of purposes defined in the model


    auto_own       		= {    3,    3,     1,      1,       3,    1,    1}               // List of auto ownership categories by purpose
    PurposePeriod               = {"PK","OP","OP","OP","OP","OP","PK"}                                  // Skim that each purpose gets in the mode choice
    TransitTimeFactor           = {1.00,1.00,0.00,0.00}                             // corresponds to Link TTF No. (arterials, expressways, transitonly links, railroads)
    TransitOnlyLinkDefaultSpeed = {0.00, 0.00, 13.00, 40.00}                        // corresponds to Link TTF No.
    WalkSpeed                   = Args.[WalkSpeed]                                  // Walking Speed in miles per hour
    WalkBufferDistance          = {Args.[WalkBufferDistance]}                       // in miles
    ValueofTime                 = Args.[ValueofTime]                                // in $/min
    AutoOperatingCost           = Args.[AutoOperatingCost]                          // in cents/mile
    AOCC_PNR                    = Args.[AOCC_PNR]                                   // average occupancy of vehicle using PNRs
    PNR_TerminalTime            = Args.[PNR_TerminalTime]                           // in minutes
    MaxPNR_DriveTime            = Args.[MaxPNR_DriveTime]                           // in minutes
    DeleteTempOutputFiles       = Args.[DeleteTempOutputFiles]                      // 1 to delete the temporary files created during the transit model run (helps save disk space)
    DeleteSummitFiles           = Args.[DeleteSummitFiles]                          // 1 to delete the files required to run FTA's summit program (helps save disk space)

// Open the log file
    runtime = OpenFile(OutDir + "runtime.prn", "w")
    Return(1)
EndMacro

// STEP 1: Prepare inputs required by the transit model in the subsequent steps
Macro "PrepareInputs"
UpdateProgressBar("SetTransitParameters",)
    shared OutDir
    shared Periods, PeriodsHwy, Modes, TransitTimeFactor, WalkSpeed, TransitOnlyLinkDefaultSpeed, DwellTimebyMode
    shared highway_dbd, highway_link_bin, zone_dbd, zone_bin, route_stop, route_bin, SpeedFactorTable, IDTable, modetable // input files
    shared OutMarketSegment, runtime // output files

    stime=GetDateAndTime()
    WriteLine(runtime,"\n Begin Model Run                      - "+SubString(stime,1,3)+","+SubString(stime,4,7)+""+SubString(stime,20,5)+" ("+SubString(stime,12,8)+") ")

    RunMacro("TCB Init")

// STEP 1.1: Create a market segment file using the information available in the TAZ layer
    zone_dbd_layers = GetDBLayers(zone_dbd)
    db_tazlyr = zone_dbd + "|" + zone_dbd_layers[1]

    tazview = OpenTable("zones","FFB",{zone_bin,})
    idtableview = OpenTable("MATID","FFB",{IDTable, null})
    marketseg = OpenFile(OutMarketSegment, "w")
    parkingfile = OpenFile(OutDir + "ParkingCost.csv", "w")
    jv11=JoinViews("JV11","MATID.NEWID","zones.ID_NEW",)

rec=GetFirstRecord(jv11+"|",)
    WriteLine(parkingfile, JoinStrings({"TAZ","dailyParkingCost","CBD"},","))
    while (rec<>null) do
    
        zerocar = 0.00
        onecar = 0.00
        twocar = 0.00
        short_park = 0.00
        long_park = 0.00
        cbd_type_taz = 0.00

        if (jv11.HH10 > 0) then do
            zerocar = (jv11.[W0V0]+jv11.[W1V0]+jv11.[W2V0]+jv11.[W3V0])
            onecar = (jv11.[W0V1]+jv11.[W1V1]+jv11.[W2V1]+jv11.[W3V1])
            twocar = (jv11.[W0V2]+jv11.[W1V2]+jv11.[W2V2]+jv11.[W3V2]+jv11.[W0V3]+jv11.[W1V3]+jv11.[W2V3]+jv11.[W3V3]) 
        end
        if (jv11.SHT_PRK <> null) then short_park = jv11.SHT_PRK
        if (jv11.LNG_PRK <> null) then long_park = jv11.LNG_PRK
        if (jv11.TRANS_DISTRICT = 1) then cbd_type_taz = 1
        if (jv11.TRANS_DISTRICT <> 1) then cbd_type_taz = 0
        Writeline(marketseg, LPad(i2s(jv11.MATID.NEWID), 8) + LPad(Format(Nz(zerocar),"*0.0"), 8) +  
        		    LPad(Format(Nz(onecar),"*0.0"), 8) + LPad(Format(Nz(twocar),"*0.0"), 8) + "       0")
        WriteLine(parkingfile, JoinStrings({i2s(jv11.MATID.NEWID),r2s(long_park),i2s(cbd_type_taz)},","))
        rec=GetNextRecord(jv11+"|",,)
    end

    CloseFile(marketseg)
    CloseFile(parkingfile)


// STEP 1.3: Add required fields in the highway layer (if not already existing)
    vws = GetViewNames()
    for i = 1 to vws.length do CloseView(vws[i]) end

/* on notfound goto quit  */
    view_name = OpenTable ("hwy_bin","FFB",{highway_link_bin,})

WalkLink:
    on notfound goto WalkLinkIn
    GetField(view_name+".WalkLink")
    goto TransitTime

WalkLinkIn:
    strct = GetTableStructure(view_name)
    for i = 1 to strct.length do strct[i] = strct[i] + {strct[i][1]} end

    new_struct = strct + {{"WalkLink", "Integer", 10, 0, "False",,,, null},
                          {"LinkTTF", "Integer", 10, 0, "False",,,, null},
                          {"WalkTime", "Real", 10, 4, "False",,,, null}}
    ModifyTable(view_name, new_struct)

TransitTime:
    on notfound goto TransitTimeIn
    GetField(view_name+".TransitTimeOP_AB")
    goto skip

TransitTimeIn:
    strct = GetTableStructure(view_name)
    for i = 1 to strct.length do strct[i] = strct[i] + {strct[i][1]} end

    new_struct = strct + {{"TransitTimeOP_AB", "Real", 10, 4, "False",,,, null},
                          {"TransitTimeOP_BA", "Real", 10, 4, "False",,,, null},
                          {"TransitTimePK_AB", "Real", 10, 4, "False",,,, null},
                          {"TransitTimePK_BA", "Real", 10, 4, "False",,,, null}}
    ModifyTable(view_name, new_struct)

skip:

// STEP 1.4: Fill the highway fields with default values
    RunMacro("TCB Init")
    vws = GetViewNames()
    for i = 1 to vws.length do CloseView(vws[i]) end

    layers = GetDBlayers(highway_dbd)
    nlayer = layers[1]
    llayer = layers[2]
    db_nodelyr = highway_dbd + "|" + nlayer
    db_linklyr = highway_dbd + "|" + llayer

// STEP 1.4.2: Fill WalkLink, WalkTime and LinkTTF
    
    Opts = null
    Opts.Input.[Dataview Set] = {db_linklyr, llayer, "Selection", "Select * where ID>=1"}         // Fill All links with LinkTTF=1
    Opts.Global.Fields = {"[LinkTTF]","[WalkLink]","[WalkTime]"}
    Opts.Global.Method = "Formula"
    Opts.Global.Parameter = {"1","250","99999"}
    ret_value = RunMacro("TCB Run Operation", 1, "Fill Dataview", Opts)
    if !ret_value then goto quit

    Opts = null
    Opts.Input.[Dataview Set] = {db_linklyr, llayer, "Selection", "Select * where CCSTYLE=3 | CCSTYLE=4 | CCSTYLE>=6 & TMODE<>12"}    // exclude freeways, ramps and railroads
    Opts.Global.Fields = {"[WalkLink]","[WalkTime]"}
    Opts.Global.Method = "Formula"
    Opts.Global.Parameter = {"98", "[" + llayer + "].Length*60/"+string(WalkSpeed)}
    ret_value = RunMacro("TCB Run Operation", 1, "Fill Dataview", Opts)
    if !ret_value then goto quit
    
    // Cap walktime on long centroid connectors to take care of huge zones in the suburbs
    Opts = null
    Opts.Input.[Dataview Set] = {db_linklyr, llayer, "Selection", "Select * where CCSTYLE=99 & Length>0.5"}    // centroid connectors longer than 0.5 miles
    Opts.Global.Fields = {"[WalkTime]"}
    Opts.Global.Method = "Formula"
    Opts.Global.Parameter = {"0.5*60/"+string(WalkSpeed)}     // walk time no longer than 0.5 mile walk
    ret_value = RunMacro("TCB Run Operation", 1, "Fill Dataview", Opts)
    if !ret_value then goto quit

    Opts = null
    Opts.Input.[Dataview Set] = {db_linklyr, llayer, "Selection", "Select * where CCSTYLE<=2 | CCSTYLE=5"}    // freeways, ramps
    Opts.Global.Fields = {"[LinkTTF]"}
    Opts.Global.Method = "Value"
    Opts.Global.Parameter = {2}
    ret_value = RunMacro("TCB Run Operation", 1, "Fill Dataview", Opts)
    if !ret_value then goto quit

    Opts = null
    Opts.Input.[Dataview Set] = {db_linklyr, llayer, "Selection", "Select * where CCSTYLE=11"}    // transit only links
    Opts.Global.Fields = {"[LinkTTF]"}
    Opts.Global.Method = "Value"
    Opts.Global.Parameter = {3}
    ret_value = RunMacro("TCB Run Operation", 1, "Fill Dataview", Opts)
    if !ret_value then goto quit

    Opts = null
    Opts.Input.[Dataview Set] = {db_linklyr, llayer, "Selection", "Select * where TMODE=98"}    // rail-bus stop connector links
    Opts.Global.Fields = {"[WalkLink]"}
    Opts.Global.Method = "Value"
    Opts.Global.Parameter = {98}
    ret_value = RunMacro("TCB Run Operation", 1, "Fill Dataview", Opts)
    if !ret_value then goto quit

    Opts = null
    Opts.Input.[Dataview Set] = {db_linklyr, llayer, "Selection", "Select * where TMODE=98"}    // rail-bus stop connector links
    Opts.Global.Fields = {"[WalkTime]"}
    Opts.Global.Method = "Value"
    Opts.Global.Parameter = {1}
    ret_value = RunMacro("TCB Run Operation", 1, "Fill Dataview", Opts)
    if !ret_value then goto quit

flds = {"LinkTTF","WalkLink","WalkTime"}
values = {4,250,99999}
for i=1 to flds.length do
    Opts = null
    Opts.Input.[Dataview Set] = {db_linklyr, llayer, "Selection", "Select * where TMODE=12 | TMODE=13 | TMODE=14"}    // railroad links
    Opts.Global.Fields = {flds[i]}
    Opts.Global.Method = "Value"
    Opts.Global.Parameter = {values[i]}
    ret_value = RunMacro("TCB Run Operation", 1, "Fill Dataview", Opts)
    if !ret_value then goto quit
end

// STEP 1.4.3: Calculate default transit times based on the auto speeds
    for i=1 to TransitTimeFactor.length do
        Opts = null
        Opts.Input.[Dataview Set] = {db_linklyr, llayer, "Selection", "Select * where [LinkTTF]="+string(i)}
        Opts.Global.Fields = {"[TransitTimeOP_AB]","[TransitTimeOP_BA]","[TransitTimePK_AB]","[TransitTimePK_BA]"}
        Opts.Global.Method = "Formula"
        if (i=1) then  Opts.Global.Parameter = {"if (time_MD_AB=null | time_MD_AB<0.001) then [" + llayer + "].Length*60/15 else time_MD_AB*"+string(TransitTimeFactor[i]),
                                                "if (time_MD_BA=null | time_MD_BA<0.001) then [" + llayer + "].Length*60/15 else time_MD_BA*"+string(TransitTimeFactor[i]),
                                                "if (time_AM_AB=null | time_AM_AB<0.001) then [" + llayer + "].Length*60/15 else time_AM_AB*"+string(TransitTimeFactor[i]),
                                                "if (time_AM_BA=null | time_AM_BA<0.001) then [" + llayer + "].Length*60/15 else time_AM_BA*"+string(TransitTimeFactor[i])}
        if (i=2) then  Opts.Global.Parameter = {"if (time_MD_AB=null | time_MD_AB<0.001) then [" + llayer + "].Length*60/15 else time_MD_AB*"+string(TransitTimeFactor[i]),
                                                "if (time_MD_BA=null | time_MD_BA<0.001) then [" + llayer + "].Length*60/15 else time_MD_BA*"+string(TransitTimeFactor[i]),
                                                "if (time_AM_AB=null | time_AM_AB<0.001) then [" + llayer + "].Length*60/15 else time_AM_AB*"+string(TransitTimeFactor[i]),
                                                "if (time_AM_BA=null | time_AM_BA<0.001) then [" + llayer + "].Length*60/15 else time_AM_BA*"+string(TransitTimeFactor[i])}
        if (i=3) then  Opts.Global.Parameter = {"[" + llayer + "].Length*60/"+string(TransitOnlyLinkDefaultSpeed[i]),  // LinkTTF=3 for transit only links
                                                "[" + llayer + "].Length*60/"+string(TransitOnlyLinkDefaultSpeed[i]),
                                                "[" + llayer + "].Length*60/"+string(TransitOnlyLinkDefaultSpeed[i]),
                                                "[" + llayer + "].Length*60/"+string(TransitOnlyLinkDefaultSpeed[i])}
        if (i=4) then  Opts.Global.Parameter = {"[" + llayer + "].TTIME",                                              // LinkTTF=4 for rail tracks
                                                "[" + llayer + "].TTIME",
                                                "[" + llayer + "].TTIME",
                                                "[" + llayer + "].TTIME"}
        ret_value = RunMacro("TCB Run Operation", 4, "Fill Dataview", Opts)
        if !ret_value then goto quit
    end

// STEP 1.5: Fill Stop Layer with StopFlags (check whether there is a stop or not)
// add 0's to missing layover values in the stop file
    Opts = null
    Opts.Input.[Dataview Set] = {route_stop + "|Route Stops", "Route Stops", "Selection", "Select * where Layover=null"}
    Opts.Global.Fields = {"Layover"}
    Opts.Global.Method = "Value"
    Opts.Global.Parameter = {0}
    ret_value = RunMacro("TCB Run Operation", 6, "Fill Dataview", Opts)
    // if !ret_value then goto quit
	
    for iper=1 to Periods.length do
        // first set all flag to null and then add 1's to the selected stops
        Opts = null
        Opts.Input.[Dataview Set] = {{route_stop + "|Route Stops", route_bin, "Route_ID", "Route_ID"},}
        Opts.Global.Fields = {Periods[iper]+"TransitFlag"}
        Opts.Global.Method = "Value"
        Opts.Global.Parameter = {}
        ret_value = RunMacro("TCB Run Operation", 6, "Fill Dataview", Opts)
        if !ret_value then goto quit

        Opts = null
        Opts.Input.[Dataview Set] = {{route_stop + "|Route Stops", route_bin, "Route_ID", "Route_ID"}, "StopsRouteSystemR", "Selection", "Select * where test_HW_"+Periods[iper]+">0& test_HW_"+Periods[iper]+"<999"}
        //Opts.Input.[Dataview Set] = {{route_stop + "|Route Stops", route_bin, "Route_ID", "Route_ID"}, "StopsRouteSystemR", "Selection", "Select * where HW_"+PeriodsHwy[iper]+">0& HW_"+PeriodsHwy[iper]+"<999"}
        Opts.Global.Fields = {Periods[iper]+"TransitFlag"}
        Opts.Global.Method = "Value"
        Opts.Global.Parameter = {1}
        ret_value = RunMacro("TCB Run Operation", 6, "Fill Dataview", Opts)
        if !ret_value then goto quit
    end

// STEP 1.6: Open & read the modes table to add Dwell Times
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
    NoofModes=i-1

// Fill Peak Dwell Time Values
    for imode=1 to NoofModes do
        Opts = null
        Opts.Input.[Dataview Set] = {{route_stop + "|Route Stops", route_bin, "Route_ID", "Route_ID"}, "Route StopsRouteSystemR", "Selection", "Select * where MODE="+string(DwellTimebyMode[imode][1])}
        Opts.Global.Fields = {"[PKDwellTime]"}
        Opts.Global.Method = "Value"
        Opts.Global.Parameter = {DwellTimebyMode[imode][2]}
        ret_value = RunMacro("TCB Run Operation", 5, "Fill Dataview", Opts)
    //    if !ret_value then goto quit
    end

// Fill Off-Peak Dwell Time Values
    for imode=1 to NoofModes do
        Opts = null
        Opts.Input.[Dataview Set] = {{route_stop + "|Route Stops", route_bin, "Route_ID", "Route_ID"}, "Route StopsRouteSystemR", "Selection", "Select * where MODE="+string(DwellTimebyMode[imode][1])}
        Opts.Global.Fields = {"[OPDwellTime]"}
        Opts.Global.Method = "Value"
        Opts.Global.Parameter = {DwellTimebyMode[imode][3]}
        ret_value = RunMacro("TCB Run Operation", 5, "Fill Dataview", Opts)
    //    if !ret_value then goto quit
    end

// STEP 1.7: Make a zone-zone matrix of 1's to conduct Preassignment
    zonefile=OpenTable("zonedata","FFB",{IDTable,})
    CreateMatrix({zonefile+"|","NEWID","Rows"}, {zonefile+"|","NEWID","Columns"},
                 {{"File Name",OutDir + "zone.mtx"}, {"Type" ,"Short"}, {"Tables" ,{"Matrix 1"}}})
    Opts = null
    Opts.Input.[Matrix Currency] = {OutDir + "zone.mtx", "Matrix 1", "Rows", "Columns"}
    Opts.Global.Method = 1
    Opts.Global.Value = 1
    Opts.Global.[Cell Range] = 2
    Opts.Global.[Matrix Range] = 1
    Opts.Global.[Matrix List] = {"Matrix 1"}
    ret_value = RunMacro("TCB Run Operation", 1, "Fill Matrices", Opts)

    vws = GetViewNames()
    for i = 1 to vws.length do CloseView(vws[i]) end
    stime=GetDateAndTime()
    WriteLine(runtime,"\n End Prepare Inputs to Transit Model  - "+SubString(stime,1,3)+","+SubString(stime,4,7)+""+SubString(stime,20,5)+" ("+SubString(stime,12,8)+") ")
    Return(1)
quit:
    stime=GetDateAndTime()
    WriteLine(runtime,"\n End Prepare Inputs to Transit Model  - "+SubString(stime,1,3)+","+SubString(stime,4,7)+""+SubString(stime,20,5)+" ("+SubString(stime,12,8)+") ")
    Return(ret_value)
EndMacro

// STEP 3: Create weighted drive connectors
Macro "BuildDriveConnectors"
UpdateProgressBar("BuildDriveConnectors",)
    shared Periods, PeriodsHwy, Modes
    shared ValueofTime, AutoOperatingCost, AOCC_PNR, PNR_TerminalTime, MaxPNR_DriveTime
    shared highway_dbd, highway_node_bin, zone_bin
    shared mc_network_file, op_pnr_time_mat, pk_pnr_time_mat, runtime // output files


    RunMacro("TCB Init")

    layers = GetDBlayers(highway_dbd)
    nlayer = layers[1]
    llayer = layers[2]

    db_nodelyr = highway_dbd + "|" + nlayer
    db_linklyr = highway_dbd + "|" + llayer


/* Added Build Highway Network Step */

    // STEP 3.1: Build Highway Network

    Opts = null
    Opts.Input.[Link Set] = {db_linklyr , llayer, "Selection", "Select * where CCSTYLE<> null & CCSTYLE<>9 & CCSTYLE<>11"}
    Opts.Global.[Network Label] = "Based on "+db_linklyr
    //Opts.Global.[Network Options].[Node Id] = nlayer+".ID"
    Opts.Global.[Network Options].[Turn Penalties] = "Yes"
    Opts.Global.[Network Options].[Keep Duplicate Links] = "FALSE"
    Opts.Global.[Network Options].[Ignore Link Direction] = "FALSE"
    Opts.Global.[Network Options].[Time Units] = "Minutes"
    Opts.Global.[Link Options] = {{"Length", {llayer+".Length", llayer+".Length", , , "False"}}, 
    	{"[capacity_am_AB / capacity_am_BA]", {llayer+".capacity_am_AB", llayer+".capacity_am_BA", , , "False"}}, 
    	{"[capacity_pm_AB / capacity_pm_BA]", {llayer+".capacity_pm_AB", llayer+".capacity_pm_BA", , , "False"}}, 
    	{"[capacity_op_AB / capacity_op_BA]", {llayer+".capacity_op_AB", llayer+".capacity_op_BA", , , "False"}}, 
    	{"[capacity_md_AB / capacity_md_BA]", {llayer+".capacity_md_AB", llayer+".capacity_md_BA", , , "False"}}, 
    	{"[capacity_daily_AB / capacity_daily_BA]", {llayer+".capacity_daily_AB", llayer+".capacity_daily_BA", , , "False"}}, 
    	
    	{"[SPD_FF_AB / SPD_FF_BA]", {llayer+".SPD_FF_AB", llayer+".SPD_FF_BA", , , "False"}}, 
    	{"[SPD_AM_AB / SPD_AM_BA]", {llayer+".SPD_AM_AB", llayer+".SPD_AM_BA", , , "False"}}, 
    	{"[SPD_MD_AB / SPD_MD_BA]", {llayer+".SPD_MD_AB", llayer+".SPD_MD_BA", , , "False"}}, 
    	{"[SPD_PM_AB / SPD_PM_BA]", {llayer+".SPD_PM_AB", llayer+".SPD_PM_BA", , , "False"}}, 
    	{"[SPD_OP_AB / SPD_OP_BA]", {llayer+".SPD_OP_AB", llayer+".SPD_OP_BA", , , "False"}}, 
    	{"[SPD_MU_AB / SPD_MU_BA]", {llayer+".SPD_MU_AB", llayer+".SPD_MU_BA", , , "False"}}, 
    	
    	{"TimeFF_*", {llayer+".time_FF_AB", llayer+".time_FF_BA", , , "False"}}, 
    	{"TimeCPK_*", {llayer+".time_AM_AB", llayer+".time_AM_BA", , , "False"}}, 
    	{"TimeCOP_*", {llayer+".time_MD_AB", llayer+".time_MD_BA", , , "False"}}, 
    	{"alpha", {llayer+".alpha", llayer+".alpha", , , "False"}}, 
    	{"beta", {llayer+".beta", llayer+".beta", , , "False"}}}
    Opts.Global.[Length Units] = "Miles"
    Opts.Global.[Time Units] = "Minutes"
    Opts.Output.[Network File] = mc_network_file
    ret_value = RunMacro("TCB Run Operation", "Build Highway Network", Opts, &Ret)
    if !ret_value then goto quit 


   for iper=1 to Periods.length do
        if (iper=1) then innet=mc_network_file
        if (iper=1) then outmat=pk_pnr_time_mat
        if (iper=2) then innet=mc_network_file
        if (iper=2) then outmat=op_pnr_time_mat

    // STEP 3.2: TCSPMAT - Centroids to Parking Nodes Skim
        Opts = null
        Opts.Input.Network = innet
        Opts.Input.[Origin Set] = {db_nodelyr, nlayer, "Selection", "Select * where CCSTYLE=99 | CCSTYLE=98 | CCSTYLE=97"}
        Opts.Input.[Destination Set] = {db_nodelyr, nlayer, "PNR_NODE", "Select * where [PNR_NODE]=1"}
        Opts.Input.[Via Set] = {db_nodelyr, nlayer}
        Opts.Field.Minimize = "TimeC" + Periods[iper] + "_*"
        Opts.Field.Nodes = nlayer + ".ID"
        Opts.Field.[Skim Fields]= {{"TimeC" + Periods[iper] + "_*", "All"}, {"Length", "All"}}
        Opts.Output.[Output Type] = "Matrix"
        Opts.Output.[Output Matrix].Label = "Shortest Path"
        Opts.Output.[Output Matrix].[File Name] = outmat
        ret_value = RunMacro("TCB Run Procedure", 3, "TCSPMAT", Opts)
        if !ret_value then goto quit

        vws = GetViewNames()
        for i = 1 to vws.length do CloseView(vws[i]) end

    // STEP 3.2: Revise the times to a weighted time
        tazview = OpenTable("zones","FFB",{zone_bin,})
        hnodeview = OpenTable("hnodes","FFB",{highway_node_bin,})
        dacc = OpenMatrix(outmat,)
        midx = GetMatrixIndex(dacc)
        dacc_time_cur   = CreateMatrixCurrency(dacc, "TimeC" + Periods[iper] +"_* (Skim)", midx[1], midx[2], )
        dacc_dist_cur   = CreateMatrixCurrency(dacc, "Length (Skim)", midx[1], midx[2], )
        dacc_time_cur   := NullToZero(dacc_time_cur)
        rowID           = GetMatrixRowLabels(dacc_time_cur)
        pnrID           = GetMatrixColumnLabels(dacc_time_cur)
        
        //test
        fields = GetFields(hnodeview, "All")

        for i=1 to rowID.length do
            drive_time   = GetMatrixVector(dacc_time_cur,  {{"Row", StringToInt(rowID[i])}})
            drive_distance   = GetMatrixVector(dacc_dist_cur,  {{"Row", StringToInt(rowID[i])}})
            DriveTime    = Vector(drive_time.length, "Float",)
            // identify production area type
            rh1 = LocateRecord(tazview+"|", "ID_NEW", {StringToInt(rowID[i])}, {{"Exact", "True"}})
            if rh1 <> null then ProdAType=tazview.Predict
            if ProdAType = "CBD" then DrWt = 99       // no connector from CBD
            if (ProdAType = "URBAN" | ProdAType = "SU" | ProdAType = "RURAL") then DrWt = 1.5

            for j=1 to drive_time.length do
                pnrshed = 0
                pnrcost = 0
                DriveTime[j] = null
                rh2 = LocateRecord(hnodeview+"|", "ID", {StringToInt(pnrID[j])}, {{"Exact", "True"}})
                if rh2 <> null then pnrshed = hnodeview.PNR_SHED
                if rh2 <> null then pnrcost = hnodeview.PNR_COST
                if (pnrshed > 0) then do
                    if (drive_time[j] <= pnrshed) then DriveTime[j] = DrWt*drive_time[j] +
                                                                         (((AutoOperatingCost/100)/AOCC_PNR)*drive_distance[j]/ValueofTime) +
                                                                         (pnrcost/ValueofTime) +
                                                                         PNR_TerminalTime
                    if (drive_time[j] > pnrshed)  then DriveTime[j] = DrWt*pnrshed +
                                                                         DrWt*((pnrshed - drive_time[j]) + (pnrshed - drive_time[j])*(pnrshed - drive_time[j])) +
                                                                         (((AutoOperatingCost/100)/AOCC_PNR)*drive_distance[j]/ValueofTime) +
                                                                         (pnrcost/ValueofTime) +
                                                                         PNR_TerminalTime
                    if (drive_time[j] > MaxPNR_DriveTime) then DriveTime[j] = null
                    if (DriveTime[j] > 45) then DriveTime[j] = null
                end
            end
            SetMatrixVector(dacc_time_cur, DriveTime, {{"Row", StringToInt(rowID[i])}} )
        end
         vws = GetViewNames()
         for i = 1 to vws.length do CloseView(vws[i]) end
   end
   stime=GetDateAndTime()
   WriteLine(runtime,"\n End Build Drive Connectors           - "+SubString(stime,1,3)+","+SubString(stime,4,7)+""+SubString(stime,20,5)+" ("+SubString(stime,12,8)+") ")
   Return(1)
quit:
   stime=GetDateAndTime()
   WriteLine(runtime,"\n End Build Drive Connectors           - "+SubString(stime,1,3)+","+SubString(stime,4,7)+""+SubString(stime,20,5)+" ("+SubString(stime,12,8)+") ")
   Return(ret_value)
EndMacro

// STEP 4: Build transit paths
Macro "BuildTransitPaths"
UpdateProgressBar("BuildTransitPaths",)
    shared OutDir, Periods, PeriodsHwy, Modes, AccessModes, ValueofTime, highway_dbd, route_system
    shared route_stop, route_stop_bin, IDTable, TerminalTimeMtx, modetable, modexfertable     // input files
    shared op_pnr_time_mat, pk_pnr_time_mat, runtime // output files
	shared iper_count, iacc_count, imode_count // for quick transit skim
	
    RunMacro("TCB Init")

    layers = GetDBlayers(highway_dbd)
    nlayer = layers[1]
    llayer = layers[2]
    db_nodelyr = highway_dbd + "|" + nlayer
    db_linklyr = highway_dbd + "|" + llayer
	counter=Periods.length*Modes.length*AccessModes.length
	count=1
	
	//imode_start=5
	// //added by cheng
	// if iper_count=null then iper_count=Periods.length
	// if iacc_count=null then iacc_count=AccessModes.Length
	// if imode_count=null then do 
	// 	imode_count=Modes.length
	// 	imode_start=1
	// end
	            
	           
// Main loop
    for iper=1 to Periods.Length do
    // for iper=1 to iper_count do
        for iacc=1 to AccessModes.Length do
        // for iacc=1 to iacc_count do
            for imode=1 to Modes.Length do
            // for imode=imode_start to imode_count do
            
					UpdateProgressBar("Build transit paths Loop - "+ Periods[iper] +" - " + AccessModes[iacc] + " - "+  Modes[imode] + " -" +i2s(count)+" of " +i2s(counter),)
                outtnw= OutDir + Periods[iper] + "_" + AccessModes[iacc] + Modes[imode] + ".tnw"
                outskim = OutDir + Periods[iper] + "_" + AccessModes[iacc] + Modes[imode] + ".mtx"
                outtps  = OutDir + Periods[iper] + "_" + AccessModes[iacc] + Modes[imode] + ".tps"

                if (iper=1) then pnr_file = pk_pnr_time_mat
                if (iper=2) then pnr_file = op_pnr_time_mat

                if imode=1 then selmode=" (Mode<>null & Mode<=5)"
                if imode=2 then selmode=" (Mode<>null & (Mode<=5 | Mode=8 | Mode=9))"
                if imode=3 then selmode=" (Mode<>null & Mode<=9)"
                if imode=4 then selmode=" (Mode<>null & Mode<=10)"
                if imode=5 then selmode=" (Mode<>null & Mode<=14)"


            // STEP 4.1: Build Transit Network
                Opts = null
                Opts.Input.[Transit RS] = route_system
                Opts.Input.[RS Set] = {route_system + "|Route System", "Route System", "Routes", "Select * where test_HW_" + Periods[iper] + ">0 & " + selmode}
								//Opts.Input.[RS Set] = {route_system + "|Route System", "Route System", "Routes", "Select * where HW_" + PeriodsHwy[iper] + ">0 & " + selmode}
                Opts.Input.[Walk Set] = {db_linklyr, llayer}
                Opts.Input.[Stop Set] = {route_stop + "|Route Stops", "Route Stops"}
                Opts.Global.[Network Label] = "Based on 'Route System'"
                Opts.Global.[Network Options].[Link Attributes] = {{"Length", {llayer + ".Length", llayer + ".Length"}, "SUMFRAC"},
                                                                   {"ID", {llayer + ".ID", llayer + ".ID"}, "SUMFRAC"},
                                                                   {"TimeCOP_*", {llayer + ".time_MD_AB", llayer + ".time_MD_BA"}, "SUMFRAC"},
                                                                   {"TimeCPK_*", {llayer + ".time_AM_AB", llayer + ".time_AM_BA"}, "SUMFRAC"},
                                                                   {"WalkTime", {llayer + ".WalkTime", llayer + ".WalkTime"}, "SUMFRAC"},
                                                                   {"TransitTimeOP_*", {llayer + ".TransitTimeOP_AB", llayer + ".TransitTimeOP_BA"}, "SUMFRAC"},
                                                                   {"TransitTimePK_*", {llayer + ".TransitTimePK_AB", llayer + ".TransitTimePK_BA"}, "SUMFRAC"}}
                Opts.Global.[Network Options].[Street Attributes].Length = {llayer + ".Length", llayer + ".Length"}
                Opts.Global.[Network Options].[Street Attributes].ID = {llayer + ".ID", llayer + ".ID"}
                Opts.Global.[Network Options].[Street Attributes].[TimeCOP_*] = {llayer + ".time_MD_AB", llayer + ".time_MD_BA"}
                Opts.Global.[Network Options].[Street Attributes].[TimeCPK_*] = {llayer + ".time_AM_AB", llayer + ".time_AM_BA"}
                Opts.Global.[Network Options].[Street Attributes].WalkTime = {llayer + ".WalkTime", llayer + ".WalkTime"}
                Opts.Global.[Network Options].[Street Attributes].[TransitTimeOP_*] = {llayer + ".TransitTimeOP_AB", llayer + ".TransitTimeOP_BA"}
                Opts.Global.[Network Options].[Street Attributes].[TransitTimePK_*] = {llayer + ".TransitTimePK_AB", llayer + ".TransitTimePK_BA"}
                Opts.Global.[Network Options].[Route Attributes].Route_ID = {"[Route System].Route_ID"}
                Opts.Global.[Network Options].[Route Attributes].Direction = {"[Route System].Direction"}
                Opts.Global.[Network Options].[Route Attributes].Track = {"[Route System].Track"}
                Opts.Global.[Network Options].[Route Attributes].Distance = {"[Route System].Distance"}
                //Opts.Global.[Network Options].[Route Attributes].PK_HDWY = {"[Route System].HW_AM"}
                //Opts.Global.[Network Options].[Route Attributes].OP_HDWY = {"[Route System].HW_MD"}
                Opts.Global.[Network Options].[Route Attributes].PK_HDWY = {"[Route System].test_HW_PK"}
                Opts.Global.[Network Options].[Route Attributes].OP_HDWY = {"[Route System].test_HW_OP"}				
                Opts.Global.[Network Options].[Route Attributes].Mode = {"[Route System].Mode"}
                Opts.Global.[Network Options].[Route Attributes].FareType = {"[Route System].FareType"}
                Opts.Global.[Network Options].[Stop Attributes] = {{"ID", {"[Route Stops].ID"}},
                                                                   {"Longitude", {"[Route Stops].Longitude"}},
                                                                   {"Latitude", {"[Route Stops].Latitude"}},
                                                                   {"Route_ID", {"[Route Stops].Route_ID"}},
                                                                   {"Pass_Count", {"[Route Stops].Pass_Count"}},
                                                                   {"Milepost", {"[Route Stops].Milepost"}},
                                                                   {"STOP_ID", {"[Route Stops].STOP_ID"}},
                                                            //sra       {"UserID", {"[Route Stops].UserID"}},
                                                                   {"FareZone", {"[Route Stops].FareZone"}},
                                                                   {"NearNode", {"[Route Stops].NearNode"}}}
                Opts.Global.[Network Options].[Street Node Attributes].ID = {nlayer + ".ID"}
                Opts.Global.[Network Options].[Street Node Attributes].CCSTYLE = {nlayer + ".CCSTYLE"}
                Opts.Global.[Network Options].Walk = "Yes"
                Opts.Global.[Network Options].[Mode Field] = "[Route System].Mode"
                Opts.Global.[Network Options].[Walk Mode] = llayer + ".WalkLink"
                Opts.Global.[Network Options].TagField = "NearNode"
                Opts.Global.[Network Options].Overide = {"[Route Stops].ID", "Route Stops.NearNode"}
                Opts.Output.[Network File] = outtnw

                ret_value = RunMacro("TCB Run Operation", "Build Transit Network", Opts, &Ret)
                if !ret_value then goto quit


            // STEP 3.2: Transit Network Setting PF
                Opts = null
		Opts.Global.[Class Names] = {"Class 1"}
		Opts.Global.[Class Description] = {"Class 1"}
		Opts.Global.[current class] = "Class 1"

                Opts.Input.[Transit RS] = route_system
                Opts.Input.[Transit Network] = outtnw
                Opts.Input.[Mode Table] = {modetable}
                Opts.Input.[Mode Cost Table] = {modexfertable}
                if AccessModes[iacc]="Drive" then do
                  Opts.Input.[OP Time Currency] = {pnr_file, "TimeC" + Periods[iper] + "_* (Skim)", , }
                  Opts.Input.[OP Dist Currency] = {pnr_file, "Length (Skim)", , }
                  
                  //debug
                  SetView(llayer)
                  qry= "Select * where CCSTYLE<>11 & TMODE<>98 & TMODE<>12 & TMODE<>13 & TMODE<>14 & (time_" + PeriodsHwy[iper] + "_AB+time_" + PeriodsHwy[iper] +"_BA)<>null"
                  n1 = SelectByQuery("selection", "Several", qry,)
                  if n1=0 then showmessage("can't select "+ llayer +" " + qry)
                  //debug
                  
                  Opts.Input.[Driving Link Set] = {db_linklyr, llayer, "Selection", "Select * where CCSTYLE<>11 & TMODE<>98 & TMODE<>12 & TMODE<>13 & TMODE<>14 & (time_" + PeriodsHwy[iper] + "_AB+time_" + PeriodsHwy[iper] +"_BA)<>null"}
                end
                Opts.Input.[Centroid Set] = {db_nodelyr, nlayer, "AllZones", "Select * where CCSTYLE=99 | CCSTYLE=98 | CCSTYLE=97"}
                  
                  //debug
                  SetView(nlayer)
                  qry= "Select * where CCSTYLE=99 | CCSTYLE=98 | CCSTYLE=97"
                  n1 = SelectByQuery("selection", "Several", qry,) 
                  if n1=0 then showmessage("can't select "+ nlayer +" " + qry)
                  //debug
                  
                Opts.Field.[Link Impedance] = "TransitTime"+Periods[iper]+"_*"
                if AccessModes[iacc]="Drive" then do
                  Opts.Field.[Link Drive Time] = "TimeC"+Periods[iper]+"_*"
                end
                Opts.Field.[Route Headway] = Periods[iper] + "_HDWY"
                Opts.Field.[Mode Fare]            = "FARE"
                Opts.Field.[Mode Imp Weight]      = Periods[iper]+"_LNKIMP"
                Opts.Field.[Mode IWait Weight]    = "WAIT_IW"
                Opts.Field.[Mode XWait Weight]    = "WAIT_XW"
                Opts.Field.[Mode Dwell Weight]    = "DWELL_W"
            //    Opts.Field.[Mode Headway]         = "MODES.HEADWAY"
                Opts.Field.[Mode Max IWait]       = "MAX_WAIT"
                Opts.Field.[Mode Min IWait]       = "MIN_WAIT"
                Opts.Field.[Mode Max XWait]       = "MAX_WAIT"
                Opts.Field.[Mode Min XWait]       = "MIN_WAIT"
                Opts.Field.[Mode Dwell Time]      = Periods[iper]+"_DWELL"
                Opts.Field.[Mode Max Access]      = "MAX_ACCESS"
                Opts.Field.[Mode Max Egress]      = "MAX_EGRESS"
                Opts.Field.[Mode Max Transfer]    = "MAX_XFER"
                Opts.Field.[Mode Max Imp]         = "MAX_TIME"
                Opts.Field.[Mode Impedance]       = Periods[iper]+"_IMP"
            //    Opts.Field.[Mode Speed]           = "MODES.SPEED"
                Opts.Field.[Mode Used]            = "MODE_USED"
                Opts.Field.[Mode Access]          = "MODE_ACC"
                Opts.Field.[Mode Egress]          = "MODE_EGR"
                Opts.Field.[Inter-Mode Xfer From] = "FROM"
                Opts.Field.[Inter-Mode Xfer To]   = "TO"
                Opts.Field.[Inter-Mode Xfer Time] = "XFER_PEN"
                Opts.Field.[Inter-Mode Xfer Fare] = "XFER_FARE"
                Opts.Global.[Global Fare Type] = 1
                Opts.Global.[Global Fare Value] = 1.60
                Opts.Global.[Global Xfer Fare] = 1.60
                Opts.Global.[Global Max WACC Path] = 50
                Opts.Global.[Global Max PACC Path] = 5
                Opts.Global.[Path Method] = 3
                Opts.Global.[Path Threshold] = 0.7
                Opts.Global.[Value of Time] = ValueofTime
                Opts.Global.[Max Xfer Number] = 4
                Opts.Global.[Max Trip Time] = 240
                Opts.Global.[Max Drive Time] = 45                     // this is weighted drive time
                Opts.Global.[Walk Weight] = 2.5
                Opts.Global.[Drive Time Weight] = 1.0                 // already weighted
                Opts.Flag.[Use All Walk Path] = "Yes"
                if AccessModes[iacc]="Drive" then do
                 Opts.Flag.[Use All Walk Path] = "No"
                 Opts.Flag.[Use Park and Ride] = "Yes"
                 Opts.Flag.[Use P&R Walk Access] = "No"
                end
                if AccessModes[iacc]<>"Drive" then do
                  Opts.Flag.[Use Park and Ride] = "No"
                end
                Opts.Global.[Global Layover Time] = 0
                Opts.Flag.[Use Mode] = "Yes"
                Opts.Flag.[Use Mode Cost] = "Yes"
                Opts.Flag.[Combine By Mode] = "Yes"
                Opts.Flag.[Fare System] = 1

                ret_value = RunMacro("TCB Run Operation", "Transit Network Setting PF", Opts, &Ret)
                if !ret_value then goto quit

            // STEP 4.3: Update the transit network with layover times / dwell times
                Opts = null
                Opts.Input.[Transit RS] = route_system
                Opts.Input.Network = outtnw
                Opts.Input.[OD Matrix Currency] = {OutDir + "zone.mtx", "Matrix 1", , }
                Opts.Output.[Flow Table] = OutDir + Periods[iper] + AccessModes[iacc] + Modes[imode] + "PreloadFlow.bin"
                Opts.Output.[Walk Flow Table] = OutDir + Periods[iper] + AccessModes[iacc] + Modes[imode] + "PreloadWalkFlow.bin"
                ret_value = RunMacro("TCB Run Procedure", 2, "Transit Assignment PF", Opts)
                if !ret_value then goto quit

            // STEP 4.3.1 Fill Stop layer BaseIVTT variable with results of preload ivtt (add the layover time coded in the stop layer)
                Opts = null
                Opts.Input.[Dataview Set] = {{route_stop + "|Route Stops", OutDir + Periods[iper]+AccessModes[iacc]+Modes[imode]+"PreloadFlow.bin", "ID", "FROM_STOP"}, "Route Stops"+"RouteSystem"+Periods[iper]+"Prel"}
                Opts.Global.Fields = {Periods[iper] + AccessModes[iacc] + Modes[imode] + "IVTT"}
                Opts.Global.Method = "Formula"
            //  Opts.Global.Parameter = "BaseIVTT + Layover + [" + Periods[iper] + "DwellTime]"
                Opts.Global.Parameter = "BaseIVTT + Layover"
                ret_value = RunMacro("TCB Run Operation", 7, "Fill Dataview", Opts)
                if !ret_value then goto quit

            // STEP 4.3.2: Now Update the Time Layer with the Correct Time Information
                if (iper=1) then net_time_fidx = 7                                         // index (1-based) of network TIME field
                if (iper=2) then net_time_fidx = 6                                         // index (1-based) of network TIME field
                ActiveTransitNetwork=ReadNetwork(outtnw)
                StopTable=OpenTableEx("StopTable","FFB", {route_stop_bin,},{"Shared","False"})
                UpdateTransitLinks(ActiveTransitNetwork, StopTable, "STOP_ID",
                  {{Periods[iper]+AccessModes[iacc]+Modes[imode]+"IVTT", net_time_fidx} },,)
                ActiveTransitNetwork=null
            // NOTE: In-vehicle time in the transit networks includes IVTT and layover (no dwelling time) -> this is done for skimming purposes in order to count
            //     : dwelling time just once in the generalized cost

            // STEP 4.4: Transit Skim PF
                timevar = "TransitTime"+Periods[iper]+"_*"

                Opts = null
                Opts.Input.Database = highway_dbd
                Opts.Input.Network = outtnw
                
                  //debug
                  SetView(nlayer)
                  qry= "Select * where CCSTYLE=99 | CCSTYLE=98 | CCSTYLE=97"
                  n1 = SelectByQuery("AllZones", "Several", qry,) 
                  if n1=0 then showmessage("can't select "+ nlayer +" " + qry)
                  //debug
                  
                Opts.Input.[Origin Set] = {db_nodelyr, nlayer, "AllZones", "Select * where CCSTYLE=99 | CCSTYLE=98 | CCSTYLE=97"}
                Opts.Input.[Destination Set] = {db_nodelyr, nlayer, "AllZones"}
                Opts.Global.[Skim Var] = {"Generalized Cost", "Fare", "In-Vehicle Time", "Initial Wait Time", "Transfer Wait Time", "Transfer Penalty Time",
                                          "Transfer Walk Time", "Access Walk Time", "Egress Walk Time", "Access Drive Time", "Dwelling Time",
                                          "Number of Transfers", "In-Vehicle Distance", "Drive Distance", timevar}  
                // Number of Transfers is edited to Number of Boardings: by nagendra.dhakar@rsginc.com
                Opts.Global.[OD Layer Type] = 2
                Opts.Global.[Skim Modes] = {4, 5, 6, 7, 8, 9, 10, 12, 13, 14}  // skim travel times on new and project modes for additional bias logic in mode choice model
                Opts.Output.[Skim Matrix].Label = Periods[iper] + AccessModes[iacc] + Modes[imode] + " (Skim)"
                Opts.Output.[Skim Matrix].Compression = 0
                Opts.Output.[Skim Matrix].[File Name] = outskim
                if AccessModes[iacc]="Drive" then do
                 Opts.Output.[OP Matrix].Label = "Origin to Parking Matrix"
                 Opts.Output.[OP Matrix].[File Name]= OutDir + Periods[iper] + AccessModes[iacc] + Modes[imode] + "_pnr_time.mtx"
                 Opts.Output.[Parking Matrix].Label = "Parking Matrix"
                 Opts.Output.[Parking Matrix].[File Name] = OutDir + Periods[iper] + AccessModes[iacc] + Modes[imode] + "_pnr_node.mtx"
                end
                Opts.Output.[TPS Table] = outtps

                ret_value = RunMacro("TCB Run Procedure", "Transit Skim PF", Opts, &Ret)
                if !ret_value then goto quit

            // STEP 4.5: Fill Stop layer BaseIVTT variable with results of preload ivtt (also add the dwell time so that the final network for assignment contains dwell time as well)
                Opts = null
                Opts.Input.[Dataview Set] = {{route_stop + "|Route Stops", OutDir + Periods[iper]+AccessModes[iacc]+Modes[imode]+"PreloadFlow.bin", "ID", "FROM_STOP"}, "Route Stops"+"RouteSystem"+Periods[iper]+"Prel"}
                Opts.Global.Fields = {Periods[iper] + AccessModes[iacc] + Modes[imode] + "IVTT"}
                Opts.Global.Method = "Formula"
                Opts.Global.Parameter = "BaseIVTT + Layover + [" + Periods[iper] + "DwellTime]"
                ret_value = RunMacro("TCB Run Operation", 7, "Fill Dataview", Opts)
                if !ret_value then goto quit

            // STEP 4.5.1:  Now Update the Time Layer with the Correct Time Information
                if (iper=1) then net_time_fidx = 7                                            // index (1-based) of network TIME field
                if (iper=2) then net_time_fidx = 6                                            // index (1-based) of network TIME field
                ActiveTransitNetwork=ReadNetwork(outtnw)
                StopTable=OpenTableEx("StopTable","FFB", {route_stop_bin,},{"Shared","False"})
                UpdateTransitLinks(ActiveTransitNetwork, StopTable, "STOP_ID", {{Periods[iper]+AccessModes[iacc]+Modes[imode]+"IVTT", net_time_fidx} },,)
                ActiveTransitNetwork=null
                // NOTE: In-vehicle time in the transit networks now includes IVTT, layover and dwelling time ->
                // this is done so that the assignment BaseIVTT gives total IVTT
                
            // STEP 5: Calculate boardings as xfers+1

                Opts = null
                Opts.Input.[Matrix Currency] = { outskim, "Number of Transfers",,}
                Opts.Global.Method = 11
                Opts.Global.[Cell Range] = 2
                Opts.Global.[Expression Text] = "[Number of Transfers]+ ([Number of Transfers] / [Number of Transfers])"
                Opts.Global.[Force Missing] = "No"
                ret_value = RunMacro("TCB Run Operation", "Fill Matrices", Opts)
                if !ret_value then goto quit
                
                //convert to nulls to zeros
                //m = OpenMatrix(outskim, "True")
                //mc = CreateMatrixCurrency(m, "Number of Transfers",,, )
                //mc:=nz(mc)
                
				count=count+1
             end  // end mode loop
         end  // end access mode loop
     end  // end period loop

    stime=GetDateAndTime()
    WriteLine(runtime,"\n End Build Transit Paths Module       - "+SubString(stime,1,3)+","+SubString(stime,4,7)+""+SubString(stime,20,5)+" ("+SubString(stime,12,8)+") ")
    ret_value=1
quit:
//         Return( RunMacro("TCB Closing", ret_value, True ) )
    stime=GetDateAndTime()
    WriteLine(runtime,"\n End Build Transit Paths Module       - "+SubString(stime,1,3)+","+SubString(stime,4,7)+""+SubString(stime,20,5)+" ("+SubString(stime,12,8)+") ")
    Return(ret_value)
EndMacro


// STEP 6: Create percent walk for TCMS
Macro "PercentWalk"(Args)
    shared scen_data_dir
    shared OutDir, Periods, Modes, WalkBufferDistance, zone_dbd, route_stop, IDTable
    shared runtime // output files

    OutDir              = scen_data_dir + "outputs\\" 
    zone_dbd            = Args.[taz]   
    route_system        = Args.[rs_file]                                    // input rts file
    IDTable             = Args.[IDTable]   
    Periods             = {"PK","OP"}                                       // Periods defined in the transit model
    Modes               = {"Local","Brt", "ExpBus", "UrbRail", "ComRail"}   // List of transit modes
    WalkBufferDistance  = {Args.[WalkBufferDistance]}                       // in miles

    parts               = SplitPath(route_system)
    route_stop          = parts[1] + parts[2] + parts[3] + "S.dbd"
            
    RunMacro("TCB Init")
    RunMacro("G30 File Close All")

// STEP 6.1: Create period specific percent walk files
    for iper=1 to Periods.length do
		imode=1

		Stopdb_info=GetDBInfo(route_stop)
		Stopdb_scope = Stopdb_info[1]
		Stopdb_layers = GetDBLayers(route_stop)

		Stopview=AddLayertoWorkspace("StopviewPCT", route_stop, Stopdb_layers[1])
		SetLayer(Stopview)

		stopqname="All Stops"
		stopqry="Select * where "+Periods[iper]+"TransitFlag=1"   //All stop used in the period
		nnode=SelectByQuery(stopqname,"Several",stopqry,)

		CreateBuffers(OutDir+Periods[iper]+"Buffer.dbd","Stop Buffer",{stopqname},
				 "Value",{WalkBufferDistance[1]},)
		DropLayerFromWorkSpace(Stopview)

		zone_dbd_info=GetDBInfo(zone_dbd)
		zone_dbd_scope = zone_dbd_info[1]
		zone_dbd_layers = GetDBLayers(zone_dbd)
		Zoneview=AddLayertoWorkspace("Zone", zone_dbd, zone_dbd_layers[1])
		SetLayer(Zoneview)
		zoneqname="Zone Set"
		zoneqry="Select * where ID>=1"
		nzone=SelectByQuery(zoneqname,"Several",zoneqry,)

		Walkdb =OutDir + Periods[iper]+"Buffer.dbd"
		Walkdb_info=GetDBInfo(Walkdb)
		Walkdb_scope = Walkdb_info[1]
		Walkdb_layers = GetDBLayers(Walkdb)
		Walkview=AddLayertoWorkspace("Walk", Walkdb, Walkdb_layers[1])
		SetLayer(Walkview)
		walkqname="Walk Area"
		walkqry="Select * where ID=1"
		nwalk=SelectByQuery(walkqname,"Several",walkqry,)

		ComputeIntersectionPercentages({Walkview+"|"+walkqname,Zoneview+"|"+zoneqname},OutDir + Periods[iper]+"WalkPct.bin",)

		DropLayerFromWorkSpace(Walkview)
		DropLayerFromWorkSpace(Zoneview)

		Share = 0.00
	    	PctTable=OpenTable("pctwalk","FFB",{OutDir + Periods[iper]+"WalkPct.bin",})
	    	Setview(PctTable)
	    	n = selectbyquery("area_1_eql_1","Several", "Select * where Area_1 > 0 & Area_2 > 0")  
	    	area_2 = GetDataVector(PctTable+"|area_1_eql_1", "Area_2", )
	    	percent_2 = GetDataVector(PctTable+"|area_1_eql_1", "Percent_2", )
	    	   	
		// set the percentages, production percent walk only
		pcwalkfile = OpenFile(OutDir + Periods[iper]+"WalkPercent.csv", "w")
		WriteLine(pcwalkfile, JoinStrings({"TAZ","ShortWalk","LongWalk"},","))
		zdatafile = OpenTable("MATID","FFB",{IDTable, null})
		order = {{"MATID.ID","Ascending"}}
                TAZ_ID = GetDataVector(zdatafile+"|", "ID", )
                NEW_ID = GetDataVector(zdatafile+"|", "NEWID", )
		
		// Loop by mat ID
		for i = 1 to TAZ_ID.length do
		  val = 0
		  // Loop by walk pct zones
		  for j = 1 to area_2.length do
		     if (TAZ_ID[i] =area_2[j]) then val = percent_2[j]
		  end
		    WriteLine(pcwalkfile, JoinStrings({String(NEW_ID[i]),"0",String(val)},","))
	    end
	      CloseFile(pcwalkfile)
	      CloseView(PctTable)
	      CloseView(zdatafile)

	end
	ok= 1
quit:
   return(ok)
EndMacro

Macro "CopyTransitSkims"   
    shared Scen_Dir, OutDir, Periods, Modes, AccessModes, loop
    shared runtime // output files
    
    // Export only Walk Transit Skims
    counter=Periods.length*Modes.length
    count=1
    
    for iper=1 to Periods.Length do
        for imode=1 to Modes.Length do
            UpdateProgressBar("saving skims - "+ Periods[iper] +" - " + "Walk" + " - "+  Modes[imode] + " -" +i2s(count)+" of " +i2s(counter),)

            inMat = OutDir + Periods[iper] + "_" + "Walk" + Modes[imode] + "Skim.mtx"

            //copy loop specific skims
            outMat = OutDir + Periods[iper] + "_" + "Walk" + Modes[imode] + "Skim_" + String(loop) + ".mtx"
            CopyFile(inMat, outMat)                
            
            count=count+1
        end
    end 
    
EndMacro
