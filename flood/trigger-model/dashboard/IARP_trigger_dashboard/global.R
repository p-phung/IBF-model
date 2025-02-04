library(shiny)
library(janitor)
library(tidyverse)
library(lubridate)
library(plotly)
library(shinydashboard)
library(sf)
library(leaflet)
library(readr)
library(httr)
library(zoo)

source('r_resources/plot_functions.R')
source('r_resources/predict_functions.R')
source('r_resources/Geo_settings.R')
source('r_resources/misc_functions.R')


countries <- c("Ethiopia" = 1, "Kenya" = 2,"Uganda" = 3)
levels <- c("LEVEL 2" = 2, "LEVEL 3" = 3)


#---------------------- setting -------------------------------



settings <- country_settings
url<- parse_url(url_geonode)

# country="ethiopia"
# for (elm in  names(eval(parse(text=paste("settings$",country,sep=""))))){
#   assign(paste0(country,"_",elm), download.features.geonode(country, elm))
# }
#
#
# country="kenya"
# for (elm in  names(eval(parse(text=paste("settings$",country,sep=""))))){
#   assign(paste0(country,"_",elm), download.features.geonode(country, elm))
# }
#
# country="uganda"
# for (elm in  names(eval(parse(text=paste("settings$",country,sep=""))))){
#   assign(paste0(country,"_",elm), download.features.geonode(country, elm))
# }

ethiopia_admin3 <- sf::read_sf("shapes/eth_adminboundaries_3.shp")

uganda_admin2 <- sf::read_sf("shapes/uga_adminboundaries_1.shp")

#kenya_admin1<-sf::read_sf("shapes/ken_adminboundaries_2.shp") %>% dplyr::mutate(ADM2_PCODE=ADM1_PCODE,ADM2_EN=ADM1_EN)

kenya_admin1 <- sf::read_sf("shapes/ken_adminboundaries_4.shp") %>%
  dplyr::mutate(ADM3_EN=WARDS,ADM2_EN=CNSTTNC) %>% dplyr::select(ADM3_PCODE,ADM3_EN,ADM2_PCODE,ADM2_EN)



admin <- list(ethiopia_admin3, kenya_admin1, uganda_admin2)

# swi <- read.csv("data/ethiopia_admin3_swi_all.csv", stringsAsFactors = F, colClasses = c("character", "character", "numeric", "numeric", "numeric"))
#ethiopia_impact <- read.csv("data/Eth_impact_data2.csv", stringsAsFactors = F, sep=";")

ethiopia_impact <- read_delim("data/eth_impactdata_master_.csv", ";", escape_double = FALSE, trim_ws = TRUE)%>%
  dplyr::mutate(score=ifelse(is.na(Data_quality_score),99,Data_quality_score))%>%
  dplyr::filter(score != 0)

#ethiopia_impact <- read_delim("data/Ethiopia_impact.csv", ",", escape_double = FALSE, trim_ws = TRUE)
#uganda_impact <- read_delim("data/uga_impactdata_master.csv", ",", escape_double = FALSE, trim_ws = TRUE)

uganda_impact <- read_delim("data/uga_impactdata_v2.csv", ",", escape_double = FALSE, trim_ws = TRUE)
uganda_impact <- uganda_impact %>% filter(data_quality_score > 0)

#
uganda_extra_impact <- read_delim("data/uga_impactdata_dref_appeal.csv", ",", escape_double = FALSE, trim_ws = TRUE)
#kenya_extra_impact <- read_delim("data/ken_impactdata_dref_appeal.csv", ",", escape_double = FALSE, trim_ws = TRUE)
#ethiopia_extra_impact <- read_delim("data/eth_impactdata_dref_appeal.csv", ",", escape_double = FALSE, trim_ws = TRUE)



#kenya_impact <- read_delim("data/ken_impactdata_master.csv", ";", escape_double = FALSE, trim_ws = TRUE)


