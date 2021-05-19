********************************************************************************************************
** Covid-19 and Excess Mortality in the United States: An Analysis of Counties
** Last Updated: April 21, 2021				        
********************************************************************************************************

///////////////////////////////////////////////////////////////////
// PART 1: PRIMARY ANALYSIS 								 	 //
// CALCULATE RELATIONSHIP BETWEEN DIRECT AND ALL-CAUSE MORTALITY //
///////////////////////////////////////////////////////////////////

*******************
**** BLOCK #1A ****
**** LOAD DATA ****
*******************

// Set Directory Containing Raw Data
cd ""

// 1. NCHS Provisional Data on All-Cause & COVID-19 Mortality by County, 2020
/* Data covers 2020, reported by March 12, 2021 */
/* Source: https://data.cdc.gov/NCHS/AH-County-level-Provisional-COVID-19-Deaths-Counts/6vqh-esgs */
import delimited "1_cdc_2020_3.12.21.csv", clear
keep state county fipscode covid19deaths totaldeaths
rename county countyname
rename fipscode fipscountycode
save data_1.dta, replace

// 2. CDC Wonder Data on All-Cause Mortality by County, 2013-2018
/* Source: https://wonder.cdc.gov/ (Underlying Cause Data) */
/* Note: Select All-Cause Mortality, Produce File Containing Deaths from 2013-2018 by County */ 
import delimited "2_wonder_2013_2018.txt", clear 
keep countycode deaths
rename countycode fipscountycode
drop if fipscountycode == .
rename deaths deaths_13_18
save data_2.dta, replace

// 3. U.S. Census Bureau Data on Population by County, 2013-2018
/* Source: https://www.census.gov/data/datasets/time-series/demo/popest/2010s-counties-total.html?# */
/* Link to Download: https://www2.census.gov/programs-surveys/popest/datasets/2010-2019/counties/totals/ */
import delimited "3_census_counties_2011_2019.csv", clear
gen state_string = string(state, "%02.0f")
gen county_string = string(county, "%03.0f")
gen fipscountycode = state_string + county_string
drop state county_string state_string
destring fipscountycode, replace
keep fipscountycode popestimate2013 popestimate2014 popestimate2015 popestimate2016 popestimate2017 popestimate2018
save data_3.dta, replace

// 4. U.S. Census Bureau Data on Population by County, 2020
/* Source: File obtained by special request to U.S. Census Bureau */
**** import delimited "4_pop_2020.csv", clear
**** gen state_string = string(state, "%02.0f")
**** gen county_string = string(county, "%03.0f")
**** gen fipscountycode = state_string + county_string
**** drop state_string county_string state county
**** destring fipscountycode, replace
**** bysort fipscountycode: egen pop2020 = sum(pop_count_2020)
**** bysort fipscountycode: egen pop_2020 = max(pop2020)
**** keep fipscountycode pop_2020
**** duplicates drop
**** export delimited 4_census_counties_2020.csv, replace
import delimited 4_census_counties_2020.csv, clear
save data_4.dta, replace

// 5. 2020 RWJ Foundation County Health Rankings
/* Source: https://www.countyhealthrankings.org/explore-health-rankings/rankings-data-documentation */
import delimited "5_RWJF_county_health_rankings.csv", clear
rename fipscode fipscountycode 
rename v053_rawvalue percent_65_over
rename v058_rawvalue percent_rural
rename v054_rawvalue percent_black
rename v126_rawvalue percent_white
rename v056_rawvalue percent_hispanic
rename v063_rawvalue household_income
rename v069_rawvalue some_college
rename v153_rawvalue home_ownership
rename v002_rawvalue poor_or_fair_health
rename v011_rawvalue obesity
rename v009_rawvalue smoking
rename v060_rawvalue diabetes
keep fipscountycode state percent_65_over percent_rural percent_black percent_white percent_hispanic household_income some_college home_ownership poor_or_fair_health obesity smoking diabetes
save data_5.dta, replace

// 6. U.S. Census Regions
/* Source: https://raw.githubusercontent.com/cphalpert/census-regions/master/us%20census%20bureau%20regions%20and%20divisions.csv */
import delimited "https://raw.githubusercontent.com/cphalpert/census-regions/master/us%20census%20bureau%20regions%20and%20divisions.csv", clear varnames(1)
drop state division
rename statecode state
save data_6.dta, replace

********************
**** BLOCK #1B  ****
**** MERGE DATA ****
********************

