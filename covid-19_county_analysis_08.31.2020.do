********************************************************************************************************
** Assessing the Impact of the Covid-19 Pandemic on US Mortality: A County-Level Analysis
** Andrew Stokes; Dielle J. Lundberg; Anna Mcgregor; Katherine Hempstead; Irma T. Elo; Samuel H. Preston
** Do File Last Updated: August 29, 2020				        
********************************************************************************************************

*****************
** BLOCK #1.   **
** IMPORT DATA **
*****************

// Data Sources for Mortality
*** 1. 2020 CDC Provisional Data on All-Cause & COVID-19 Mortality by County
*** 2. 2014-2018 CDC Wonder Estimates on All-Cause Mortality by County
*** 3. 2014-2019 U.S. Census Estimates of Population by County
*** 4. 2020 U.S. Census Estimates of Population by County

// Data Sources for Demographic, Structural & Covid-19 Policy Factors
*** 5. 2020 RWJ Foundation County Health Rankings
*** 6. County Land Size
*** 7. Governors' Political Parties
*** 8. State Covid-19 Testing Data
*** 9. State Stay-at-Home Closure Data
*** 10. New York Times County-Level Covid-19 Cases

// Set Directory Containing Raw Data
cd ""

// 1. 2020 CDC Provisional Data on All-Cause & COVID-19 Mortality by County
/* Source: https://data.cdc.gov/NCHS/Provisional-COVID-19-Death-Counts-in-the-United-St/kn79-hsxy */
import delimited "1_cdc_2020_counties_8.26.2020.csv", clear
keep state countyname fipscountycode deathsinvolvingcovid19 deathsfromallcauses
save data_1.dta, replace

