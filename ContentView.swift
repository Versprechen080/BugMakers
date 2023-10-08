//
//  ContentView.swift
//  product2 Watch App
//
//  Created by zq on 19/9/2023.
//


import SwiftUI
import WatchConnectivity
import WatchKit
import Combine
import UIKit
import UserNotifications
import CoreMotion
import CoreML
import Foundation

// set up user’s defaults database
struct UserDefaultsKeys {
    static let appInstalledKey = "AppInstalledKey"
}
extension UserDefaults {
    var isAppInstalledBefore: Bool {
        get {
            return bool(forKey: UserDefaultsKeys.appInstalledKey)
        }
        set {
            setValue(newValue, forKey: UserDefaultsKeys.appInstalledKey)
        }
    }
}

/* The entry of the app
   Has two buttons in it, setting view and statistics view
   When opening the app for the first time, it will show the alert view firstly.
   The programme will run normally if the user presses the button "Agree",
   or the programme will exit normally if the user presses the button " Disagree"
   */

struct ContentView: View {
    @StateObject var viewModel = AppViewModel()
    @State private var timer2: Timer?
    @State private var isWashStart: Bool = false
    @State private var isWashStop: Bool = true
    
    @State private var SundayData: Int = UserDefaults.standard.integer(forKey:"Sunday")
    @State private var MondayData: Int = UserDefaults.standard.integer(forKey:"Monday")
    @State private var TuesdayData: Int = UserDefaults.standard.integer(forKey:"Tuesday")
    @State private var WednesdayData: Int = UserDefaults.standard.integer(forKey:"Wednesday")
    @State private var ThursdayData: Int = UserDefaults.standard.integer(forKey:"Thursday")
    @State private var FridayData: Int = UserDefaults.standard.integer(forKey:"Friday")
    @State private var SaturdayData: Int = UserDefaults.standard.integer(forKey:"Saturday")
    
    @State private var showSettingView = false
    @State private var showStatisticsView = false
    @State private var isShowingAlarmView = false
    @State private var isShowingAlarmView2 = false
    @State private var isCrossButtonTapped = false
    @State private var isCheckButtonTapped = false
    @State private var isTimerRunning = false
    @State private var timeRemaining = 0
    @State private var checkCounter = 0
    
    @State private var predictionResult: Int = 0 // The value returned by the ML model
    @State private var motionManager = CMMotionManager()
    @State private var recordingCount = 0
    @State private var sensorData: [[Double]] = []
    @AppStorage("localDateString") var storedDate: String = "2023-09-24"
    @State private var showPrivacyAlert = false

    var body: some View {
        GeometryReader { geometry in
            NavigationStack {
                VStack {
                    Button(action: {
                        showSettingView = true
                    }) {
                        Text("Setting")
                    }
                    .padding()
                    Button(action: {
                        showStatisticsView = true
                    }) {
                        Text("Statistics")
                    }
                    .padding()
                }
                .padding()
                .navigationTitle("Navigation")
                
                /* ensure the  ethics, security and data privacy
                   if the user presses the "agree" button,
                 */
                .alert(isPresented: $showPrivacyAlert) {
                    Alert(title: Text("Privacy limitations"),
                          message: Text("Do you agree to allow this app to access your private data (hand movement data)?"),
                          primaryButton: .default(Text("Agree")) {
                            self.generalTimer()
                            print ("first start timer")
                          },
                          secondaryButton: .destructive(Text("Disagree"), action: {
                            exit(0)
                          })
                    )
                }

                .sheet(isPresented: $showSettingView) {
                    SettingView(timeRemaining: $timeRemaining, isTimerRunning:  $isTimerRunning, isCrossButtonTapped: $isCrossButtonTapped, isCheckButtonTapped: $isCheckButtonTapped, isShowingAlarmView: $isShowingAlarmView, checkCounter: $checkCounter)
                }
                .sheet(isPresented: $showStatisticsView) {
                    StatisticsView(SundayData: $SundayData, MondayData: $MondayData, TuesdayData: $TuesdayData, WednesdayData: $WednesdayData, ThursdayData: $ThursdayData, FridayData: $FridayData, SaturdayData: $SaturdayData)
                        
                }
                .sheet(isPresented: $isShowingAlarmView) {
                    AlarmView()
                }
                .onAppear {
                    if viewModel.customValue == 0 {
                        self.showPrivacyAlert = true
                        generalTimer()
                    } else {
                        generalTimer()
                    }
     
                }
                .sheet(isPresented: $isWashStart) {
                    AlarmView2(isWashStart: $isWashStart, isWashStop: $isWashStop)
                }
            }
        }
    }
    