// Merge Datasets 1-4
use data_1.dta, clear
merge 1:1 fipscountycode using data_2.dta
keep if _merge == 3
drop _merge
foreach num in 3 4 5 {
merge 1:1 fipscountycode using data_`num'.dta
keep if _merge == 3
drop _merge
}
merge m:1 state using data_6.dta
keep if _merge == 3
drop _merge

// Compute Population for 2013-2018
egen pop_13_18 = rowtotal(popestimate2013 popestimate2014 popestimate2015 popestimate2016 popestimate2017 popestimate2018)
drop popestimate2013 popestimate2014 popestimate2015 popestimate2016 popestimate2017 popestimate2018 

******************************
**** BLOCK #1D  		  ****
**** GENERATE DEATH RATES ****
******************************

// All-Cause Death Rate, 2020
gen all_2020_death_rate = 1000 * totaldeaths / pop_2020
label var all_2020_death_rate "All-Cause Death Rate per 1000 Person-Years, 2020"

// All-Cause Death Rate, 2013-2018
gen all_hist_death_rate = 1000 * deaths_13_18 / pop_13_18
label var all_hist_death_rate "All-Cause Death Rate per 1000 Person-Years, 2013-2018"

// Direct Covid-19 Death Rate, 2020
gen covid_2020_death_rate = 1000 * covid19deaths / pop_2020
label var covid_2020_death_rate "Direct Covid-19 Death Rate per 1000 Person-Years, 2020"

// All-Cause Death Rate, 2020 – All-Cause Death Rate, 2013-2018
gen excess_2020_death_rate = all_2020_death_rate - all_hist_death_rate
label var excess_2020_death_rate "Difference in Death Rates per 1000 Person-Years, 2020 vs. 2013-2018"
save data_all.dta, replace

****************************
**** BLOCK #1D  		****
**** EXCLUSION CRITERIA ****
****************************

// Exclusion Criteria
use data_all.dta, clear
/* Drop if 20 or Fewer Covid-19 Deaths */
drop if covid19deaths < 10 | covid19deaths == .
drop if covid19deaths < 20 
count
save data_clean.dta, replace

*******************
**** BLOCK #1E ****
**** FIGURE 1  ****
*******************

// Plot Relationship Between Covid-19 and Excess Death Rates by Region
use data_clean.dta, clear
drop if covid_2020_death_rate > 6
drop if excess_2020_death_rate > 10
ssc install sepscatter
sepscatter excess_2020_death_rate covid_2020_death_rate [weight=pop_2020], separate(region) msymbol(0) mlwidth(0 0 0 0) color(%25 %25 %25 %25)  graphregion(color(white)) plotregion(fcolor(gray%20)) ylabel(,grid glcolor(white) angle(0)) xlabel(, grid glcolor(white)) addplot(lfit excess_2020_death_rate covid_2020_death_rate [weight=pop_2020], color(blue) || function y=x, color(black) range(0.08 5.5) lpattern(dash) legend(position(3) col(1) order(1 "Midwest" 2 "Northeast" 3 "South" 4 "West") title("Census Region", size(medsmall) color(black))) ytitle("All-Cause Death Rate, 2020 - Rate, 2013-2018") xtitle("Direct COVID-19 Death Rate per 1,000 Person-Years")) xsize(6.2) ysize(4) xlabel(0 1 2 3 4 5) ylabel(-4 -2 0 2 4 6 8)
graph export figure_1.jpg, replace 
graph export figure_1.tif, replace 

*******************
**** BLOCK #1F ****
**** TABLE 2   ****
*******************

// Estimate Beta2 Coefficient 
/* Note: the coefficient for covid_2020_death_rate is the coefficient of interest */
/* Included Counties */
use data_clean.dta, clear
regress all_2020_death_rate all_hist_death_rate covid_2020_death_rate [weight=pop_2020] 
nlcom (_b[covid_2020_death_rate] - 1) / _b[covid_2020_death_rate]
/* All Counties, No Exclusions*/
use data_all.dta, clear
drop if covid19deaths == 0 | covid19deaths == .
regress all_2020_death_rate all_hist_death_rate covid_2020_death_rate [weight=pop_2020] 
nlcom (_b[covid_2020_death_rate] - 1) / _b[covid_2020_death_rate]
/* Counties with 50+ Covid-19 Deaths */
use data_clean.dta, clear
drop if covid19deaths < 50
regress all_2020_death_rate all_hist_death_rate covid_2020_death_rate [weight=pop_2020]
nlcom (_b[covid_2020_death_rate] - 1) / _b[covid_2020_death_rate]
/* Counties with 50,000 or More Residents */
use data_clean.dta, clear
drop if pop_2020 < 50000
regress all_2020_death_rate all_hist_death_rate covid_2020_death_rate [weight=pop_2020]
nlcom (_b[covid_2020_death_rate] - 1) / _b[covid_2020_death_rate]

//////////////////////////////////////////////////////////////////////////////////
// PART 2: SECONDARY ANALYSIS 								 	 				//
// EXAMINE DIFFERENCES IN THE RELATIONSHIP BY SOCIODEMOGRAPHIC & HEALTH FACTORS //
//////////////////////////////////////////////////////////////////////////////////

********************
**** BLOCK #2A  ****
**** TABLE 1    ****
********************

// Counties in the Sample
use data_clean.dta, clear
foreach lname in percent_65_over percent_rural percent_white percent_hispanic percent_black household_income some_college home_ownership poor_or_fair_health obesity smoking diabetes  {
summarize `lname' [weight = pop_2020]
}

// Counties in the US
use data_4.dta, clear
merge 1:1 fipscountycode using data_5.dta
keep if _merge == 3
foreach lname in percent_65_over percent_rural percent_white percent_hispanic percent_black household_income some_college home_ownership poor_or_fair_health obesity smoking diabetes  {
summarize `lname' [weight = pop_2020]
}

********************
**** BLOCK #2C  ****
**** FIGURE 2   ****
********************

// Divide Sociodemographic and Health Factors into Population Weighted Quartiles
use data_clean.dta, clear
foreach lname in percent_65_over percent_rural percent_white percent_hispanic percent_black household_income some_college home_ownership poor_or_fair_health obesity smoking diabetes {
xtile `lname'_up = `lname' [weight=pop_2020], nq(4)
}

// Estimate Beta2 Coefficient for the Lower 25% and Upper 25% of Values for Each Variable
/* Note: the coefficient for covid_2020_death_rate is the coefficient of interest */
foreach lname in percent_65_over percent_rural percent_black percent_white percent_hispanic household_income some_college home_ownership poor_or_fair_health obesity smoking diabetes {
reg all_2020_death_rate all_hist_death_rate covid_2020_death_rate [weight = pop_2020] if `lname'_up == 1
reg all_2020_death_rate all_hist_death_rate covid_2020_death_rate [weight = pop_2020] if `lname'_up == 4
}
reg all_2020_death_rate all_hist_death_rate covid_2020_death_rate [weight = pop_2020] if region == "Midwest"
reg all_2020_death_rate all_hist_death_rate covid_2020_death_rate [weight = pop_2020] if region == "Northeast"
reg all_2020_death_rate all_hist_death_rate covid_2020_death_rate [weight = pop_2020] if region == "South"
reg all_2020_death_rate all_hist_death_rate covid_2020_death_rate [weight = pop_2020] if region == "West"

********************
**** BLOCK #2D  ****
**** FIGURE 3   ****
********************

// Calculate Directly Assigned Covid-19 Mortality for the Lower 25% and Upper 25% of Values for Each Variable
// Note: the mean is the directly assigned Covid-19 death rate for the stratum
foreach lname in percent_65_over percent_rural percent_black percent_white percent_hispanic household_income some_college home_ownership poor_or_fair_health obesity smoking diabetes {
mean covid_2020_death_rate [weight = pop_2020] if `lname'_up == 1
mean covid_2020_death_rate [weight = pop_2020] if `lname'_up == 4
}
mean covid_2020_death_rate [weight = pop_2020] if region == "Midwest"
mean covid_2020_death_rate [weight = pop_2020] if region == "Northeast"
mean covid_2020_death_rate [weight = pop_2020] if region == "South"
mean covid_2020_death_rate [weight = pop_2020] if region == "West"

// Calculate Excess Deaths Not Assigned to Covid-19 for the Lower 25% and Upper 25% of Values for Each Variable
// Note: the value labeled output is the excess death rate not assigned to Covid-19 for the stratum
foreach lname in percent_65_over percent_rural percent_black percent_white percent_hispanic household_income some_college home_ownership poor_or_fair_health obesity smoking diabetes {
regress all_2020_death_rate all_hist_death_rate covid_2020_death_rate [weight=pop_2020] if `lname'_up == 1
mat results = r(table)
summarize covid_2020_death_rate [weight = pop_2020] if `lname'_up == 1
gen output = (results[1,2] - 1) * r(mean)
mean output
drop output
regress all_2020_death_rate all_hist_death_rate covid_2020_death_rate [weight=pop_2020] if `lname'_up == 4
mat results = r(table)
summarize covid_2020_death_rate [weight = pop_2020] if `lname'_up == 4
gen output = (results[1,2] - 1) * r(mean)
mean output
drop output
}
foreach lname in Midwest Northeast South West {
regress all_2020_death_rate all_hist_death_rate covid_2020_death_rate [weight=pop_2020] if region == "`lname'"
mat results = r(table)
summarize covid_2020_death_rate [weight = pop_2020] if region == "`lname'"
gen output = (results[1,2] - 1) * r(mean)
mean output
drop output	
}

//////////////////////////////////////////////////////////////////////
// PART 3: SUPPLEMENTAL ANALYSIS 								    //
// ASSESSING THE EFFECT OF INDIRECT AGE STANDARDIZATION ON RESULTS  //
//////////////////////////////////////////////////////////////////////