// 2. 2014-2018 CDC Wonder Estimates on All-Cause Mortality by County
/* Source: https://wonder.cdc.gov/ - All-Cause Mortality, February through August for each year, stratified by month and county */
/* Source: https://wonder.cdc.gov/ - All-Cause Mortality, February through July for each year, stratified by county */
forvalues num=13/18 {
import delimited "2_wonder_20`num'_counties.txt", clear
keep countycode month deaths
replace month = "02_`num'" if month == "Feb., 20`num'"
replace month = "03_`num'" if month == "Mar., 20`num'"
replace month = "04_`num'" if month == "Apr., 20`num'"
replace month = "05_`num'" if month == "May, 20`num'"
replace month = "06_`num'" if month == "Jun., 20`num'"
replace month = "07_`num'" if month == "Jul., 20`num'"
replace month = "08_`num'" if month == "Aug., 20`num'"
drop if countycode == .
reshape wide deaths, i(countycode) j(month) string
save data_2_`num', replace
import delimited "2_wonder_20`num'.txt", clear
keep countycode deaths
rename deaths deaths_02_07_`num'
drop if countycode == .
merge 1:1 countycode using data_2_`num'.dta
rename countycode fipscountycode
drop _merge
save data_2_`num', replace
}

// 3. 2014-2019 U.S. Census Estimates of Population by County
/* Source: https://www.census.gov/data/datasets/time-series/demo/popest/2010s-counties-total.html?# */
import delimited "3_census_counties_2011_2019.csv", clear
gen state_string = string(state, "%02.0f")
gen county_string = string(county, "%03.0f")
gen fipscountycode = state_string + county_string
drop state_string county_string state
destring fipscountycode, replace
label var fipscountycode "FIPS code"
keep fipscountycode popestimate2013 popestimate2014 popestimate2015 popestimate2016 popestimate2017 popestimate2018 popestimate2019 npopchg_2013 npopchg_2014 npopchg_2015 npopchg_2016 npopchg_2017 npopchg_2018 npopchg_2019
save data_3.dta, replace

// 4. 2020 U.S. Census Estimates of Population by County
/* Source: file obtained by special request to U.S. Census Bureau */
import delimited "4_pop_2020.csv", clear
gen state_string = string(state, "%02.0f")
gen county_string = string(county, "%03.0f")
gen fipscountycode = state_string + county_string
drop state_string county_string state
destring fipscountycode, replace
bysort fipscountycode: egen popestimate2019 = sum(pop_count_2019)
bysort fipscountycode: egen popestimate2020 = sum(pop_count_2020)
gen npopchg_2020 = popestimate2020 - popestimate2019
label var fipscountycode "FIPS code"
keep fipscountycode popestimate2020 npopchg_2020
duplicates drop
save data_4.dta, replace

// 5. 2020 RWJ Foundation County Health Rankings
/* Source: https://www.countyhealthrankings.org/explore-health-rankings/rankings-data-documentation */
import delimited "5_RWJF_county_health_rankings.csv", clear
rename fipscode fipscountycode 
rename v053_rawvalue percent_65_over
rename v054_rawvalue percent_black
rename v126_rawvalue percent_white
rename v063_rawvalue household_income
rename v044_rawvalue income_inequality
rename v153_rawvalue home_ownership
keep fipscountycode percent_65_over percent_black percent_white household_income income_inequality home_ownership
save data_5.dta, replace

// 6. County Land Size
/* Source: https://gist.github.com/palewire/5cf017f21730ebd8303fb51e0cc7a2cd */
import excel "6_land_size.xls", clear firstrow
keep STCOU LND110210D
rename STCOU fipscountycode
destring fipscountycode, replace
rename LND110210D land_size
save data_6.dta, replace

// 7. Governors' Political Parties
/* Source: https://www.kff.org/other/state-indicator/state-political-parties/ */
import delimited "7_governors_political.csv", clear
keep v2 v3
rename v3 state
generate governor_party = 0 if v2 == "Democrat"
replace governor_party = 1 if v2 == "Republican"
drop v2
save data_7.dta, replace

// 8. State Covid-19 Testing Data
/* Source: https://covidtracking.com/data/download */
import delimited "https://covidtracking.com/api/v1/states/daily.csv", clear
keep if date == 20200826
replace pending = 0 if pending == .
gen tests = positive + negative + pending
keep state tests
save data_8.dta, replace

// 9. State Stay-at-Home Closure Data
/* Source: https://docs.google.com/spreadsheets/d/1zu9qEWI8PsOI_i8nI_S29HDGHlIp2lfVMsGxpQ5tvAQ/edit#gid=1489353670 */
import excel "9_stay_at_home.xlsx", clear firstrow
drop State
rename state_abbreviation state
rename Stayathomeshelterinplace stay_at_home
rename Population2018 state_pop_2018
drop if state_pop_2018 == .
replace stay_at_home = "" if stay_at_home == "."
generate stay_at_home_date = date(stay_at_home, "DMY")
format stay_at_home_date %td
drop stay_at_home
save data_9.dta, replace

// 10. New York Times County-Level Covid-19 Cases 
/* Source: https://github.com/nytimes/covid-19-data/blob/master/us-counties.csv */
/* Identify Date County Exceeded 25 Covid-19 Cases */
import delimited "https://raw.githubusercontent.com/nytimes/covid-19-data/master/us-counties.csv", clear
rename date dateold
gen cases_2 = cases if date == "2020-08-26"
bysort fips: egen cases_covid = min(cases_2)
generate date = date(dateold, "YMD")
keep if cases > 25
bysort fips: egen first_date_25_cases = min(date) 
format first_date %td
keep fips first_date_25_cases
rename fips fipscountycode
duplicates drop
save data_10.dta, replace

****************
** BLOCK #2.  **
** MERGE DATA **
****************

// Merge Data Files 1-10
use data_1.dta, clear
forvalues num = 13/18 {
merge 1:1 fipscountycode using "data_2_`num'.dta"
keep if _merge == 3 | _merge == 1
drop _merge
}
merge 1:1 fipscountycode using "data_3.dta"
keep if _merge == 3
drop _merge
merge 1:1 fipscountycode using "data_4.dta"
keep if _merge == 3
drop _merge
merge 1:1 fipscountycode using "data_5.dta"
keep if _merge == 3
drop _merge
merge 1:1 fipscountycode using "data_6.dta"
keep if _merge == 3 | _merge == 1
drop _merge
merge m:1 state using "data_7.dta"
keep if _merge == 3
drop _merge
merge m:1 state using "data_8.dta"
keep if _merge == 3
drop _merge
merge m:1 state using "data_9.dta"
keep if _merge == 3 | _merge == 1
drop _merge
merge 1:1 fipscountycode using "data_10.dta"
keep if _merge == 3 | _merge == 1
drop _merge
save clean_data.dta, replace

**********************************
** BLOCK #3. 					**
** PRODUCE POPULATION ESTIMATES **
**********************************

// Produce County Population Estimates for May 15 of 2014-2020
/* popestimate#### reflects the population estimate for July 1 of the year */
/* npopchg_#### reflects the annual population change since July 1 of the prior year to July 1 of year #### */
generate pop_2013 = popestimate2013 - (npopchg_2013 * 1.5/12)
label var pop_2013 "Population Estimate 04/01/2013"
generate pop_2014 = popestimate2014 - (npopchg_2014 * 1.5/12)
label var pop_2014 "Population Estimate 04/01/2014"
generate pop_2015 = popestimate2015 - (npopchg_2015 * 1.5/12)
label var pop_2015 "Population Estimate 04/01/2015"
generate pop_2016 = popestimate2016 - (npopchg_2016 * 1.5/12)
label var pop_2016 "Population Estimate 04/01/2016"
generate pop_2017 = popestimate2017 - (npopchg_2017 * 1.5/12)
label var pop_2017 "Population Estimate 04/01/2017"
generate pop_2018 = popestimate2018 - (npopchg_2018 * 1.5/12)
label var pop_2018 "Population Estimate 04/01/2018"
generate pop_2019 = popestimate2019 - (npopchg_2019 * 1.5/12)
label var pop_2019 "Population Estimate 04/01/2019"
generate pop_2020 = popestimate2020 - (npopchg_2020 * 1.5/12)
label var pop_2020 "Population Estimate 04/01/2020"

