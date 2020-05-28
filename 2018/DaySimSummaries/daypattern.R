###This script generates Day Patterns from DaySim run outputs

print("Day Pattern Summary...Started")

prep_perdata <- function(perdata,hhdata)
{
  hhdata[,hhcounty:=countycorr$DISTRICT[match(hhtaz,countycorr$TAZ)]]
  hhdata[,inccat:=findInterval(hhincome,c(0,15000,50000,75000))]
  perdata[,hh16cat:=ifelse(pagey>=16,1,0)]
  hhdata <- merge(hhdata,perdata[,list(hh16cat=sum(hh16cat)),by=hhno],by="hhno",all.x=T)
  hhdata[hh16cat>4,hh16cat:=4]
  hhdata[hhvehs == 0,vehsuf:=1]
  hhdata[hhvehs > 0 & hhvehs < hh16cat,vehsuf:=2]
  hhdata[hhvehs > 0 & hhvehs == hh16cat,vehsuf:=3]
  hhdata[hhvehs > 0 & hhvehs > hh16cat,vehsuf:=4]
  perdata <- merge(perdata,hhdata[,list(hhno,hhcounty,inccat,vehsuf)],by="hhno",all.x=T)

  return(perdata)
}

#this is added because pday data do not match with tour and trip (stops) files
#this function overwrrites number of tours and stops by purpose
update_pdaydata <- function(pdaydata, tourdata, tripdata)
{
  #aggregate trips by person and destination purpose
  aggper_trips_long <- tripdata[,list(trips=sum(trexpfac)),by=c("hhno","pno","dpurp")]
  aggper_trips_wide <- reshape(aggper_trips_long, timevar = "dpurp", idvar = c("hhno","pno"), direction="wide")
  aggper_trips_wide[is.na(aggper_trips_wide)] <- 0
  aggper_trips <- rename(aggper_trips_wide, c("trips.0"="hmtrips","trips.1"="wktrips","trips.2"="sctrips","trips.3"="estrips","trips.4"="pbtrips","trips.5"="shtrips","trips.6"="mltrips","trips.7"="sotrips","trips.10"="cmtrips"))
  aggper_trips[,tottrips:=hmtrips+wktrips+sctrips+estrips+pbtrips+shtrips+mltrips+sotrips+cmtrips]

  #aggregate non-workbased tours by person and destination purpose
  tourdata_nowb <- tourdata[tourdata$parent==0,]
  aggper_tours_long <- tourdata_nowb[,list(tours=sum(toexpfac)),by=c("hhno","pno","pdpurp")]
  aggper_tours_wide <- reshape(aggper_tours_long, timevar = "pdpurp", idvar = c("hhno","pno"), direction="wide")
  aggper_tours_wide[is.na(aggper_tours_wide)] <- 0
  aggper_tours <- rename(aggper_tours_wide, c("tours.1"="wktours","tours.2"="sctours","tours.3"="estours","tours.4"="pbtours","tours.5"="shtours","tours.6"="mltours","tours.7"="sotours"))

  #aggregate workbased subtours by person and destination purpose 
  tourdata_wb <- tourdata[tourdata$parent==1,]
  aggper_tours_long <- tourdata_wb[,list(tours=sum(toexpfac)),by=c("hhno","pno","pdpurp")]
  aggper_tours_wide <- reshape(aggper_tours_long, timevar = "pdpurp", idvar = c("hhno","pno"), direction="wide")
  aggper_tours_wide[is.na(aggper_tours_wide)] <- 0
  aggper_tours_wb <- rename(aggper_tours_wide, c("tours.1"="wktours_wb","tours.2"="sctours_wb","tours.3"="estours_wb","tours.4"="pbtours_wb","tours.5"="shtours_wb","tours.6"="mltours_wb","tours.7"="sotours_wb"))
  aggper_tours_wb[,tottours_wb:=wktours_wb+sctours_wb+estours_wb+pbtours_wb+shtours_wb+mltours_wb+sotours_wb]
  
  #merge all into one
  pdaydata_new <- merge(aggper_tours, aggper_trips, by=c("hhno","pno"), all.x=T)
  pdaydata_new <- merge(pdaydata_new, aggper_tours_wb, by=c("hhno","pno"), all.x=T)
  pdaydata_new[is.na(pdaydata_new)] <- 0
  
  #calculate number of stops by purpose
  #for each purpose, remove workbased and non-workbased tours. tours are by destination purpose, tour primary destination isn't a stop so remove that.
  #exclude all workbased subtours from work stops. workbased subtours always have inbound (return) trip with destination as work. returning to work isn't a stop so remove that.
  pdaydata_new[,wkstops:=wktrips-wktours-wktours_wb-tottours_wb]
  pdaydata_new[,scstops:=sctrips-sctours-sctours_wb]
  pdaydata_new[,esstops:=estrips-estours-estours_wb]
  pdaydata_new[,pbstops:=pbtrips-pbtours-pbtours_wb]
  pdaydata_new[,shstops:=shtrips-shtours-shtours_wb]
  pdaydata_new[,mlstops:=mltrips-mltours-mltours_wb]
  pdaydata_new[,sostops:=sotrips-sotours-sotours_wb]
  pdaydata_new[,cmstops:=cmtrips]
    
  pdaydata <- merge(pdaydata[,list(hhno,pno,metours,retours,mestops,restops)], pdaydata_new, by=c("hhno","pno"), all.x=T)
  pdaydata[is.na(pdaydata)] <- 0
  
  return(pdaydata)

}