    /* Use the model every 4 seconds to monitor handwashing activity and make predictions
       Based on the predictions, it determines whether the user has started or stopped washing their hands.
       Additionally, it records the number of times the user washes their hands per day for each day of the week.
     */
    func generalTimer() {
        var count: Int = 0
        setZeros()
        timer2 = Timer.scheduledTimer(withTimeInterval: 2.5, repeats: true) { _ in
            DispatchQueue.global().async {
                DispatchQueue.main.async {
                    count += 1
                    print("count:\(count)")
                    makePrediction()
                     // indicate that the user is washing hands
                    if predictionResult == 1 {
                        timer2?.invalidate()
                        isWashStart = true
                
                        isWashStop = false
                        DispatchQueue.main.async {
                            print("start timer again!")
                            generalTimer()
                        }
                    }
                    /* Determine which day of the week it is and add the data from this
                       handwashing session to the variable that records the number of
                       handwashing times per day
                     */
                    if isWashStart == true && predictionResult == 0 {
                        if currentDayOfWeek() == "Sunday" {
                            SundayData += 1
                            UserDefaults.standard.set(SundayData, forKey: "Sunday")
                            print("Sunday data: \(SundayData)")
                        } else if currentDayOfWeek() == "Monday" {
                            MondayData += 1
                            UserDefaults.standard.set(MondayData, forKey: "Monday")
                            print("MondayData: \(MondayData)")
                        } else if currentDayOfWeek() == "Tuesday" {
                            TuesdayData += 1
                            UserDefaults.standard.set(TuesdayData, forKey: "Tuesday")
                            print("TuesdayData: \(TuesdayData)")
                        } else if currentDayOfWeek() == "Wednesday" {
                            WednesdayData += 1
                            UserDefaults.standard.set(WednesdayData, forKey: "Wednesday")
                            print("WednesdayData: \(WednesdayData)")
                        } else if currentDayOfWeek() == "Thursday" {
                            ThursdayData += 1
                            UserDefaults.standard.set(ThursdayData, forKey: "Thursday")
                            print("ThursdayData: \(ThursdayData)")
                        } else if currentDayOfWeek() == "Friday" {
                            FridayData += 1
                            UserDefaults.standard.set(FridayData, forKey: "Friday")
                            print("FridayData: \(FridayData)")
                        } else if currentDayOfWeek() == "Saturday" {
                            SaturdayData += 1
                            UserDefaults.standard.set(SaturdayData, forKey: "Saturday")
                            print("SaturdayData: \(SaturdayData)")
                        }
                        isWashStop = true
                        timer2?.invalidate()
                        DispatchQueue.main.async {
                            print("restart timer !")
                            generalTimer()
                        }
                    }
               
                    if count >= 5000 {
                        timer2?.invalidate()
                        print("Timer invalidated.")
                    }
                }
            }
        }
    }
    
    // Return which day of the week it is today
    func currentDayOfWeek() -> String {
        let calendar = Calendar.current
        let today = Date()
        let weekdays = calendar.weekdaySymbols
        let weekday = calendar.component(.weekday, from: today)
        
        return weekdays[weekday - 1]
    }
    
