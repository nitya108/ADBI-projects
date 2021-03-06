#
# @author Rachit Shah (rshah25)
#
## Import Libraries
library(reshape)
library(fastDummies)
library(qcc)

##Function to find similar categories among features after pivoting and hence reduce features
combine_category_and_apply <- function(pivot,col){
  threshold = 0.03
  similar_dict = list()
  for(i in 1:(length(pivot)-1)){
    for(j in i+1:length(pivot)){
      if(abs(pivot[i,2]-pivot[j,2]) < threshold){
        similar_dict[toString(pivot[j,1])] = pivot[i,1]
      }
    }
  }
  for(x in names(similar_dict)){
    train_df[train_df[col]==x,col] <<- similar_dict[[x]]
    test_df[test_df[col]==x,col] <<- similar_dict[[x]]
  }
}


## Read Data
df = readxl::read_xls("eBayAuctions.xls")
colnames(df)[8] = "Competitive"
df$Duration = as.factor(df$Duration)


##Split into training and testing sets
train_size = 0.6
size <- floor(train_size * nrow(df))
set.seed(7)
train_ind <- sample(seq_len(nrow(df)), size = size)
train_df <- df[train_ind, ]
test_df <- df[-train_ind, ]
train_copy <- train_df

##Pivot Table
train_df.melt = melt(train_df, id.vars = c("Category","currency","Duration","endDay"), measure.vars = "Competitive")
train_df.melt
train_df.pivotCat = cast(train_df.melt, Category ~ variable, mean)
train_df.pivotCur = cast(train_df.melt, currency ~ variable, mean)
train_df.pivotDur = cast(train_df.melt, Duration ~ variable, mean)
train_df.pivotEnd = cast(train_df.melt, endDay ~ variable, mean)

##Combine Categories that are similar
combine_category_and_apply(train_df.pivotCat,"Category")
combine_category_and_apply(train_df.pivotCur, "currency")
combine_category_and_apply(train_df.pivotDur, "Duration")
combine_category_and_apply(train_df.pivotEnd, "endDay")


##Create Dummy Variables (optional since glm does it automatically)
train_df = dummy_cols(train_df,remove_first_dummy = TRUE)
train_df = within(train_df, rm("Category", "currency","Duration","endDay"))

test_df = dummy_cols(test_df,remove_first_dummy = TRUE)
test_df = within(test_df, rm("Category", "currency","Duration","endDay"))


##Fitting with all predictors
fit.all = glm(Competitive ~ ., family=binomial(link="logit"),data=train_df)
summary(fit.all)
max=-.Machine$integer.max
max_feature = NA
for(i in 1:length(fit.all$coefficients)){
  if(abs(fit.all$coefficients[i])>max){
    max = fit.all$coefficients[i]
    max_feature = names(fit.all$coefficients[i])
  }
}
message("Feature with highest estimate is ",max_feature," with an estimate of ",max)



##Find statistically significant predictors and fit reduced model
significance = summary(fit.all)$coef[,4]
formula = "Competitive ~ "
count=0
for(i in 1:length(significance)){
  if(significance[i]<0.05){
    if(count==0){
      formula = paste(formula,names(significance[i]),"")
      count=count+1
    }
    else{
      formula = paste(formula,"+",names(significance[i]))
    }
  }
}
fit.reduced = glm(formula, family=binomial(link="logit"),data=train_df)
summary(fit.reduced)

##Check if both are equivalent
anova(fit.reduced, fit.all, test = "Chisq")

##Check overdispersion
message("Dispersion of model is ",(fit.reduced$deviance/fit.reduced$df.residual))
sample_size=rep(100, length(train_df$Competitive))
qcc.overdispersion.test(train_df$Competitive, size=sample_size, type="binomial")


