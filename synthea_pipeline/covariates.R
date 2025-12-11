library(DatabaseConnector)
library(keyring)
library(dplyr)

key_set("db_username")
key_set("db_password")

connectionDetails <- createConnectionDetails(
  dbms = "postgresql",
  server = "localhost/postgres",
  port = 5433,
  user = key_get("db_username"),
  password = key_get("db_password"),
  pathToDriver = "/Users/j.bradenday/Documents/programming/driver"
)

con <- connect(connectionDetails)

synthea_schema <- "public"
write_schema <- "scratch"


executeSql(con, "
           CREATE TABLE scratch.cohort2 AS
           SELECT DISTINCT c.patient, c.start AS cohort_start_date
           FROM public.conditions c
           INNER Join public.medications m
            ON c.patient = m.patient
           WHERE c.code = '40055000'
            AND m.code = '309362'
            AND m.start > '2001-11-05'
           ")

#turning table 1 into function so it can be used by others
table1 <- function(
    con,
    cohort_table,
    schema = "scratch",
    synthea_schema = "public",
    min_count = NULL) {
  
  #from here down within the function (excluding the if and return statements) can be run to generate table 1 manually
  cohort <- tbl(
  con,
  inDatabaseSchema(write_schema, "cohort1"))
  
  patients <- tbl(
  con,
  inDatabaseSchema(synthea_schema, "patients"))
  
  demographics <- cohort |> 
  inner_join(patients, by = c("patient" = "id")) |> 
  select(patient, cohort_start_date, birthdate, race, gender) |> 
  mutate(
    age_at_entry = year(cohort_start_date) - year(birthdate),
    age_group = case_when(
      age_at_entry < 5 ~ "0-4",
      age_at_entry >= 5 & age_at_entry < 10 ~ "5-9",
      age_at_entry >= 10 & age_at_entry < 15 ~ "10-14",
      age_at_entry >= 15 & age_at_entry < 20 ~ "15-19",
      age_at_entry >= 20 & age_at_entry < 25 ~ "20-24",
      age_at_entry >= 25 & age_at_entry < 30 ~ "25-29",
      age_at_entry >= 30 & age_at_entry < 35 ~ "30-34",
      age_at_entry >= 35 & age_at_entry < 40 ~ "35-39",
      age_at_entry >= 40 & age_at_entry < 45 ~ "40-44",
      age_at_entry >= 45 & age_at_entry < 50 ~ "45-49",
      age_at_entry >= 50 & age_at_entry < 55 ~ "50-54",
      age_at_entry >= 55 & age_at_entry < 60 ~ "55-59",
      age_at_entry >= 60 & age_at_entry < 65 ~ "60-64",
      age_at_entry >= 65 & age_at_entry < 70 ~ "65-69",
      age_at_entry >= 70 & age_at_entry < 75 ~ "70-74",
      age_at_entry >= 75 & age_at_entry < 80 ~ "75-79",
      age_at_entry >= 80 & age_at_entry < 85 ~ "80-84",
      age_at_entry >= 85 & age_at_entry < 90 ~ "85-89",
      age_at_entry >= 90 ~ "> 89"))
  
  conditions <- tbl(
  con, 
  inDatabaseSchema("public", "conditions"))
  
  medications <- tbl(
  con, 
  inDatabaseSchema("public", "medications"))
  
  procedures <- tbl(
  con, 
  inDatabaseSchema("public", "procedures"))
  
  observations <- tbl(
  con,
  inDatabaseSchema("public", "observations"))
  
  total_patients <- cohort |>
  summarise(n = n_distinct(patient)) |>
  collect() |>
  pull(n)
  
  gender_summary <- demographics |>
  group_by(gender) |>
  summarise(n_persons = n()) |>
  collect() |>
  mutate(
    category = "Demographics",
    covariate = paste0("Gender: ", gender),
    percent = round(100 * n_persons / total_patients, 1)) |>
  select(category, covariate, n_persons, percent) |>
  arrange(desc(n_persons))
  
  race_summary <- demographics |>
  group_by(race) |>
  summarise(n_persons = n()) |>
  collect() |>
  mutate(
    category = "Demographics",
    covariate = paste0("Race: ", race),
    percent = round(100 * n_persons / total_patients, 1)) |>
  select(category, covariate, n_persons, percent) |>
  arrange(desc(n_persons))
  
  age_summary <- demographics |>
  group_by(age_group) |>
  summarise(n_persons = n()) |>
  collect() |>
  mutate(
    category = "Demographics",
    covariate = paste0("Age Group: ", age_group),
    percent = round(100 * n_persons / total_patients, 1)) |>
  select(category, covariate, n_persons, percent) |>
  arrange(desc(n_persons))
  
  conditions_summary <- cohort |>
  inner_join(conditions, by = "patient") |>
  group_by(code, description) |>
  summarise(n_persons = n_distinct(patient), .groups = "drop") |>
  collect() |>
  mutate(
    category = "Conditions",
    covariate = description,
    percent = round(100 * n_persons / total_patients, 1)) |>
  select(category, covariate, n_persons, percent) |>
  arrange(desc(n_persons))
  
  if (!is.null(min_count)) {
    conditions_summary <- conditions_summary |> 
      filter(n_persons >= min_count)
  }
  
  medications_summary <- cohort |>
  inner_join(medications, by = "patient") |>
  group_by(code, description) |>
  summarise(n_persons = n_distinct(patient), .groups = "drop") |>
  collect() |>
  mutate(
    category = "Medications",
    covariate = description,
    percent = round(100 * n_persons / total_patients, 1)) |>
  select(category, covariate, n_persons, percent) |>
  arrange(desc(n_persons))
  
  if (!is.null(min_count)) {
    medications_summary <- medications_summary |> 
      filter(n_persons >= min_count)
  }
  
  procedures_summary <- cohort |>
  inner_join(procedures, by = "patient") |>
  group_by(code, description) |>
  summarise(n_persons = n_distinct(patient), .groups = "drop") |>
  collect() |>
  mutate(
    category = "Procedures",
    covariate = description,
    percent = round(100 * n_persons / total_patients, 1)) |>
  select(category, covariate, n_persons, percent) |>
  arrange(desc(n_persons))
  
  if (!is.null(min_count)) {
    procedures_summary <- procedures_summary |> 
      filter(n_persons >= min_count)
  }
  
  observations_summary <- cohort |>
  inner_join(observations, by = "patient") |>
  group_by(code, description) |>
  summarise(n_persons = n_distinct(patient), .groups = "drop") |>
  collect() |>
  mutate(
    category = "Observations",
    covariate = description,
    percent = round(100 * n_persons / total_patients, 1)) |>
  select(category, covariate, n_persons, percent) |>
  arrange(desc(n_persons))
  
  if (!is.null(min_count)) {
    observations_summary <- observations_summary |> 
      filter(n_persons >= min_count)
  }
  
  result <- bind_rows(
  gender_summary,
  race_summary,
  age_summary,
  conditions_summary,
  medications_summary,
  procedures_summary,
  observations_summary)
  
  cat(
    sprintf(
      "Table1: Baseline Characteristics (N= %g)\n",
      total_patients))
  
  return(result)
}

#using above function to generate, view, and export table 1
my_table1 <- table1(
  con,
  "cohort2",
  synthea_schema = "public",
  schema = "scratch",
  min_count = 1)

View(my_table1)

write.csv(my_table1, "table1.csv", row.names = FALSE)
