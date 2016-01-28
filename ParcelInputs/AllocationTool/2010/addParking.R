library(foreign)

setwd("E:/Projects/Clients/Nashville/RunModel/CleanABMsetup/ToNashvilleMPO/ParcelInputs/AllocationTool/2010")
# read microzone file - output of the allocation tool
parcels <- read.csv("MZ_disaggregation_nashville_2010.csv",header=TRUE)
nrow(parcels)
# read parking data
addParking <- read.csv("MZ_Parking_06122015_Final.csv",header=TRUE)
addParking<-round(addParking,digits=2)
nrow(addParking)
# merge the parking data to the microzone file
temp <-merge(parcels,addParking,by="microzoneid",all=TRUE)
temp[is.na(temp)]<-0
# set parking variables
temp$parkdy_p<-ifelse(temp$DlCapacity>0,temp$DlCapacity,0)
temp$parkhr_p<-ifelse(temp$HrCapacity>0,temp$HrCapacity,0)
temp$ppricdyp<-ifelse(temp$AvgDlRate>0,temp$AvgDlRate,0)
temp$pprichrp<-ifelse(temp$AvgHrRate>0,temp$AvgHrRate,0)
# remove unnecessary variables
parcelsWithParking<-subset(temp,select=-c(DlCapacity,HrCapacity,AvgDlRate,AvgHrRate))
# write out a new microzone file
write.table(parcelsWithParking,"MZ_disaggregation_nashville_2010_parking.csv",row.names=F,quote=F,sep = ",")
rm(parcels,addParking)