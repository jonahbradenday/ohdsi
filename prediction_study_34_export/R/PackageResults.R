# Copyright 2020 Observational Health Data Sciences and Informatics
#
# This file is part of test
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

#' Package the results for sharing with OHDSI researchers
#'
#' @details
#' This function packages the results.
#'
#' @param outputFolder        Name of folder containing the study analysis results 
#'                            (/)
#' @param minCellCount        The minimum number of subjects contributing to a count before it can be included in the results.
#'
#' @export
packageResults <- function(outputFolder, 
  minCellCount = 5) {
  if(missing(outputFolder)){
    stop('Missing outputFolder...')
  }
  
  # for each analysis copy the requested files...
  folders <- list.dirs(path = outputFolder, recursive = F, full.names = F)
  folders <- folders[grep('Analysis_', folders)]
  
  #create export subfolder in workFolder
  exportFolder <- file.path(outputFolder, "export")
  if(!dir.exists(exportFolder)){
    dir.create(exportFolder, recursive = T)
  }
  
  for(folder in folders){
    #copy all plots across
    if (!file.exists(file.path(exportFolder,folder))){
      dir.create(file.path(exportFolder,folder), recursive = T)
    }
    
    # loads analysis results
    if(dir.exists(file.path(outputFolder,folder, 'plpResult'))){
      plpResult <- PatientLevelPrediction::loadPlpResult(file.path(outputFolder,folder, 'plpResult'))
      
      PatientLevelPrediction::savePlpShareable(
        result = plpResult, 
        saveDirectory = file.path(exportFolder,folder), 
        minCellCount = minCellCount
      )
    }
  }
  
  ### Add all to zip file ###
  zipName <- paste0(file.path(outputFolder, 'resultsToShare.zip'))
  OhdsiSharing::compressFolder(exportFolder, zipName)
  # delete temp folder
  unlink(exportFolder, recursive = T)
  
  ParallelLogger::logInfo(paste("\nStudy results are compressed and ready for sharing at:", zipName))
  return(zipName)
}

