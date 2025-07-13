set maxvar 10000

*Use pgen.dta as the backbone
*Load pgen.dta
use "pgen.dta", replace

*Keep only the variables needed
keep cid hid pid syear pgpartz pgpartnr pglabgro pglabnet pgstib pgjobend imonth

*Import sex gebjahr gebmonat from ppathl.dta
merge 1:1 pid syear using "ppathl.dta", keepusing(sex gebjahr gebmonat)

*Drop the observations which are not in both pgen.dta and ppathl.dta
drop if _merge != 3

*Drop the variable _merge
drop _merge

*Import ple0040 (disability status: reduced employment (Erwerbsminderung) or legally handicapped (Schwerbehinderung)) from pl.dta
merge 1:1 pid syear using "pl.dta", keepusing(ple0040)

*Drop the observations which are not in both pgen.dta and pl.dta
drop if _merge != 3

*Drop the variable _merge
drop _merge

*Keep only observations which are women born between 1947 and 1956
keep if inrange(gebjahr, 1947, 1956)
keep if sex == 2

*Drop observations whose values of gebmonat are invalid
drop if inlist(gebmonat, -1, -2, -5) // -1 means "no answer"; -2 means "does not apply"; -5 means "not included in this version of the questionnaire"

*Drop observations whose values of ple0040 are invalid
drop if inlist(ple0040, -1, -2, -4, -5, -8) // -1 means "no answer"; -2 means "does not apply"; -4 means "inadmissable multiple response"; -5 means "not included in this version of the questionnaire"; -8 means "question this year not part of survey"

*Save the dataset
save master_data_47_56_v4.dta, replace


/* Generate the retirement age variable */

*Load pkal.dta
use "pkal.dta", clear

*Keep only the variables needed
keep pid syear kal1e001 kal1e002 kal1e003 kal1e004 kal1e005 kal1e006 kal1e007 kal1e008 kal1e009 kal1e010 kal1e011 kal1e012

*Import sex gebjahr gebmonat from ppathl.dta
merge 1:1 pid syear using "ppathl.dta", keepusing(sex gebjahr gebmonat)

*Drop the observations which are not in both pkal.dta and ppathll.dta
drop if _merge != 3

*Drop the variable _merge
drop _merge

*Keep only observations which are women born between 1947 and 1956
keep if inrange(gebjahr, 1947, 1956)
keep if sex == 2

*Drop observations whose values of gebmonat are invalid
drop if inlist(gebmonat, -1, -2, -5) // -1 means "no answer"; -2 means "does not apply"; -5 means "not included in this version of the questionnaire"

*Rename monthly caldendar variables
rename (kal1e001 kal1e002 kal1e003 kal1e004 kal1e005 kal1e006 kal1e007 kal1e008 kal1e009 kal1e010 kal1e011 kal1e012) (kal1e00_1 kal1e00_2 kal1e00_3 kal1e00_4 kal1e00_5 kal1e00_6 kal1e00_7 kal1e00_8 kal1e00_9 kal1e00_10 kal1e00_11 kal1e00_12)

*Reshape monthly calendar variables to long format
reshape long kal1e00_, i(pid syear) j(month)

*Reconstruct actual retirement year and month (monthly calendar variables refer to previous year)
gen retire_year = syear - 1
gen retire_month = month

*Identify if respondent is retired in that month
gen is_retired = kal1e00_ == 1

*Create retirement year variable
bysort pid (retire_year): egen retirement_year = min(cond(is_retired == 1, retire_year, .))

*Create retirement month variable
gen _temp_month = retire_month if retirement_year == retire_year & is_retired == 1
bysort pid (retire_year): egen retirement_month = min(cond(!missing(_temp_month), _temp_month, .))
drop _temp_month

*Generate the retirement age variable and compute retirement age in years with decimals
gen retirement_age = .
replace retirement_age = (retirement_year - gebjahr) + (retirement_month - gebmonat)/12 if retirement_month >= gebmonat
replace retirement_age = (retirement_year - gebjahr - 1) + (12 - gebmonat + retirement_month)/12 if retirement_month < gebmonat

*Drop observations with no retirement age information
drop if retirement_age == .

*Keep only one observation for each woman
collapse (firstnm) syear sex gebjahr gebmonat retirement_year retirement_month retirement_age, by(pid)

*Save the dataset
save "retirement_age_47_56_v4.dta", replace