********************
**** BLOCK #3A. ****
**** LOAD DATA  ****
********************

// 8. 2020 CDC Provisional Data on All-Cause & COVID-19 Mortality by Age
/* Source: https://data.cdc.gov/NCHS/Provisional-COVID-19-Death-Counts-by-Sex-Age-and-W/vsak-wrfu*/
import delimited "8_cdc_age_week.3.3.21.csv", clear
keep if sex == "All Sex" & state == "United States"
drop if mmwrweek > 52
generate age = ""
replace age = "0_24" if agegroup == "Under 1 year" | agegroup == "1-4 Years" | agegroup == "5-14 Years" | agegroup == "15-24 Years"
replace age = "25_34" if agegroup == "25-34 Years"
replace age = "35_44" if agegroup == "35-44 Years"
replace age = "45_54" if agegroup == "45-54 Years"
replace age = "55_64" if agegroup == "55-64 Years"
replace age = "65_74" if agegroup == "65-74 Years"
replace age = "75_84" if agegroup == "75-84 Years"
replace age = "85plus" if agegroup == "85 Years and Over"
drop agegroup
bysort age: egen deaths_2020_age = sum(totaldeaths)
bysort age: egen deaths_2020_covid_age = sum(covid19deaths)
keep age deaths_2020_age deaths_2020_covid_age
duplicates drop
drop if age == ""
generate code = 1
reshape wide deaths_2020_age deaths_2020_covid_age, i(code) j(age) string
save data_8.dta, replace

// 9. 2013-2018 CDC Wonder Estimates on All-Cause Mortality by Age
/* Source: https://wonder.cdc.gov/ - All-Cause Mortality, for each year, stratified by 10-year age group */
import delimited "9_wonder_age_13_18.txt", clear
generate age = ""
replace age = "0_24" if tenyearagegroupscode == "1" | tenyearagegroupscode == "1-4" | tenyearagegroupscode == "5-14" | tenyearagegroupscode == "15-24"
replace age = "25_34" if tenyearagegroupscode == "25-34"
replace age = "35_44" if tenyearagegroupscode == "35-44"
replace age = "45_54" if tenyearagegroupscode == "45-54"
replace age = "55_64" if tenyearagegroupscode == "55-64"
replace age = "65_74" if tenyearagegroupscode == "65-74"
replace age = "75_84" if tenyearagegroupscode == "75-84"
replace age = "85plus" if tenyearagegroupscode == "85+"
drop if age == ""
keep year age deaths
bysort year age: egen deaths_ = sum(deaths)
drop deaths
drop if year == .
duplicates drop
reshape wide deaths_, i(age) j(year)
egen deaths_1318_ = rowtotal(deaths_2013 deaths_2014 deaths_2015 deaths_2016 deaths_2017 deaths_2018)
keep age deaths_1318_
gen code = 1
reshape wide deaths_1318_, i(code) j(age) string
save data_9.dta, replace

// 10. 2013-2018 U.S. Census Estimates of Population by County, Stratified by Age
/* Source: https://www.census.gov/data/tables/time-series/demo/popest/2010s-counties-detail.html */
import delimited "10_census_counties_ages_2010_2018.csv", clear
keep if year == 6 | year == 7 | year == 8 | year == 9 | year == 10 | year == 11
replace year = 2013 if year == 6
replace year = 2014 if year == 7
replace year = 2015 if year == 8
replace year = 2016 if year == 9
replace year = 2017 if year == 10
replace year = 2018 if year == 11
generate age = ""
replace age = "total" if agegrp == 0
replace age = "0_24" if agegrp == 1 | agegrp == 2 | agegrp == 3 | agegrp == 4 | agegrp == 5
replace age = "25_34" if agegrp == 6 | agegrp == 7
replace age = "35_44" if agegrp == 8 | agegrp == 9
replace age = "45_54" if agegrp == 10 | agegrp == 11
replace age = "55_64" if agegrp == 12 | agegrp == 13
replace age = "65_74" if agegrp == 14 | agegrp == 15
replace age = "75_84" if agegrp == 16 | agegrp == 17
replace age = "85plus" if agegrp == 18
bysort state county age: egen pop = sum(tot_pop)
bysort state county year age: egen pop_18_ = sum(tot_pop)
gen state_string = string(state, "%02.0f")
gen county_string = string(county, "%03.0f")
gen fipscountycode = state_string + county_string
keep fipscountycode age year pop pop_18_
keep if year == 2018
drop year
rename pop pop_1318_
duplicates drop
reshape wide pop_1318_ pop_18_, i(fipscountycode) j(age) string
destring fipscountycode, replace
save data_10.dta, replace

// 11. 2013-2018 Annual Estimates of U.S. Population by Age
/* Source: https://www.census.gov/content/census/en/data/datasets/time-series/demo/popest/2010s-national-detail.html */
import delimited "11_census_us_age_2010_2019.csv", clear
keep if sex == 0
keep age popestimate2013 popestimate2014 popestimate2015 popestimate2016 popestimate2017 popestimate2018
foreach lname in popestimate2013 popestimate2014 popestimate2015 popestimate2016 popestimate2017 popestimate2018 {
egen `lname'_0_24 = sum(`lname') if age >= 0 & age <= 24
egen `lname'_25_34 = sum(`lname') if age >= 25 & age <= 34
egen `lname'_35_44 = sum(`lname') if age >= 35 & age <= 44
egen `lname'_45_54 = sum(`lname') if age >= 45 & age <= 54
egen `lname'_55_64 = sum(`lname') if age >= 55 & age <= 64
egen `lname'_65_74 = sum(`lname') if age >= 65 & age <= 74
egen `lname'_75_84 = sum(`lname') if age >= 75 & age <= 84
egen `lname'_85plus = sum(`lname') if age >= 85 & age <= 100
replace `lname' = `lname'_0_24 if `lname'_0_24 != .
replace `lname' = `lname'_25_34 if `lname'_25_34 != .
replace `lname' = `lname'_35_44 if `lname'_35_44 != .
replace `lname' = `lname'_45_54 if `lname'_45_54 != .
replace `lname' = `lname'_55_64 if `lname'_55_64 != .
replace `lname' = `lname'_65_74 if `lname'_65_74 != .
replace `lname' = `lname'_75_84 if `lname'_75_84 != .
replace `lname' = `lname'_85plus if `lname'_85plus != .
drop `lname'_0_24 `lname'_25_34 `lname'_35_44 `lname'_45_54 `lname'_55_64 `lname'_65_74 `lname'_75_84 `lname'_85plus
}
generate agegroup = ""
replace agegroup = "0_24" if age >= 0 & age <= 24
replace agegroup = "25_34" if age >= 25 & age <= 34
replace agegroup = "35_44" if age >= 35 & age <= 44
replace agegroup = "45_54" if age >= 45 & age <= 54
replace agegroup = "55_64" if age >= 55 & age <= 64
replace agegroup = "65_74" if age >= 65 & age <= 74
replace agegroup = "75_84" if age >= 75 & age <= 84
replace agegroup = "85plus" if age >= 85 & age <= 100
drop age
rename agegroup age
keep age popestimate2013 popestimate2014 popestimate2015 popestimate2016 popestimate2017 popestimate2018
duplicates drop
drop if age == ""
egen us_pop_1318_ = rowtotal(popestimate2013 popestimate2014 popestimate2015 popestimate2016 popestimate2017 popestimate2018)
keep age us_pop_1318_ popestimate2018
rename popestimate2018 us_pop_18
generate code = 1
reshape wide us_pop_1318_ us_pop_18, i(code) j(age) string
save data_11.dta, replace