prep_pdaydata <- function(pdaydata,perdata,tourdata,tripdata,datatype)
{
  if(datatype=="model")
	pdaydata <- update_pdaydata(pdaydata, tourdata, tripdata)
	
  pdaydata <- merge(pdaydata,perdata,by=c("hhno","pno"),all.x=T)
  if(excludeChildren5)
    pdaydata <- pdaydata[pptyp<8]
  
  #persons with at-least one stop
  pdaydata[wkstops>0,per_wkstops:=1]
  pdaydata[scstops>0,per_scstops:=1]
  pdaydata[esstops>0,per_esstops:=1]
  pdaydata[pbstops>0,per_pbstops:=1]
  pdaydata[shstops>0,per_shstops:=1]
  pdaydata[mlstops>0,per_mlstops:=1]
  pdaydata[sostops>0,per_sostops:=1]
  pdaydata[is.na(pdaydata)] <- 0

  pdaydata[,pbtours:= pbtours + metours]
  pdaydata[,sotours:= sotours + retours]
  pdaydata[,pbstops:= pbstops + mestops]
  pdaydata[,sostops:= sostops + restops]
  
  pdaydata[,tottours:=wktours+sctours+estours+pbtours+shtours+mltours+sotours]
  pdaydata[tottours>3,tottours:=3]
  pdaydata[,totstops:=wkstops+scstops+esstops+pbstops+shstops+mlstops+sostops]

  pdaydata[tottours == 0 & totstops == 0,tourstop:=0]
  pdaydata[tottours == 1 & totstops == 0,tourstop:=1]
  pdaydata[tottours == 1 & totstops == 1,tourstop:=2]
  pdaydata[tottours == 1 & totstops == 2,tourstop:=3]
  pdaydata[tottours == 1 & totstops >= 3,tourstop:=4]
  pdaydata[tottours == 2 & totstops == 0,tourstop:=5]
  pdaydata[tottours == 2 & totstops == 1,tourstop:=6]
  pdaydata[tottours == 2 & totstops == 2,tourstop:=7]
  pdaydata[tottours == 2 & totstops >= 3,tourstop:=8]
  pdaydata[tottours == 3 & totstops == 0,tourstop:=9]
  pdaydata[tottours == 3 & totstops == 1,tourstop:=10]
  pdaydata[tottours == 3 & totstops == 2,tourstop:=11]
  pdaydata[tottours == 3 & totstops >= 3,tourstop:=12]
  
  pdaydata[wktours == 0 & wkstops == 0,wktostp:=1]
  pdaydata[wktours == 0 & wkstops >= 1,wktostp:=2]
  pdaydata[wktours >= 1 & wkstops == 0,wktostp:=3]
  pdaydata[wktours >= 1 & wkstops >= 1,wktostp:=4]
  
  pdaydata[sctours == 0 & scstops == 0,sctostp:=1]
  pdaydata[sctours == 0 & scstops >= 1,sctostp:=2]
  pdaydata[sctours >= 1 & scstops == 0,sctostp:=3]
  pdaydata[sctours >= 1 & scstops >= 1,sctostp:=4]
  
  pdaydata[estours == 0 & esstops == 0,estostp:=1]
  pdaydata[estours == 0 & esstops >= 1,estostp:=2]
  pdaydata[estours >= 1 & esstops == 0,estostp:=3]
  pdaydata[estours >= 1 & esstops >= 1,estostp:=4]
  
  pdaydata[pbtours == 0 & pbstops == 0,pbtostp:=1]
  pdaydata[pbtours == 0 & pbstops >= 1,pbtostp:=2]
  pdaydata[pbtours >= 1 & pbstops == 0,pbtostp:=3]
  pdaydata[pbtours >= 1 & pbstops >= 1,pbtostp:=4]
  
  pdaydata[shtours == 0 & shstops == 0,shtostp:=1]
  pdaydata[shtours == 0 & shstops >= 1,shtostp:=2]
  pdaydata[shtours >= 1 & shstops == 0,shtostp:=3]
  pdaydata[shtours >= 1 & shstops >= 1,shtostp:=4]
  
  pdaydata[mltours == 0 & mlstops == 0,mltostp:=1]
  pdaydata[mltours == 0 & mlstops >= 1,mltostp:=2]
  pdaydata[mltours >= 1 & mlstops == 0,mltostp:=3]
  pdaydata[mltours >= 1 & mlstops >= 1,mltostp:=4]
  
  pdaydata[sotours == 0 & sostops == 0,sotostp:=1]
  pdaydata[sotours == 0 & sostops >= 1,sotostp:=2]
  pdaydata[sotours >= 1 & sostops == 0,sotostp:=3]
  pdaydata[sotours >= 1 & sostops >= 1,sotostp:=4]

  pdaydata[,wktopt:=findInterval(wktours,0:3)]
  pdaydata[,sctopt:=findInterval(sctours,0:3)]
  pdaydata[,estopt:=findInterval(estours,0:3)]
  pdaydata[,pbtopt:=findInterval(pbtours,0:3)]
  pdaydata[,shtopt:=findInterval(shtours,0:3)]
  pdaydata[,mltopt:=findInterval(mltours,0:3)]
  pdaydata[,sotopt:=findInterval(sotours,0:3)]

  return(pdaydata)
}