*Load master_data_47_56_v4.dta
use "master_data_47_56_v4.dta", clear

*Import the retirement year, retirement month, and retirement age variables from retirement_age_47_56_v4.dta
merge m:1 pid using "retirement_age_47_56_v4.dta", keepusing(retirement_year retirement_month retirement_age)

*Drop observations which are not in both datasets
drop if _merge != 3
drop _merge

*Generate the distance to cutoff variable
gen dtc = (gebjahr - 1952)*12 + (gebmonat - 1)

*Generate the policy treatment indicator variable
gen reform = dtc >= 0

*Generate the policy treatment-distance to cutoff interaction term
gen reform_dtc = reform * dtc

*Generate the quarter of year of birth variable
gen birth_quarter = floor((gebmonat - 1)/3) + 1
gen cluster_qob = gebjahr * 10 + birth_quarter

*Save the data
save master_data_47_56_v4.dta, replace


/* Do baseline analysis */

*Keep only one observation for each woman who were born between 1949 and 1954 and retired at 60 to 65 and save as a new dataset
keep if gebjahr >= 1949 & gebjahr <= 1954 & retirement_age >= 60 & retirement_age < 65
collapse (firstnm) retirement_age reform dtc reform_dtc gebjahr gebmonat cluster_qob, by(pid)
save main_49_54_v4.dta, replace

*Run regression
reg retirement_age reform dtc reform_dtc, vce(cluster cluster_qob)

*Keep only one observation for each woman who were born between 1950 and 1953 and retired at 60 to 65 and save as a new dataset (as robustness check)
*keep if gebjahr >= 1950 & gebjahr <= 1953 & retirement_age >= 60 & retirement_age < 65
*collapse (firstnm) retirement_age reform dtc reform_dtc gebjahr gebmonat cluster_qob, by(pid)
*save main_50_53_v4.dta, replace

*Run regression
*reg retirement_age reform dtc reform_dtc, vce(cluster cluster_qob)

*Keep only one observation for each woman who were born between 1948 and 1955 and retired at 60 to 65 and save as a new dataset (as robustness check)
*keep if gebjahr >= 1948 & gebjahr <= 1955 & retirement_age >= 60 & retirement_age < 65
*collapse (firstnm) retirement_age reform dtc reform_dtc gebjahr gebmonat cluster_qob, by(pid)
*save main_48_55_v4.dta, replace

*Run regression
*reg retirement_age reform dtc reform_dtc, vce(cluster cluster_qob)



/* Generate the income dummy variable and do heterogeneity analysis */

*Load the master dataset
use "master_data_47_56_v4.dta", clear

*Change the value of pglabnet to 0 if pglabgro = -2 (-2 means "does not apply")
replace pglabnet = 0 if pglabgro == -2

*Change the value of pglabnet to . if pglabgro = -5 (-5 means "not inludced in questionnaire version")
replace pglabnet = . if pglabgro == -5

*Mark the five years before the retirement year
gen pre5 = (syear >= retirement_year - 5) & (syear < retirement_year)

*Create a variable which contains only the net income data in the five years before retirement
gen net_income_pre5 = pglabnet if pre5 == 1

*Create a variable of the average net income in the five years before retirement
bysort pid: egen avg_net_income = mean(net_income_pre5)

*Save the data
save master_data_47_56_v4.dta, replace

*Drop the observations whose avg_net_income has a missing value
drop if missing(avg_net_income)

*Keep only observations of women who were born between 1949 and 1954 and retired at 60 to 65
keep if gebjahr >= 1949 & gebjahr <= 1954 & retirement_age >= 60 & retirement_age < 65

*Keep only observations of women who were born between 1950 and 1953 and retired at 60 to 65 (as robustness check)
*keep if gebjahr >= 1950 & gebjahr <= 1953 & retirement_age >= 60 & retirement_age < 65

*Keep only observations of women who were born between 1948 and 1955 and retired at 60 to 65 (as robustness check)
*keep if gebjahr >= 1948 & gebjahr <= 1955 & retirement_age >= 60 & retirement_age < 65

*Keep only one observation for each woman in the data
collapse (firstnm) retirement_age reform dtc reform_dtc gebjahr gebmonat cluster_qob avg_net_income, by(pid)

*Save as a new dataset
save income_49_54_v4.dta, replace
*save income_50_53_v4.dta, replace (as robustness check)
*save income_48_55_v4.dta, replace (as robustness check)

