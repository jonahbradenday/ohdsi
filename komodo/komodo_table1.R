#' Generate Table 1 for Komodo Data
#'
#' Creates a baseline characteristics table (Table 1) from a cohort in Komodo data
#'
#' @param con Database connection object
#' @param cohort_table Name of the cohort table
#' @param write_schema Schema where the cohort table is located
#' @param komodo_schema Schema containing Komodo tables
#' @param min_count Minimum count threshold for filtering results (optional)
#' @return A data frame with baseline characteristics
#' @export
#' @examples
#' \dontrun{
#' my_table1 <- komodo_table1(con, "cohort", min_count = 5)
#' }
komodo_table1 <- function(
    con,
    cohort_table,
    write_schema = paste0(
      "work_",
      keyring::key_get("db_username")),
    komodo_schema = "komodo",
    min_count = NULL) {
  
  # Load cohort from write_schema (requires cohort with columns patient_id, index_date)
  cohort <- tbl(
    con,
    inDatabaseSchema(write_schema, cohort_table))
  
  # Calculate total patients
  total_patients <- cohort |>
    summarize(n = n_distinct(patient_id)) |>
    collect() |>
    pull(n)
  
  # Load patient demographics
  patient <- tbl(
    con,
    inDatabaseSchema(komodo_schema, "patient_demographics"))
  
  # Load patient race and ethnicity
  patient_race_ethnicity <- tbl(
    con,
    inDatabaseSchema(komodo_schema, "patient_race_ethnicity"))
  
  # Create demographics table
  demographics <- cohort |> 
    inner_join(patient, by = "patient_id") |> 
    inner_join(patient_race_ethnicity, by = "patient_id") |>
    select(
      patient_id,
      index_date,
      patient_dob,
      patient_gender,
      patient_race_ethnicity) |> 
    mutate(
      age_at_entry = year(index_date) - year(patient_dob),
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
  
  # Create gender summary
  gender_summary <- demographics |>
    group_by(patient_gender) |>
    summarize(n_persons = n()) |>
    collect() |>
    mutate(
      category = "Demographics",
      covariate = paste0("Gender: ", patient_gender),
      percent = round(100 * n_persons / total_patients, 1)) |>
    select(category, covariate, n_persons, percent) |>
    arrange(desc(n_persons))
  
  # Create race and ethnicity summary
  race_ethnicity_summary <- demographics |>
    group_by(patient_race_ethnicity) |>
    summarize(n_persons = n()) |>
    collect() |>
    mutate(
      category = "Demographics",
      covariate = paste0("Race/Ethnicity: ", patient_race_ethnicity),
      percent = round(100 * n_persons / total_patients, 1)) |>
    select(category, covariate, n_persons, percent) |>
    arrange(desc(n_persons))
  
  # Create age group summary
  age_summary <- demographics |>
    group_by(age_group) |>
    summarize(n_persons = n()) |>
    collect() |>
    mutate(
      category = "Demographics",
      covariate = paste0("Age Group: ", age_group),
      percent = round(100 * n_persons / total_patients, 1)) |>
    select(category, covariate, n_persons, percent) |>
    arrange(desc(n_persons))
  
  # Adding pharmacy data 
  # Load pharmacy table
  pharmacy <- tbl(con, inDatabaseSchema(komodo_schema, "pharmacy_events"))
  
  # filter to cohort population and create pharmaceuticals summary
  pharmacy_summary <- pharmacy |>
    inner_join(cohort |> distinct(patient_id), by = "patient_id") |>
    group_by(generic_name) |>
    summarize(n_persons = n_distinct(patient_id)) |>
    collect() |>
    mutate(
      category = "Pharmaceuticals",
      covariate = generic_name,
      percent = round(100 * n_persons / total_patients, 1)
    ) |>
    select(category, covariate, n_persons, percent) |>
    arrange(desc(n_persons))
  
  # Adding procedure data (procedures are stored across multiple fields and tables)
  # Load procedure tables
  inpatient <- tbl(con, inDatabaseSchema(komodo_schema, "inpatient_events"))
  non_inpatient <- tbl(con, inDatabaseSchema(komodo_schema, "non_inpatient_events"))
  
  # Load procedure lookup table
  procedure_lookup <- tbl(con, inDatabaseSchema(komodo_schema, "procedure_lookup"))
  
  # Union all procedure fields/values into a single long table of patient_id, procedure_code
  # Inpatient: two string fields
  # Non Inpatient: two string fields
  all_procedures <- dplyr::tbl(con, dplyr::sql(paste0("
    SELECT patient_id, icd_pcs_codes AS procedure_code
    FROM ", komodo_schema, ".inpatient_events

    UNION ALL

    SELECT patient_id, cpt_hcpcs_codes AS procedure_code
    FROM ", komodo_schema, ".inpatient_events

    UNION ALL

    SELECT patient_id, procedure_code
    FROM ", komodo_schema, ".non_inpatient_events

    UNION ALL

    SELECT patient_id, icd_pcs_codes AS procedure_code
    FROM ", komodo_schema, ".non_inpatient_events
  ")))
  
  # Filter to cohort population, join to procedure lookup table, create procedure summary
  procedures_summary <- all_procedures |>
    inner_join(cohort |> distinct(patient_id), by = "patient_id") |>
    inner_join(procedure_lookup, by = "procedure_code") |>
    group_by(procedure_name) |>
    summarize(n_persons = n_distinct(patient_id)) |>
    collect() |>
    mutate(
      category = "Procedures",
      covariate = procedure_name,
      percent = round(100 * n_persons / total_patients, 1)
    ) |>
    select(category, covariate, n_persons, percent) |>
    arrange(desc(n_persons))
  
  # Adding condition data (conditions are stored across multiple fields and tables)
  # Load condition lookup table
  condition_lookup <- tbl(con, inDatabaseSchema(komodo_schema, "condition_lookup"))
  
  # Union all diagnosis sources into a single long table of patient_id, icd_code
  # Inpatient: three string fields
  # Non-inpatient: two string fields (field names are legacy, not arrays)
  all_diagnoses <- dplyr::tbl(con, dplyr::sql(paste0("
    SELECT patient_id, admission_diagnosis_code AS icd_code
    FROM ", komodo_schema, ".inpatient_events

    UNION ALL

    SELECT patient_id, primary_diagnosis_code AS icd_code
    FROM ", komodo_schema, ".inpatient_events

    UNION ALL

    SELECT patient_id, secondary_diagnosis_codes AS icd_code
    FROM ", komodo_schema, ".inpatient_events

    UNION ALL

    SELECT patient_id, diagnosis_codes AS icd_code
    FROM ", komodo_schema, ".non_inpatient_events

    UNION ALL

    SELECT patient_id, primary_diagnosis_code_array AS icd_code
    FROM ", komodo_schema, ".non_inpatient_events
  ")))
  
  # Filter to cohort population, join to lookup table, create condition summary
  conditions_summary <- all_diagnoses |>
    inner_join(cohort |> distinct(patient_id), by = "patient_id") |>
    inner_join(condition_lookup, by = "icd_code") |>
    group_by(condition_name) |>
    summarize(n_persons = n_distinct(patient_id)) |>
    collect() |>
    mutate(
      category = "Conditions",
      covariate = condition_name,
      percent = round(100 * n_persons / total_patients, 1)
    ) |>
    select(category, covariate, n_persons, percent) |>
    arrange(desc(n_persons))
  
  # Combine all summaries
  result <- bind_rows(
    gender_summary,
    race_ethnicity_summary,
    age_summary,
    pharmacy_summary,
    procedures_summary,
    conditions_summary)
  
  cat(
    sprintf(
      "Table 1: Baseline Characteristics (N= %g)\n",
      total_patients))
  
  if (!is.null(min_count)) {
    result <- result |> filter(n_persons >= min_count)
  }
  
  return(result)
}

#using above function to generate, view, and export table 1
#cut/comment this out before adding to ohdsilab package
my_table1 <- komodo_table1(
  con,
  "cohort",
  komodo_schema = "komodo",
  write_schema = paste0(
    "work_",
    keyring::key_get("db_username")),
  min_count = 1)

View(my_table1)

write.csv(my_table1, "table1.csv", row.names = FALSE)
