renv::install("OHDSI/Eunomia")
remotes::install_github("OHDSI/Eunomia")

connectionDetails <- Eunomia::getEunomiaConnectionDetails()

con <- DatabaseConnector::connect(connectionDetails)

atlas_url = "https://atlas.roux-ohdsi-prod.aws.northeastern.edu/WebAPI"

options(con.default.value = con)

ROhdsiWebApi::authorizeWebApi(atlas_url, 
                              authMethod = "db", 
                              webApiUsername = keyring::key_get("atlas_username"), 
                              webApiPassword = keyring::key_get("atlas_password"))

cohortId <- 4734

cohortDefinitionSet <- ROhdsiWebApi::exportCohortDefinitionSet(baseUrl = atlas_url,
                                                               cohortIds = cohortId)

cohortTableNames <- getCohortTableNames(cohortTable = "cohort")

createCohortTables(connectionDetails = connectionDetails,
                   cohortTableNames = cohortTableNames,
                   cohortDatabaseSchema = "main")

cohortsGenerated <- generateCohortSet(connectionDetails = connectionDetails,
                                      cdmDatabaseSchema = "main",
                                      cohortDatabaseSchema = "main",
                                      cohortTableNames = cohortTableNames,
                                      cohortDefinitionSet = cohortDefinitionSet)

cohort <- tbl(con, inDatabaseSchema("main", "cohort")) |>
  select(person_id = subject_id, cohort_start_date, cohort_end_date)

tally(cohort)
