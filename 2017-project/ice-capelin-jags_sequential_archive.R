# extra code from ice-capelin-jag_sequential - removed to enahnce readability of code.


## not sure of use----
df_age <- df[c("year", "logcapelin", "age2", "age3", "age4", "age5", "age6", "age2PerMat", "resids_adj")]

mean(df_age$age2PerMat, na.rm = T)
summary(df_age$age2PerMat)
plot(df_age$logcapelin, df_age$age2PerMat)
plot(df_age$year, df_age$age2PerMat)
summary(lm(age2PerMat ~ logcapelin, data = df_age))
m1 <- lm(age2PerMat ~ logcapelin, data = df_age)

layout(matrix(c(1,2,3,4),2,2)) # optional layout 
plot(m1)
layout(matrix(1,1))

#test to see if lag occurs
plot(lag(df_age$logcapelin, 1), df_age$age2PerMat)
summary(lm(age2PerMat ~ lead(logcapelin, 1), data = df_age))
# no lag occurs

Age2PMat <- df_age$age2PerMat
df_age <- df_age %>%
     mutate(N3_6 = age3 + age4 + age5 + age6)
N3_6 <- df_age$N3_6

ST <- df$Ssurface_tows_lag2
TI <- df$tice
N <- nrow(df)

## test 1 first try----
jags_code = '
model {
# Likelihood
for (i in 1:N) {
#recruitment
mu_n2[i] <- beta + alpha*ST[i]
N2[i] ~ dnorm(mu_n2[i], sigma^-2)
# proportion N2
Nsp[i] <- N2[i]*Age2Mat + N3_6
# mortality
mu_sp[i] <- gamma*TI[i]*(1-(TI[i]/delta))
Nsp[i] ~ dnorm(mu_sp[i], sigma^-2)
}
# Priors
alpha ~ dnorm(0, 100^-2)
beta ~ dnamma(0, 100^-2)
gamma ~ dnorm(0, 100^-2)
delta ~ dnorm(0, 100^-2) 
sigma_r ~ dunif(0, 100)
sigma_m ~ dunif(0, 100)
}'

num_forecasts = 2 # 10 extra years
model_data <- list(L = c(df$logcapelin, rep(NA, num_forecasts)), 
                   ST=c(df$Ssurface_tows_lag2, c(98, 41)), #from capelin_larval_indices 
                   RA=c(df$resids_adj, c(15, 15)), #made up - need new data
                   N = nrow(df) + num_forecasts)

jags_run <- jags(data=model_data,
                 parameters.to.save = c('mu', 'sigma'),
                 model.file = textConnection(jags_code))

y_pred = jags_run$BUGSoutput$sims.list$mu
y_med = apply(y_pred,2,'median')
plot(c(test$year,2017:2018),y_med,type='l', ylim=c(0,9))
points(test$year, test$logcapelin)
points(test$year, y_med[1:14])
points(c(2017:2018), y_med[15:16], col = 'red', pch=19)
# this makes the credible interval 90%
lines(c(test$year,2017:2018), ci_test[1, ], lty = 3)
lines(c(test$year,2017:2018), ci_test[2, ], lty = 3)


str(test)
apply(y_pred,2,'quantile', c(0.05, 0.95))[, 15:16] #these are the extra 2 years
ci_test <- apply(y_pred,2,'quantile', c(0.05, 0.95))
ci_test[1, ]


## test 2 ----
# not sequential
#"Beta + Alpha*ST+ Gamma*RA",
jags_code = '
model {
# Likelihood
for (i in 1:N) {
#recruitment
mu[i] <- beta + alpha*ST[i] + gamma*RA[i]
N2[i] ~ dnorm(mu[i], sigma^-2)
N2_new[i] ~ dnorm(mu[i], sigma^-2)
}
# Priors
alpha ~ dnorm(0, 100^-2)
beta ~ dnorm(0, 100^-2)
gamma ~ dnorm(0, 100^-2)
sigma ~ dunif(0, 100)
}'