*Calculate the median of the average net income values of these women
summarize avg_net_income if avg_net_income < ., detail
scalar median_income = r(p50)

*Generate the income dummy variable
gen income = .
replace income = 1 if avg_net_income > median_income
replace income = 0 if avg_net_income <= median_income

*Generate the reform-income interaction term variable
gen reform_income = reform * income

*Run regression
regress retirement_age reform dtc reform_dtc income reform_income, vce(cluster cluster_qob)



/* Generate the wealth dummy variable and do heterogeneity analysis */

*Load the master dataset
use "master_data_47_56_v4.dta", clear

*Import variables w0111a w0111b w0111c w0111d w0111e from pwealth.dta into master_data_47_56_v4.dta
merge 1:1 pid syear using pwealth.dta, keepusing(w0111a w0111b w0111c w0111d w0111e)

*Drop observations of people who are originally not in master_data_47_56_v4.dta and save the data
drop if _merge == 2
drop _merge
save master_data_47_56_v4.dta, replace

*Keep only the observations whose net overall wealth values are not empty in the five years before their retirement
keep if pre5 == 1 & (w0111a < . & w0111b < . & w0111c < . & w0111d < . & w0111e < .)

*Check whether each woman only has one observation of wealth
ssc install unique
unique pid

*Keep observations of women who were born between 1949 and 1954 and retired at 60 to 65 and save as a new dataset
keep if gebjahr >= 1949 & gebjahr <= 1954 & retirement_age >= 60 & retirement_age < 65
save wealth_49_54_v4.dta, replace

*Keep observations of women who were born between 1950 and 1953 and retired at 60 to 65 and save as a new dataset (as robustness check)
*keep if gebjahr >= 1950 & gebjahr <= 1953 & retirement_age >= 60 & retirement_age < 65
*save wealth_50_53_v4.dta, replace

*Keep observations of women who were born between 1948 and 1955 and retired at 60 to 65 and save as a new dataset (as robustness check)
*keep if gebjahr >= 1948 & gebjahr <= 1955 & retirement_age >= 60 & retirement_age < 65
*save wealth_48_55_v4.dta, replace

*Load wealth_49_54_v4.dta and rename the net overall wealth variables
use wealth_49_54_v4.dta, clear
rename (w0111a w0111b w0111c w0111d w0111e) (w0111_1 w0111_2 w0111_3 w0111_4 w0111_5)

*Load wealth_50_53_v4.dta and rename the net overall wealth variables (as robustness check)
*use wealth_50_53_v4.dta, clear
*rename (w0111a w0111b w0111c w0111d w0111e) (w0111_1 w0111_2 w0111_3 w0111_4 w0111_5)

*Load wealth_48_55_v4.dta and rename the net overall wealth variables (as robustness check)
*use wealth_48_55_v4.dta, clear
*rename (w0111a w0111b w0111c w0111d w0111e) (w0111_1 w0111_2 w0111_3 w0111_4 w0111_5)

*Create the wealth dummy and the reform-wealth interaction term for each imputation
forvalues j = 1/5 {
    quietly summarize w0111_`j' if w0111_`j' < ., detail
    scalar med`j' = r(p50)
    gen wealth_`j' = (w0111_`j' > med`j')
	gen rwealth_`j' = reform * wealth_`j'
}

*Resahpe the data into long format and rename the variables
reshape long w0111_ wealth_ rwealth_, i(pid) j(m)
rename (w0111_ wealth_ rwealth_) (net_wealth wealth reform_wealth)

*Create a basaline (m = 0) whose values of net_wealth, wealth, and reform_wealth are missing and append it back into wealth_49_54_v4.dta
preserve
keep pid gebjahr retirement_age reform dtc reform_dtc cluster_qob net_wealth wealth reform_wealth m
keep if m == 1 // use m = 1 as the source of structure of the baseline
replace m = 0
replace net_wealth = .
replace wealth = .
replace reform_wealth = .
save "baseline_m0.dta", replace
restore
append using "baseline_m0.dta", force
sort pid m