#kenya_impact <- read_delim("data/ken_impactdata_master_1.csv", ";", escape_double = FALSE, trim_ws = TRUE)%>% 
#  filter(	adm3_pcode != '#N-A') %>% left_join(kenya_admin1 %>% dplyr::select(ADM3_PCODE,ADM3_EN,ADM2_EN),by=c('ADM3_PCODE'=='adm3_pcode')) %>% dplyr::mutate(adm2_name=cnsttnc) 

#kenya_impact <- read_delim("data/ken_impactdata_master_1.csv", ";", escape_double = FALSE, trim_ws = TRUE) %>% filter(adm3_pcode != '#N-A') %>% 
#  dplyr::mutate(ADM3_PCODE=adm3_pcode)%>% left_join(kenya_admin1 %>% dplyr::select(ADM3_PCODE,ADM3_EN,ADM2_EN),by="ADM3_PCODE")%>%clean_names()


kenya_impact <- read_delim("data/ken_impactdata_master_1.csv", ";", escape_double = FALSE, trim_ws = TRUE) %>% filter(adm3_pcode != '#N-A') %>% 
  dplyr::rename(ADM3_PCODE=adm3_pcode)%>% left_join(kenya_admin1 %>% dplyr::select(ADM3_PCODE,ADM3_EN,ADM2_EN),by="ADM3_PCODE")%>%clean_names()

#>>>>>>> Stashed changes

# to be replaced by data imorted from Geonode
#eth_admin3 <- sf::read_sf("shapes/ETH_Admin3_2019.shp")


for (n in range(1,length(admin))){
  admin[[n]] <- st_transform(admin[[n]], crs = "+proj=longlat +datum=WGS84")
}


glofas_date_window=14

glofas_raw <- read_csv("data/GLOFAS_fill_allstation_.csv") %>%
  group_by(station) %>%
  mutate(q50=quantile(dis,probs=.5, names = FALSE),
         q95=quantile(dis,probs=.95, names = FALSE),
          dis = rollapplyr(data = dis, width = glofas_date_window,FUN=max,align="center",fill = NA,na.rm = TRUE),
          dis_3 = rollapplyr(data = dis_3, width = glofas_date_window,FUN=max,align="center",fill = NA,na.rm = TRUE),
          dis_7 = rollapplyr(data = dis_7, width = glofas_date_window,FUN=max,align="center",fill = NA,na.rm = TRUE))%>%  ungroup()


glofas_mapping <- list()

glofas_mapping[[1]] <- read.csv("data/Eth_affected_area_stations2.csv", stringsAsFactors = F)

#glofas_mapping[[2]] <- read.csv("data/kenya_affected_area_stations.csv", stringsAsFactors = F)


########## per ward
kenya_mapp<- read.csv("data/kenya_affected_area_stations.csv", stringsAsFactors = F)%>%clean_names()

 
glofas_mapping[[2]] <-  read.csv("data/ken_adm4.csv", stringsAsFactors = F) %>% clean_names() %>% 
  left_join(kenya_mapp,by='county') %>% dplyr::mutate(adm2_name=cnsttnc) %>% 
  dplyr::select(adm2_name,adm2_pcode,adm3_pcode,station)  %>% drop_na()



glofas_mapping[[3]] <- read.csv("data/uga_affected_area_stations.csv", stringsAsFactors = F)




rainfall_raw <- list()
rainfall_raw[[1]] <- read.delim('data/Impact_Hazard_catalog.csv',sep=';') %>% clean_names()
#rainfall_raw[[2]] <- read_csv('data/WRF_kenya_2000-2010.csv') %>% clean_names()

#use the data calculated for counties to sub_counties
 
kenya_rain_county<-read_csv('data/WRF_kenya_2000-2010.csv') %>% gather("name","rainfall",-time)

