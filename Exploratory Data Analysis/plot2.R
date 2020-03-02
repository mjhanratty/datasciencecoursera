Elec_Con<-data.table::fread(input = "household_power_consumption.txt"
                            , na.strings="?"
)

Elec_Con[, Global_active_power:=lapply(.SD, as.numeric), .SDcols = c("Global_active_power")]
Elec_Con[, dateTime := as.POSIXct(paste(Date, Time), format = "%d/%m/%Y %H:%M:%S")]

Elec_Con<-Elec_Con[(dateTime >= "2007-02-01") & (dateTime < "2007-02-03")]

png("plot2.png", width=480, height=480)

plot(x=Elec_Con[, dateTime]
     , y=Elec_Con[, Global_active_power]
     , type="l", xlab="", ylab="Global Active Power (kilowatts)")

dev.off()