/*Create a basaline (m = 0) whose values of net_wealth, wealth, and reform_wealth are missing and append it back into wealth_50_53_v4.dta (as robustness check)
preserve
keep pid gebjahr retirement_age reform dtc reform_dtc cluster_qob net_wealth wealth reform_wealth m
keep if m == 1 // use m = 1 as the source of structure of the baseline
replace m = 0
replace net_wealth = .
replace wealth = .
replace reform_wealth = .
save "baseline_m0.dta", replace
restore
append using "baseline_m0.dta", force
sort pid m */

/*Create a basaline (m = 0) whose values of net_wealth, wealth, and reform_wealth are missing and append it back into wealth_48_55_v4.dta (as robustness check)
preserve
keep pid gebjahr retirement_age reform dtc reform_dtc cluster_qob net_wealth wealth reform_wealth m
keep if m == 1 // use m = 1 as the source of structure of the baseline
replace m = 0
replace net_wealth = .
replace wealth = .
replace reform_wealth = .
save "baseline_m0.dta", replace
restore
append using "baseline_m0.dta", force
sort pid m */

*Save and load the dataset again
save wealth_49_54_reshaped.dta, replace
use wealth_49_54_reshaped.dta, clear

*Save and load the dataset again (as robustness check)
*save wealth_50_53_reshaped.dta, replace
*use wealth_50_53_reshaped.dta, clear

*Save and load the dataset again (as robustness check)
*save wealth_48_55_reshaped.dta, replace
*use wealth_48_55_reshaped.dta, clear

*Import mi flong structure (including baseline (m=0) and five implicates (m = 1,...,5))
mi import flong, id(pid) m(m)

*Register the variables
mi register imputed net_wealth wealth reform_wealth
mi register regular retirement_age reform dtc reform_dtc cluster_qob gebjahr

*Use mi estimate to run regression analysis
mi estimate, esampvaryok: regress retirement_age reform dtc reform_dtc wealth reform_wealth, vce(cluster cluster_qob)



/* Generate the partner's retirement status dummy variable and do heterogeneity analysis */

*Import partner's pgstib (occupational position) from pgen.dta into master_data_47_56_v4.dta
use pid syear pgstib using "pgen.dta", clear
rename pid pgpartnr
rename pgstib partner_pgstib
keep pgpartnr syear partner_pgstib
save "partner_status.dta", replace
use "master_data_47_56_v4.dta", clear
drop if pgpartnr <= 0  // Delete the observations with no partner
merge 1:1 pgpartnr syear using "partner_status.dta"
keep if _merge == 3 // Keep only the matched observations
drop _merge

*Drop observations with no valid partner_pgstib information
drop if partner_pgstib == -2 | partner_pgstib == -5 // -2 means "does not apply", -5 means "not included in questionnaire version"

*Generate the longitudinal partner's retirement dummy variable
gen partner_retired = (partner_pgstib == 13) // 13 means "NE (not employed): pensioner"

*Compress partner's retirement data in the five years prior to women's retirement and generate a dummy variable
bysort pid (syear): egen avg_partner_retired = mean(partner_retired) if pre5 == 1
gen partner_retired_pre5 = (avg_partner_retired > 0)

*Generate the reform-partner's retirement status interaction term
gen reform_partner = reform * partner_retired_pre5

*Save as a new dataset
save "master_data_w_partner_47_56_v4.dta", replace

*Keep only one observation for each woman in the data
collapse (firstnm) retirement_age reform dtc reform_dtc gebjahr gebmonat cluster_qob partner_retired_pre5 reform_partner, by(pid)

*Keep only observations of women who were born between 1949 and 1954 and retired at 60 to 65 and save as a new dataset
keep if gebjahr >= 1949 & gebjahr <= 1954 & retirement_age >= 60 & retirement_age < 65
save "partner_49_54_v4.dta", replace

*Keep only observations of women who were born between 1950 and 1953 and retired at 60 to 65 and save as a new dataset (as robustness check)
*keep if gebjahr >= 1950 & gebjahr <= 1953 & retirement_age >= 60 & retirement_age < 65
*save "partner_50_53_v4.dta", replace

*Keep only observations of women who were born between 1948 and 1955 and retired at 60 to 65 and save as a new dataset (as robustness check)
*keep if gebjahr >= 1948 & gebjahr <= 1955 & retirement_age >= 60 & retirement_age < 65
*save "partner_48_55_v4.dta", replace

*Do the heterogeneity analysis
regress retirement_age reform dtc reform_dtc partner_retired_pre5 reform_partner, vce(cluster cluster_qob)



