# BugMakers
## Model Description
* "tensorflow_model.py" is the raw machine learning model for hand movements detection
* The dataset for training is not provided due to data privacy, since it was collected from team members
* The model in "tensorflow_model.py" is converted to "coreml_model.mlpackage" using code in "convert_model.ipynb"
## Runnning Project 
### Prerequisite
* Having Macbook(2021 after),Apple Watch(watchOS 9.0 above) and iPhone(IOS 16 above) at hand
* Sign up for an Apple Developer account
### Installation and Configuration
* Open "Settings" -> "Privacy & Security" -> "Developer Mode" -> "On" on both iPhone and iWatch
* Download Xcode(the latest version) from Apple Store on Macbook
* Open Xcode
* Click "Window" tab in the navigation bar and choose "Devices and Simulators"
* Using the cable connecting your iPhone with Macbook
* Unlock iPhone and iWatch and trust devices
### Compile
* click "File" in menu bar and open the submitted folder "product1"
* click "product1" icon and change the "Team" to your team name under the "Signing & Capabilities" option
* delete the empty "coreml_model" and "Assets" marked in red
* drag the "coreml_model.mlpackage" and "Assets.xcassets" in the folder "product1" to the same position under the folder "product1 Watch App"
### Execute
* Choosing your identified physical devices in the "Run Destinations" at the top centre of the Xcode interface
### Run
* Click the "Start the active scheme" button (triangle icon) at the top of navigation tab to build and run the project
## Tutorial
Instructions on how to use this application
[This is the tutorial](https://bugmakersw-wewash.squarespace.com)
## Back-up video
[This is back-up video](https://youtu.be/nkZ98nIH2X4)