prep_tourdata <- function(tourdata,perdata)
{
  tourdata <- merge(tourdata,perdata,by=c("hhno","pno"),all.x=T)
  if(excludeChildren5)
    tourdata <- tourdata[pptyp<8,]

  tourdata[pdpurp==8,pdpurp:=7]
  tourdata[pdpurp==9,pdpurp:=4]
  tourdata[,ftwind:=ifelse(pptyp==1,1,2)]

  tourdata[,stcat:=findInterval(subtrs,0:3)]
  tourdata[,stops:=tripsh1+tripsh2-2]
  tourdata[,stopscat:=findInterval(stops,1:6)]
  tourdata[,h1stopscat:=findInterval(tripsh1-1,1:6)]
  tourdata[,h2stopscat:=findInterval(tripsh2-1,1:6)]
  tourdata[,pdpurp2:=ifelse(parent == 0,pdpurp,8)]

  return(tourdata)
}

prep_tripdata <- function(tripdata,perdata)
{
  tripdata <- merge(tripdata,perdata,by=c("hhno","pno"),all.x=T)
  if(excludeChildren5)
    tripdata <- tripdata[pptyp<8]
  
  tripdata[dpurp==8,dpurp:=7]
  tripdata[dpurp==9,dpurp:=4]
  tripdata[dpurp==0,dpurp:=8]
  
  tripdata[,ocounty:=countycorr$DISTRICT[match(otaz,countycorr$TAZ)]]

  return(tripdata)
}

if(prepSurvey)
{
  survperdata <- assignLoad(paste0(surveyperfile,".Rdata"))
  survhhdata <- assignLoad(paste0(surveyhhfile,".Rdata"))
  survperdata <- prep_perdata(survperdata,survhhdata)
  survperdata <- survperdata[,c("hhno","pno","pptyp","hhcounty","inccat","vehsuf","psexpfac"),with=F]
  if(tourAdj)
  {
    setnames(touradj,2,"adjfac")
    survperdata <- merge(survperdata,touradj,by=c("pptyp"),all.x=T)
    survperdata[is.na(adjfac),adjfac:=1]
    survperdata[,psexpfac_orig:=psexpfac]
    survperdata[,psexpfac:=psexpfac*adjfac]
  }
  rm(survhhdata)
  
  survpdaydata <- assignLoad(paste0(surveypdayfile,".Rdata"))
  survtourdata <- assignLoad(paste0(surveytourfile,".Rdata"))
  survtripdata <- assignLoad(paste0(surveytripfile,".Rdata"))

  survpdaydata <- prep_pdaydata(survpdaydata,survperdata,survtourdata,survtripdata,"survey")
  write_tables(daypatmodelout,survpdaydata,daypatmodelfile1,"survey")
  rm(survpdaydata)
  
  survtourdata <- prep_tourdata(survtourdata,survperdata)
  write_tables(daypatmodelout,survtourdata,daypatmodelfile2,"survey")
  rm(survtourdata)
  
  survtripdata <- prep_tripdata(survtripdata,survperdata)
  write_tables(daypatmodelout,survtripdata,daypatmodelfile3,"survey")
  rm(survperdata,survtripdata)
  gc()
}

if(prepDaySim)
{
  dsperdata <- assignLoad(paste0(dsperfile,".Rdata"))
  dshhdata <- assignLoad(paste0(dshhfile,".Rdata"))
  dsperdata <- prep_perdata(dsperdata,dshhdata)
  dsperdata <- dsperdata[,c("hhno","pno","pptyp","hhcounty","inccat","vehsuf","psexpfac"),with=F]
  rm(dshhdata)
  
  dspdaydata <- assignLoad(paste0(dspdayfile,".Rdata"))
  dstourdata <- assignLoad(paste0(dstourfile,".Rdata"))
  dstripdata <- assignLoad(paste0(dstripfile,".Rdata"))

  dspdaydata <- prep_pdaydata(dspdaydata,dsperdata,dstourdata,dstripdata,"model")
  write_tables(daypatmodelout,dspdaydata,daypatmodelfile1,"daysim")
  rm(dspdaydata)

  dstourdata <- prep_tourdata(dstourdata,dsperdata)
  write_tables(daypatmodelout,dstourdata,daypatmodelfile2,"daysim")
  rm(dstourdata)
  
  dstripdata <- prep_tripdata(dstripdata,dsperdata)
  write_tables(daypatmodelout,dstripdata,daypatmodelfile3,"daysim")
  rm(dsperdata,dstripdata)
  
  gc()
}

print("Day Pattern Summary...Finished")