// Drop Variables
drop popestimate2013 popestimate2014 popestimate2015 popestimate2016 popestimate2017 popestimate2018 popestimate2019 popestimate2020 npopchg_2013 npopchg_2014 npopchg_2015 npopchg_2016 npopchg_2017 npopchg_2018 npopchg_2019 npopchg_2020

*************************************
** BLOCK #4. 					   **
** PRODUCE HISTORICAL DEATH COUNTS **
*************************************

// When Deaths in August are Missing (<10), Replace with Nearest Available Month or Average for 6 Months
forvalues num=13/18 {
replace deaths08_`num' = deaths07_`num' if deaths08_`num' == .
replace deaths08_`num' = deaths06_`num' if deaths08_`num' == .
replace deaths08_`num' = deaths05_`num' if deaths08_`num' == .
replace deaths08_`num' = deaths04_`num' if deaths08_`num' == .
replace deaths08_`num' = deaths03_`num' if deaths08_`num' == .
replace deaths08_`num' = deaths02_`num' if deaths08_`num' == .
replace deaths08_`num' = deaths_02_07_`num' / 6 if deaths08_`num' == .
}

// Count Historical Deaths from February 1 to August 26 Each Year
/* Not Including June 8 through June 17 Due to the Incompleteness of 2020 Data */
forvalues num=13/18 {
generate observed_all_20`num' = (deaths_02_07_`num' + (deaths08_`num'* 26/31)) / pop_20`num'
}
egen observed_all_2013_2018 = rmean(observed_all_2013 observed_all_2014 observed_all_2015 observed_all_2016 observed_all_2017 observed_all_2018)

*************************************
** BLOCK #5. 					   **
** ESTIMATING OBSERVED DEATH RATES **
*************************************

// Observed All-Cause Deaths, 2020
rename deathsfromallcauses all_obs_deaths
label var all_obs_deaths "Observed All-Cause Deaths, 2020"
generate all_obs_death_rate = (all_obs_deaths * 1000) / pop_2020
label var all_obs_death_rate "Observed All-Cause Death Rate per 1000 People, 2020"

// Observed All-Cause Historical Deaths, 2013-2018
generate all_hist_deaths = observed_all_2013_2018 * pop_2020
replace all_hist_deaths = round(all_hist_deaths)
label var all_hist_deaths "Historical All-Cause Deaths, 2013-2018"
generate all_hist_death_rate = (all_hist_deaths * 1000) / pop_2020
label var all_hist_death_rate "Historical All-Cause Death Rate per 1000 People, 2013-2018"

// Observed Direct Death Rate, 2020
rename deathsinvolvingcovid19 direct_deaths
label var direct_deaths "Direct Covid-19 Deaths, 2020"
generate direct_deaths_rate = (direct_deaths * 1000) / pop_2020
label var direct_deaths_rate "Direct Covid-19 Death Rate per 1000 People, 2020"

// Obeserved Excess Death Rate, 2020
generate excess_death_rate = all_obs_death_rate - all_hist_death_rate
label var excess_death_rate "Excess All-Cause Death Rate per 1000 People, 2020"
generate excess_deaths = (excess_death_rate / 1000) * pop_2020
label var excess_deaths "Excess All-Cause Deaths, 2020"

// Drop Variables
drop observed_all_2013_2018 deaths02_13 deaths03_13 deaths04_13 deaths05_13 deaths06_13 deaths02_14 deaths03_14 deaths04_14 deaths05_14 deaths06_14 deaths02_15 deaths03_15 deaths04_15 deaths05_15 deaths06_15 deaths02_16 deaths03_16 deaths04_16 deaths05_16 deaths06_16 deaths02_17 deaths03_17 deaths04_17 deaths05_17 deaths06_17 deaths02_18 deaths03_18 deaths04_18 deaths05_18 deaths06_18 pop_2013 pop_2014 pop_2015 pop_2016 pop_2017 pop_2018 observed_all_2013 observed_all_2014 observed_all_2015 observed_all_2016 observed_all_2017 observed_all_2018 deaths07_13 deaths08_13 deaths07_14 deaths08_14 deaths07_15 deaths08_15 deaths07_16 deaths08_16 deaths07_17 deaths08_17 deaths07_18 deaths08_18 deaths_02_07_13 deaths_02_07_14 deaths_02_07_15 deaths_02_07_16 deaths_02_07_17 deaths_02_07_18

// Order Variables
order fipscountycode state countyname pop_2020 all_obs_deaths all_hist_deaths excess_deaths direct_deaths all_obs_death_rate all_hist_death_rate direct_deaths_rate excess_death_rate

**************************
** BLOCK #6. 			**
** COUNTY-LEVEL FACTORS **
**************************

// Generate Population Density
gen pop_density = pop_2020 / land_size

// Generate Tests per State Population 2018
replace tests = tests / state_pop_2018
drop state_pop_2018

// Generate Upper/Lower Indicator for Demographic, Policy, Structural, and Health Variables
foreach lname in percent_65_over percent_black percent_white pop_density household_income income_inequality home_ownership tests stay_at_home_date first_date_25_cases {
summarize `lname' [weight = pop_2020], detail
generate wtmedian = r(p50)
generate `lname'_upper = 0
replace `lname'_upper = 1 if `lname' > wtmedian & `lname'  < .
drop wtmedian
}

// Save Clean Data
save clean_data_no_exclusions.dta, replace

****************
** BLOCK #7.  **
** EXCLUSIONS **
****************

// Rename NYC as NYC
replace state = "NYC" if (countyname == "Bronx County" | countyname == "Queens County" | countyname == "New York County" | countyname == "Richmond County" | countyname == "Kings County") & state == "NY"

// Drop if PA Outlier
drop if county == "Montour County"

// Drop Independent Cities in VA
drop if county == "Emporia city" | county == "Galax city" | county == "Hopewell city" | county == "Lynchburg city" | county == "Petersburg city" | county == "Richmond city" | county == "Roanoke city" | county == "Salem city" | county == "Winchester city" | county == "Alexandria city" | county == "Charlottesville city" | county == "Chesapeake city" | county == "Norfolk city" | county == "Portsmouth city" | county == "Suffolk city" | county == "Virginia Beach city" |  county == "Fredericksburg city" | county == "Spotsylvania County" | county == "Fredericksburg city" | county == "Hampton city"| county == "Newport News city" | county == "Harrisonburg city" | county == "Manassas city" | county == "Danville city" | county == "Martinsville city"

// Save Clean Data
save clean_data.dta, replace

*******************************************************************************************
** TABLES & FIGURES ***********************************************************************
*******************************************************************************************

**************
** FIGURE 1 **
**************

// Graph
use clean_data.dta, clear
graph twoway (scatter excess_death_rate direct_deaths_rate [aweight=pop_2020], mcolor(olive_teal%50) ytitle("All-Cause Death Rate, 2020 - Historical Rate", height(5) size(medium)) xtitle(,size(medium) height(5)) legend(off) graphregion(color(white)) bgcolor(white))(lfit excess_death_rate direct_deaths_rate [aweight=pop_2020], lcolor(navy))
graph export figure_1.png, width(1500) replace
graph export figure_1.eps, replace

// R Squared Value 
regress excess_death_rate direct_deaths_rate [aweight=pop_2020]

// Absolute Estimates for Excess Deaths
use clean_data.dta, clear
egen direct_deaths_sum = sum(direct_deaths)
list direct_deaths_sum in 1
regress all_obs_death_rate all_hist_death_rate direct_deaths_rate [aweight=pop_2020], vce(ols)
nlcom _b[direct_deaths_rate] * direct_deaths_sum
nlcom ((_b[direct_deaths_rate] - 1) / _b[direct_deaths_rate]) * (_b[direct_deaths_rate] * direct_deaths_sum)

**************
** FIGURE 2 **
**************

// Calculate Residuals
use clean_data.dta, clear
regress all_obs_death_rate all_hist_death_rate direct_deaths_rate [aweight = pop_2020]
predict observed_residuals, residuals
gen indicator = _n
gen mean = .

// Demographic Factors
local num = 3
foreach lname in pop_density {
mean observed_residuals if `lname'_upper == 0 [pweight=pop_2020]
mat results = r(table)
replace mean = results[1,1] if indicator == `num'
mean observed_residuals if `lname'_upper == 1 [pweight=pop_2020]
local num = `num' + 1
mat results = r(table)
replace mean = results[1,1] if indicator == `num'
local num = `num' + 2
}
local num = `num' + 2

