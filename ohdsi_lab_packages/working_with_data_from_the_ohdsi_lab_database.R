library(ohdsilab)
library(ROhdsiWebApi)
library(CohortGenerator)
library(tidyverse)

#Create the connection details. These details be used as arguments in later 
#functions.
connectionDetails <- createConnectionDetails(dbms = "redshift",
                                             server = "ohdsi-lab-redshift-cluster-prod.clsyktjhufn7.us-east-1.redshift.amazonaws.com/ohdsi_lab",
                                             port = 5439,
                                             user = keyring::key_get("db_username"),
                                             password = keyring::key_get("db_password"),
                                             pathToDriver = "D:/Users/j.bradenday/Documents/jdbc_driver")

# DB Connections
atlas_url = "https://atlas.roux-ohdsi-prod.aws.northeastern.edu/WebAPI"
cdm_schema = "omop_cdm_53_pmtx_202203"
write_schema = paste0("work_", keyring::key_get("db_username"))

#Make it easier for some r functions to find the database
options(con.default.value = con)
options(schema.default.value = cdm_schema)
options(write_schema.default.value = write_schema)

# Create the connection
con =  DatabaseConnector::connect(
  dbms = "redshift",
  server = "ohdsi-lab-redshift-cluster-prod.clsyktjhufn7.us-east-1.redshift.amazonaws.com/ohdsi_lab",
  port = 5439,
  user = keyring::key_get("db_username"),
  password = keyring::key_get("db_password"),
  pathToDriver = "D:/Users/j.bradenday/Documents/jdbc_driver")

#Connect to ATLAS.
ROhdsiWebApi::authorizeWebApi(atlas_url, 
                              authMethod = "db", 
                              webApiUsername = keyring::key_get("atlas_username"), 
                              webApiPassword = keyring::key_get("atlas_password"))

#Identify the ATLAS cohort definition your want to use.
cohortId <- 860

#Pull the cohort definition from ATLAS
cohortDefinitionSet <- ROhdsiWebApi::exportCohortDefinitionSet(baseUrl = atlas_url,
                                                               cohortIds = cohortId)
#Name the cohort tables
cohortTableNames <- getCohortTableNames(cohortTable = "rc_aphasia")

#Create empty tables in your personal schema using the naming convention
#designated in the last step.
createCohortTables(connectionDetails = connectionDetails,
                   cohortTableNames = cohortTableNames,
                   cohortDatabaseSchema = write_schema)

#Apply cohort definition criteria to pmtx database.
cohortsGenerated <- generateCohortSet(connectionDetails = connectionDetails,
                                      cdmDatabaseSchema = cdm_schema,
                                      cohortDatabaseSchema = write_schema,
                                      cohortTableNames = cohortTableNames,
                                      cohortDefinitionSet = cohortDefinitionSet)

#Get cohort that has an entry date prior to 2018
cohort = tbl(con, inDatabaseSchema(write_schema, "rc_aphasia")) |>
  select(person_id = subject_id, cohort_start_date, cohort_end_date)

#create concept set for aphasia
aphasia_concepts = c(4049150,4312097,4320483,763039,4299183,46272980,440084,
                     4012864,4215589,4217159,4031157,4256743,40484101,42535427,
                     4240405,4063072,4082040,4252416,4146672,4046084,4047125,
                     4131821,42535429,3181357,37396532,440424,4043379,4062431,
                     40480002,4147666,4304820,4225746,4269227,4044923,4060092,
                     35621734,4245018,4278687,4184473,35610281,765610,4327962,
                     36685003,4046219,36685012,4185285,4084825,4173098,4077061,
                     4036512,4287230,4232189,4045421,4232482,4207412,37396465,
                     4203167,4263333,4287839,4148072)

#get the human readbale name of each concept id
concepts = tbl(con, inDatabaseSchema(cdm_schema, "concept")) |> 
  filter(concept_id %in% !!aphasia_concepts)

#join the cohort to the condition occurrence table, count the rows, and turn it 
#into a dataframe
cond = cohort |> 
  omop_join("condition_occurrence", type = "inner", by = "person_id") |> 
  filter(condition_start_date > cohort_start_date & condition_start_date < cohort_end_date) |> 
  inner_join(concepts, by = c("condition_concept_id" = "concept_id")) |> 
  select(person_id, cohort_start_date, cohort_end_date, condition_concept_id,
         condition_start_date, provider_id, visit_occurrence_id, visit_detail_id,
         condition_source_value, condition_source_concept_id, concept_name, domain_id)

tally(cond)

cond = cond |> dbi_collect()

#alternatively capture only those patients who have two or more aphasia concepts 
#in their record
pwa_table = cohort |> 
  omop_join("condition_occurrence", type = "inner", by = "person_id") |> 
  filter(condition_start_date > cohort_start_date & condition_start_date < cohort_end_date) |> 
  inner_join(concepts, by = c("condition_concept_id" = "concept_id")) |> 
  count(person_id) |> 
  filter(n > 1) |> 
  select(person_id)

tally(pwa_table)

#Assign variables to outpatient treatment session concepts
slp_tx = 2313701
slp_eval = 44816446
aphasia_eval = 2314188
old_eval = 2313700

OP = c("Outpatient Hospital", "Office Visit", 
       "Comprehensive Outpatient Rehabilitation Facility", 
       "Outpatient Visit", "Independent Clinic")                      

#join the last cohort with procedure occurrence and visit occurrence and turn 
#into a dataframe
pwa_visits <- pwa_table |> 
  omop_join("procedure_occurrence", type = "left", by = "person_id") |> 
  filter(procedure_concept_id %in% c(slp_tx, slp_eval, aphasia_eval, old_eval)) |> 
  select(person_id, procedure_concept_id, procedure_date, visit_occurrence_id, visit_detail_id, procedure_source_value) |> 
  omop_join("visit_occurrence", type = "left", by = c("visit_occurrence_id", "person_id")) |> 
  omop_join("concept", type = "inner", by = c("visit_concept_id" = "concept_id")) |> 
  inner_join(cohort, by = "person_id") |> 
  dbi_collect()