********************
**** BLOCK #3B. ****
**** MERGE DATA ****
********************

use data_all.dta, clear
gen code = 1
merge 1:1 fipscountycode using data_10.dta
keep if _merge == 3
drop _merge
foreach num in 8 9 11 {
merge m:1 code using data_`num'.dta
drop _merge
}

************************************
**** BLOCK #3D.           		  **
**** INDIRECT AGE STANDARDIZATION **
************************************

// CMR for 2020 All-Cause Mortality
gen cmr_2020 = totaldeaths / ((pop_18_0_24 * deaths_2020_age0_24 / us_pop_180_24) + (pop_18_25_34 * deaths_2020_age25_34 / us_pop_1825_34) + (pop_18_35_44 * deaths_2020_age35_44 / us_pop_1835_44) + (pop_18_45_54 * deaths_2020_age45_54 / us_pop_1845_54) + (pop_18_55_64 * deaths_2020_age55_64 / us_pop_1855_64) + (pop_18_65_74 * deaths_2020_age65_74 / us_pop_1865_74) + (pop_18_75_84 * deaths_2020_age75_84 / us_pop_1875_84) + (pop_18_85plus * deaths_2020_age85plus / us_pop_1885plus)) 
gen inage_2020_death_rate = 1000 * cmr_2020 * ((deaths_2020_age0_24 + deaths_2020_age25_34 + deaths_2020_age35_44 + deaths_2020_age45_54 + deaths_2020_age55_64 + deaths_2020_age65_74 + deaths_2020_age75_84 + deaths_2020_age85plus) / ((us_pop_180_24 + us_pop_1825_34 + us_pop_1835_44 + us_pop_1845_54 + us_pop_1855_64 + us_pop_1865_74 + us_pop_1875_84 + us_pop_1885plus) * 301 / 365.25))

// CMR for 2020 Covid Mortality
gen cmr_covid = covid19deaths / ((pop_18_0_24 * deaths_2020_covid_age0_24 / us_pop_180_24) + (pop_18_25_34 * deaths_2020_covid_age25_34 / us_pop_1825_34) + (pop_18_35_44 * deaths_2020_covid_age35_44 / us_pop_1835_44) + (pop_18_45_54 * deaths_2020_covid_age45_54 / us_pop_1845_54) + (pop_18_55_64 * deaths_2020_covid_age55_64 / us_pop_1855_64) + (pop_18_65_74 * deaths_2020_covid_age65_74 / us_pop_1865_74) + (pop_18_75_84 * deaths_2020_covid_age75_84 / us_pop_1875_84) + (pop_18_85plus * deaths_2020_covid_age85plus / us_pop_1885plus))
gen inage_covid_death_rate = 1000 * cmr_covid * ((deaths_2020_covid_age0_24 + deaths_2020_covid_age25_34 + deaths_2020_covid_age35_44 + deaths_2020_covid_age45_54 + deaths_2020_covid_age55_64 + deaths_2020_covid_age65_74 + deaths_2020_covid_age75_84 + deaths_2020_covid_age85plus) / ((us_pop_180_24 + us_pop_1825_34 + us_pop_1835_44 + us_pop_1845_54 + us_pop_1855_64 + us_pop_1865_74 + us_pop_1875_84 + us_pop_1885plus) * 301 / 365.25))

// CMR for 2013-2018 All-Cause Mortality
gen cmr_hist = deaths_13_18 / ((pop_1318_0_24 * deaths_1318_0_24 / us_pop_1318_0_24) + (pop_1318_25_34 * deaths_1318_25_34 / us_pop_1318_25_34) + (pop_1318_35_44 * deaths_1318_35_44 / us_pop_1318_35_44) + (pop_1318_45_54 * deaths_1318_45_54 / us_pop_1318_45_54) + (pop_1318_55_64 * deaths_1318_55_64 / us_pop_1318_55_64) + (pop_1318_65_74 * deaths_1318_65_74 / us_pop_1318_65_74) + (pop_1318_75_84 * deaths_1318_75_84 / us_pop_1318_75_84) + (pop_1318_85plus * deaths_1318_85plus / us_pop_1318_85plus)) 
gen inage_hist_death_rate = 1000 * cmr_hist * ((deaths_1318_0_24 + deaths_1318_25_34 + deaths_1318_35_44 + deaths_1318_45_54 + deaths_1318_55_64 + deaths_1318_65_74 + deaths_1318_75_84 + deaths_1318_85plus) / ((us_pop_1318_0_24 + us_pop_1318_25_34 + us_pop_1318_35_44 + us_pop_1318_45_54 + us_pop_1318_55_64 + us_pop_1318_65_74 + us_pop_1318_75_84 + us_pop_1318_85plus)  * 301 / 365.25))

// Exclusion Criteria
drop if covid19deaths < 20 | covid19deaths == .
save data_iage.dta, replace

******************************
**** BLOCK #3E.           ****
**** SUPPLEMENTAL TABLE 2 ****
******************************

// Supplemental Table 2
/* Ordinary Least Squares Regression, Not Age-Standardized */
use data_clean.dta, clear
regress all_2020_death_rate all_hist_death_rate covid_2020_death_rate [weight=pop_2020] 
nlcom (_b[covid_2020_death_rate] - 1) / _b[covid_2020_death_rate]

/* Ordinary Least Squares Regression, Age-Standardized */
use data_iage.dta, clear
drop if covid19deaths < 20 | covid19deaths == .
regress inage_2020_death_rate inage_hist_death_rate inage_covid_death_rate [weight=pop_2020] 
nlcom (_b[inage_covid_death_rate] - 1) / _b[inage_covid_death_rate]

/*  Negative Binomial Regression, Not Age-Standardized */
use data_clean.dta, clear
mean covid_2020_death_rate [weight = pop_2020]
replace pop_2020 = round(pop_2020)
glm totaldeaths all_hist_death_rate covid_2020_death_rate [weight=pop_2020], link(log) family(nbinomial) exposure(pop_2020) eform
margins, at(covid_2020_death_rate = 1.05 covid_2020_death_rate = 1.25) predict(nooffset) post
nlcom ((_b[2._at] - _b[1bn._at]) * 1000) / 0.2
nlcom (((_b[2._at] - _b[1bn._at]) * 1000) - 0.2) / ((_b[2._at] - _b[1bn._at]) * 1000)

*********************************
**** BLOCK #3F.  			 ****
**** SUPPLEMENTAL FIGURE 3   ****
*********************************

// Divide Sociodemographic and Health Factors into Population Weighted Quartiles
use data_iage.dta, clear
foreach lname in percent_65_over percent_rural percent_white percent_hispanic percent_black household_income some_college home_ownership poor_or_fair_health obesity smoking diabetes  {
xtile `lname'_up = `lname' [weight=pop_2020], nq(4)
}