    /* Check whether the current day is Sunday and if it's a new Sunday
       compared with the previous stored date. If both conditions are met, the function resets handwashing
       data counters to zero
     */
    func setZeros() {
        let today = Date()
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.timeZone = TimeZone.current

        if currentDayOfWeek() == "Sunday" {
            let localDateString = formatter.string(from: today)
            if storedDate != localDateString {
                resetData()
                storedDate = localDateString
            }

        }

    }

    /* Reset the data variables corresponding to each day of the week to zero. 
       Additionally, it updates the UserDefaults with the newly reset values to persist this information.
    */
    func resetData() {
        SundayData = 0
        UserDefaults.standard.set(SundayData, forKey: "Sunday")
        
        MondayData = 0
        UserDefaults.standard.set(TuesdayData, forKey: "Monday")
        
        TuesdayData = 0
        UserDefaults.standard.set(TuesdayData, forKey: "Tuesday")
        
        WednesdayData = 0
        UserDefaults.standard.set(WednesdayData, forKey: "Wednesday")
        
        ThursdayData = 0
        UserDefaults.standard.set(ThursdayData, forKey: "Thursday")
        
        FridayData = 0
        UserDefaults.standard.set(FridayData, forKey: "Friday")
        
        SaturdayData = 0
        UserDefaults.standard.set(SaturdayData, forKey: "Saturday")
    }
    
    /* Initializing and collecting device motion data. 
       It captures user acceleration and rotation rates from the device's sensors.
       Once a predetermined amount of records (200 records in this instance) is gathered,
       it ceases capturing and prepares the data for model prediction.
     */
    func makePrediction() {
        self.sensorData.removeAll()
        self.recordingCount = 0
        motionManager.deviceMotionUpdateInterval = 0.01
        motionManager.startDeviceMotionUpdates(to: OperationQueue.current!) { (data, error) in
            if let data = data {
                let record: [Double] = [data.userAcceleration.x, data.userAcceleration.y, data.userAcceleration.z, data.rotationRate.x, data.rotationRate.y, data.rotationRate.z]
                self.sensorData.append(record)
                self.recordingCount += 1
                if self.recordingCount >= 200 {
                    self.motionManager.stopDeviceMotionUpdates()
                    self.dataToModel()
                    self.recordingCount = 0
                    self.sensorData.removeAll()
                   
                }
            }
        }
    }

    /* Processing the captured motion data to be fit for model prediction.
       Once the data is processed, it's fed into the model to generate a prediction.
     */
    func dataToModel() {
        // Load the model
        let model = Bundle.main.url(forResource: "coreml_model", withExtension: "mlmodelc")!
        let compiled_Model = try! MLModel(contentsOf: model)
        
        // Reshape the input data to match the expected shape (6 x 200)
        var reshape_input: [Double] = []
        for record in self.sensorData {
            reshape_input += record
        }
        // Convert the input data into an MLMultiArray
        let input = try! MLMultiArray(shape: [NSNumber(value: 6), NSNumber(value: 200)], dataType: .double)
        for (position, value) in reshape_input.enumerated() {
            input[position] = NSNumber(value: value)
        }
       let mapped_input: [String: Any] = ["input_18": input]
        // Convert the input dictionary to MLFeatureProvider
        let featureProvider = try! MLDictionaryFeatureProvider(dictionary: mapped_input)
        // Make predictions using the model
        let prediction = try! compiled_Model.prediction(from: featureProvider)
        if let output = prediction.featureValue(for: "Identity")?.multiArrayValue {
            if output.count == 2 {
                let threshold: Double = 0.6
                if output[0].doubleValue > threshold {
                    predictionResult = 0
                } else {
                    predictionResult = 1
                }
            }
        }
        print("predictionResult:\(predictionResult)")
    }
}
// Preparing a data model for the bar chart
struct DataItem: Identifiable {
    var id = UUID()
    var name: String
    @AppStorage("value") var value: Int = UserDefaults.standard.integer(forKey: "value")
}

// A view that displays statistical data for each day of the week as a histogram.
struct StatisticsView: View {
    @Binding var SundayData: Int
    @Binding var MondayData: Int
    @Binding var TuesdayData: Int
    @Binding var WednesdayData: Int
    @Binding var ThursdayData: Int
    @Binding var FridayData: Int
    @Binding var SaturdayData: Int
    var chartData: [DataItem]
        
