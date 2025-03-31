renv::install("OHDSI/PatientLevelPrediction")

library(tidyverse)
library(DatabaseConnector)
library(keyring)
library(ROhdsiWebApi)
library(CohortGenerator)
library(FeatureExtraction)

#4. Create the connection details. These details will be used as arguments in 
#later functions.
Sys.setenv("DATABASECONNECTOR_JAR_FOLDER" = "D:/Users/j.bradenday/Documents/jdbc_driver")

connectionDetails <- createConnectionDetails(dbms = "redshift",
                                             server = "ohdsi-lab-redshift-cluster-prod.clsyktjhufn7.us-east-1.redshift.amazonaws.com/ohdsi_lab",
                                             port = 5439,
                                             user = keyring::key_get("db_username"),
                                             password = keyring::key_get("db_password"))

#5. Assign variables to the atlas url, the synpuf database schema and your 
#personal schema.
atlas_url = "https://atlas.roux-ohdsi-prod.aws.northeastern.edu/WebAPI"
cdm_schema = "omop_cdm_53_pmtx_202203"
write_schema = paste0("work_", keyring::key_get("db_username"))

#6. Connect to the database. You will do this again later, but for now you just 
#need the "con" information saved for the next step.
con =  DatabaseConnector::connect(connectionDetails)

#7. Make it easier for some r functions to find the database
options(con.default.value = con)
options(schema.default.value = cdm_schema)
options(write_schema.default.value = write_schema)


#8. Connect to ATLAS.
ROhdsiWebApi::authorizeWebApi(atlas_url, 
                              authMethod = "db", 
                              webApiUsername = keyring::key_get("atlas_username"), 
                              webApiPassword = keyring::key_get("atlas_password"))

#9. Identify the ATLAS cohort definition your want to use.
cohortIds <- c(4675, 4681)

#10. Pull the cohort definition from ATLAS
cohortDefinitionSet <- ROhdsiWebApi::exportCohortDefinitionSet(
  baseUrl = atlas_url,
  cohortIds = cohortIds)

#11. Set a naming convention for the cohort tables.
cohortTableNames <- getCohortTableNames(cohortTable = "cohort")

#12. Create empty tables in your personal schema using the naming convention
#designated in the last step.
createCohortTables(connectionDetails = connectionDetails,
                   cohortTableNames = cohortTableNames,
                   cohortDatabaseSchema = write_schema)

#13. Generate your cohort for the Synpuf database.
cohortsGenerated <- generateCohortSet(connectionDetails = connectionDetails,
                                      cdmDatabaseSchema = cdm_schema,
                                      cohortDatabaseSchema = write_schema,
                                      cohortTableNames = cohortTableNames,
                                      cohortDefinitionSet = cohortDefinitionSet)


databaseDetails <- PatientLevelPrediction::createDatabaseDetails(
  connectionDetails = connectionDetails,
  cdmDatabaseSchema = cdm_schema,
  cdmDatabaseName = cdm_schema,
  cdmDatabaseId = "pmtx",
  cohortDatabaseSchema = write_schema,
  cohortTable = "cohort",
  outcomeDatabaseSchema = write_schema,
  outcomeTable = "cohort",
  targetId = 4675,
  outcomeIds = 4681
)



# start new

plpData <- PatientLevelPrediction::getPlpData(
  databaseDetails = databaseDetails,
  covariateSettings = FeatureExtraction::createDefaultCovariateSettings()
)

PatientLevelPrediction::savePlpData(plpData, "plpData_demo_3")

plpData <- PatientLevelPrediction::loadPlpData("plpData_demo_3")

populationSettings <- PatientLevelPrediction::createStudyPopulationSettings(
  binary = TRUE,
  firstExposureOnly = FALSE,
  washoutPeriod = 0,
  removeSubjectsWithPriorOutcome = FALSE,
  priorOutcomeLookback = 99999,
  requireTimeAtRisk = TRUE,
  minTimeAtRisk = 0,
  riskWindowStart = 0,
  startAnchor = 'cohort start',
  riskWindowEnd = 365,
  endAnchor = 'cohort start'
)

lr_model <- PatientLevelPrediction::setLassoLogisticRegression()

lr_results <- PatientLevelPrediction::runPlp( 
  plpData = plpdata, 
  outcomeId = 4681,
  analysisId = 'demo_3', 
  analysisName = 'run plp demo', 
  populationSettings = populationSettings, 
  splitSettings = PatientLevelPrediction::createDefaultSplitSetting(
    type = "time",
    testFraction = 0.25,
    nfold = 2), 
  sampleSettings = PatientLevelPrediction::createSampleSettings(),
  preprocessSettings = PatientLevelPrediction::createPreprocessSettings(
    minFraction = 0, 
    normalize = T), 
  modelSettings = lr_model, 
  executeSettings = PatientLevelPrediction::createDefaultExecuteSettings(), 
  saveDirectory = "D:/Users/j.bradenday/Documents/plp")

PatientLevelPrediction::savePlpResult(lr_results, "demo_3_results")

lr_results <- PatientLevelPrediction::loadPlpResult("demo_3_results")

### You can start the Shiny App by using this command now:
PatientLevelPrediction::viewPlp(lr_results)

results <- PatientLevelPrediction::loadPlpResult("D:/Users/j.bradenday/Documents/plp/demo_2/plpResult")
View(results$prediction)




