#1. Install the necessary packages. Because ohdsilab and ROhdsiWebApi have not 
#been added to CRAN, renv:install() is used instead of install.packages().
#remotes::install_github could also be used here.
renv::install(c("roux-ohdsi/ohdsilab","tidyverse", "DatabaseConnector", 
                "keyring", "OHDSI/RohdsiWebApi", "CohortGenerator", "gt"))

#2. Load the necessary packages.


#3. Set your database and ATLAS credentials. You credentials can be found in the 
#"Workspace Details" email you received after you created your workspace.


#4. Create the connection details and set path to JDBC driver. These details will be used as arguments in 
#later functions.


#5. Assign variables to the atlas url, the synpuf database schema and your 
#personal schema.


#6. Connect to the database. You will do this again later, but for now you just 
#need the "con" information saved for the next step.


#7. Make it easier for some r functions to find the database


#8. Connect to ATLAS.


#9. Identify the ATLAS cohort definition your want to use.



#10. Pull the cohort definition from ATLAS


#11. Set a naming convention for the cohort tables.



#12. Create empty tables in your personal schema using the naming convention
#designated in the last step.


#13. Generate your cohort for the Synpuf database.


#14. Connect to the database.


#15. Because you reran "con" you will have to set the following option again.



#16. Create a table containing your new cohort.


#17. How many people are in the cohort?


#18. Join your cohort to the person table to retrieve demographic information 
#and to the condition, drug, and concept tables to retreive those data


#19. Create table showing all condition and drug events in chronological order
# and look at patient_id 6385's journey


#20. Create histogram of gender within age


