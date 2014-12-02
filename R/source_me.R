rm(list = ls())

# library path
.libPaths('C:\\Users\\mbeck\\R\\library')

# startup message
cat('Bays and bays and bays...\n')

# packages to use
library(knitr)
library(reshape2) 
library(plyr)
library(ggplot2)
library(scales)
library(doParallel)
library(foreach)
library(Metrics)
library(GGally)
library(gridExtra)
library(ggmap)
library(data.table)

cases <- c('APACP', 'GNDBL', 'MARMB', 'RKBMB', 'WKBWB')

# setup parallel backend
cl <- makeCluster(7)
registerDoParallel(cl)

# start time
strt <- Sys.time()

# do w/ tide
foreach(case = cases) %dopar% {
   
  setwd('M:/presentations/bb_pres/')
  
  source('R/funcs.R')
  
#   # progress
#   sink('log.txt')
#   cat('Log entry time', as.character(Sys.time()), '\n')
#   cat(case, '\n')
#   print(Sys.time() - strt)
#   sink()
#     
  to_proc <- prep_wtreg(case)
  subs <- format(to_proc$DateTimeStamp, '%Y') %in% '2011'
  to_proc <- to_proc[subs, ]
  
  # create wt reg contour surface
  wtreg <- wtreg_fun(to_proc, wins = list(6, 1, 0.6), 
    parallel = F, 
    progress = T)
    
  # save results for each window
  wtreg_nm <-paste0(case, '_wtreg') 
  assign(wtreg_nm, wtreg)
  save(
    list = wtreg_nm,
    file=paste0('wtreg/', wtreg_nm, '.RData')
    )

  # clear RAM
  rm(list = c(wtreg_nm))
  
  }

stopCluster(cl)

#####
# get metab ests before and after detiding
# one element per site, contains both metab ests in the same data frame

# setup parallel backend
cl <- makeCluster(8)
registerDoParallel(cl)

# start time
strt <- Sys.time()

cases <- list.files(path = paste0(getwd(), '/wtreg/'), pattern = '_wtreg_')

# metab ests as list
met_ls <- foreach(case = cases) %dopar% {
  
  # progress
  sink('log.txt')
  cat('Log entry time', as.character(Sys.time()), '\n')
  cat(which(case == cases), ' of ', length(cases), '\n')
  print(Sys.time() - strt)
  sink()
  
  # get data for eval
  load(paste0('wtreg/', case))
  nm <- gsub('.RData', '', case)
  stat <- gsub('_wtreg_[0-9]+$', '', nm)
  dat_in <- get(nm)
  
  # get metab for obs DO
  met_obs <- nem.fun(dat_in, stat = stat, 
    DO_var = 'DO_obs')
  met_dtd <- nem.fun(dat_in, stat = stat, 
    DO_var = 'DO_nrm')
  
  # combine results
  col_sel <- c('Pg', 'Rt', 'NEM')
  met_obs <- met_obs[, c('Station', 'Date', 'Tide', col_sel)]
  met_dtd <- met_dtd[, col_sel]
  names(met_dtd) <- c('Pg_dtd', 'Rt_dtd', 'NEM_dtd')
  met_out <- cbind(met_obs, met_dtd)

  # return results
  met_out

  }
stopCluster(cl)

names(met_ls) <- cases
save(met_ls, file = 'data/met_ls.RData')