// Estimate Beta2 Coefficient for the Lower 25% and Upper 25% of Values for Each Variable
/* Note: the coefficient for covid_2020_death_rate is the coefficient of interest */
foreach lname in percent_65_over percent_rural percent_black percent_white percent_hispanic household_income some_college home_ownership poor_or_fair_health obesity smoking diabetes {
reg inage_2020_death_rate inage_hist_death_rate inage_covid_death_rate [weight = pop_2020] if `lname'_up == 1
reg inage_2020_death_rate inage_hist_death_rate inage_covid_death_rate [weight = pop_2020] if `lname'_up == 4
}
reg inage_2020_death_rate inage_hist_death_rate inage_covid_death_rate [weight = pop_2020] if region == "Midwest"
reg inage_2020_death_rate inage_hist_death_rate inage_covid_death_rate [weight = pop_2020] if region == "Northeast"
reg inage_2020_death_rate inage_hist_death_rate inage_covid_death_rate [weight = pop_2020] if region == "South"
reg inage_2020_death_rate inage_hist_death_rate inage_covid_death_rate [weight = pop_2020] if region == "West"

*********************************
**** BLOCK #3G.  			 ****
**** SUPPLEMENTAL FIGURE 4   ****
*********************************

// Calculate Directly Assigned Covid-19 Mortality for the Lower 25% and Upper 25% of Values for Each Variable
// Note: the mean is the directly assigned Covid-19 death rate for the stratum
foreach lname in percent_65_over percent_rural percent_black percent_white percent_hispanic household_income some_college home_ownership poor_or_fair_health obesity smoking diabetes {
mean inage_covid_death_rate [weight = pop_2020] if `lname'_up == 1
mean inage_covid_death_rate [weight = pop_2020] if `lname'_up == 4
}
mean inage_covid_death_rate [weight = pop_2020] if region == "Midwest"
mean inage_covid_death_rate [weight = pop_2020] if region == "Northeast"
mean inage_covid_death_rate [weight = pop_2020] if region == "South"
mean inage_covid_death_rate [weight = pop_2020] if region == "West"

// Calculate Excess Deaths Not Assigned to Covid-19 for the Lower 25% and Upper 25% of Values for Each Variable
// Note: the value labeled output is the excess death rate not assigned to Covid-19 for the stratum
foreach lname in percent_65_over percent_rural percent_black percent_white percent_hispanic household_income some_college home_ownership poor_or_fair_health obesity smoking diabetes {
regress inage_2020_death_rate inage_hist_death_rate inage_covid_death_rate [weight=pop_2020] if `lname'_up == 1
mat results = r(table)
summarize inage_covid_death_rate [weight = pop_2020] if `lname'_up == 1
gen output = (results[1,2] - 1) * r(mean)
mean output
drop output
regress inage_2020_death_rate inage_hist_death_rate inage_covid_death_rate [weight=pop_2020] if `lname'_up == 4
mat results = r(table)
summarize inage_covid_death_rate [weight = pop_2020] if `lname'_up == 4
gen output = (results[1,2] - 1) * r(mean)
mean output
drop output
}
foreach lname in Midwest Northeast South West {
regress inage_2020_death_rate inage_hist_death_rate inage_covid_death_rate [weight=pop_2020] if region == "`lname'"
mat results = r(table)
summarize inage_covid_death_rate [weight = pop_2020] if region == "`lname'"
gen output = (results[1,2] - 1) * r(mean)
mean output
drop output	
}

////////////////////////////////////////////
// PART 4: AUTOMATED FIGURE GENERATOR	  //
// FIGURES 2-3, SUPPLEMENTAL FIGURES 2-4  //
////////////////////////////////////////////

// Generate Figure 2 (Automated Code)
use data_clean.dta, clear
foreach lname in percent_65_over percent_rural percent_white percent_hispanic percent_black household_income some_college home_ownership poor_or_fair_health obesity smoking diabetes {
xtile `lname'_up = `lname' [weight=pop_2020], nq(4)
}
gen estimate = .
gen lower_bound = .
gen upper_bound = .
gen indicator = _n
gen variable = ""
gen level = ""
gen percent = .
gen pct_lower_bound = .
gen pct_upper_bound = .
reg all_2020_death_rate all_hist_death_rate covid_2020_death_rate [weight = pop_2020] 
mat results = r(table)
replace variable = "Overall" if indicator == 1
replace level = "Estimate"  if indicator == 1
replace estimate = results[1,2] if indicator == 1
replace lower_bound = results[5,2] if indicator == 1
replace upper_bound = results[6,2] if indicator == 1
nlcom (_b[covid_2020_death_rate] - 1) / _b[covid_2020_death_rate], post
esttab, ci
mat results = r(coefs)
replace percent = results[1,1] if indicator == 1
replace pct_lower_bound = results[1,2] if indicator == 1
replace pct_upper_bound = results[1,3] if indicator == 1
local num = 2
foreach lname in percent_65_over percent_rural percent_black percent_white percent_hispanic household_income some_college home_ownership poor_or_fair_health obesity smoking diabetes {
reg all_2020_death_rate all_hist_death_rate covid_2020_death_rate [weight = pop_2020] if `lname'_up == 1
mat results = r(table)
replace variable = "`lname'" if indicator == `num'
replace level = "Lower 25% of Values"  if indicator == `num'
replace estimate = results[1,2] if indicator == `num'
replace lower_bound = results[5,2] if indicator == `num'
replace upper_bound = results[6,2] if indicator == `num'
nlcom (_b[covid_2020_death_rate] - 1) / _b[covid_2020_death_rate], post
esttab, ci
mat results = r(coefs)
replace percent = results[1,1] if indicator == `num'
replace pct_lower_bound = results[1,2] if indicator == `num'
replace pct_upper_bound = results[1,3] if indicator == `num'
local num = `num' + 1
reg all_2020_death_rate all_hist_death_rate covid_2020_death_rate [weight = pop_2020] if `lname'_up == 4
mat results = r(table)
replace variable = "`lname'" if indicator == `num'
replace level = "Upper 25% of Values"  if indicator == `num'
replace estimate = results[1,2] if indicator == `num'
replace lower_bound = results[5,2] if indicator == `num'
replace upper_bound = results[6,2] if indicator == `num'
nlcom (_b[covid_2020_death_rate] - 1) / _b[covid_2020_death_rate], post
esttab, ci
mat results = r(coefs)
replace percent = results[1,1] if indicator == `num'
replace pct_lower_bound = results[1,2] if indicator == `num'
replace pct_upper_bound = results[1,3] if indicator == `num'
local num = `num' + 1
}
encode region, gen(region_new)
forvalue num2 = 1/4 {
regress all_2020_death_rate all_hist_death_rate covid_2020_death_rate [weight=pop_2020] if region_new == `num2'
mat results = r(table)
replace variable = "Region" if indicator == `num'
replace level = "`num2'"  if indicator == `num'
replace estimate = results[1,2] if indicator == `num'
replace lower_bound = results[5,2] if indicator == `num'
replace upper_bound = results[6,2] if indicator == `num'
nlcom (_b[covid_2020_death_rate] - 1) / _b[covid_2020_death_rate], post
esttab, ci
mat results = r(coefs)
replace percent = results[1,1] if indicator == `num'
replace pct_lower_bound = results[1,2] if indicator == `num'
replace pct_upper_bound = results[1,3] if indicator == `num'
local num = `num' + 1
}
drop if level == ""
keep indicator estimate lower_bound upper_bound variable level percent pct_lower_bound pct_upper_bound
replace percent = percent * 100
replace pct_lower_bound = pct_lower_bound * 100
replace pct_upper_bound = pct_upper_bound * 100
replace percent = round(percent)
tostring percent, gen(percent1) force
replace pct_lower_bound = round(pct_lower_bound)
tostring pct_lower_bound, gen(percent2) force
replace pct_upper_bound = round(pct_upper_bound)
tostring pct_upper_bound, gen(percent3) force
gen percent_underreport = percent1 + "% (" + percent2 +"%, " + percent3 + "%)"
drop percent1 percent2 percent3
replace variable = "Age (65 or Over)" if variable == "percent_65_over"
replace variable = "Hispanic" if variable == "percent_hispanic"
replace variable = "Non-Hispanic White" if variable == "percent_white" 
replace variable = "Non-Hispanic Black" if variable == "percent_black" 
replace variable = "Rural" if variable == "percent_rural"
replace variable = "Some College or More Education" if variable == "some_college"
replace variable = "Median Household Income" if variable == "household_income" 
replace variable = "Homeownership" if variable == "home_ownership"
replace variable = "Poor or Fair Health" if variable == "poor_or_fair_health" 
replace variable = "Obesity" if variable == "obesity" 
replace variable = "Diabetes" if variable == "diabetes" 
replace variable = "Smoking" if variable == "smoking" 
replace level = "Midwest" if level == "1" 
replace level = "Northeast" if level == "2" 
replace level = "South" if level == "3" 
replace level = "West" if level == "4" 
label var variable "Indicators"
label var level "Factors"
label var variable "Factors"
label var percent_underreport "Percent of Excess Deaths Not Assigned to COVID-19 (95% CI)"
metan estimate lower_bound upper_bound, by(variable)
metan estimate lower_bound upper_bound, by(variable) nooverall nosubgroup xline(1, lcolor(black)) xline(1.20, lcolor(navy) lpattern(shortdash)) xlabel(0, 1, 2) nulloff effect("Coefficients Relating Excess Deaths to COVID-19 Deaths") lcols(level) rcols(percent_underreport) graphregion(color(white)) xsize(14) ysize(17) boxsca(0.8) scale(1.6) force pointopt(msize(0.4)) ciopt(lwidth(medthin)) 
graph export figure_2.jpg, replace width(3000)
graph export figure_2.tif, replace

