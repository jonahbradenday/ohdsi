#load necessary packages
library(DatabaseConnector)
library(keyring)
library(dplyr)

#set database credentials
key_set("db_username")
key_set("db_password")

#point R to JDBC driver you installed on your workspace
Sys.setenv("DATABASECONNECTOR_JAR_FOLDER" = "insert path to jdbc driver here")

#set database connection details
connectionDetails <- createConnectionDetails(
  dbms = "redshift",
  server = "ohdsi-lab-redshift-cluster-prod.clsyktjhufn7.us-east-1.redshift.amazonaws.com/ohdsi_lab",
  port = 5439,
  user = keyring::key_get("db_username"),
  password = keyring::key_get("db_password"))

#connect to database
con <- connect(connectionDetails)

#set dataset and write schemas
veradigm_schema <- "veradigm"
write_schema <- paste0(
  "work_",
  keyring::key_get("db_username"))

#because ndcs are so granular, depending on the number of codes relevant to your
#analysis, you may want to export them from the NDC Directory as a .csv file and
#import them into your R session as a separate variable.
#read ndc codes from a .csv file
lisinopril_ndcs <- read.csv("/Users/j.bradenday/Downloads/National Drug Code Directory.csv")$NDC.Package.Code

# Remove any NA or empty values
lisinopril_ndcs <- lisinopril_ndcs[!is.na(lisinopril_ndcs) & lisinopril_ndcs != ""]

# Reformat ndc codes for for easy SQL insertion
lisinopril_ndcs <- paste0("('", lisinopril_ndcs, "')", collapse = ",\n")

# Create temp table with NDCs
executeSql(
  con,
  "CREATE TEMP TABLE lisinopril_ndcs (ndc VARCHAR(11));")

# Insert NDCs into temp table
insert_sql <- paste0(
  "INSERT INTO lisinopril_ndcs VALUES\n",
  lisinopril_ndcs,
  ";")
executeSql(
  con,
  insert_sql)

#generate cohort of persons satisfying specific inclusion criteria
executeSql(con, "
           CREATE TABLE scratch.cohort AS
           SELECT DISTINCT p.hi_patient_id, p.start_date AS cohort_start_date
           FROM veradigm.Problem p
           INNER JOIN veradigm.Problem_Code pc
            ON p.problem_id = pc.problem_id
           INNER JOIN veradigm.Medication m
            ON p.hi_patient_id = m.hi_patient_id
           WHERE pc.code = '155296003'
            AND EXISTS (
              SELECT 1 
              FROM lisinopril_ndcs ln 
              WHERE ln.ndc = m.ndc
            )
            AND m.start_date > '2001-11-05'
           ")

#retrieve cohort table as a lazy table
cohort <- tbl(
  con,
  inDatabaseSchema(write_schema, "cohort")) |>
  select(hi_patient_id, cohort_start_date)

#check cohort size
tally(cohort)

#retrieve patient table as a lazy table
patient <- tbl(
  con,
  inDatabaseSchema(veradigm_schema, "Patient"))

#join patient lazy table to cohort for cohort demographics
demographics <- cohort |> 
  inner_join(patient, by = "hi_patient_id") |> 
  select(
    hi_patient_id,
    cohort_start_date,
    birth_year, 
    gender,
    race,
    ethnicity,
    state,
    zip3) |> 
  mutate(age_at_entry = year(cohort_start_date) - year(birth_year))

#retrieve Problem and Problem_Code tables as lazy tables
problem <- tbl(
  con,
  inDatabaseSchema(veradigm_schema, "Problem")
)
problem_code <- tbl(
  con,
  inDatabaseSchema(veradigm_schema, "Problem_Code")
)

#join problem and problem_code lazy tables to cohort for cohort condition history
condition_history <- cohort |>
  inner_join(problem, by = "hi_patient_id") |>
  inner_join(problem_code, by = "problem_id") |>
  select(
    hi_patient_id,
    cohort_start_date,
    code,
    problem_name,
    start_date)

