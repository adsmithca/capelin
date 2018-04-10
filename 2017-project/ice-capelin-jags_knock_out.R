#  Script written by Keith Lewis (Keith.Lewis@dfo-mpo.gc.ca)  #
#  Created 2018-03-19, R version 3.3.3 (2017-03-06)   

# The purpose of this file is to test the sensitivity of the results from the models in "ice-capelin-sequential-jag.R".  Specifically, the purpose is to test the sensitivity of any one year. 


## libraries----
library(R2jags)
library(rjags)
library(readr)
library(tidyr)
library(dplyr)
library(psych)
library(ggplot2)
library(lattice)
library(magrittr)
library(loo)

rm(list=ls())

## read in source code-----
source('D:/Keith/R/zuur_rcode/MCMCSupportHighstatV2.R')
source('D:/Keith/R/zuur_rcode/HighstatLibV7.R')
source("D:/Keith/capelin/2017-project/ice-capelin-covariates-FUN.R")
source("D:/Keith/capelin/2017-project/ice-capelin-jags_sequential-FUN.R")

## data knock out----
#df2 <- df
#View(df2)
#df3 <- subset(df2, year>2002)
#View(df3)
#df2[c("year", "tice", "surface_tows_lag2", "meanCond_lag")]
#df2[c("year", "tice", "surface_tows_lag2", "meanCond_lag")][5,]

# png("Bayesian/EVs_1999_2017.png")
# par(mfrow = c(2,2), mar = c(5,5,2,2))
# plot(df2$year, df2$tice)
# plot(df2$year, df2$surface_tows_lag2)
# plot(df2$year, df2$meanCond_lag)
# par(mfrow = c(1,1))
# dev.off()

dataset <- "age" #biomass
if(dataset == "biomass"){
     df <- read_csv("Bayesian/biomass_cond_ag1/all_data_a1.csv")
     df2 <- df
     #View(df2)
     df3 <- subset(df2, year>2002)
     yaxis1 = "ln_biomass_med" 
     ylab1 = "ln(capelin biomass(ktons))"
     var_x <- df3$ln_biomass_med
     
} else if(dataset == "age") {
     df <- read_csv("Bayesian/age2_cond_ag1/all_data_a1.csv")
     df2 <- df
     #View(df2)
     df3 <- subset(df2, year>2002)
     yaxis1 = "age2_log10" 
     ylab1 = "log10 capelin - age2"
     var_x <- df3$age2_log10
}

#df3: 2003-2017
df3$year
x <- 15 #1:15
insert <- df3[x,]
df3 <- df3[-x, ]

#df2: 1999-2017
y <- x+4
insert_year <- 2017
insert_row  <- x
folder <- "leave_out_ag2"

st <- df2[c("year", "surface_tows_lag2")][y,]
ti <- df2[c("year", "tice")][y,]
co <- df2[c("year", "meanCond_lag")][y,]
st[,2]
ti[,2]
co[,2]

## R/M3 knock-off----
#"alpha + beta*ST[i] + gamma*TI[i]*(1-TI[i]/delta + epsilon*CO[i])"

m.RM3 = '
model {
# 1. Likelihood
for (i in 1:N) {
#recruitment
mu[i] <- alpha + beta*ST[i] + gamma*TI[i]*(1-TI[i]/delta + epsilon*CO[i])
N2[i] ~ dnorm(mu[i], sigma^-2)
N2_new[i] ~ dnorm(mu[i], sigma^-2) # #### ADB: This is simulated data   
log_lik[i] <- logdensity.norm(N2[i], mu[i], sigma^-2)

# 3. Discrepancy measures
expY[i] <- mu[i]
varY[i] <- sigma^2
Res[i] <- (N2[i] - expY[i])
PRes[i] <- (N2[i] - expY[i]) / sigma
PResNew[i] <- (N2_new[i] - expY[i]) / sigma
#Squared residuals
D[i] <- pow(PRes[i], 2) #SSQ
DNew[i] <- pow(PResNew[i], 2)
#CD[i] <- 
}
#Sum of squared Pearson residuals:
Fit <- sum(D[1:N]) # look at overdispersion
FitNew <- sum(DNew[1:N])

# 2. Priors
alpha ~ dnorm(0, 20^-2) 
beta ~ dnorm(0, 10^-2) 
gamma ~ dgamma(5, 1/3) 
delta ~ dgamma(2.8, 1)
epsilon ~ dnorm(0, 20^-2) 
sigma ~ dunif(0, 100) 
}'