// Structural Factors
foreach lname in percent_black percent_white household_income income_inequality home_ownership {
mean observed_residuals if `lname'_upper == 0 [pweight=pop_2020]
mat results = r(table)
replace mean = results[1,1] if indicator == `num'
mean observed_residuals if `lname'_upper == 1 [pweight=pop_2020]
local num = `num' + 1
mat results = r(table)
replace mean = results[1,1] if indicator == `num'
local num = `num' + 2
}
local num = `num' + 2

// Policy Factors
foreach lname in first_date_25_cases stay_at_home_date tests {
mean observed_residuals if `lname'_upper == 0 [pweight=pop_2020]
mat results = r(table)
replace mean = results[1,1] if indicator == `num'
mean observed_residuals if `lname'_upper == 1 [pweight=pop_2020]
local num = `num' + 1
mat results = r(table)
replace mean = results[1,1] if indicator == `num'
local num = `num' + 2
}
mean observed_residuals if governor_party == 0 [pweight=pop_2020]
mat results = r(table)
replace mean = results[1,1] if indicator == `num'
mean observed_residuals if governor_party == 1 [pweight=pop_2020]
local num = `num' + 1
mat results = r(table)
replace mean = results[1,1] if indicator == `num'

// Label Factors & Graph
keep indicator mean
drop if indicator > 35
gsort -indicator mean
drop indicator
generate indicator = _n
label define factors_label 35 "Demographic Factors" 34 " " 33 "Population Density (Lower Values)" 32 "Population Density (Upper Values)" 31 " " 30 "Structural Factors" 29 " "  28 "% Non-Hispanic Black (Lower Values)" 27 "% Non-Hispanic Black (Upper Values)" 26 " "  25 "% Non-Hispanic White (Lower Values)" 24 "% Non-Hispanic White (Upper Values)" 23 " " 22 "Median Household Income (Lower Values)" 21 "Median Household Income (Upper Values)" 20 " " 19 "Income Inequality (Lower Values)" 18 "Income Inequality (Upper Values)" 17 " " 16 "% Homeownership (Lower Values)" 15 "% Homeownership (Upper Values)" 14 " " 13 "Covid-19 Policy Factors" 12 " " 11 "Date on Which 25+ Cases Reached (Earlier)" 10 "Date on Which 25+ Cases Reached (Later)" 9 " " 8 "Date on Which Stay-at-Home Order Issued (Earlier" 7 "Date on Which Stay-at-Home Order Issued (Later)" 6 " " 5 "% of State Tested (Lower Values)" 4 "% of State Tested (Upper Values)" 3 " " 2 "States with Democratic Governors" 1 "States with Republican Governors"
label values indicator factors_label 
twoway dropline mean indicator, horizontal ylab(#52, value) ylab(,angle(0) labsize(2) labgap(0.5)) xsize(25) ysize(30) graphregion(margin(2 0 0 0)) ytitle("") graphregion(color(white)) xlab(, labsize(2.5)) xtitle("Residuals") xline(0, lcolor(black)) ylabel(, noticks) ylabel(,nogrid) note("Positive residuals indicate higher" "than predicted excess death rates," "and negative residuals indicate lower" "than predicted excess death rates.", position(6) size(2.5) margin(medsmall))
graph export figure_2.jpg, replace
graph export figure_2.eps, replace

**************
** FIGURE 3 **
**************

// Calculate Residuals
use clean_data.dta, clear
regress all_obs_death_rate all_hist_death_rate direct_deaths_rate [pweight = pop_2020]
predict observed_residuals, residuals
gen indicator = _n
foreach lname in pop_density percent_black percent_white household_income income_inequality home_ownership {
foreach num in 10 20 30 40 50 60 70 80 90 {
egen p`num' = pctile(`lname'), p(`num')
}
gen `lname'_10 = .
replace `lname'_10 = 10 if `lname' >= -20 & `lname' < p10
replace `lname'_10 = 9 if `lname' >= p10 & `lname' < p20
replace `lname'_10 = 8 if `lname' >= p20 & `lname' < p30
replace `lname'_10 = 7 if `lname' >= p30 & `lname' < p40
replace `lname'_10 = 6 if `lname' >= p40 & `lname' < p50
replace `lname'_10 = 5 if `lname' >= p50 & `lname' < p60
replace `lname'_10 = 4 if `lname' >= p60 & `lname' < p70
replace `lname'_10 = 3 if `lname' >= p70 & `lname' < p80
replace `lname'_10 = 2 if `lname' >= p80 & `lname' < p90
replace `lname'_10 = 1 if `lname' >= p90 & `lname' < .
drop p10 p20 p30 p40 p50 p60 p70 p80 p90 
gen mean_`lname' = .
forvalues num = 1/10 {
mean observed_residuals if `lname'_10 == `num' [pweight=pop_2020]
mat results = r(table)
replace mean_`lname' = results[1,1] if indicator == `num'
}
}