// Generate Figure 3 (Automated Code)
use data_clean.dta, clear
foreach lname in percent_65_over percent_rural percent_hispanic percent_black percent_white household_income some_college home_ownership poor_or_fair_health obesity smoking diabetes  {
xtile `lname'_up = `lname' [weight=pop_2020], nq(4)
}

gen hist_bar = .
gen direct_bar = .
gen notassigned_bar = .
gen variable = ""
gen level = ""
local num = 1
gen indicator = _n

replace variable = "Overall" if indicator == 1
replace level = "Estimate" if indicator == 1
regress all_2020_death_rate all_hist_death_rate covid_2020_death_rate [weight=pop_2020] 
mat results = r(table)
gen directcoeff = results[1,2]
replace directcoeff = directcoeff - 1
mean covid_2020_death_rate [weight = pop_2020] 
mat results = r(table)
replace direct_bar = results[1,1] if indicator == 1
replace notassigned_bar = direct_bar * directcoeff  if indicator == 1
drop directcoeff
local num = 2

foreach lname in percent_65_over percent_rural percent_black percent_white percent_hispanic household_income some_college home_ownership poor_or_fair_health obesity smoking diabetes  {
replace variable = "`lname'" if indicator == `num'
replace level = "Lower 25% of Values" if indicator == `num'
regress all_2020_death_rate all_hist_death_rate covid_2020_death_rate [weight=pop_2020] if `lname'_up == 1
mat results = r(table)
gen directcoeff = results[1,2]
replace directcoeff = directcoeff - 1
mean covid_2020_death_rate [weight = pop_2020] if `lname'_up == 1
mat results = r(table)
replace direct_bar = results[1,1] if indicator == `num'
replace notassigned_bar = direct_bar * directcoeff  if indicator == `num'
drop directcoeff
local num = `num' + 1

replace variable = "`lname'" if indicator == `num'
replace level = "Upper 25% of Values" if indicator == `num'
regress all_2020_death_rate all_hist_death_rate covid_2020_death_rate [weight=pop_2020] if `lname'_up == 4
mat results = r(table)
gen directcoeff = results[1,2]
replace directcoeff = directcoeff - 1
mean covid_2020_death_rate [weight = pop_2020] if `lname'_up == 4
mat results = r(table)
replace direct_bar = results[1,1] if indicator == `num'
replace notassigned_bar = direct_bar * directcoeff if indicator == `num'
drop directcoeff
local num = `num' + 1
}