#gamma and delta based on Bolker pg 132 - Fig4.13 - trying for an uniformative alpha
#delta: shape(a) is mean^2/var; we used 90 days based on Ales original #work; scale(s) equal Var/mean
# gamma,delta, sigma: uninformative for condition


num_forecasts =  1# 1 extra years
# df3$ln_biomass_med
# df3$age2_log10
model_data <- list(N2 = c(var_x, rep(NA, num_forecasts)), 
                   ST=c(df3$surface_tows_lag2, st[,2]),
                   TI=c(df3$tice, ti[,2]), 
                   CO=c(df3$meanCond_lag, co[,2]),
                   N = nrow(df3) + num_forecasts)

run_RM3 <- jags(data=model_data,
                parameters.to.save = c('mu', 'sigma', 'N2', 'N2_new', 'alpha', 'beta', 'gamma', 'delta', 'epsilon', 'Fit', 'FitNew', 'Res', 'PRes', 'expY', 'D', "log_lik"),
                model.file = textConnection(m.RM3))

#UPDATE WITH MORE BURN INS
run_RM3 <-update(run_RM3, n.iter = 300000, n.thin = 50, n.burnin = 100000)


##R/M3-plot 5----
# DIAGNOSTICS
out <- run_RM3$BUGSoutput 

# CREDIBLE AND PREDICITON INTERVALS
#generate credible intervals for time series using mu
y_pred = run_RM3$BUGSoutput$sims.list$mu

#look at output
y_med = apply(y_pred,2,'median')
ci_df3 <- apply(y_pred,2,'quantile', c(0.05, 0.95))

#generate prediciton intevals using N2_new
y_new = run_RM3$BUGSoutput$sims.list$N2_new
p_med = apply(y_new,2,'median')
pi_df3 <- apply(y_new,2,'quantile', c(0.05, 0.95))


## RM_3-Results----

#plot credible and prediction intervals
plotCredInt2(df3, insert, 
             yaxis = yaxis1, 
             ylab = ylab1, 
             y_line = y_med, 
             ci = ci_df3, 
             dpp = p_med,
             dpi = pi_df3, 
             insert_year = insert_year, type = NA)

ggsave(paste0("Bayesian/", folder, "/credInt", insert_year, ".png"), width=10, height=8, units="in")

if(dataset == "biomass"){
     per_diff <- ((df2$ln_biomass_med[y] - p_med[15])/df2$ln_biomass_med[y])*100
     per_diff_file <- as.data.frame(cbind(insert_year, per_diff))
} else if (dataset == "age"){
     per_diff <- ((df2$age2_log10[y] - p_med[15])/df2$age2_log10[y])*100
     per_diff_file <- as.data.frame(cbind(insert_year, per_diff))
}

per_diff_file
#write_csv(per_diff_file, paste0("Bayesian/", folder, "/perdiff_all.csv"))

temp <- read_csv(paste0("Bayesian/", folder, "/perdiff_all.csv"))

temp <- rbind(per_diff_file, temp)

write_csv(temp, paste0("Bayesian/", folder, "/perdiff_all.csv"))

##R^2-----
# calculate the Bayesian R-squared
# variance of predicted values
y_var = apply(y_pred,2,'var')
y_Var <- sum(y_var)/15

# variance of residuals
res_pred = run_RM3$BUGSoutput$sims.list$Res
res_med = apply(res_pred,2,'median')
res_var = apply(res_pred,2,'var')

res_Var <- sum(res_var)/15

# Bayesian R-squared
bay_rsq <- y_Var/((sum(res_var) + sum(y_var))/15)
bay_rsq

###Sensitivity----
ti_sd <- sd(df3$tice)
st_sd <- sd(df3$surface_tows_lag2)
co_sd <- sd(df3$meanCond_lag)

sd_vec <- c(1:4)



## extra stuff----
y_temp = run_RM3$BUGSoutput$sims.list$expY
y_expY = apply(y_temp,2,'median')
ci_expY <- apply(y_temp,2,'quantile', c(0.05, 0.95))

y_temp = run_RM3$BUGSoutput$sims.list$N2
y_N2 = apply(y_temp,2,'median')
ci_N2 <- apply(y_temp,2,'quantile', c(0.05, 0.95))