    // Initializing the view with data for each day.
    init(SundayData: Binding<Int>, MondayData: Binding<Int>, TuesdayData: Binding<Int>, WednesdayData: Binding<Int>, ThursdayData: Binding<Int>, FridayData: Binding<Int>, SaturdayData: Binding<Int>) {
        _SundayData = SundayData
        _MondayData = MondayData
        _TuesdayData = TuesdayData
        _WednesdayData = WednesdayData
        _ThursdayData = ThursdayData
        _FridayData = FridayData
        _SaturdayData = SaturdayData

        chartData = [
            DataItem(name: "Su", value: SundayData.wrappedValue),
            DataItem(name: "M", value: MondayData.wrappedValue),
            DataItem(name: "Tu", value: TuesdayData.wrappedValue),
            DataItem(name: "W", value: WednesdayData.wrappedValue),
            DataItem(name: "Th", value: ThursdayData.wrappedValue),
            DataItem(name: "F", value: FridayData.wrappedValue),
            DataItem(name: "Sa", value: SaturdayData.wrappedValue),
        ]
    }
    var body: some View {
            VStack {
                // Display the histogram only if there's data for at least one day.
                if SundayData != 0 || MondayData != 0 || TuesdayData != 0 || WednesdayData != 0 || ThursdayData != 0 || FridayData != 0 || SaturdayData != 0 {
                    HistogramView(
                        title: "last 7 days", data: chartData)
                    .frame(width: 180, height: 140, alignment: .center)
                    
                    Spacer()
                }
               
            }

        
       
    }
}

// A histogram view that combines a header and area to show data.
struct HistogramView: View {
    var title: String
    var data: [DataItem]

    var body: some View {
        GeometryReader { gr in
            let headHeight = gr.size.height * 0.10
            VStack {
                // Header of the histogram.
                HistogramHeaderView(title: title, height: headHeight)
                // Area that displays the actual bars of the histogram.
                HistogramAreaView(data: data)
            }
        }
    }
}

// The header view of the histogram.
struct HistogramHeaderView: View {
    var title: String
    var height: CGFloat
    
    var body: some View {
        // Display the title of the histogram.
        Text(title)
            .frame(height: height)
    }
}

// The area view of the histogram where bars for each data point are shown.
struct HistogramAreaView: View {
    var data: [DataItem]
    
