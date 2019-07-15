"""
    GDD(25.,5.0,28.0)

Compute the daily growing degree days (GDD) directly from the daily mean
temperature.

# Arguments
- `Tmean::Float64`: Optional. Average daily temperature (Celsius degree).
- `MinTT::Float64`: Minimum temperature threshold, also called base temperature (Celsius degree), default to 5.
- `MaxTT::Float64`: Maximum temperature threshold (Celsius degree), optional, default to 30.0

# Return
GDD: Growing degree days (Celsius degree)

# Examples
```julia
GDD(25.0,5.0,28.0)
20.0
GDD(5.0,5.0,28.0)
0.0
```
"""
function GDD(Tmean::Float64,MinTT::Float64=5.0,MaxTT::Float64=30.0)::Float64
  DD= Tmean-MinTT
  if DD<0.0 || DD>(MaxTT-MinTT)
    DD= 0.0
  end
  DD
end

"""
    GDD(30.0,27.0,5.0,27.0)

Compute the daily growing degree days (GDD) using the maximum and minimum daily temperature.

# Arguments
- `Tmax::Float64`: Maximum daily temperature (Celsius degree)
- `Tmin::Float64`: Minimum daily temperature (Celsius degree)
- `MinTT::Float64`: Minimum temperature threshold, also called base temperature (Celsius degree), default to 5.
- `MaxTT::Float64`: Maximum temperature threshold (Celsius degree), optional, default to 30.0

Please keep in mind that this function gives an approximation of the degree days.
GDD are normally computed as the integral of hourly (or less) values.

# Return
GDD: Growing degree days (Celsius degree)

# Examples
```julia
GDD(30.0,27.0,5.0,27.0)
0.0
```
"""
function GDD(Tmax::Float64,Tmin::Float64,MinTT::Float64=5.0,MaxTT::Float64=30.0)::Float64
 Tmean= (Tmax+Tmin)/2.0
 GDD(Tmean,MinTT,MaxTT)
end


"""
    is_missing(MetData, "Date")
Find if a column is missing from a DataFrame.

# Arguments
- `data::DataFrame`: a DataFrame
- `column::String`: a column name

# Return
A boolean: `true` if the column is missing, `false` if it is present.

# Examples
```julia
df= DataFrame(A = 1:10)
is_missing(df,"A")
false
is_missing(df,"B")
true
```
"""
function is_missing(data::DataFrame,column::String)::Bool
  columns= names(data)
  for i in 1:length(columns)
    is_in_col= columns[i] == Symbol(column)
    if is_in_col
      return false
    end
  end
  return true
end


"""
    is_missing(Dict("test"=> 2), "test")
Find if a key is missing from a dictionary.

# Arguments
- `data::Dict`: a dictionary
- `column::String`: a key (parameter) name

# Return
A boolean: `true` if the key is missing, `false` if it is present.

# Examples
```julia
Parameters= Dict("Stocking_Coffee"=> 5580)
is_missing(Parameters,"Stocking_Coffee")
false
is_missing(Parameters,"B")
true
```
"""
function is_missing(data::Dict,column::String)::Bool
  try
    data[column]
  catch error
    if isa(error, KeyError)
      return true
    end
  end
  return false
end



"""
    warn_var("Date","Start_Date from Parameters","warn")
Warn or stop execution if mandatory meteorology input variables are not provided.
It helps the user to know which variable is missing and/or if there are replacements

# Arguments
- `Var::String`: Input variable name
- `replacement::String`: Replacement variable that is used to compute `"Var"`
- `type::String`: Type of error to return : either

# Note
* This function helps to debug the model when some mandatory meteorological variables
are missing from input: either an error (default), or a warning.
* If the `"replacement"` variable is not provided in the meteorology file either, this function
will return an error with a hint on which variables can be provided to compute `"Var"`

# Examples
```julia
warn_var("Date","Start_Date from Parameters","warn")
```
"""
function warn_var(Var::String,replacement::String,type::String="error")
  if type=="error"
    error(string("$Var missing from input Meteo. Cannot proceed unless provided.",
                 " Hint: $Var can be computed alternatively using $replacement if provided in Meteo file")
               )
  else
    println("$Var missing from input Meteo. Computed from $replacement")
  end
end

"""
    warn_var("Date")
Stop execution if mandatory meteorology input variable is not provided.

# Arguments
- `Var::String`: Input variable name

"""
function warn_var(Var::String)
  error("$Var missing from input Meteo. Cannot proceed unless provided.")
end