kenya_rain_ward<-  read.csv("data/ken_adm4.csv", stringsAsFactors = F) %>% clean_names()%>%
  dplyr::mutate(name=county,pcode=adm3_pcode) %>% left_join(kenya_rain_county,by='name') %>% 
  dplyr::select(pcode,time,rainfall)%>%  drop_na()

kenya_rain_subcounty<-  read.csv("data/ken_adm4.csv", stringsAsFactors = F) %>% clean_names()%>%
  dplyr::mutate(name=county,pcode=adm2_pcode) %>% left_join(kenya_rain_county,by='name') %>% 
  dplyr::select(pcode,time,rainfall)%>% drop_na()


rainfall_raw[[20]]<-kenya_rain_subcounty

rainfall_raw[[2]]<-kenya_rain_ward

rainfall_raw[[3]] <- read_csv('data/WRF_uganda_2000-2010.csv') %>% clean_names()

rp_glofas_station <- read_csv('data/rp_glofas_station.csv') %>% clean_names()


# Clean impact and keep relevant columns
df_impact_raw <- list()

df_impact_raw[[1]] <- ethiopia_impact %>%
  clean_names() %>%
  mutate(date = dmy(date),
         pcode = str_pad(as.character(adm3_pcode), 6, "left", "0"),
         zone = adm2_name,
         admin = adm3_name) %>%
  dplyr::select(admin, zone, pcode,ifrc_source, date) %>%
  unique() %>%
  arrange(pcode, date)

ethiopia_extra_impact <- df_impact_raw[[1]] %>% dplyr::filter(ifrc_source == 'IFRC')


df_impact_raw[[2]] <-kenya_impact %>%
  clean_names() %>%
  mutate(date = dmy(date_recorded),
         pcode = adm3_pcode,
         admin = adm3_name) %>%
  dplyr::select(admin, pcode,data_source, date) %>%
  unique() %>%
  arrange(pcode, date)

df_impact_raw[[20]] <-kenya_impact %>%
  clean_names() %>%
  mutate(date = dmy(date_recorded),
         pcode = adm2_pcode,
         admin = adm2_en) %>%
  dplyr::select(admin, pcode,data_source, date) %>%
  unique() %>%
  arrange(pcode, date)

kenya_extra_impact <- df_impact_raw[[2]] %>% dplyr::filter(data_source == 'dref')
kenya_extra_impact2 <- df_impact_raw[[20]] %>% dplyr::filter(data_source == 'dref')

df_impact_raw[[3]] <- uganda_impact %>%
  clean_names() %>%
  mutate(date = dmy(date_event),
         pcode = adm2_pcode,
         admin = adm2_name) %>%
  dplyr::select(admin, pcode, date) %>%
  unique() %>%
  arrange(pcode, date)

df_extra_impact <- list()
#df_extra_impact[[1]] <- NA
#df_extra_impact[[2]] <- NA

df_extra_impact[[1]] <- ethiopia_extra_impact %>%
  dplyr::select(admin, pcode, date) %>%
  unique() %>%
  arrange(pcode, date)
df_extra_impact[[2]] <- kenya_extra_impact %>%
  dplyr::select(admin, pcode, date) %>%
  unique() %>%
  arrange(pcode, date)

df_extra_impact[[20]] <- kenya_extra_impact2 %>%
  dplyr::select(admin, pcode, date) %>%
  unique() %>%
  arrange(pcode, date)

df_extra_impact[[3]] <- uganda_extra_impact %>%
  clean_names() %>%
  mutate(date = dmy(date_event),
         pcode = adm2_pcode,
         admin = adm2_name) %>%
  dplyr::select(admin, pcode, date) %>%
  unique() %>%
  arrange(pcode, date)

#df_extra_impact[[1]] <- df_extra_impact[[3]] # dummy data
#df_extra_impact[[2]] <- df_extra_impact[[3]] # dummy data

