Elec_Con<-data.table::fread(input="household_power_consumption.txt"
                             , na.strings="?"
)

Elec_Con[, Global_active_power:=lapply(.SD, as.numeric), .SDcols=c("Global_active_power")]
Elec_Con[, Date := lapply(.SD, as.Date, "%d/%m/%Y"), .SDcols = c("Date")]

Elec_Con<-Elec_Con[(Date>="2007-02-01") & (Date<="2007-02-02")]

png("plot1.png", width=480, height=480)

hist(Elec_Con[, Global_active_power], main="Global Active Power", 
     xlab="Global Active Power (kilowatts)", ylab="Frequency", col="Red")

dev.off()