encode region, generate(region_new)
forvalues num2 = 1/4 {
replace variable = "Region" if indicator == `num'
replace level = "`num2'" if indicator == `num'
regress all_2020_death_rate all_hist_death_rate covid_2020_death_rate [weight=pop_2020] if region_new == `num2'
mat results = r(table)
gen directcoeff = results[1,2]
replace directcoeff = directcoeff - 1
mean covid_2020_death_rate [weight = pop_2020] if region_new == `num2'
mat results = r(table)
replace direct_bar = results[1,1] if indicator == `num'
replace notassigned_bar = direct_bar * directcoeff if indicator == `num'
drop directcoeff
local num = `num' + 1
}
keep indicator direct_bar notassigned_bar variable level
replace variable = "Age (65 or Over)" if variable == "percent_65_over"
replace variable = "Hispanic" if variable == "percent_hispanic"
replace variable = "Non-Hispanic White" if variable == "percent_white" 
replace variable = "Non-Hispanic Black" if variable == "percent_black" 
replace variable = "Rural" if variable == "percent_rural"
replace variable = "Some College or More Education" if variable == "some_college"
replace variable = "Median Household Income" if variable == "household_income" 
replace variable = "Homeownership" if variable == "home_ownership"
replace variable = "Poor or Fair Health" if variable == "poor_or_fair_health" 
replace variable = "Obesity" if variable == "obesity" 
replace variable = "Diabetes" if variable == "diabetes" 
replace variable = "Smoking" if variable == "smoking" 
replace level = "Midwest" if level == "1" 
replace level = "Northeast" if level == "2" 
replace level = "South" if level == "3" 
replace level = "West" if level == "4"
label var variable "Indicators"
label var level "Factors"
label var variable "Factors"
save sup_tab_3a.dta, replace

graph hbar direct_bar notassigned_bar, stack over(level) over(variable, sort(indicator)) ysize(15) xsize(14) graphregion(color(white)) scale(0.5) legend(label(1 "Observed Direct COVID-19 Death Rate") label(2 "Predicted Death Rate Not Assigned to COVID-19") col(1)) nofill b1title("Deaths per 1,000 Person-Years")
graph export figure_3.jpg, replace
graph export figure_3.tif, replace

// Generate Supplemental Figure 2
/* Use Exported Excel File to Plot County FIPS Codes using Tableau or R */
use data_1.dta, clear
keep fipscountycode
export excel sup_figure_2.xlsx,replace

// Generate Supplemental Figure 3 (Automated Code)
use data_iage.dta, clear
foreach lname in percent_65_over percent_rural percent_white percent_hispanic percent_black household_income some_college home_ownership poor_or_fair_health obesity smoking diabetes {
xtile `lname'_up = `lname' [weight=pop_2020], nq(4)
}
gen estimate = .
gen lower_bound = .
gen upper_bound = .
gen indicator = _n
gen variable = ""
gen level = ""
gen percent = .
gen pct_lower_bound = .
gen pct_upper_bound = .
reg inage_2020_death_rate inage_hist_death_rate inage_covid_death_rate [weight = pop_2020] 
mat results = r(table)
replace variable = "Overall" if indicator == 1
replace level = "Estimate"  if indicator == 1
replace estimate = results[1,2] if indicator == 1
replace lower_bound = results[5,2] if indicator == 1
replace upper_bound = results[6,2] if indicator == 1
nlcom (_b[inage_covid_death_rate] - 1) / _b[inage_covid_death_rate], post
esttab, ci
mat results = r(coefs)
replace percent = results[1,1] if indicator == 1
replace pct_lower_bound = results[1,2] if indicator == 1
replace pct_upper_bound = results[1,3] if indicator == 1
local num = 2
foreach lname in percent_65_over percent_rural percent_black percent_white percent_hispanic household_income some_college home_ownership poor_or_fair_health obesity smoking diabetes {
reg inage_2020_death_rate inage_hist_death_rate inage_covid_death_rate [weight = pop_2020] if `lname'_up == 1
mat results = r(table)
replace variable = "`lname'" if indicator == `num'
replace level = "Lower 25% of Values"  if indicator == `num'
replace estimate = results[1,2] if indicator == `num'
replace lower_bound = results[5,2] if indicator == `num'
replace upper_bound = results[6,2] if indicator == `num'
nlcom (_b[inage_covid_death_rate] - 1) / _b[inage_covid_death_rate], post
esttab, ci
mat results = r(coefs)
replace percent = results[1,1] if indicator == `num'
replace pct_lower_bound = results[1,2] if indicator == `num'
replace pct_upper_bound = results[1,3] if indicator == `num'
local num = `num' + 1
reg inage_2020_death_rate inage_hist_death_rate inage_covid_death_rate [weight = pop_2020] if `lname'_up == 4
mat results = r(table)
replace variable = "`lname'" if indicator == `num'
replace level = "Upper 25% of Values"  if indicator == `num'
replace estimate = results[1,2] if indicator == `num'
replace lower_bound = results[5,2] if indicator == `num'
replace upper_bound = results[6,2] if indicator == `num'
nlcom (_b[inage_covid_death_rate] - 1) / _b[inage_covid_death_rate], post
esttab, ci
mat results = r(coefs)
replace percent = results[1,1] if indicator == `num'
replace pct_lower_bound = results[1,2] if indicator == `num'
replace pct_upper_bound = results[1,3] if indicator == `num'
local num = `num' + 1
}
encode region, gen(region_new)
forvalue num2 = 1/4 {
regress inage_2020_death_rate inage_hist_death_rate inage_covid_death_rate [weight=pop_2020] if region_new == `num2'
mat results = r(table)
replace variable = "Region" if indicator == `num'
replace level = "`num2'"  if indicator == `num'
replace estimate = results[1,2] if indicator == `num'
replace lower_bound = results[5,2] if indicator == `num'
replace upper_bound = results[6,2] if indicator == `num'
nlcom (_b[inage_covid_death_rate] - 1) / _b[inage_covid_death_rate], post
esttab, ci
mat results = r(coefs)
replace percent = results[1,1] if indicator == `num'
replace pct_lower_bound = results[1,2] if indicator == `num'
replace pct_upper_bound = results[1,3] if indicator == `num'
local num = `num' + 1
}
drop if level == ""
keep indicator estimate lower_bound upper_bound variable level percent pct_lower_bound pct_upper_bound
replace percent = percent * 100
replace pct_lower_bound = pct_lower_bound * 100
replace pct_upper_bound = pct_upper_bound * 100
replace percent = round(percent)
tostring percent, gen(percent1) force
replace pct_lower_bound = round(pct_lower_bound)
tostring pct_lower_bound, gen(percent2) force
replace pct_upper_bound = round(pct_upper_bound)
tostring pct_upper_bound, gen(percent3) force
gen percent_underreport = percent1 + "% (" + percent2 +"%, " + percent3 + "%)"
drop percent1 percent2 percent3
replace variable = "Age (65 or Over)" if variable == "percent_65_over"
replace variable = "Hispanic" if variable == "percent_hispanic"
replace variable = "Non-Hispanic White" if variable == "percent_white" 
replace variable = "Non-Hispanic Black" if variable == "percent_black" 
replace variable = "Rural" if variable == "percent_rural"
replace variable = "Some College or More Education" if variable == "some_college"
replace variable = "Median Household Income" if variable == "household_income" 
replace variable = "Homeownership" if variable == "home_ownership"
replace variable = "Poor or Fair Health" if variable == "poor_or_fair_health" 
replace variable = "Obesity" if variable == "obesity" 
replace variable = "Diabetes" if variable == "diabetes" 
replace variable = "Smoking" if variable == "smoking" 
replace level = "Midwest" if level == "1" 
replace level = "Northeast" if level == "2" 
replace level = "South" if level == "3" 
replace level = "West" if level == "4" 
label var variable "Indicators"
label var level "Factors"
label var variable "Factors"
label var percent_underreport "Percent of Excess Deaths Not Assigned to Covid-19 (95% CI)"
metan estimate lower_bound upper_bound, by(variable)
metan estimate lower_bound upper_bound, by(variable) nooverall nosubgroup xline(1, lcolor(black)) xline(1.15, lcolor(navy) lpattern(shortdash)) xlabel(0, 1, 2) nulloff effect("Coefficients Relating Excess Deaths to Covid-19 Deaths") lcols(level) rcols(percent_underreport) graphregion(color(white)) xsize(14) ysize(17) boxsca(0.8) scale(1.6) force pointopt(msize(0.4)) ciopt(lwidth(medthin)) 
graph export sup_figure_3.jpg, replace