# Used to join against
all_days <- tibble(date = seq(min(c(df_impact_raw[[1]]$date, df_impact_raw[[2]]$date, df_impact_raw[[3]]$date), na.rm=T) - 60,
                              max(c(df_impact_raw[[1]]$date, df_impact_raw[[2]]$date, df_impact_raw[[3]]$date), na.rm=T) + 60, by="days"))

# Clean GLOFAS mapping
glofas_mapping[[1]] <- glofas_mapping[[1]] %>%
  dplyr::select(-Z_NAME) %>%
  gather(station_i, station_name, -W_NAME) %>%
  dplyr::filter(!is.na(station_name)) %>%
  dplyr::mutate(admin = W_NAME) %>%
  dplyr::select(admin, station_name) %>%
  left_join(df_impact_raw[[1]] %>% dplyr::select(admin, pcode) %>% unique(), by = c("admin" = "admin")) %>%
  mutate(pcode = str_pad(as.character(pcode), 6, "left", "0")) %>%
  dplyr::filter(!is.na(pcode))


#per sub ward


glofas_mapping_ <- glofas_mapping[[2]] %>% 
  left_join(kenya_impact  %>% dplyr::select(adm2_pcode) %>%  unique(), by = "adm2_pcode") %>%
  dplyr::mutate(admin = adm2_name,station_name=station,pcode=adm2_pcode) %>%
  dplyr::select(admin, station_name, pcode) %>% drop_na()


glofas_mapping[[20]]  <- glofas_mapping_[!duplicated(glofas_mapping_[c("pcode","station_name")]),]

glofas_mapping[[2]] <- glofas_mapping[[2]] %>% 
  left_join(kenya_impact  %>% dplyr::select(adm3_name, adm3_pcode) %>%  unique(), by = "adm3_pcode") %>%
  dplyr::mutate(admin = adm3_name,station_name=station,pcode=adm3_pcode) %>%
  dplyr::select(admin, station_name, pcode) %>% drop_na()

# glofas_mapping[[2]] <- glofas_mapping[[2]] %>%
#   left_join(kenya_impact  %>% dplyr::select(County, adm2_pcode) %>%  unique(), by = "County") %>%
#   dplyr::mutate(admin = County,station_name=station,pcode=adm2_pcode) %>%
#   dplyr::select(admin, station_name, pcode)

glofas_mapping[[3]] <- glofas_mapping[[3]] %>%
  dplyr::select(name, pcode, Glofas_st, Glofas_st2, Glofas_st3, Glofas_st4) %>%
  gather(station_i, station_name, -name, -pcode) %>%
  dplyr::filter(!is.na(station_name) & station_name != "") %>%
  dplyr::mutate(admin = name) %>%
  dplyr::select(admin, station_name, pcode)

# Clean glofas
glofas_raw <- glofas_raw %>%
  dplyr::filter(
    date >= min(all_days$date),
    date <= max(all_days$date))

glofas_raw <- expand.grid(all_days$date, unique(glofas_raw$station)) %>%
  dplyr::rename(date = Var1, station = Var2) %>%
  left_join(glofas_raw %>% dplyr::select(date, dis, dis_3, dis_7,q50,q95, station), by = c("date", "station")) %>% 
  arrange(station, date) %>%
  group_by(station) %>%
  fill(dis, dis_3, dis_7, .direction="down") %>%
  fill(dis, dis_3, dis_7, .direction="up") %>%
  ungroup()

rainfall_raw[[1]] <- rainfall_raw[[1]]%>%dplyr::select(-pcode) %>%
  left_join(df_impact_raw[[1]] %>% dplyr::select(pcode, zone), by = "zone") %>%
  group_by(pcode, date) %>%
  dplyr::summarise(rainfall = mean(rainfall, na.rm=T))

