

Nashville ABM
==============

1. Update paths in 2040model.lst and nashville4.bin to replicate your setup. 

2. Update R path in daysim_summaries.cmd (./DaySimSummaries/daysim_summaries.cmd)

    "C:\Program Files\R\R-3.2.2\bin\x64\R.exe" CMD BATCH --no-save main.R log.txt

3. Unzip the following file to two locations:

  node_node_distances.zip 

  to:
  
  ParcelInputs\BufferTool\2010\node_node_distances.dat

  2010\DaySim\node_node_distances.dat

4. Requires Git Large File Storage (LFS)