// Generate Supplemental Figure 4 (Automated Code)
use data_iage.dta, clear
foreach lname in percent_65_over percent_rural percent_hispanic percent_black percent_white household_income some_college home_ownership poor_or_fair_health obesity smoking diabetes {
xtile `lname'_up = `lname' [weight=pop_2020], nq(4)
}

gen direct_bar = .
gen notassigned_bar = .
gen variable = ""
gen level = ""
local num = 1
gen indicator = _n

replace variable = "Overall" if indicator == 1
replace level = "Estimate" if indicator == 1
regress inage_2020_death_rate inage_hist_death_rate inage_covid_death_rate [weight=pop_2020] 
mat results = r(table)
gen directcoeff = results[1,2]
replace directcoeff = directcoeff - 1
mean inage_covid_death_rate [weight = pop_2020] 
mat results = r(table)
replace direct_bar = results[1,1] if indicator == 1
replace notassigned_bar = direct_bar * directcoeff  if indicator == 1
drop directcoeff
local num = 2

foreach lname in percent_65_over percent_rural percent_black percent_white percent_hispanic household_income some_college home_ownership poor_or_fair_health obesity smoking diabetes {
replace variable = "`lname'" if indicator == `num'
replace level = "Lower 25% of Values" if indicator == `num'
regress inage_2020_death_rate inage_hist_death_rate inage_covid_death_rate [weight=pop_2020] if `lname'_up == 1
mat results = r(table)
gen directcoeff = results[1,2]
replace directcoeff = directcoeff - 1
mean inage_covid_death_rate [weight = pop_2020] if `lname'_up == 1
mat results = r(table)
replace direct_bar = results[1,1] if indicator == `num'
replace notassigned_bar = direct_bar * directcoeff  if indicator == `num'
drop directcoeff
local num = `num' + 1

replace variable = "`lname'" if indicator == `num'
replace level = "Upper 25% of Values" if indicator == `num'
regress inage_2020_death_rate inage_hist_death_rate inage_covid_death_rate [weight=pop_2020] if `lname'_up == 4
mat results = r(table)
gen directcoeff = results[1,2]
replace directcoeff = directcoeff - 1
mean inage_covid_death_rate [weight = pop_2020] if `lname'_up == 4
mat results = r(table)
replace direct_bar = results[1,1] if indicator == `num'
replace notassigned_bar = direct_bar * directcoeff if indicator == `num'
drop directcoeff
local num = `num' + 1
}

encode region, generate(region_new)
forvalues num2 = 1/4 {
replace variable = "Region" if indicator == `num'
replace level = "`num2'" if indicator == `num'
regress inage_2020_death_rate inage_hist_death_rate inage_covid_death_rate [weight=pop_2020] if region_new == `num2'
mat results = r(table)
gen directcoeff = results[1,2]
replace directcoeff = directcoeff - 1
mean inage_covid_death_rate [weight = pop_2020] if region_new == `num2'
mat results = r(table)
replace direct_bar = results[1,1] if indicator == `num'
replace notassigned_bar = direct_bar * directcoeff if indicator == `num'
drop directcoeff
local num = `num' + 1
}
keep indicator direct_bar notassigned_bar variable level
replace variable = "Age (65 or Over)" if variable == "percent_65_over"
replace variable = "Hispanic" if variable == "percent_hispanic"
replace variable = "Non-Hispanic White" if variable == "percent_white" 
replace variable = "Non-Hispanic Black" if variable == "percent_black" 
replace variable = "Rural" if variable == "percent_rural"
replace variable = "Some College or More Education" if variable == "some_college"
replace variable = "Median Household Income" if variable == "household_income" 
replace variable = "Homeownership" if variable == "home_ownership"
replace variable = "Poor or Fair Health" if variable == "poor_or_fair_health" 
replace variable = "Obesity" if variable == "obesity" 
replace variable = "Diabetes" if variable == "diabetes" 
replace variable = "Smoking" if variable == "smoking" 
replace level = "Midwest" if level == "1" 
replace level = "Northeast" if level == "2" 
replace level = "South" if level == "3" 
replace level = "West" if level == "4"
label var variable "Indicators"
label var level "Factors"
label var variable "Factors"
save sup_tab_3b.dta, replace
graph hbar direct_bar notassigned_bar, stack over(level) over(variable, sort(indicator)) ysize(15) xsize(14) graphregion(color(white)) scale(0.5) legend(label(1 "Observed Direct Covid-19 Death Rate") label(2 "Predicted Death Rate Not Assigned to Covid-19") col(1)) nofill b1title("Deaths per 1000 Person-Years")
graph export sup_figure_4.jpg, replace


/////////////////////////////////////////////////
// PART 5: OTHER CALCULATIONS 		           //
// ABSOLUTE NUMBERS, SUPPLEMENTAL TABLES 3-4 //
/////////////////////////////////////////////////

***************************
**** BLOCK #5A.  	   ****
**** ABSOLUTE NUMBERS  ****
***************************

// Mean Covid-19 and All-Cause Death Rate, 2020
use data_clean.dta, clear
mean covid_2020_death_rate [weight=pop_2020]
mean all_2020_death_rate [weight=pop_2020]

// Absolute Numbers of Excess Deaths
/* Direct Covid-19 Deaths */
use data_clean.dta, clear
egen covid19deaths_sum = sum(covid19deaths)
mean covid19deaths_sum
/* Excess Deaths Not Assigned to Covid-19 */
regress all_2020_death_rate all_hist_death_rate covid_2020_death_rate [weight=pop_2020]
nlcom (_b[covid_2020_death_rate] - 1) * covid19deaths_sum
/* Total Excess Deaths */
regress all_2020_death_rate all_hist_death_rate covid_2020_death_rate [weight=pop_2020]
nlcom _b[covid_2020_death_rate] * covid19deaths_sum

*******************************
**** BLOCK #5C.  	       ****
**** SUPPLEMENTAL TABLE 4  ****
*******************************

// Cut-Offs for Upper 25% and Lower 25% Strata 
use data_clean.dta, clear
foreach lname in percent_65_over percent_rural percent_white percent_hispanic percent_black household_income some_college home_ownership poor_or_fair_health obesity smoking diabetes {
xtile `lname'_up = `lname' [weight=pop_2020], nq(4)
}
foreach lname in percent_65_over percent_rural percent_white percent_hispanic percent_black household_income some_college home_ownership poor_or_fair_health obesity smoking diabetes {
summarize `lname' if `lname'_up == 1 
summarize `lname' if `lname'_up == 4
}

// Generate Map of Counties
use data_clean.dta, clear
keep fipscountycode
gen fips = fipscountycode
gen number = 1
export delimited sup_figure_2.csv, replace


///////////////////////////////
// PART 6: CLEAN UP	        //
// ERASE TEMPORARY DATASETS //
//////////////////////////////

// Erase Datasets 1-4
erase data_1.dta
forvalues num = 1/12 {
erase data_2_`num'.dta
}
erase data_3.dta
erase data_4.dta 
erase data_5.dta
erase data_6.dta 
erase data_7a.dta
erase data_7b.dta
erase data_8.dta
erase data_9.dta 
erase data_10.dta
erase data_11.dta  
erase sup_tab_3a.dta
erase sup_tab_3b.dta