num_forecasts = 2 # 2 extra years
model_data <- list(N2 = c(df1$logcapelin, rep(NA, num_forecasts)), 
                   ST=c(df1$Ssurface_tows_lag2, c(98, 41)), #from capelin_larval_indices 
                   RA=c(df1$resids_adj, c(15, 15)), #made up - need new data
                   N = nrow(df1) + num_forecasts)

jags_run <- jags(data=model_data,
                 parameters.to.save = c('mu', 'sigma', 'N2_new'),
                 model.file = textConnection(jags_code))

y_pred = jags_run$BUGSoutput$sims.list$mu
y_med = apply(y_pred,2,'median')

str(df1)
apply(y_pred,2,'quantile', c(0.05, 0.95))[, 15:16] #these are the extra 2 years
ci_df1 <- apply(y_pred,2,'quantile', c(0.05, 0.95))
ci_df1[1, ]

y_new = jags_run$BUGSoutput$sims.list$N2_new
pi_df1 <- apply(y_new,2,'quantile', c(0.05, 0.95))

plot(c(df1$year,2017:2018),y_med,type='l', ylim=c(0,9))
points(df1$year, df1$logcapelin)
#points(df1$year, y_med[1:14], col = "blue")
#points(c(2017:2018), y_med[15:16], col = 'red', pch=19)
# this makes the credible interval 90%
#lines(c(df1$year,2017:2018), ci_df1[1, ], lty = 3)
lines(c(df1$year[1:14]), ci_df1[1, 1:14], lty = 3)
#lines(c(df1$year,2017:2018), ci_df1[2, ], lty = 3)
lines(c(df1$year[1:14]), ci_df1[2, 1:14], lty = 3)
#lines(c(df1$year,2017:2018), pi_df1[1, ], lty = 2)
lines(c(2017:2018), pi_df1[1, 15:16], lty = 2)
#lines(c(df1$year,2017:2018), pi_df1[2, ], lty = 2)
lines(c(2017:2018), pi_df1[2, 15:16], lty = 2)

polygon(x = c(2017, 2017, 2018, 2018), y = c(pi_df1[1, 15], pi_df1[2,15], pi_df1[2, 16], pi_df1[1, 16]), col="grey75")
text(2007,8, "log(caplein) = Beta + Alpha*ST+ Gamma*RA")



## test 3 ----
# not sequential
#"Beta + Alpha*ST+ Gamma*PS",
jags_code = '
model {
# Likelihood
for (i in 1:N) {
#recruitment
mu[i] <- beta + alpha*ST[i] + gamma*PS[i]
N2[i] ~ dnorm(mu[i], sigma^-2)
N2_new[i] ~ dnorm(mu[i], sigma^-2)
}
# Priors
alpha ~ dnorm(0, 100^-2)
beta ~ dnorm(0, 100^-2)
gamma ~ dnorm(0, 100^-2)
sigma ~ dunif(0, 100)
}'


num_forecasts = 2 # 2 extra years
model_data <- list(N2 = c(df1$logcapelin, rep(NA, num_forecasts)), 
                   ST=c(df1$Ssurface_tows_lag2, c(98, 41)), #from capelin_larval_indices 
                   PS=c(df1$ps_meanTot_lag2, c(80, 80)), #made up - need new data
                   N = nrow(df1) + num_forecasts)

jags_run <- jags(data=model_data,
                 parameters.to.save = c('mu', 'sigma', 'N2_new'),
                 model.file = textConnection(jags_code))

y_pred = jags_run$BUGSoutput$sims.list$mu
y_med = apply(y_pred,2,'median')

apply(y_pred,2,'quantile', c(0.05, 0.95))[, 15:16] #these are the extra 2 years
ci_df1 <- apply(y_pred,2,'quantile', c(0.05, 0.95))
ci_df1[1, ]

y_new = jags_run$BUGSoutput$sims.list$N2_new
pi_df1 <- apply(y_new,2,'quantile', c(0.05, 0.95))

