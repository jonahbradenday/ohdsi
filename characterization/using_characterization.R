renv::install("ohdsi/Characterization")



library(ohdsilab)
library(tidyverse)
library(DatabaseConnector)
library(keyring)
library(ROhdsiWebApi)
library(CohortGenerator)
library(Characterization)


Sys.setenv("DATABASECONNECTOR_JAR_FOLDER" = "D:/Users/j.bradenday/Documents/jdbc_driver")

connectionDetails <- createConnectionDetails(dbms = "redshift",
                                             server = "ohdsi-lab-redshift-cluster-prod.clsyktjhufn7.us-east-1.redshift.amazonaws.com/ohdsi_lab",
                                             port = 5439,
                                             user = keyring::key_get("db_username"),
                                             password = keyring::key_get("db_password"))



atlas_url = "https://atlas.roux-ohdsi-prod.aws.northeastern.edu/WebAPI"
synpuf_schema = "omop_cdm_synpuf_110k_531"
write_schema = paste0("work_", keyring::key_get("db_username"))



con =  DatabaseConnector::connect(
  dbms = "redshift",
  server = "ohdsi-lab-redshift-cluster-prod.clsyktjhufn7.us-east-1.redshift.amazonaws.com/ohdsi_lab",
  port = 5439,
  user = keyring::key_get("db_username"),
  password = keyring::key_get("db_password"))



options(con.default.value = con)
options(schema.default.value = synpuf_schema)
options(write_schema.default.value = write_schema)



ROhdsiWebApi::authorizeWebApi(atlas_url, 
                              authMethod = "db", 
                              webApiUsername = keyring::key_get("atlas_username"), 
                              webApiPassword = keyring::key_get("atlas_password"))



targetId <- 4675
outcomeId <- 4681


#10. Pull the cohort definition from ATLAS
cohortDefinitionSet <- ROhdsiWebApi::exportCohortDefinitionSet(baseUrl = atlas_url,
                                                               cohortIds = c(targetId, outcomeId))


#11. Set a naming convention for the cohort tables.
cohortTableNames <- getCohortTableNames(cohortTable = "cohort")



#12. Create empty tables in your personal schema using the naming convention
#designated in the last step.
createCohortTables(connectionDetails = connectionDetails,
                   cohortTableNames = cohortTableNames,
                   cohortDatabaseSchema = write_schema)



#13. Generate your cohort for the Synpuf database.
cohortsGenerated <- generateCohortSet(connectionDetails = connectionDetails,
                                      cdmDatabaseSchema = synpuf_schema,
                                      cohortDatabaseSchema = write_schema,
                                      cohortTableNames = cohortTableNames,
                                      cohortDefinitionSet = cohortDefinitionSet)



aggregateCovariateSettings <- createAggregateCovariateSettings(
  targetIds = targetId,
  outcomeIds = outcomeId,
  riskWindowStart = 1,
  startAnchor = 'cohort start',
  riskWindowEnd = 365,
  endAnchor = 'cohort start',
  covariateSettings = FeatureExtraction::createDefaultCovariateSettings())




characterizationSettings <- createCharacterizationSettings(
  aggregateCovariateSettings = aggregateCovariateSettings)



runCharacterizationAnalyses(
  connectionDetails = connectionDetails,
  cdmDatabaseSchema = synpuf_schema,
  targetDatabaseSchema = write_schema,
  targetTable = 'cohort',
  outcomeDatabaseSchema = write_schema,
  outcomeTable = 'cohort',
  characterizationSettings = characterizationSettings,   
  outputDirectory = "D:/Users/j.bradenday/Documents/characterization_test",
  executionPath = "D:/Users/j.bradenday/Documents/characterization_test",
  csvFilePrefix = 'c_')

