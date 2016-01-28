library(data.table)

setwd("E:/Projects/Clients/Nashville/RunModel/CleanABMsetup/ToNashvilleMPO/ParcelInputs/BufferTool/2010")
# read parcel to new taz correspondence file
pcl <- fread("parcel_taz.dat")
#read parcel file - output of the buffer tool
pcl2 <- fread("Nashville_mzbuffer_allstreets_2010_longtaz.dat")
# get header of the parcel file
cols <- names(data.frame(pcl2))
# in the parcel file, set column name taz_p to longtaz
setnames(pcl2,"taz_p","longtaz")
# merge the parcel to taz correspondence to the parcel file
pcl2 <- merge(pcl2,pcl,by="parcelid")
pcl2 <- pcl2[,cols,with=F]
# set lutype_p to 1
pcl2$lutype_p<-1
summary(pcl2$taz_p)
setnames(pcl2,"dist_park","dist_park") 
write.table(pcl2,"Nashville_mzbuffer_allstreets_2010.dat",row.names=F,eol="\r",quote=F)