/* Draw the retirement age around reform cutoff graph */
use "main_49_54_v4.dta", clear

collapse (mean) retirement_age dtc, by(cluster_qob)

twoway ///
(scatter retirement_age dtc, mcolor(black) msymbol(O) msize(small)) ///
(lfit retirement_age dtc if dtc < 0, lcolor(black)) ///
(lfit retirement_age dtc if dtc >= 0, lcolor(black)), ///
xline(0, lcolor(black) lpattern(dash)) ///
ytitle("Retirement age") ///
xtitle("Distance of individual month of birth to reform cutoff") ///
legend(off)



/* Summary statistics of the baseline sample */

use main_49_54_v4.dta, clear

*Summarise the variables
sum gebjahr gebmonat retirement_age reform dtc reform_dtc
sum gebjahr gebmonat retirement_age reform dtc reform_dtc if reform == 0
sum gebjahr gebmonat retirement_age reform dtc reform_dtc if reform == 1


/* Summary statistics of the income heterogeneity sample */

use income_49_54_v4.dta, clear

*Calculate the median of the average net income values of these women
summarize avg_net_income, detail
scalar median_income = r(p50)

*Generate the income dummy variable
gen income = .
replace income = 1 if avg_net_income > median_income
replace income = 0 if avg_net_income <= median_income

*Generate the reform-income interaction term variable
gen reform_income = reform * income

*Summarise the variables
sum gebjahr gebmonat retirement_age reform dtc reform_dtc income reform_income
sum gebjahr gebmonat retirement_age reform dtc reform_dtc income reform_income if reform == 0
sum gebjahr gebmonat retirement_age reform dtc reform_dtc income reform_income if reform == 1


/* Summary statistics of the wealth heterogeneity sample */

*Load wealth_49_54_v4.dta and rename the net overall wealth variables
use wealth_49_54_v4.dta, clear
rename (w0111a w0111b w0111c w0111d w0111e) (w0111_1 w0111_2 w0111_3 w0111_4 w0111_5)

*Create the wealth dummy and the reform-wealth interaction term for each imputation
forvalues j = 1/5 {
    quietly summarize w0111_`j' if w0111_`j' < ., detail
    scalar med`j' = r(p50)
    gen wealth_`j' = (w0111_`j' > med`j')
	gen rwealth_`j' = reform * wealth_`j'
}

*Resahpe the data into long format and rename the variables
reshape long w0111_ wealth_ rwealth_, i(pid) j(m)
rename (w0111_ wealth_ rwealth_) (net_wealth wealth reform_wealth)

*Create a basaline (m = 0) whose values of net_wealth, wealth, and reform_wealth are missing and append it back into wealth_49_54_v4.dta
preserve
keep pid gebjahr retirement_age reform dtc reform_dtc cluster_qob net_wealth wealth reform_wealth m
keep if m == 1 // use m = 1 as the source of structure of the baseline
replace m = 0
replace net_wealth = .
replace wealth = .
replace reform_wealth = .
save "baseline_m0.dta", replace
restore
append using "baseline_m0.dta", force
sort pid m

*Save and load the dataset again
save wealth_49_54_reshaped.dta, replace
use wealth_49_54_reshaped.dta, clear

*Import mi flong structure (including baseline (m=0) and five implicates (m = 1,...,5))
mi import flong, id(pid) m(m)

*Register the variables
mi register imputed net_wealth wealth reform_wealth
mi register regular retirement_age reform dtc reform_dtc cluster_qob gebjahr gebmonat

*Summarise the variables
mi xeq: summarize gebjahr gebmonat retirement_age reform dtc reform_dtc wealth reform_wealth
mi xeq: summarize gebjahr gebmonat retirement_age reform dtc reform_dtc wealth reform_wealth if reform == 0
mi xeq: summarize gebjahr gebmonat retirement_age reform dtc reform_dtc wealth reform_wealth if reform == 1


/* Summary statistics of the partner's retirement status heterogeneity sample */

use "partner_49_54_v4.dta", clear

*Summarise the variables
summarize gebjahr gebmonat retirement_age reform dtc reform_dtc partner_retired_pre5 reform_partner
summarize gebjahr gebmonat retirement_age reform dtc reform_dtc partner_retired_pre5 reform_partner if reform == 0
summarize gebjahr gebmonat retirement_age reform dtc reform_dtc partner_retired_pre5 reform_partner if reform == 1
