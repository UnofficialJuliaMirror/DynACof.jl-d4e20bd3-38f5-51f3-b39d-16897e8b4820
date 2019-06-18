"""
    Meteorology(file = NULL, Period = NULL, Parameters = Import_Parameters())

Import the meteorology data, check its format, and eventually compute missing variables.
# Arguments
- `file::Char`: Either the file name to read, a shell command that preprocesses the file (e.g. fread("grep filename"))
or the input itself as a string, see [data.table::fread()]. In both cases, a length 1 character string.
A filename input is passed through path.expand for convenience and may be a URL starting http:// or file://.
Default to `NULL` to return the [Aquiares()] example data from the package.
- `Period::Date`: A vector of two POSIX dates that correspond to the min and max dates for the desired time period to be returned.
- `Parameters::Date`: A list of parameters
    * Start_Date: optional, the Posixct date of the first meteo file record. Only needed if the Date column is missing.
    * FPAR      : Fraction of global radiation corresponding to PAR radiation, only needed if either RAD or PAR is missing.
    * Elevation : elevation of the site (m), only needed if atmospheric pressure is missing
    * Latitude  : latitude of the site (degree), only needed if the diffuse fraction of light is missing
    * WindSpeed : constant wind speed (m s-1), only needed if windspeed is missing
    * CO2       : constant atmospheric \eqn{CO_2} concentration (ppm), only needed if \eqn{CO_2} is missing
    * MinTT     : minimum temperature threshold for degree days computing (Celsius), see [GDD()]
    * MaxTT     : maximum temperature threshold for degree days computing (Celsius), see [GDD()]
    * albedo    : site shortwave surface albedo, only needed if net radiation is missing, see [Rad_net()]

Details: The imported file is expected to be at daily time-step. The albedo is used to compute the system net radiation that is then
used to compute the soil net radiation using an extinction coefficient with the plot LAI following the Shuttleworth & Wallace (1985)
formulation. This computation is likely to be depreciated in the near future as the computation has been replaced by a metamodel. It
is kept for information for the moment.

| *Var*           | *unit*      | *Definition*                                 | *If missing*                                                       |
|-----------------|-------------|----------------------------------------------|--------------------------------------------------------------------|
| Date            | POSIXct     | Date in POSIXct format                       | Computed from start date parameter, or set a dummy date if missing |
| year            | year        | Year of the simulation                       | Computed from Date                                                 |
| DOY             | day         | day of the year                              | Computed from Date                                                 |
| Rain            | mm          | Rainfall                                     | Assume no rain                                                     |
| Tair            | Celsius     | Air temperature (above canopy)               | Computed from Tmax and Tmin                                        |
| Tmax            | Celsius     | Maximum air temperature during the day       | Required (error)                                                   |
| Tmin            | Celsius     | Minimum air temperature during the day       | Required (error)                                                   |
| RH              | \%          | Relative humidity                            | Not used, but prefered over VPD for Rn computation                 |
| RAD             | MJ m-2 d-1  | Incident shortwave radiation                 | Computed from PAR                                                  |
| Pressure        | hPa         | Atmospheric pressure                         | Computed from VPD, Tair and Elevation, or alternatively from Tair and Elevation. |
| WindSpeed       | m s-1       | Wind speed                                   | Taken as constant: `Parameters$WindSpeed`                          |
| CO2             | ppm         | Atmospheric CO2 concentration                | Taken as constant: `Parameters$CO2`                                |
| DegreeDays      | Celsius     | Growing degree days                          | Computed using [GDD()]                                             |
| PAR             | MJ m-2 d-1  | Incident photosynthetically active radiation | Computed from RAD                                                  |
| FDiff           | Fraction    | Diffuse light fraction                       | Computed using [Diffuse_d()] using Spitters et al. (1986) formula  |
| VPD             | hPa         | Vapor pressure deficit                       | Computed from RH                                                   |
| Rn              | MJ m-2 d-1  | Net radiation (will be depreciated)          | Computed using [Rad_net()] with RH, or VPD                         |
| DaysWithoutRain | day         | Number of consecutive days with no rainfall  | Computed from Rain                                                 |
| Air_Density     | kg m-3      | Air density of moist air (\eqn{\rho}) above canopy | Computed using [bigleaf::air.density()]                      |
| ZEN             | radian      | Solar zenithal angle at noon                 | Computed from Date, Latitude, Longitude and Timezone               |

Note: It is highly recommended to set the system environment timezone to the one from the meteorology file. If not, the function try to use the Timezone
from the parameter files to set it. When in doubt, set it to UTC (`Sys.setenv(TZ="UTC")`), as for [Aquiares()].

# Returns
A daily meteorology data.frame (invisibly).

See also: [`DynACof()`](@ref)

# Examples
```julia-repl
julia> Met_c= Meteorology()
1
```
"""
function Meteorology(file, Period, Parameters= Import_Parameters())
# continuer ici, c'est dur de continuer sans connaitre un peu mieux Julia

  MetData= data.table::fread(file,data.table = F)

  MetData$Date= lubridate::fast_strptime(MetData$Date, "%Y-%m-%d",lt=F)


  # Missing Date:
  if(is.null(MetData$Date)){
    if(!is.null(Parameters$Start_Date)){
      MetData$Date= seq(from=lubridate::ymd(Parameters$Start_Date),
                        length.out= nrow(MetData), by="day")
      warn.var(Var= "Date","Parameters$Start_Date",type='warn')
    }else{
      MetData$Date= seq(from=lubridate::ymd("2000/01/01"),
                        length.out= nrow(MetData), by="day")
      warn.var(Var= "Date","dummy 2000/01/01",type='warn')
    }
  }

  if(!is.null(Period)){
    if(Period[1]<min(MetData$Date)|Period[2]>max(MetData$Date)){
      if(Period[2]>max(MetData$Date)){
        warning(paste("Meteo file do not cover the given period", "\n",
                      "Max date in meteo file= ",as.character(format(max(MetData$Date), "%Y-%m-%d")),
                      " ; max given period= ", as.character(Period[2]), "\n",
                      "setting the maximum date of simulation to the one from the meteo file"))
      }
      if(Period[1]<min(MetData$Date)){
        warning(paste("Meteo file do not cover the given period", "\n",
                      "Min date in meteo file= ",as.character(format(min(MetData$Date), "%Y-%m-%d")),
                      " ; min given period= ", as.character(Period[1]), "\n",
                      "setting the minimum date of simulation to the one from the meteo file"))
      }
    }
    MetData= MetData[MetData$Date>=Period[1]&MetData$Date<=(Period[2]),]
  }

  # Missing RAD:
  if(is.null(MetData$RAD)){
    if(!is.null(MetData$PAR)){
      MetData$RAD= MetData$PAR/Parameters$FPAR
      warn.var(Var= "RAD", replacement= "PAR",type='warn')
    }else{
      warn.var(Var= "RAD", replacement= "PAR",type='error')
    }
  }

  # Missing PAR:
  if(is.null(MetData$PAR)){
    MetData$PAR= MetData$RAD*Parameters$FPAR
    warn.var(Var= "PAR",replacement= "RAD",type='warn')
  }
  MetData$PAR[MetData$PAR<0.1]= 0.1

  # Missing Tmax and/or Tmin Temperature:
  if(is.null(MetData$Tmin)|is.null(MetData$Tmax)){
    warn.var(Var= "Tmin and/or Tmax",type='error')
  }

  # Missing air temperature:
  if(is.null(MetData$Tair)){
    MetData$Tair= (MetData$Tmax-MetData$Tmin)/2
    warn.var(Var= "Tair",replacement= "the equation (MetData$Tmax-MetData$Tmin)/2",type='warn')
  }

  # Missing VPD:
  if(is.null(MetData$VPD)){
    if(!is.null(MetData$RH)){
      MetData$VPD= bigleaf::rH.to.VPD(rH = MetData$RH/100, Tair = MetData$Tair)*10 # hPa
      warn.var(Var= "VPD","RH and Tair using bigleaf::rH.to.VPD",type='warn')
    }else{
      warn.var(Var= "VPD", replacement= "RH",type='error')
    }
  }

  # Missing air pressure:
  if(is.null(MetData$Pressure)){
    if(!is.null(Parameters$Elevation)){
      if(!is.null(MetData$VPD)){
        bigleaf::pressure.from.elevation(elev = Parameters$Elevation,
                                         Tair = MetData$Tair,
                                         VPD = MetData$VPD)*10
        # Return in kPa
        warn.var(Var= "Pressure",
                 replacement=paste("Elevation, Tair and VPD",
                                   "using bigleaf::pressure.from.elevation"),
                 type='warn')
      }else{
        bigleaf::pressure.from.elevation(elev = Parameters$Elevation,
                                         Tair = MetData$Tair)*10
        # Return in kPa
        warn.var(Var= "Pressure",
                 replacement=paste("Elevation and Tair",
                                   "using bigleaf::pressure.from.elevation"),
                 type='warn')
      }
    }else{
      warn.var(Var= "Pressure",replacement="Elevation",type='error')
    }
  }

  # Missing rain:
  if(is.null(MetData$Rain)){
    MetData$Rain= 0 # assume no rain
    warn.var(Var= "Rain","constant (= 0, assuming no rain)",type='warn')
  }

  # Missing wind speed:
  if(is.null(MetData$WindSpeed)){
    if(!is.null(Parameters$WindSpeed)){
      MetData$WindSpeed= Parameters$WindSpeed # assume constant windspeed
      warn.var(Var= "WindSpeed","constant (= Parameters$WindSpeed)",type='warn')
    }else{
      warn.var(Var= "WindSpeed", replacement= "Parameters$WindSpeed (constant value)",type='error')
    }
  }
  MetData$WindSpeed[MetData$WindSpeed<0.01]= 0.01
  # Missing atmospheric CO2 concentration:
  if(is.null(MetData$CO2)){
    if(!is.null(Parameters$CO2)){
      MetData$CO2= Parameters$CO2 # assume constant windspeed
      warn.var(Var= "CO2","constant (= Parameters$CO2)",type='warn')
    }else{
      warn.var(Var= "CO2", replacement= "Parameters$CO2 (constant value)",type='error')
    }
  }

  # Missing DegreeDays:
  if(is.null(MetData$DegreeDays)){
    MetData$DegreeDays=
      GDD(Tmax= MetData$Tmax,Tmin= MetData$Tmin, MinTT= Parameters$MinTT,
          MaxTT = Parameters$MaxTT)
    warn.var(Var= "DegreeDays","Tmax, Tmin and MinTT",type='warn')
  }

  # Missing diffuse fraction:
  if(is.null(MetData$FDiff)){
    MetData$FDiff=
      Diffuse_d(DOY = MetData$DOY, RAD = MetData$RAD,
                Latitude = Parameters$Latitude,type = "Spitters")
    warn.var(Var= "FDiff","DOY, RAD and Latitude using Diffuse_d()",type='warn')
  }


  MetData$year= lubridate::year(MetData$Date)
  MetData$DOY= lubridate::yday(MetData$Date)

  # Correct the noon hour by the Timezone if the user use TZ="UTC":
  if(Sys.timezone()=="UTC"|Sys.timezone()=="GMT"){
    cor_tz= Parameters$TimezoneCF*60*60
  }else{
    # Else R use the user time zone (with warning).
    warning("Meteo file uses this time-zone: ",Sys.timezone(),". Set it to \"UTC\" if you want to use ",
            "the timezone from your parameter file")
    cor_tz= 1
  }

  # Solar zenithal angle at noon (radian):
  MetData$ZEN=
    solartime::computeSunPosition(timestamp = MetData$Date+60*60*12+cor_tz,
                                  latDeg = Parameters$Latitude,
                                  longDeg = Parameters$Longitude)%>%
    as.data.frame()%>%{sin(.$elevation)}%>%acos(.)

  # Compute net radiation using the Allen et al. (1998) equation :

  if(!is.null(MetData$RH)){
    MetData$Rn= Rad_net(DOY = MetData$DOY,RAD = MetData$RAD,Tmax = MetData$Tmax,
                        Tmin = MetData$Tmin, Rh =  MetData$RH,
                        Elevation = Parameters$Elevation,Latitude = Parameters$Latitude,
                        albedo = Parameters$albedo)
  }else if(!is.null(MetData$VPD)){
    MetData$Rn= Rad_net(DOY = MetData$DOY,RAD = MetData$RAD,Tmax = MetData$Tmax,
                        Tmin = MetData$Tmin, VPD =  MetData$VPD,
                        Elevation = Parameters$Elevation,Latitude = Parameters$Latitude,
                        albedo = Parameters$albedo)
  }

  DaysWithoutRain= Rain= NULL # To avoid notes by check
  MetData= as.data.table(MetData)
  MetData[, DaysWithoutRain := 0]; MetData[Rain > 0, DaysWithoutRain := 1]
  MetData$DaysWithoutRain= sequence(MetData[,.N,cumsum(DaysWithoutRain)]$N)-1
  MetData= as.data.frame(MetData)

  MetData$Air_Density= bigleaf::air.density(MetData$Tair,MetData$Pressure/10)

  # Force to keep only the input variable the model need to avoid any issues:
  Varnames= c('year','DOY','Date','Rain','Tair','RH','RAD','Pressure',
              'WindSpeed','CO2','DegreeDays','PAR','FDiff',
              'VPD','Rn','Tmax','Tmin','DaysWithoutRain','Air_Density','ZEN')
  MetData= MetData[colnames(MetData)%in%Varnames]
  MetData[,-c(1:3)]= round(MetData[,-c(1:3)],4)

  attr(MetData,"unit")=
    data.frame(Var= Varnames,
               unit=c("year","day","POSIXct date","mm","Celsius","%","MJ m-2 d-1","hPa",
                      "m s-1","ppm","Celsius","MJ m-2 d-1","Fraction","hPa","MJ m-2 d-1",
                      "Celsius","Celsius","day","kg m-3","rad"))

  message("Meteo computation done\n")
  message(paste("\n", crayon::green$bold$underline("Meteo computation done\n")))
  invisible(MetData)
end