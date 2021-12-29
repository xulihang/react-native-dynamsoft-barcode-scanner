import DynamsoftCameraEnhancer
import DynamsoftBarcodeReader
import React

@objc(DynamsoftBarcodeScannerViewManager)
class DynamsoftBarcodeScannerViewManager: RCTViewManager  {

  override func view() -> (DynamsoftBarcodeScannerView) {
      let view = DynamsoftBarcodeScannerView()
      view.setBridge(bridge: self.bridge)
      return view
  }
}



class DynamsoftBarcodeScannerView : UIView, DMDLSLicenseVerificationDelegate, DCELicenseVerificationListener, DBRTextResultDelegate {
    @objc var dceLicense: String = "DLS2eyJvcmdhbml6YXRpb25JRCI6IjIwMDAwMSJ9"
    @objc var dbrLicense: String = ""
    @objc var organizationID: String = "200001"
    var dce:DynamsoftCameraEnhancer! = nil
    var barcodeReader:DynamsoftBarcodeReader! = nil
    var dceView:DCECameraView! = nil
    var bridge:RCTBridge! = nil

    func setBridge(bridge:RCTBridge){
        self.bridge = bridge
    }
    
    @objc var isScanning: Bool = false {
        didSet {
            if isScanning
            {
                if (barcodeReader == nil){
                    configurationDBR()
                    configurationDCE()
                    updateSettings()
                }else{
                    dce.resume()
                }
            }else{
                if dce != nil {
                    dce.pause()
                }
            }
        }
    }
    
    @objc var flashOn: Bool = false {
        didSet {
            toggleFlash()
        }
    }
    
    @objc var cameraID: String = "" {
        didSet {
            if dce != nil {
                if cameraID != "" {
                    var error: NSError? = NSError()
                    dce.selectCamera(cameraID, error: &error)
                }
            }
        }
    }
    
    @objc var template: String = "" {
        didSet {
            updateTemplate()
        }
    }
    
    func updateSettings(){
        toggleFlash()
        updateTemplate()
    }
    
    func toggleFlash(){
        if dce != nil {
            if flashOn
            {
                dce.turnOnTorch()
            }else{
                dce.turnOffTorch()
            }
        }
    }
    
    func updateTemplate(){
        if barcodeReader != nil {
            if (template != ""){
                var error: NSError? = NSError()
                barcodeReader.initRuntimeSettings(with: template, conflictMode: EnumConflictMode.overwrite, error: &error)
            }else{
                var error: NSError? = NSError()
                barcodeReader.resetRuntimeSettings(&error)
            }
        }
    }
    
    func configurationDBR() {
        let dls = iDMDLSConnectionParameters()
        if (dbrLicense != ""){
            barcodeReader = DynamsoftBarcodeReader(license: dbrLicense)
        }else{
            dls.organizationID = organizationID
            barcodeReader = DynamsoftBarcodeReader(licenseFromDLS: dls, verificationDelegate: self)
        }
    }
        
    func configurationDCE() {
        // Initialize a camera view for previewing video.
        dceView = DCECameraView.init(frame: self.bounds)
       
        self.addSubview(dceView)
        dceView.overlayVisible = true
        DynamsoftCameraEnhancer.initLicense(dceLicense, verificationDelegate: self)
        dce = DynamsoftCameraEnhancer.init(view: dceView)
        dce.open()
        onCameraOpened()
        bindDCEtoDBR()
    }

    func bindDCEtoDBR(){
        // Create settings of video barcode reading.
        let para = iDCESettingParameters.init()
        // This cameraInstance is the instance of the Dynamsoft Camera Enhancer.
        // The Barcode Reader will use this instance to take control of the camera and acquire frames from the camera to start the barcode decoding process.
        para.cameraInstance = dce
        // Make this setting to get the result. The result will be an object that contains text result and other barcode information.
        para.textResultDelegate = self
        // Bind the Camera Enhancer instance to the Barcode Reader instance.
        barcodeReader.setCameraEnhancerPara(para)
    }
    
    public func dlsLicenseVerificationCallback(_ isSuccess: Bool, error: Error?) {
        if(error != nil)
        {
            print("dbr dls error")
        }
    }
    
    func dceLicenseVerificationCallback(_ isSuccess: Bool, error: Error?) {
        if(error != nil){
            print("dce dls error")
        }
    }
    
    // Obtain the recognized barcode results from the textResultCallback and display the results
    public func textResultCallback(_ frameId: Int, results: [iTextResult]?, userData: NSObject?) {
        let count = results?.count ?? 0
        let array = NSMutableArray()
        for index in 0..<count {
            let tr = results![index]
            let result = NSMutableDictionary()
            result["barcodeText"] = tr.barcodeText
            result["barcodeFormat"] = tr.barcodeFormatString
            result["barcodeBytesBase64"] = tr.barcodeBytes?.base64EncodedString()
            array.add(result)
        }
        bridge.eventDispatcher().sendDeviceEvent(withName: "onScanned", body: array)
    }
    
    public func onCameraOpened(){
        let info = NSMutableDictionary()
        info["selectedCamera"] = dce.getSelectedCamera()
        print(dce.getSelectedCamera())
        let array = NSMutableArray()
        for cameraID in dce.getAllCameras(){
            array.add(cameraID)
        }
        info["cameras"] = array
        bridge.eventDispatcher().sendDeviceEvent(withName: "onCameraOpened", body: info)
    }
}
