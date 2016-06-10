#DaySim Version - DelPhi or C#
dsVersion                                 = "C#"

parcelfile                                = "../DaySim/Nashville_mzbuffer_allstreets.dat"
dshhfile                                  = "e:/rd/nashvilleabm-git/2010/DaySim/regression_results_2016-06-10/12h46m26s_configuration_regress.xml_FAILED/outputs/_household.tsv"
dsperfile                                 = "e:/rd/nashvilleabm-git/2010/DaySim/regression_results_2016-06-10/12h46m26s_configuration_regress.xml_FAILED/outputs/_person.tsv"
dspdayfile                                = "e:/rd/nashvilleabm-git/2010/DaySim/regression_results_2016-06-10/12h46m26s_configuration_regress.xml_FAILED/outputs/_person_day.tsv"
dstourfile                                = "e:/rd/nashvilleabm-git/2010/DaySim/regression_results_2016-06-10/12h46m26s_configuration_regress.xml_FAILED/outputs/_tour.tsv"
dstripfile                                = "e:/rd/nashvilleabm-git/2010/DaySim/regression_results_2016-06-10/12h46m26s_configuration_regress.xml_FAILED/outputs/_trip.tsv"
dstriplistfile                            = "e:/rd/nashvilleabm-git/2010/DaySim/regression_results_2016-06-10/12h46m26s_configuration_regress.xml_FAILED/outputs/Tdm_trip_list.csv"

# Nashville Survey
#surveyhhfile                              = "./data/nash_hrecx_rewt.dat"
surveyhhfile                              = "e:/rd/nashvilleabm-git/2010/DaySim/configuration_regress_outputs/_household.tsv"
#surveyperfile                             = "./data/nash_precx_rewt.dat"
surveyperfile                             = "e:/rd/nashvilleabm-git/2010/DaySim/configuration_regress_outputs/_person.tsv"
#surveypdayfile                            = "./data/nash_pdayx.dat"
surveypdayfile                            = "e:/rd/nashvilleabm-git/2010/DaySim/configuration_regress_outputs/_person_day.tsv"
#surveytourfile                            = "./data/nash_tourx.dat"
surveytourfile                            = "e:/rd/nashvilleabm-git/2010/DaySim/configuration_regress_outputs/_tour.tsv"
#surveytripfile                            = "./data/nash_tripx.dat"
surveytripfile                            = "e:/rd/nashvilleabm-git/2010/DaySim/configuration_regress_outputs/_trip.tsv"

amskimfile                                = "../DaySim/hwyskim_am.TXT"
mdskimfile                                = "../DaySim/hwyskim_md.TXT"
pmskimfile                                = "../DaySim/hwyskim_pm.TXT"
evskimfile                                = "../DaySim/hwyskim_op.TXT"

tazcountycorr                             = "./data/county_districts_nash.csv"

wrklocmodelfile                           = "./templates/WrkLocation.csv"
schlocmodelfile                           = "./templates/SchLocation.csv"
vehavmodelfile                            = "./templates/VehAvailability.csv"
daypatmodelfile1                          = "./templates/DayPattern_pday.csv"
daypatmodelfile2                          = "./templates/DayPattern_tour.csv"
daypatmodelfile3                          = "./templates/DayPattern_trip.csv"
tourdestmodelfile                         = "./templates/TourDestination.csv"
tourdestwkbmodelfile                      = "./templates/TourDestination_wkbased.csv"
tripdestmodelfile                         = "./templates/TripDestination.csv"
tourmodemodelfile                         = "./templates/TourMode.csv"
tourtodmodelfile                          = "./templates/TourTOD.csv"
tripmodemodelfile                         = "./templates/TripMode.csv"
triptodmodelfile                          = "./templates/TripTOD.csv"

wrklocmodelout                            = "WrkLocation.xlsm"
schlocmodelout                            = "SchLocation.xlsm"
vehavmodelout                             = "VehAvailability.xlsm"
daypatmodelout                            = "DayPattern.xlsm"
tourdestmodelout                          = c("TourDestination_Escort.xlsm","TourDestination_PerBus.xlsm","TourDestination_Shop.xlsm",
                                              "TourDestination_Meal.xlsm","TourDestination_SocRec.xlsm")
tourdestwkbmodelout                       = "TourDestination_WrkBased.xlsm"
tourmodemodelout                          = "TourMode.xlsm"
tourtodmodelout                           = "TourTOD.xlsm"
tripmodemodelout                          = "TripMode.xlsm"
triptodmodelout                           = "TripTOD.xlsm"

outputsDir                                = "e:/rd/nashvilleabm-git/2010/DaySim/regression_results_2016-06-10/12h46m26s_configuration_regress.xml_FAILED/reports"
validationDir                             = ""

prepSurvey                                = TRUE
prepDaySim                                = TRUE

runWrkSchLocationChoice                   = TRUE
runVehAvailability                        = TRUE
runDayPattern                             = TRUE
runTourDestination                        = TRUE
runTourMode                               = TRUE
runTourTOD                                = TRUE
runTripMode                               = TRUE
runTripTOD                                = TRUE

excludeChildren5                          = TRUE
tourAdj                                   = FALSE
tourAdjFile				                        = "./data/peradjfac.csv"