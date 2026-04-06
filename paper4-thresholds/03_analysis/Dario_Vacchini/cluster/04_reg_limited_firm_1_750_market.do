set processor 64

capture file close myfile_1  // Close any existing file handle named myfile

*** 0. Import data
use "/cluster/work/lawecon/Projects/procurement_brazil/dario_vacchini/data/final/df_convite_winner_looser.dta", clear

* Open a CSV file to store results
file open myfile_1 using "/cluster/work/lawecon/Projects/procurement_brazil/dario_vacchini/output/tables/reg_limited_firm_1_750_market.csv", write replace
file write myfile_1 "Variable, Coefficient, Std. Error, Market Item, Sig_1pct, Sig_5pct, Sig_10pct" _n

* RD regression for each market
levelsof market_item, local(market_items)

* Initialize a counter
local count = 0

foreach market in `market_items' {
    * Increment the counter
    local count = `count' + 1

    * Stop the loop after 2500 markets
    if `count' > 600 {
        break
    }

    // Count the number of observations for each market_item
    count if market_item == `market' & MV < 0.01 & MV > -0.01
    local n = r(N) // Store the count in a local macro

    // Run the regression only if there are more than 10 observations
    if `n' >= 30 {
        di "Running regression for market_item = `market' with `n' observations"
        
        reghdfe limited_firm i.flagvencedor##c.MV if market_item == `market' & MV < 0.01 & MV > -0.01, abs(year)

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
                file write myfile_1 "`var', `coef', `stderr', `market', `sig_1pct', `sig_5pct', `sig_10pct'" _n
            }
        }

        * Optionally, save regression results in Excel as before
        outreg2 using "/cluster/work/lawecon/Projects/procurement_brazil/dario_vacchini/output/tables/reg_limited_firm_1_750_market.xls" , excel tex(frag) bdec(4) label ctitle(last_bid_`market') addtext(Year FE, YES)
    }
    else {
        di "Skipping market_item = `market' due to insufficient observations (`n')"
    }
}

* Close the CSV file
file close myfile_1