    var body: some View {
        GeometryReader { gr in
            let fullBarHeight = gr.size.height * 0.90
            let maxValue = data.map { $0.value }.max()!
            
            ZStack {
                // Base shape for the histogram area.
                RoundedRectangle(cornerRadius: 5.0)
                    .fill(Color(#colorLiteral(red: 1, green: 1, blue: 1, alpha: 0)))
                VStack {
                    HStack(spacing:0) {
                        // Create a bar for each data item.
                        ForEach(data) { item in
                            ColumnView(
                                name: item.name,
                                value: Double(item.value),
                                maxValue: Double(maxValue),
                                fullBarHeight: Double(fullBarHeight))
                        }
                    }
                    .padding(4)
                }
            }
        }
    }
}

// Represents a single column/bar in the histogram.
struct ColumnView: View {
    var name: String
    var value: Double
    var maxValue: Double
    var fullBarHeight: Double
    var body: some View {
        // Calculate the height of the bar based on the value.
        let barHeight = (Double(fullBarHeight) / maxValue) * value
        VStack {
            Spacer()
            ZStack {
                VStack {
                    Spacer()
                    RoundedRectangle(cornerRadius:5.0)
                        .fill(Color.red)
                        .frame(height: CGFloat(barHeight), alignment: .trailing)
                }
                
                // Value text displayed on the bar.
                VStack {
                    Spacer()
                    Text("\(value, specifier: "%.0F")")
                        .font(Font.system(size: 12))
                        .foregroundColor(.white)
                        .fontWeight(.bold)
                }
            }
            // Name of the data item (e.g., "Su", "M", etc.)
            Text(name).font(Font.system(size: 10))
        }
        .padding(.horizontal, 4)
    }
}

/*
 View for allowing users to customize the handwashing reminder interval
 Features:
 - Users can adjust the hours and minutes for the alarm using `+` and `-` buttons.
 - The user's chosen hour and minute values are stored in `savedHour` and `savedMinute` respectively.
 - Clicking the confirm button starts the timer with the set hours and minutes.
 - The alarm time can be cancelled using the cancel button.
 - Upon the timer's completion, an alarm is presented to the user.
 */
struct SettingView: View {
    @Binding var timeRemaining : Int
    @Binding var isTimerRunning : Bool
    @State private var timer: Timer?
    @Environment(\.dismiss) var dismiss
    
    @State private var hours: Int = 0
    @State private var minutes: Int = 0

    @Binding var isCrossButtonTapped : Bool
    @Binding var isCheckButtonTapped : Bool
    @State private var previousStateCheck: Bool = false
    
    @AppStorage("savedHour") private var savedHour: Int = 0
    @AppStorage("savedMinute") private var savedMinute: Int = 0
    
    @Binding var isShowingAlarmView : Bool// show alert
    @State private var timerCounter : Int = 0
    @Binding var checkCounter : Int
    @State var vibrationCounter2 = 0
    var body: some View {
        GeometryReader { geometry in
            VStack(alignment: .center, spacing: geometry.size.width * 0.02) {
                    HStack {
                        Spacer()
                        Text("Edit Alarm")
                            .font(.system(size: 23))
                            .foregroundColor(.blue)
                            .padding(.top, -15) 
                    }
                Spacer()
                    VStack(alignment: .center, spacing: geometry.size.width * 0.08) {
                        HStack(spacing: geometry.size.width * 0.13) {
                            Button("-") {
                                if self.hours > 0 {
                                    self.hours -= 1
                                } else {
                                    self.hours = 23
                                }
                            }
                            .font(.title2)
                            .frame(width: geometry.size.width * 0.25, height: geometry.size.height * 0.05)
                            .padding(.leading, -geometry.size.width*0.03)
                            
                            Text("\(self.hours) h")
                                .font(.body)
                                .frame(width: geometry.size.width * 0.22, height: geometry.size.width * 0.2)
                                .background(
                                    RoundedRectangle(cornerRadius: 10)
                                        .stroke(Color.yellow, lineWidth: 2)
                                        .frame(width: geometry.size.width * 0.3, height: geometry.size.width * 0.20)
                                )
                            
                            Button("+") {
                                if self.hours < 23 {
                                    self.hours += 1
                                } else {
                                    self.hours = 0
                                }
                            }
                            .font(.title2)
                            .frame(width: geometry.size.width * 0.25, height: geometry.size.width * 0.05)
                        }
                        
                        HStack(spacing: geometry.size.width * 0.13)
                        {
                            Button("-") {
                                if self.minutes > 0 {
                                    self.minutes -= 1
                                    
                                } else {
                                    self.minutes = 59
                                }
                            }
                            .font(.title2)
                            .frame(width: geometry.size.width * 0.25, height: geometry.size.width * 0.05)
                            .padding(.leading, -geometry.size.width*0.03)
                            Text("\(self.minutes) m")
                                .font(.body)
                                .frame(width: geometry.size.width * 0.22, height: geometry.size.width * 0.2)
                                .background(
                                    RoundedRectangle(cornerRadius: 10)
                                        .stroke(Color.yellow, lineWidth: 2)
                                        .frame(width: geometry.size.width * 0.3, height: geometry.size.width * 0.20)
                                )
                            Button("+") {
                                if self.minutes < 59 {
                                    self.minutes += 1
                                   // self.minutes = self.minutes
                                } else {
                                    self.minutes = 0
                                }
                            }
                            .font(.title2)
                            .frame(width: geometry.size.width * 0.25, height: geometry.size.width * 0.15)
                        }
                        .padding(.horizontal)
                    }
                    Spacer().frame(height: 1)
                
                    HStack(alignment: .center, spacing: geometry.size.width * 0.44) {
                            // set the cancel button
                            Button(action: {
                                withAnimation {
                                    
                                    isCrossButtonTapped.toggle()
                                    
                                }
                            }) {
                                Image(systemName: "multiply.circle.fill")
                                    .font(.largeTitle)
                                    .foregroundColor(.gray)

                            }
                            .buttonStyle(PlainButtonStyle())
                            .alignmentGuide(.leading) { _ in
                                -5
                            }
                        
                            // set confirm button
                            Button(action: {
                                withAnimation {
                                    checkCounter += 1
                                    isCheckButtonTapped.toggle()
                                    isTimerRunning.toggle()
                                }
                                savedMinute = self.minutes
                                savedHour = self.hours
                                timeRemaining = savedHour * 60 + savedMinute * 1
                                startTimer()
                                dismiss()
                            }) {
                                Image(systemName: "checkmark.circle.fill")
                                    .font(.largeTitle)
                                    .foregroundColor(.green)
                            }
                            .buttonStyle(PlainButtonStyle())
                            .alignmentGuide(.leading) { _ in
                                -5
                            }
                        }
                .onAppear {
                    hours = savedHour
                    minutes = savedMinute
                }
               
            }
            .sheet(isPresented: $isShowingAlarmView) {
                AlarmView()
            }
        }
    }
    
    /* This function starts a timer that counts down the `timeRemaining` variable by one every second.
       The timer's behavior is conditional based on the state of several variables:
       - When the check button is tapped (`isCheckButtonTapped`) once (`checkCounter == 1`), it decreases the `timeRemaining`.
       - If the cross button is tapped (`isCrossButtonTapped`), the timer is corrupted by calling `justTimerCorrupt()`.
       - If `checkCounter` exceeds 1, the timer is also corrupted.
       - When `timeRemaining` reaches 0, it calls `handleTimerCompletion()` to handle the timer's completion.
     */
    func startTimer() {
        timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { timer in
            DispatchQueue.global().async {
                DispatchQueue.main.async {
                    if self.timeRemaining > 0 {
                        if !isCrossButtonTapped && isCheckButtonTapped && checkCounter == 1 {
                            print("timeRemaining: \(timeRemaining)")
                            self.timeRemaining -= 1
                           
                        } else if !isCrossButtonTapped && !isCheckButtonTapped && checkCounter == 1{
                            print("timeRemaining: \(timeRemaining)")
                            self.timeRemaining -= 1
                           
                        } else if isCrossButtonTapped {
                            justTimerCorrupt()
                        } else if checkCounter > 1 {
                            justTimerCorrupt()
                        }
                    } else if self.timeRemaining == 0 {
                        self.handleTimerCompletion()
                    }
                }
            }
        } 
    }
    func justTimerCorrupt() { //corrupt the timer abnormally
        previousStateCheck = isCheckButtonTapped
        timer?.invalidate()
        timer = nil
        isTimerRunning = false
        isCrossButtonTapped = false
        isCheckButtonTapped = false
        isShowingAlarmView = false
        checkCounter -= 1
    }
    
    // forcefully stops the timer and resets all related states to their default values.
    func handleTimerCompletion() {
        print("Timer completed!")
        secondLocalNotification()
        isTimerRunning = false
        timer?.invalidate() // stop the timer
        timer = nil // release the timer
        isShowingAlarmView = true
        Timer.scheduledTimer(withTimeInterval: 0.7, repeats: true) { timer in
            if vibrationCounter2 < 2 {
                WKInterfaceDevice.current().play(.notification)
                vibrationCounter2 += 1
            }
        }
        isCrossButtonTapped = false
        timeRemaining = savedHour * 60 + savedMinute * 1 // reset the timer
        startTimer() //restart the timer
    }
    
    // This function triggers a local notification prompting the user to wash their hands.
    func secondLocalNotification() {
        let content = UNMutableNotificationContent()
        content.title = "Time for Washing hands!"
        content.body = " "
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 0.01, repeats: false)
        let request = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: trigger)
        UNUserNotificationCenter.current().add(request) { (error) in
            if let error = error {
                print("Error sending notification: \(error.localizedDescription)")
            } else {
                print("Notification sent successfully!")
            }
        }
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { granted, error in
            if granted {
                print("App has granted notification")
            } else {
                print("Error: App does not have granted notification")
            }
        }
    }
}

