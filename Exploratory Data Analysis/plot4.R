Elec_Con<-data.table::fread(input = "household_power_consumption.txt"
                            , na.strings="?"
)

Elec_Con[, Global_active_power:=lapply(.SD, as.numeric), .SDcols = c("Global_active_power")]
Elec_Con[, dateTime := as.POSIXct(paste(Date, Time), format = "%d/%m/%Y %H:%M:%S")]

Elec_Con<-Elec_Con[(dateTime >= "2007-02-01") & (dateTime < "2007-02-03")]

png("plot4.png", width=480, height=480)

par(mfrow=c(2,2))

plot(Elec_Con[, dateTime], Elec_Con[, Global_active_power], type="l", xlab="", ylab="Global Active Power")
plot(Elec_Con[, dateTime],Elec_Con[, Voltage], type="l", xlab="datetime", ylab="Voltage")
plot(Elec_Con[, dateTime], Elec_con[, Sub_metering_1], type="l", xlab="", ylab="Energy sub metering")
lines(Elec_Con[, dateTime], Elec_COn[, Sub_metering_2], col="red")
lines(Elec_Con[, dateTime], Elec_Con[, Sub_metering_3],col="blue")
legend("topright", col=c("black","red","blue")
       , c("Sub_metering_1  ","Sub_metering_2  ", "Sub_metering_3  ")
       , lty=c(1,1)
       , bty="n"
       , cex=.5) 
plot(Elec_Con[, dateTime], Elec_Con[,Global_reactive_power], type="l", xlab="datetime", ylab="Global_reactive_power")

dev.off(