plot(c(df1$year,2017:2018),y_med,type='l', ylim=c(0,9))
points(df1$year, df1$logcapelin)
#points(df1$year, y_med[1:14], col = "blue")
#points(c(2017:2018), y_med[15:16], col = 'red', pch=19)
# this makes the credible interval 90%
#lines(c(df1$year,2017:2018), ci_df1[1, ], lty = 3)
lines(c(df1$year[1:14]), ci_df1[1, 1:14], lty = 3)
#lines(c(df1$year,2017:2018), ci_df1[2, ], lty = 3)
lines(c(df1$year[1:14]), ci_df1[2, 1:14], lty = 3)
#lines(c(df1$year,2017:2018), pi_df1[1, ], lty = 2)
lines(c(2017:2018), pi_df1[1, 15:16], lty = 2)
#lines(c(df1$year,2017:2018), pi_df1[2, ], lty = 2)
lines(c(2017:2018), pi_df1[2, 15:16], lty = 2)

polygon(x = c(2017, 2017, 2018, 2018), y = c(pi_df1[1, 15], pi_df1[2,15], pi_df1[2, 16], pi_df1[1, 16]), col="grey75")
text(2007,8, "log(caplein) = Beta + Alpha*ST+ Gamma*PS")


## test 4 ----
# not sequential
#"Alpha*tice*(1-(tice/Beta)) + Gamma*resids_adj"
jags_code = '
model {
# Likelihood
for (i in 1:N) {
#recruitment
mu[i] <- alpha*TI[i]*(1-(TI[i])*beta) + gamma*RA[i]
N2[i] ~ dnorm(mu[i], sigma^-2)
N2_new[i] ~ dnorm(mu[i], sigma^-2)
}
# Priors
alpha ~ dnorm(0, 100^-2)
beta ~ dnorm(0, 100^-2)
gamma ~ dnorm(0, 100^-2)
sigma ~ dunif(0, 100)
}'


num_forecasts = 2 # 2 extra years
model_data <- list(N2 = c(df1$logcapelin, rep(NA, num_forecasts)), 
                   TI=c(df1$tice, c(70, 70)), #from capelin_larval_indices 
                   RA=c(df1$resids_adj, c(15, 15)), #made up - need new data
                   N = nrow(df1) + num_forecasts)

jags_run <- jags(data=model_data,
                 parameters.to.save = c('mu', 'sigma', 'N2_new'),
                 model.file = textConnection(jags_code))

y_pred = jags_run$BUGSoutput$sims.list$mu
y_med = apply(y_pred,2,'median')

apply(y_pred,2,'quantile', c(0.05, 0.95))[, 15:16] #these are the extra 2 years
ci_df1 <- apply(y_pred,2,'quantile', c(0.05, 0.95))
ci_df1[1, ]

y_new = jags_run$BUGSoutput$sims.list$N2_new
pi_df1 <- apply(y_new,2,'quantile', c(0.05, 0.95))

plot(c(df1$year,2017:2018),y_med,type='l', ylim=c(0,9))
points(df1$year, df1$logcapelin)
#points(df1$year, y_med[1:14], col = "blue")
#points(c(2017:2018), y_med[15:16], col = 'red', pch=19)
# this makes the credible interval 90%
#lines(c(df1$year,2017:2018), ci_df1[1, ], lty = 3)
lines(c(df1$year[1:14]), ci_df1[1, 1:14], lty = 3)
#lines(c(df1$year,2017:2018), ci_df1[2, ], lty = 3)
lines(c(df1$year[1:14]), ci_df1[2, 1:14], lty = 3)
#lines(c(df1$year,2017:2018), pi_df1[1, ], lty = 2)
lines(c(2017:2018), pi_df1[1, 15:16], lty = 2)
#lines(c(df1$year,2017:2018), pi_df1[2, ], lty = 2)
lines(c(2017:2018), pi_df1[2, 15:16], lty = 2)

polygon(x = c(2017, 2017, 2018, 2018), y = c(pi_df1[1, 15], pi_df1[2,15], pi_df1[2, 16], pi_df1[1, 16]), col="grey75")

text(2007,8, "log(caplein) = Alpha*tice*(1-(tice/Beta)) + Gamma*resids_adj")