/* Displays an animated image sequence that works as an alarm.
   The animation runs from frame 31 to frame 50 and loops back to the beginning upon completion.
 */
struct AlarmView: View {
    @Environment(\.dismiss) var dismiss
    @State private var currentFrame = 31
    let totalFrames2 = 50
    let frameDuration2 = 0.1
    @State var showRedImage = true
    var body: some View {
        VStack {
            Image("red-\(currentFrame)")
                .resizable()
                .scaledToFit()
                .frame(width: 187, height: 187)
                .offset(x: 0, y: 8.5)
        }
        .onAppear {
            Timer.scheduledTimer(withTimeInterval: frameDuration2, repeats: true) { timer in
                if self.currentFrame < self.totalFrames2 {
                    self.currentFrame += 1
                } else {
                    self.currentFrame = 31
                }
            }
        }
    }
}

/* This view toggles between an animated image sequence and a static blue image based on certain conditions.
   The animated sequence runs from the 72nd frame to the 74th frame.
   When the washing stops (`isWashStop` is true), the blue image is displayed.
   When both `isWashStart` and `isWashStop` are true, there's a delay of one second to set `isWashStart` to false.
 */
struct AlarmView2: View {
    @State private var vibrationCounter = 0
    @State private var currentFrame = 72
    @Binding var isWashStart: Bool
    @Binding var isWashStop: Bool
    let totalFrames = 74
    let frameDuration = 0.04
    @State var showBlueImage = false
            