// Label Factors & Graph
drop if indicator > 10
keep indicator mean_percent_white mean_pop_density mean_percent_black mean_income_inequality mean_home_ownership mean_household_income
label define varlabel 1 "High" 2 "9" 3 "8" 4 "7" 5 "6" 6 "5" 7 "4" 8 "3" 9 "2" 10 "Low"
label values indicator varlabel
graph hbar mean_pop_density, over(indicator) ytitle("Residuals") ysize(6.5) xsize(5) graphregion(color(white)) ylabel(-0.5 0 0.5) title("Population Density", color(black)) 
graph save graph_1.gph, replace
graph hbar mean_percent_black, over(indicator) ytitle("Residuals") ysize(6.5) xsize(5) graphregion(color(white)) ylabel(-0.5 0 0.5) title("% Non-Hispanic Black", color(black)) 
graph save graph_2.gph, replace
graph hbar mean_percent_white, over(indicator) ytitle("Residuals") ysize(6.5) xsize(5) graphregion(color(white)) ylabel(-0.5 0 0.5) title("% Non-Hispanic White", color(black)) 
graph save graph_3.gph, replace
graph hbar mean_household_income, over(indicator) ytitle("Residuals") ysize(6.5) xsize(5) graphregion(color(white)) ylabel(-0.5 0 0.5) title("Median Household Income", color(black)) 
graph save graph_4.gph, replace
graph hbar mean_income_inequality, over(indicator) ytitle("Residuals") ysize(6.5) xsize(5) graphregion(color(white)) ylabel(-0.5 0 0.5) title("Income Inequality", color(black)) 
graph save graph_5.gph, replace
graph hbar mean_home_ownership, over(indicator) ytitle("Residuals") ysize(6.5) xsize(5) graphregion(color(white)) ylabel(-0.5 0 0.5) title("% Homeownership", color(black)) 
graph save graph_6.gph, replace
graph combine graph_1.gph graph_2.gph graph_3.gph graph_4.gph graph_5.gph graph_6.gph, ysize(14) xsize(16) rows(2) cols(3) imargin(med) iscale(0.5) graphregion(color(white)) note("Positive residuals indicate higher than predicted excess death rates," "and negative residuals indicate lower than predicted excess death rates.", position(6) margin(medsmall))
graph export figure_3.jpg, width(2000) replace
graph export figure_3.eps, replace

