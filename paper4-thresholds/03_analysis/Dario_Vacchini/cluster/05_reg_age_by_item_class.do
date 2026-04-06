set processor 64

capture file close myfile_3  // Close any existing file handle named myfile

*** 0. Import data
use "/cluster/work/lawecon/Projects/procurement_brazil/dario_vacchini/data/final/df_convite_winner_looser.dta", clear

* Open a CSV file to store results
file open myfile_3 using "/cluster/work/lawecon/Projects/procurement_brazil/dario_vacchini/output/tables/reg_age_by_item_class.csv", write replace
file write myfile_3 "Variable, Coefficient, Std. Error, Class Item, Sig_1pct, Sig_5pct, Sig_10pct" _n

* RD regression for each market
levelsof códigoclasse, local(item_classes)

* Initialize a counter
local count = 0

foreach item_class in `item_classes' {
    * Increment the counter
    local count = `count' + 1

    // Count the number of observations for each market_item
    count if códigoclasse == `item_class' & MV < 0.01 & MV > -0.01
    local n = r(N) // Store the count in a local macro

    // Run the regression only if there are more than 10 observations
    if `n' >= 20 {
        di "Running regression for item_class = `item_class' with `n' observations"
        
        reghdfe age i.flagvencedor##c.MV if códigoclasse == `item_class' & MV < 0.01 & MV > -0.01, abs(year)

        // Get coefficients and standard errors
        matrix b = e(b)
        matrix V = e(V)
        local varnames: colnames b  // Get variable names from the matrix b

        // Loop over each variable name to find the one related to flagvencedor
        foreach var of local varnames {
            if strpos("`var'", "1.flagvencedor") {  // Check if the variable name contains "1.flagvencedor"
                local coef = b[1, "`var'"]
                local stderr = sqrt(V["`var'", "`var'"])

                // Calculate z-score for significance testing
                local z = abs(`coef' / `stderr')

                // Determine significance at 1%, 5%, and 10% levels
                local sig_1pct = cond(`z' > 2.576, 1, 0)  // 2.576 for 1% significance level (two-tailed test)
                local sig_5pct = cond(`z' > 1.96, 1, 0)   // 1.96 for 5% significance level
                local sig_10pct = cond(`z' > 1.645, 1, 0) // 1.645 for 10% significance level

                // Write to CSV file with significance levels
                file write myfile_3 "`var', `coef', `stderr', `item_class', `sig_1pct', `sig_5pct', `sig_10pct'" _n
            }
        }

        * Optionally, save regression results in Excel as before
        outreg2 using "/cluster/work/lawecon/Projects/procurement_brazil/dario_vacchini/output/tables/reg_age_by_item_class.xls" , excel tex(frag) bdec(4) label ctitle(age_item_class_`item_class') addtext(Year FE, YES)
    }
    else {
        di "Skipping códigoclasse = `item_class' due to insufficient observations (`n')"
    }
}

* Close the CSV file
file close myfile_3