    var body: some View {
        Group {
            if showBlueImage {
                Image("blue")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 175, height: 175)
                    .offset(x: 0, y: 8.5)
            } else {
                Image("image\(currentFrame)")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 190, height: 190)
                    .offset(x: 0, y: 13)
            }
        }   
        .onAppear {
            Timer.scheduledTimer(withTimeInterval: frameDuration, repeats: true) { timer in
                if self.currentFrame < self.totalFrames {
                    self.currentFrame += 1
                } else {
                    self.currentFrame = 0
                }

                showBlueImage = isWashStop

            }
            Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { timer in
                if isWashStart && isWashStop {
                    if vibrationCounter < 2 {
                        WKInterfaceDevice.current().play(.notification)
                        vibrationCounter += 1
                        print ("1")
                    }
                    DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {
                        isWashStart = false
                    }
                }
            }
        }
    }
}

// Preview interfaces
struct StatisticsView_Previews: PreviewProvider {
    static var previews: some View {
        StatisticsView(SundayData: .constant(0), MondayData: .constant(0), TuesdayData: .constant(0), WednesdayData: .constant(0), ThursdayData: .constant(0), FridayData: .constant(0), SaturdayData: .constant(0))
        
    }
}

struct SettingView_Previews: PreviewProvider {
    static var previews: some View {
        SettingView(timeRemaining: .constant(0), isTimerRunning: .constant(false), isCrossButtonTapped: .constant(false), isCheckButtonTapped: .constant(false), /*selectedHour: .constant(0), selectedMinute: .constant(0),*/ isShowingAlarmView: .constant(false), checkCounter: .constant(0))
    }
}

struct AlarmView_Previews: PreviewProvider {
    static var previews: some View {
        AlarmView()
    }
}

struct AlarmView2_Previews: PreviewProvider {
    static var previews: some View {
        AlarmView2(isWashStart: .constant(false), isWashStop: .constant(true))
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}