**************
** FIGURE 4 **
**************

// Calculate Residuals
use clean_data.dta, clear
keep state
gen counter = 1
bysort state: egen state_count = sum(counter)
drop if state_count < 5
drop counter state_count
duplicates drop
gsort -state
encode state, gen(state_num)
save states.dta, replace
merge 1:m state using clean_data.dta
keep if _merge == 3
regress all_obs_death_rate all_hist_death_rate direct_deaths_rate [pweight = pop_2020]
predict observed_residuals, residuals
gen indicator = _n
gen mean = .

// Label States & Graph
count
forvalues num = 1/39 {
mean observed_residuals if state_num == `num' [pweight=pop_2020]
mat results = r(table)
replace mean = results[1,1] if indicator == `num'
}
keep indicator mean
drop if indicator > 39
rename indicator state_num
merge 1:1 state_num using states.dta
drop _merge
gsort mean
gen long order = _n 
ssc install labutil
labmask order, values(state)
twoway dropline mean order, horizontal ylab(#39, value) ylab(,angle(0) labsize(4) labgap(1)) xsize(6) ysize(12) graphregion(margin(3 3 3 3)) ytitle("States", size(medlarge)) graphregion(color(white)) xlab(-1 -0.5 0 0.5 1, labsize(4)) xtitle("Residuals", size(medlarge)) xline(0, lcolor(black)) ylabel(, noticks) ylabel(,nogrid) note("Positive residuals indicate higher" "than predicted excess death rates," "and negative residuals indicate lower" "than predicted excess death rates.", position(6) size(medlarge) margin(medsmall))
graph export figure_4.jpg, width(2000) replace
graph export figure_4.eps, replace

*************
** TABLE S2 **
*************

use clean_data.dta, clear
summarize pop_density percent_black percent_white household_income income_inequality home_ownership tests governor_party [weight = pop_2020]
sum first_date_25_cases [weight = pop_2020], format detail 
sum stay_at_home_date [weight = pop_2020], format detail 

**************
** TABLE S3 **
**************

// All Counties, with Exclusions
use clean_data.dta, clear
regress all_obs_death_rate all_hist_death_rate direct_deaths_rate [aweight=pop_2020], vce(ols)
nlcom (_b[direct_deaths_rate] - 1) / _b[direct_deaths_rate]

// Excluded New York City
use clean_data.dta, clear
drop if state == "NYC"
regress all_obs_death_rate all_hist_death_rate direct_deaths_rate [aweight=pop_2020], vce(ols)
nlcom (_b[direct_deaths_rate] - 1) / _b[direct_deaths_rate]

// Excluded Counties with Lowest 25% of Covid-19 Deaths
use clean_data.dta, clear
summarize direct_deaths_rate, detail
drop if direct_deaths_rate < r(p25)
regress all_obs_death_rate all_hist_death_rate direct_deaths_rate [aweight=pop_2020], vce(ols)
nlcom (_b[direct_deaths_rate] - 1) / _b[direct_deaths_rate]

// All Counties, No Exclusions
use clean_data_no_exclusions.dta, clear
regress all_obs_death_rate all_hist_death_rate direct_deaths_rate [aweight=pop_2020], vce(ols)
nlcom (_b[direct_deaths_rate] - 1) / _b[direct_deaths_rate]

***************
** TABLE S4 **
***************

// Comparison of Excess Deaths Not Attributed to Covid-19

// Ordinary Least Squares Regression
use clean_data.dta, clear
regress all_obs_death_rate all_hist_death_rate direct_deaths_rate [aweight = pop_2020]
nlcom (_b[direct_deaths_rate] - 1) / _b[direct_deaths_rate]

// Weighted Least Squares Regression
use clean_data.dta, clear
wls0 all_obs_death_rate all_hist_death_rate direct_deaths_rate, wvar(pop_2020) type(abse)
nlcom (_b[direct_deaths_rate] - 1) / _b[direct_deaths_rate]

// Negative Binomial Regression
use clean_data.dta, clear
mean direct_deaths_rate [aweight = pop_2020]
replace pop_2020 = round(pop_2020)
glm all_obs_deaths all_hist_death_rate direct_deaths_rate [aweight=pop_2020], link(log) family(nbinomial) exposure(pop_2020) eform
margins, at(direct_deaths_rate = 0.49 direct_deaths_rate = 0.69) predict(nooffset) post
nlcom ((_b[2._at] - _b[1bn._at]) * 1000) / 0.2
nlcom (((_b[2._at] - _b[1bn._at]) * 1000) - 0.2) / ((_b[2._at] - _b[1bn._at]) * 1000)

***************
** FIGURE S2 **
***************

use clean_data.dta, clear
keep fipscountycode
tostring fipscountycode, replace format(%05.0f)
export excel sup_figure_1.xlsx, replace

*****************
** FIGURE S3a **
*****************

// Calculate Residuals
use clean_data.dta, clear
regwls all_obs_death_rate all_hist_death_rate direct_deaths_rate, wvar(pop_2020) type(abse)
gen indicator = _n
gen mean = .
rename _wls_res observed_residuals

// Demographic Factors
local num = 3
foreach lname in pop_density {
mean observed_residuals if `lname'_upper == 0 
mat results = r(table)
replace mean = results[1,1] if indicator == `num'
mean observed_residuals if `lname'_upper == 1
local num = `num' + 1
mat results = r(table)
replace mean = results[1,1] if indicator == `num'
local num = `num' + 2
}
local num = `num' + 2

// Structural Factors
foreach lname in percent_black percent_white household_income income_inequality home_ownership {
mean observed_residuals if `lname'_upper == 0 
mat results = r(table)
replace mean = results[1,1] if indicator == `num' 
mean observed_residuals if `lname'_upper == 1
local num = `num' + 1
mat results = r(table)
replace mean = results[1,1] if indicator == `num'
local num = `num' + 2
}
local num = `num' + 2

// Policy Factors
foreach lname in first_date_25_cases stay_at_home_date tests {
mean observed_residuals if `lname'_upper == 0 
mat results = r(table)
replace mean = results[1,1] if indicator == `num'
mean observed_residuals if `lname'_upper == 1 
local num = `num' + 1
mat results = r(table)
replace mean = results[1,1] if indicator == `num'
local num = `num' + 2
}
mean observed_residuals if governor_party == 0 
mat results = r(table)
replace mean = results[1,1] if indicator == `num'
mean observed_residuals if governor_party == 1 
local num = `num' + 1
mat results = r(table)
replace mean = results[1,1] if indicator == `num'

// Label Factors & Graph
keep indicator mean
drop if indicator > 35
gsort -indicator mean
drop indicator
generate indicator = _n
label define factors_label 35 "Demographic Factors" 34 " " 33 "Population Density (Lower Values)" 32 "Population Density (Upper Values)" 31 " " 30 "Structural Factors" 29 " "  28 "% Non-Hispanic Black (Lower Values)" 27 "% Non-Hispanic Black (Upper Values)" 26 " "  25 "% Non-Hispanic White (Lower Values)" 24 "% Non-Hispanic White (Upper Values)" 23 " " 22 "Median Household Income (Lower Values)" 21 "Median Household Income (Upper Values)" 20 " " 19 "Income Inequality (Lower Values)" 18 "Income Inequality (Upper Values)" 17 " " 16 "% Homeownership (Lower Values)" 15 "% Homeownership (Upper Values)" 14 " " 13 "Covid-19 Policy Factors" 12 " " 11 "Date on Which 25+ Cases Reached (Earlier)" 10 "Date on Which 25+ Cases Reached (Later)" 9 " " 8 "Date on Which Stay-at-Home Order Issued (Earlier" 7 "Date on Which Stay-at-Home Order Issued (Later)" 6 " " 5 "% of State Tested (Lower Values)" 4 "% of State Tested (Upper Values)" 3 " " 2 "States with Democratic Governors" 1 "States with Republican Governors"
label values indicator factors_label 
twoway dropline mean indicator, horizontal ylab(#52, value) ylab(,angle(0) labsize(2) labgap(0.5)) xsize(25) ysize(30) graphregion(margin(2 0 0 0)) ytitle("") graphregion(color(white)) xlab(, labsize(2.5)) xlab(-0.5(0.25)0.5) xtitle("Residuals") xline(0, lcolor(black)) ylabel(, noticks) ylabel(,nogrid) note("Positive residuals indicate higher" "than predicted excess death rates," "and negative residuals indicate lower" "than predicted excess death rates.", position(6) size(2.5) margin(medsmall))
graph export sup_figure_3a.jpg, replace

****************
** FIGURE S3b **
****************

// Calculate Residuals
use clean_data.dta, clear
replace pop_2020 = round(pop_2020)
replace pop_2020 = pop_2020 / 1000
glm all_obs_deaths all_hist_death_rate direct_deaths_rate [pweight = pop_2020], link(log) family(nbinomial) exposure(pop_2020) eform
predict observed_residuals, pearson
gen indicator = _n
gen mean = .

// Demographic Factors
local num = 3
foreach lname in pop_density {
mean observed_residuals if `lname'_upper == 0 [aweight = pop_2020]
mat results = r(table)
replace mean = results[1,1] if indicator == `num'
mean observed_residuals if `lname'_upper == 1 [aweight = pop_2020]
local num = `num' + 1
mat results = r(table)
replace mean = results[1,1] if indicator == `num'
local num = `num' + 2
}
local num = `num' + 2

// Structural Factors
foreach lname in percent_black percent_white household_income income_inequality home_ownership {
mean observed_residuals if `lname'_upper == 0 [aweight = pop_2020]
mat results = r(table)
replace mean = results[1,1] if indicator == `num'
mean observed_residuals if `lname'_upper == 1 [aweight = pop_2020]
local num = `num' + 1
mat results = r(table)
replace mean = results[1,1] if indicator == `num'
local num = `num' + 2
}
local num = `num' + 2

// Policy Factors
foreach lname in first_date_25_cases stay_at_home_date tests {
mean observed_residuals if `lname'_upper == 0 [aweight = pop_2020]
mat results = r(table)
replace mean = results[1,1] if indicator == `num'
mean observed_residuals if `lname'_upper == 1 [aweight = pop_2020]
local num = `num' + 1
mat results = r(table)
replace mean = results[1,1] if indicator == `num'
local num = `num' + 2
}
mean observed_residuals if governor_party == 0 [aweight = pop_2020]
mat results = r(table)
replace mean = results[1,1] if indicator == `num'
mean observed_residuals if governor_party == 1 [aweight = pop_2020]
local num = `num' + 1
mat results = r(table)
replace mean = results[1,1] if indicator == `num'

// Label Factors & Graph
keep indicator mean
drop if indicator > 35
gsort -indicator mean
drop indicator
generate indicator = _n
label define factors_label 35 "Demographic Factors" 34 " " 33 "Population Density (Lower Values)" 32 "Population Density (Upper Values)" 31 " " 30 "Structural Factors" 29 " "  28 "% Non-Hispanic Black (Lower Values)" 27 "% Non-Hispanic Black (Upper Values)" 26 " "  25 "% Non-Hispanic White (Lower Values)" 24 "% Non-Hispanic White (Upper Values)" 23 " " 22 "Median Household Income (Lower Values)" 21 "Median Household Income (Upper Values)" 20 " " 19 "Income Inequality (Lower Values)" 18 "Income Inequality (Upper Values)" 17 " " 16 "% Homeownership (Lower Values)" 15 "% Homeownership (Upper Values)" 14 " " 13 "Covid-19 Policy Factors" 12 " " 11 "Date on Which 25+ Cases Reached (Earlier)" 10 "Date on Which 25+ Cases Reached (Later)" 9 " " 8 "Date on Which Stay-at-Home Order Issued (Earlier" 7 "Date on Which Stay-at-Home Order Issued (Later)" 6 " " 5 "% of State Tested (Lower Values)" 4 "% of State Tested (Upper Values)" 3 " " 2 "States with Democratic Governors" 1 "States with Republican Governors"
label values indicator factors_label 
twoway dropline mean indicator, horizontal ylab(#52, value) ylab(,angle(0) labsize(2) labgap(0.5)) xsize(25) ysize(30) graphregion(margin(2 0 0 0)) ytitle("") graphregion(color(white)) xlab(, labsize(2.5)) xtitle("Residuals") xline(0, lcolor(black)) ylabel(, noticks) ylabel(,nogrid) note("Positive residuals indicate higher" "than predicted excess death rates," "and negative residuals indicate lower" "than predicted excess death rates.", position(6) size(2.5) margin(medsmall))
graph export sup_figure_3b.jpg, replace

// End