rainfall_raw[[3]] <- rainfall_raw[[3]] %>% mutate(date = dmy(time)) %>% dplyr::select(-time) %>%
  gather(name, rainfall, -date) %>%
  left_join(df_impact_raw[[3]] %>% mutate(name = tolower(admin)) %>% 
              dplyr::select(name, pcode), by = "name")

# rainfall_raw[[2]] <- rainfall_raw[[2]] %>% mutate(date = dmy(time)) %>% dplyr::select(-time) %>%
#   gather(name, rainfall, -date) %>%
#   left_join(df_impact_raw[[2]] %>% mutate(name = tolower(admin)) %>% dplyr::select(name, pcode), by = "name")

rainfall_raw[[20]] <- rainfall_raw[[20]] %>% mutate(date = dmy(time)) %>% dplyr::select(-time)

rainfall_raw[[2]] <- rainfall_raw[[2]] %>% mutate(date = dmy(time)) %>% dplyr::select(-time)
#%>%  left_join(df_impact_raw[[2]] %>% mutate(name = tolower(admin)) %>% dplyr::select(name, pcode), by = "name")

# Clean rainfall - CHIRPS, kept for legacy
# rainfall_raw <- rainfall_raw %>%
#   mutate(pcode = str_pad(pcode, 6, "left", 0)) %>%
#   filter(
#     date >= min(df_impact_raw$date, na.rm=T) - 60,
#     date <= max(df_impact_raw$date, na.rm=T) + 60)

# # SWI, kept for legacy
# swi_raw <- swi %>%
#   mutate(date = ymd(date))
#
# swi_raw <- swi_raw %>%
#   gather(depth, swi, -pcode, -date)

# Determine floods per Wereda for map




admin[[10]] <- admin[[1]] %>%
  left_join(summarize_floods(df_impact_raw[[1]]) %>%
              dplyr::select(pcode, n_floods), by = c("ADM3_PCODE" = "pcode")) %>%
  dplyr::filter(!is.na(n_floods))

admin[[20]] <- admin[[2]] %>%
  left_join(summarize_floods(df_impact_raw[[20]]) %>%
              dplyr::select(pcode, n_floods), by = c("ADM2_PCODE" = "pcode")) %>%
  dplyr::filter(!is.na(n_floods))

admin[[30]] <- admin[[3]] %>%
  left_join(summarize_floods(df_impact_raw[[3]]) %>%
              dplyr::select(pcode, n_floods), by = c("ADM2_PCODE" = "pcode")) %>%
  dplyr::filter(!is.na(n_floods))

admin[[1]] <- admin[[1]] %>%
  left_join(summarize_floods(df_impact_raw[[1]]) %>%
              dplyr::select(pcode, n_floods), by = c("ADM3_PCODE" = "pcode")) %>%
  dplyr::filter(!is.na(n_floods))

admin[[2]] <- admin[[2]] %>%
  left_join(summarize_floods(df_impact_raw[[2]]) %>%
              dplyr::select(pcode, n_floods), by = c("ADM3_PCODE" = "pcode")) %>%
  dplyr::filter(!is.na(n_floods))

admin[[3]] <- admin[[3]] %>%
  left_join(summarize_floods(df_impact_raw[[3]]) %>%
              dplyr::select(pcode, n_floods), by = c("ADM2_PCODE" = "pcode")) %>%
  dplyr::filter(!is.na(n_floods))



label <- list()
label[[1]] <- "ADM3_EN"
label[[2]] <- "ADM3_EN"
label[[3]] <- "ADM2_EN"
label[[10]] <- "ADM3_EN"
label[[20]] <- "ADM2_EN"
label[[30]] <- "ADM2_EN"
layerId <- list()
layerId[[1]] <- "ADM3_PCODE"
layerId[[2]] <- "ADM3_PCODE"
layerId[[3]] <- "ADM2_PCODE"
layerId[[10]] <- "ADM3_PCODE"
layerId[[20]] <- "ADM2_PCODE"
layerId[[30]] <- "ADM2_PCODE"
