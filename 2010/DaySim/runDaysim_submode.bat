@echo off

set project_directory=E:\Projects\Clients\Nashville\RunModel\CleanABMsetup\ToNashvilleMPO\2010

rem copy the shadow pricing to the new folder
set copy_from=%project_directory%\DaySim\shadow_prices.txt
set copy_to=%project_directory%\DaySim\working\shadow_prices.txt

copy %copy_from% %copy_to%

rem copy the PNR shadow pricing to the new 
set copy_from=%project_directory%\DaySim\park_and_ride_shadow_prices.txt
set copy_to=%project_directory%\DaySim\working\park_and_ride_shadow_prices.txt

copy %copy_from% %copy_to%

Daysim.exe -c configuration.xml  

pause