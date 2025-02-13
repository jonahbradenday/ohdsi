#1. Join your cohort to the person table to get information about 
#demographics, and calculate age at cohort entry. If you generated your cohort 
#using "ohdsi_lab_training_just_r.R", replace "cohort_atlas" with "cohort_r".
demographics <- cohort_atlas |> 
  omop_join("person", type = "inner", by = "person_id") |> 
  select(person_id, cohort_start_date, cohort_end_date, year_of_birth, 
         gender = gender_concept_id, race = race_concept_id, 
         ethnicity = ethnicity_concept_id) |> 
  mutate(age_at_entry = year(cohort_start_date) - year_of_birth)

#2. Join to the drug_exposure table to get information about drugs
drugs <- demographics |>
  omop_join("drug_exposure", type = "left", by = "person_id") |>
  select(person_id, year_of_birth, gender, race, ethnicity, 
         concept_id = drug_concept_id, drug_exposure_start_date, 
         drug_exposure_end_date)

#3. Join to the concept table to get human readable drug names
drugs <- drugs |>
  omop_join("concept", type = "left", by = "concept_id") |>
  select(person_id, year_of_birth, gender, race, ethnicity, 
         concept_id, drug = concept_name, 
         drug_exposure_start_date, drug_exposure_end_date)

#4. Collect your joined table into a dataframe
drugs_df <- drugs |> dbi_collect()

#5. Replace gender, race, and ethnicity values with human readable values. 
#These values can be found using athena.ohdsi.org.
drugs_df <- drugs_df %>%
  mutate(gender = case_when(gender == 8507 ~ "Male",
                            gender == 8532 ~ "Female"),
         race = case_when(race == 0 ~ NA,
                          race == 8516 ~ "Black",
                          race == 8527 ~ "White"),
         ethnicity = case_when(ethnicity == 38003563 ~ "Hispanic or Latino",
                               ethnicity == 38003564 ~ "Not Hispanic or Latino"))

#6. Calculate prevalence rates of each drug
drug_prevalence <- drugs_df %>%
  count(drug) %>%         
  mutate(prop = prop.table(n))

#7. How many drugs per person per gender?
avg_drugs_by_gender <- drugs_df %>%
  group_by(gender, person_id) %>%
  summarise(num_drugs = n(), .groups = "drop") %>%
  group_by(gender) %>%
  summarise(avg_drugs = mean(num_drugs), .groups = "drop")

#8. How did drug exposure change over time?
drugs_per_date <- drugs_df %>%
  group_by(drug_exposure_start_date) %>%
  summarize(person_count = n_distinct(person_id))

ggplot(drugs_per_date) +
  geom_line(aes(x = drug_exposure_start_date, y = person_count))

#9. What percentage of each race has been prescribed Metformin hydrochloride 
#500 MG Oral Tablet
total_persons <- n_distinct(drugs_df$person_id)

metformin_users <- drugs_df %>%
  filter(drug == "Metformin hydrochloride 500 MG Oral Tablet") %>%
  group_by(race) %>%
  summarize(person_count = n_distinct(person_id), .groups = "drop") %>%
  mutate(proportion = person_count/total_persons)

ggplot(metformin_users) +
  geom_bar(aes(x = race, y = proportion, fill = race), stat = "identity") +
  labs(x = "Race", y = "Percentage of Race", 
       title = "Proportion of Each Race Taking Metformin")
