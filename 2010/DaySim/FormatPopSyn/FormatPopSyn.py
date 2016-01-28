'''
Created on May 29, 2014

@author: nagendra.dhakar
'''

# PURPOSE:
# Format Nashville PopSyn output to daysim format - only person file
# Parcel info in HH file was copy pasted from the allocation tool output
# the workaround was established as allocation tool output didn't give good attributes
# so first, allocation is run and then the parcel info was copy pstaed to the output of this script

# import libraries
import os
import csv
import datetime

workspace = r"E:\Projects\Clients\Nashville\RunModel\CleanABMsetup\ToNashvilleMPO\2010\DaySim\FormatPopSyn"

PopsynIndFileName="taz_posynid.csv"
personFileName = "persons.csv"
householdFileName = "households.csv"

tazCorrespondenceFile = "MATID.csv"

household_out = "nashville_household_2010.dat"
person_out = "nashville_person_2010.dat"

data_folder = workspace
popsyn_taz_dictionary = {}
taz_newtaz_dictionary = {}
parcel_taz_dictionary = {}
hhno_pno_dictionary={}

def ReadPopsynToTaz(filename):
    currenttime = datetime.datetime.now()
    print ' --> ' + str(currenttime.hour) + ':' + str(currenttime.minute)

    infile = os.path.join(data_folder,filename)

    readfile=open(infile, 'rb')
    reader = csv.reader(readfile, delimiter = ',')
    
    i=0

    for row in reader:
        if (i>0):
            
            # read from file
            tazid = row[0] # household id
            popsynid = row[1] # person id

            popsyn_taz_dictionary[popsynid] = tazid
                                        
        i=i+1

    readfile.close()

def ReadCorresponenceFile(filename):
    currenttime = datetime.datetime.now()
    print ' --> ' + str(currenttime.hour) + ':' + str(currenttime.minute)

    infile = os.path.join(data_folder,filename)

    readfile=open(infile, 'rb')
    reader = csv.reader(readfile, delimiter = ',')

    for row in reader:
            
            # read from file
            tazid = row[0] # household id
            newtazid = row[1] # new taz id - used due to allocation tool limitation
            taz_newtaz_dictionary[tazid] = newtazid

    readfile.close()

def FormatPersonFile(filename):

    currenttime = datetime.datetime.now()
    print ' --> ' + str(currenttime.hour) + ':' + str(currenttime.minute)

    infile = os.path.join(data_folder,filename)

    readfile=open(infile, 'rb')
    reader = csv.reader(readfile, delimiter = ',')

    # set variables for writing output
    outfile = os.path.join(data_folder, person_out)
    writefile = open(outfile, 'wb')
    writer = csv.writer(writefile, delimiter=' ', quoting=csv.QUOTE_MINIMAL)

    header = ["hhno","pno","pptyp","pagey","pgend","pwtyp","pwpcl","pwtaz","pwautime","pwaudist","pstyp","pspcl","pstaz",
              "psautime","psaudist","puwmode","puwarrp","puwdepp","ptpass","ppaidprk","pdiary","pproxy","psexpfac"]
    writer.writerow(header)
    
    i=0

    for row in reader:
        if (i>0):
            
            # read from file
            tempID = row[0]
            REGION = row[1]
            PUMA = row[2]
            taz = row[3]
            maz = row[4]
            WGTP = row[5]
            finalPumsId = row[6]
            finalweight = row[7]
            sporder = row[8]
            agep = int(float(row[9]))
            sex = row[10]
            wkhp = float(row[11])
            esr = float(row[12])
            schg = float(row[13])
            employed = float(row[14])
            wkw = row[15]
            mil = row[16]
            schl = row[17]
            indp02 = row[18]
            indp07 = row[19]
            occp02 = row[20]
            occp10 = row[21]
            GQFLAG = row[22]
            GQTYPE = row[23]
            n = row[24]
            PERID = row[25]
            HHID = row[26]

            # worker type - pwtyp
            pwtyp = 0
            if (employed == 0 or wkhp <= 0):
                pwtyp = 0
            elif (wkhp >= 32 and wkhp <=150):
                pwtyp = 1
            else:
                pwtyp = 2

            # Student type - pstyp
            if (schg > 0) or (agep >= 5 and agep < 18):  #before: schg > 0
                pstyp = 1
            else:
                pstyp = 0

            # Person type - pptyp
            pptyp = 0

            if (agep < 5):
                pptyp=8
            elif (agep < 16):
                pptyp=7
            elif (pwtyp >0 and wkhp >=32 and wkhp <=150):
                pptyp = 1
            elif (pstyp >0 and agep >= 16 and agep < 18):
                pptyp = 6
            elif (schg > 0 and schg <= 5 and agep <= 25):
                pptyp = 6
            elif (pstyp > 0):
                pptyp= 5
            elif (pwtyp > 0):
                pptyp = 2
            elif (agep >= 65):
                pptyp = 3
            else:
                pptyp = 4

            hhno=HHID
            pno=PERID
            pptyp=pptyp
            pagey=agep
            pgend=sex
            pwtyp=pwtyp
            pwpcl=-1
            pwtaz=-1
            pwautime=-1
            pwaudist=-1
            pstyp=pstyp
            pspcl=-1
            pstaz=-1
            psautime=-1
            psaudist=-1
            puwmode=-1
            puwarrp=-1
            puwdepp=-1
            ptpass=-1
            ppaidprk=-1
            pdiary=-1
            pproxy=-1
            psexpfac=1

            if hhno in hhno_pno_dictionary:
                pno = hhno_pno_dictionary[hhno] + 1
            else:
                pno = 1

            hhno_pno_dictionary[hhno] = pno
            
            output = [hhno,pno,pptyp,pagey,pgend,pwtyp,pwpcl,pwtaz,pwautime,pwaudist,pstyp,pspcl,pstaz,
                      psautime,psaudist,puwmode,puwarrp,puwdepp,ptpass,ppaidprk,pdiary,pproxy,psexpfac]

            writer.writerow(output)
                                        
        i=i+1

    readfile.close()
    writefile.close()
        
