download.file(
  "https://raw.githubusercontent.com/ohdsi-studies/StrategusStudyRepoTemplate/main/renv.lock", 
  "D:/Users/j.bradenday/Documents/R Projects/ohdsi/strategus/renv.lock")

renv::record("renv@1.1.2")

renv::restore()

cohortDefinitionSet <- CohortGenerator::getCohortDefinitionSet(
  settingsFileName = "testdata/Cohorts.csv",
  jsonFolder = "testdata/cohorts",
  sqlFolder = "testdata/sql",
  packageName = "Strategus"
)
ncoCohortSet <- CohortGenerator::readCsv(file = system.file("testdata/negative_controls_concept_set.csv",
                                                            package = "Strategus"
))

cgModule <- CohortGeneratorModule$new()

# Create the cohort definition shared resource element for the analysis specification
cohortDefinitionSharedResource <- cgModule$createCohortSharedResourceSpecifications(
  cohortDefinitionSet = cohortDefinitionSet
)

# Create the negative control outcome shared resource element for the analysis specification
ncoSharedResource <- cgModule$createNegativeControlOutcomeCohortSharedResourceSpecifications(
  negativeControlOutcomeCohortSet = ncoCohortSet,
  occurrenceType = "all",
  detectOnDescendants = TRUE
)

# Create the module specification
cohortGeneratorModuleSpecifications <- cgModule$createModuleSpecifications(
  generateStats = TRUE
)