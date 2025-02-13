#1. Install the necessary packages. Because ohdsilab and ROhdsiWebApi have not 
#been added to CRAN, renv:install() is used instead of install.packages()
renv::upgrade()
renv::install(c("roux-ohdsi/ohdsilab","tidyverse", "DatabaseConnector", 
                "keyring", "OHDSI/RohdsiWebApi", "CohortGenerator"))

#2. Load the necessary packages.
library(ohdsilab)
library(tidyverse)
library(DatabaseConnector)
library(keyring)
library(ROhdsiWebApi)
library(CohortGenerator)

#3. Set your database and ATLAS credentials. You credentials can be found in the 
#"Workspace Details" email you received after you created your workspace.
keyring::key_set("db_username")
keyring::key_set("db_password")
keyring::key_set("atlas_username")
keyring::key_set("atlas_password")

#4. Create the connection details. These details be used as arguments in later 
#functions.
connectionDetails <- createConnectionDetails(dbms = "redshift",
                                             server = "ohdsi-lab-redshift-cluster-prod.clsyktjhufn7.us-east-1.redshift.amazonaws.com/ohdsi_lab",
                                             port = 5439,
                                             user = keyring::key_get("db_username"),
                                             password = keyring::key_get("db_password"),
                                             pathToDriver = "D:/Users/j.bradenday/Documents/jdbc_driver")

#5. Assign variables to the atlas url, the synpuf database schema and your 
#personal schema.
atlas_url = "https://atlas.roux-ohdsi-prod.aws.northeastern.edu/WebAPI"
synpuf_schema = "omop_cdm_synpuf_110k_531"
write_schema = paste0("work_", keyring::key_get("db_username"))

#6. Make it easier for some r functions to find the database
options(con.default.value = connectionDetails)
options(schema.default.value = synpuf_schema)
options(write_schema.default.value = write_schema)


#7. Connect to ATLAS.
ROhdsiWebApi::authorizeWebApi(atlas_url, 
                              authMethod = "db", 
                              webApiUsername = keyring::key_get("atlas_username"), 
                              webApiPassword = keyring::key_get("atlas_password"))

#8. Identify the ATLAS cohort definition your want to use. 
#The human readable description of this cohort can be found in 
#cohort_description.rmd.
cohortId <- 4675

#9. Pull the cohort definition from ATLAS
cohortDefinitionSet <- ROhdsiWebApi::exportCohortDefinitionSet(baseUrl = atlas_url,
                                                               cohortIds = cohortId)
#10. Name the cohort tables
cohortTableNames <- getCohortTableNames(cohortTable = "synpuf4675")

#11. Create empty tables in your personal schema using the naming convention
#designated in the last step.
createCohortTables(connectionDetails = connectionDetails,
                   cohortTableNames = cohortTableNames,
                   cohortDatabaseSchema = write_schema)

#12. Apply cohort definition criteria to synpuf database.
cohortsGenerated <- generateCohortSet(connectionDetails = connectionDetails,
                                      cdmDatabaseSchema = synpuf_schema,
                                      cohortDatabaseSchema = write_schema,
                                      cohortTableNames = cohortTableNames,
                                      cohortDefinitionSet = cohortDefinitionSet)

#13. Connect to the database.
con =  DatabaseConnector::connect(
  dbms = "redshift",
  server = "ohdsi-lab-redshift-cluster-prod.clsyktjhufn7.us-east-1.redshift.amazonaws.com/ohdsi_lab",
  port = 5439,
  user = keyring::key_get("db_username"),
  password = keyring::key_get("db_password"),
  pathToDriver = "D:/Users/j.bradenday/Documents/jdbc_driver")

#14. Create a table containing your new cohort.
cohort_atlas <- tbl(con, inDatabaseSchema(write_schema, "synpuf4675")) |>
  select(person_id = subject_id, cohort_start_date, cohort_end_date)

#15. After running the above code, your cohort should be nearly identical to the 
#one generated using R alone in "ohdsi_lab_training_r_and_ATLAS.R" You can check 
#by comparing the output of the following tally with the output of 
#step 11 in "ohdsi_lab_training_just_r.R".
tally(cohort_atlas)
