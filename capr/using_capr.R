#install capr
renv::install("ohdsi/Capr")

#load capr
library(Capr)
library(DatabaseConnector)
library(ohdsilab)
library(tidyverse)
library(DatabaseConnector)
library(keyring)
library(CohortGenerator)

#create concept set
t2d <- cs(descendants(201826), name = "Type 2 diabetes")

#create cohort definition
t2dCohort <- cohort(
  entry = entry(
    conditionOccurrence(t2d)),
  exit = exit(endStrategy = observationExit()))

#save cohort definition as json
t2dCohortJson <- as.json(t2dCohort)

#convert cohort definition json to sql
sql <- CirceR::buildCohortQuery(
  expression = CirceR::cohortExpressionFromJson(t2dCohortJson),
  options = CirceR::createGenerateOptions(generateStats = FALSE))

#assign cohort id to prepare for generation
cohortDefinitionSet <- tibble::tibble(
  cohortId = 1,
  cohortName = "Type 2 Diabetes",
  sql = sql
)

#connection details
connectionDetails <- createConnectionDetails(dbms = "redshift",
                                             server = "ohdsi-lab-redshift-cluster-prod.clsyktjhufn7.us-east-1.redshift.amazonaws.com/ohdsi_lab",
                                             port = 5439,
                                             user = keyring::key_get("db_username"),
                                             password = keyring::key_get("db_password"),
                                             pathToDriver = "D:/Users/j.bradenday/Documents/jdbc_driver")

# Assign variables to the the synpuf database schema and your 
#personal schema.
synpuf_schema = "omop_cdm_synpuf_110k_531"
write_schema = paste0("work_", keyring::key_get("db_username"))

# Connect to the database. You will do this again later, but for now you just 
#need the "con" information saved for the next step.
con =  DatabaseConnector::connect(
  dbms = "redshift",
  server = "ohdsi-lab-redshift-cluster-prod.clsyktjhufn7.us-east-1.redshift.amazonaws.com/ohdsi_lab",
  port = 5439,
  user = keyring::key_get("db_username"),
  password = keyring::key_get("db_password"),
  pathToDriver = "D:/Users/j.bradenday/Documents/jdbc_driver")

# Make it easier for some r functions to find the database
options(con.default.value = con)
options(schema.default.value = synpuf_schema)
options(write_schema.default.value = write_schema)

# Set a naming convention for the cohort tables.
cohortTableNames <- getCohortTableNames(cohortTable = "synpuf_t2d")

# Create empty tables in your personal schema using the naming convention
#designated in the last step.
createCohortTables(connectionDetails = connectionDetails,
                   cohortTableNames = cohortTableNames,
                   cohortDatabaseSchema = write_schema)

# Generate your cohort for the Synpuf database.
cohortsGenerated <- generateCohortSet(connectionDetails = connectionDetails,
                                      cdmDatabaseSchema = synpuf_schema,
                                      cohortDatabaseSchema = write_schema,
                                      cohortTableNames = cohortTableNames,
                                      cohortDefinitionSet = cohortDefinitionSet)

# Connect to the database.
con =  DatabaseConnector::connect(
  dbms = "redshift",
  server = "ohdsi-lab-redshift-cluster-prod.clsyktjhufn7.us-east-1.redshift.amazonaws.com/ohdsi_lab",
  port = 5439,
  user = keyring::key_get("db_username"),
  password = keyring::key_get("db_password"),
  pathToDriver = "D:/Users/j.bradenday/Documents/jdbc_driver")

# Because you reran "con" you will have to set the following option again.
options(con.default.value = con)

# Create a table containing your new cohort.
cohort <- tbl(con, inDatabaseSchema(write_schema, "synpuf_t2d")) |>
  select(person_id = subject_id, cohort_start_date, cohort_end_date)

# How many people are in the cohort?
tally(cohort)

