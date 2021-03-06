path <- getwd()
url <- "https://d396qusza40orc.cloudfront.net/getdata%2Fprojectfiles%2FUCI%20HAR%20Dataset.zip"
download.file(url, file.path(path, "dataFiles.zip"))
unzip(zipfile = "dataFiles.zip")

act_labels<-fread(file.path(path, "UCI HAR Dataset/activity_labels.txt"), col.names = c("classLabels", "activityName"))
data<-fread(file.path(path, "UCI HAR Dataset/features.txt"), col.names = c("index", "data_name"))
data_wanted<-grep("(mean|std)\\(\\)", data[, data_name])
results<-data[data_wanted, data_name]
results<-gsub('[()]', '', results)

train<-fread(file.path(path, "UCI HAR Dataset/train/X_train.txt"))[, data_wanted, with = FALSE]
data.table::setnames(train, colnames(train), results)
trainAct<-fread(file.path(path, "UCI HAR Dataset/train/Y_train.txt"), col.names = c("Activity"))
trainSub<-fread(file.path(path, "UCI HAR Dataset/train/subject_train.txt"), col.names = c("SubjectNum"))
train <- cbind(trainSub, trainAct, train)

test <- fread(file.path(path, "UCI HAR Dataset/test/X_test.txt"))[, data_wanted, with = FALSE]
data.table::setnames(test, colnames(test), results)
testAct<-fread(file.path(path, "UCI HAR Dataset/test/Y_test.txt"), col.names = c("Activity"))
testSub<-fread(file.path(path, "UCI HAR Dataset/test/subject_test.txt"), col.names = c("SubjectNum"))
test <- cbind(testSub, testAct, test)

combined <- rbind(train, test)

combined[["Activity"]] <- factor(combined[, Activity], levels = act_labels[["classLabels"]], labels = act_labels[["activityName"]])

combined[["SubjectNum"]] <- as.factor(combined[, SubjectNum])
combined <- reshape2::melt(data = combined, id = c("SubjectNum", "Activity"))
combined <- reshape2::dcast(data = combined, SubjectNum + Activity ~ variable, fun.aggregate = mean)

data.table::fwrite(x = combined, file = "tidyData.txt", quote = FALSE)
