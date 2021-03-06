###################################################################
#    Calculate the adjacent school zones to extract a premium     #
###################################################################
library(rgdal)
library(rgeos)
library(dplyr)

# Load the data with the fake predictions
load("streeteasy/fakeDataForPremiums.RData")

## Read in from shape file
school_zones <- readOGR(dsn='geocoding/2013_2014_School_Zones_8May2013', layer='ES_Zones_2013-2014')

## Grabs adj zones for each zone
adjacent_zones <- gTouches(school_zones, byid = TRUE)

## Make a data frame for each pair.
adjacent_pairs <- as.data.frame(which(adjacent_zones, arr.ind = TRUE))
adjacent_pairs <- mutate(adjacent_pairs, row=row-1,col=col-1)

## Assign pairups to each DBN
zone_df = school_zones@data
zone_df$shape_id = rownames(zone_df)
id_dbn_map <- as.data.frame(zone_df[,c("shape_id","DBN")])
temp <-  merge(adjacent_pairs, id_dbn_map, by.x="row", by.y="shape_id")
temp2 <- rename(temp, DBN1=DBN)
adjacent_dbns <- merge(temp2, id_dbn_map, by.x="col", by.y="shape_id")
adjacent_dbns <- rename(adjacent_dbns, DBN2=DBN)
adjacent_dbns <- adjacent_dbns[,c("DBN1", "DBN2")]

# suppose we have a pred_prices=data.frame (DBN, bedrooms, baths, predicted_price)
# pred_prices = expand.grid(DBN=unique(adjacent_dbns$DBN1), bedrooms=c(0,1,2), 
                          #baths=c(1,2)) %>% mutate(price=runif(n(), 1, 100))

## Rename columns to use in premium extraction
pred_prices <- fakeDataForPremiums %>% rename(price=meanPrediction)

## Merge the predicted prices to the DBN/pairup information
adjacent_dbns2 <- merge (adjacent_dbns, pred_prices, by.x="DBN1", by.y="DBN") %>%
  rename( price1=price) %>%
   merge ( pred_prices, by.x=c("DBN2", "bedrooms", "baths"), 
                         by.y=c("DBN", "bedrooms", "baths")) %>%
    rename(price2=price)

## Grab the premium by subtracting the mean price in a zone from
  ## mean prices in neighboring zones.
price_premium <- adjacent_dbns2 %>% group_by(DBN1,bedrooms, baths) %>% 
  summarise(mean_premium=mean(price1)-mean(price2), 
            median_premium=median(price1)-median(price2)) %>% rename(DBN=DBN1)

## Extract for PS321 and PS282
pp321 <- filter(pred_prices, bedrooms == 2 & baths == 2 & DBN == '15K321')
pp282 <- filter(pred_prices, bedrooms == 2 & baths == 2 & DBN == '13K282')

## This is the difference in ppsqft between the two for a 2BR/2BA
priceDiff <- pp321$price - pp282$price

## Percent difference between 282 and 321
priceDiff/945

## Save in a data frame for use to plot on the map.
save(price_premium, file = "pricePremium.RData")

## Save to a tsv file.
write.table(adjacent_dbns, file = "adjacent_zones.tsv", quote = FALSE, sep = "\t", 
	row.names = FALSE, col.names = FALSE)