def FormatHouseholdFile(filename):

    currenttime = datetime.datetime.now()
    print ' --> ' + str(currenttime.hour) + ':' + str(currenttime.minute)

    infile = os.path.join(data_folder,filename)

    readfile=open(infile, 'rb')
    reader = csv.reader(readfile, delimiter = ',')

    # set variables for writing output
    outfile = os.path.join(data_folder, household_out)
    writefile = open(outfile, 'wb')
    writer = csv.writer(writefile, delimiter=' ', quoting=csv.QUOTE_MINIMAL)
 
    header=["hhno","hhsize","hhvehs","hhwkrs","hhftw","hhptw","hhret","hhoad","hhuni","hhhsc","hh515","hhcu5","hhincome","hownrent","hrestype","hhparcel","hhtaz","hhexpfac","samptype"]
    
    writer.writerow(header)
    
    i=0

    for row in reader:
        if (i>0):
            
            # read from file
            tempid = row[0]
            region = row[1]
            puma = row[2]
            taz = row[3]
            maz = row[4]
            wgtp = row[5]
            finalpumsid = row[6]
            finalweight = row[7]
            serialno = row[8]
            np = row[9]
            hincp = row[10]
            ten = float(row[11])
            bld = float(row[12])
            nwrkrs_esr = row[13]
            hhincAdj = int(round(float(row[14])))
            adjinc = row[15]
            veh = int(row[16])
            hht = row[17]
            htype = row[18]
            npf = row[19]
            hupac = row[20]
            GQFLAG = row[21]
            GQTYPE = row[22]
            n = row[23]
            HHID = row[24]

            # Household residence type - hrestyp
            if (bld ==2):
                hrestyp = 1
            elif (bld == 3):
                hrestyp = 2
            elif (bld >3 and bld <= 9):
                hrestyp = 3
            elif (bld == 1):
                hrestyp = 4
            elif (bld == 10):
                hrestyp = 6
            else:
                hrestyp = 9

            # Household own or rent - hownrent
            if (ten<0):
                hownrent=9
            elif (ten<=2):
                hownrent=1
            elif (ten==3):
                hownrent=2
            else:
                hownrent=3

            # variables that are computed by DaySim upon import are set to 1
            hhno=HHID
            hhsize=np
            if (veh<0):
                veh = 0
            hhvehs=veh
            hhwkrs=nwrkrs_esr
            hhftw=-1
            hhptw=-1
            hhret=-1
            hhoad=-1
            hhuni=-1
            hhhsc=-1
            hh515=-1
            hhcu5=-1
            if (hhincAdj<0):
                hhincAdj = 0
            hhincome=hhincAdj
            hownrent=hownrent
            hrestype=hrestyp
            hhparcel=maz
            hhtaz=taz_newtaz_dictionary[popsyn_taz_dictionary[taz]] # convert to old tazid first and then to new tazid
            hhexpfac=1 #-1
            samptype=11 #-1
            
            output = [hhno,hhsize,hhvehs,hhwkrs,hhftw,hhptw,hhret,hhoad,hhuni,
                      hhhsc,hh515,hhcu5,hhincome,hownrent,hrestype,hhparcel,hhtaz,hhexpfac,samptype]
            writer.writerow(output)         
            
        i=i+1

    readfile.close()
    writefile.close()

      
#Run Tool
ReadPopsynToTaz(PopsynIndFileName)
ReadCorresponenceFile(tazCorrespondenceFile)
FormatPersonFile(personFileName)
FormatHouseholdFile(householdFileName)

print "Finished"
