/*
* Copyright 2015-2016 IBM Corporation
*
* Licensed under the Apache License, Version 2.0 (the "License");
* you may not use this file except in compliance with the License.
* You may obtain a copy of the License at
*
* http://www.apache.org/licenses/LICENSE-2.0
*
* Unless required by applicable law or agreed to in writing, software
* distributed under the License is distributed on an "AS IS" BASIS,
* WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
* See the License for the specific language governing permissions and
* limitations under the License.
*/


import UIKit
import OpenWhisk
import CoreLocation
import Firebase

var ref: FIRDatabaseReference!


class ViewController: UIViewController, CLLocationManagerDelegate, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
    
    @IBOutlet weak var ImagePicker: UIImageView!
    @IBOutlet weak var whiskButton: WhiskButton!
    @IBOutlet weak var outputText: UITextView!
    @IBOutlet weak var statusLabel: UILabel!
    
    var imgPicker: UIImagePickerController!
    var imgData : NSData!
    
    // Change to your whisk app key and secret.
    let WhiskAppKey = "a4206bd3-92ed-489a-bcdb-0959bc447300"
    let WhiskAppSecret = "Kiz3fbOm0Z3bVijGpNWyhlae2NIHui0V8pn6Rsjj5opv2EoV2sJFaBzXK2eqFc4b"
    
    // the URL for Whisk backend
    let baseUrl: String? = "https://openwhisk.ng.bluemix.net"
    
    // The action to invoke.
    
    // Choice: specify components
    let MyNamespace: String = "whisk.system"
    let MyPackage: String? = "util"
    let MyWhiskAction: String = "date"
    
    var MyActionParameters: [String:AnyObject]? = nil
    let HasResult: Bool = true // true if the action returns a result
    
    var session: URLSession!
    
    let locationManager = CLLocationManager()
    var currentLocation: [CLLocation]?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        ref = FIRDatabase.database().reference()
        
        // create custom session that allows self-signed certificates
        let session = URLSession(configuration: URLSessionConfiguration.default, delegate: SelfSignedNetworkDelegate(), delegateQueue:OperationQueue.main)
        
        // create whisk credentials token
        let creds = WhiskCredentials(accessKey: WhiskAppKey,accessToken: WhiskAppSecret)
        
        // Setup action using components
        whiskButton.setupWhiskAction(MyWhiskAction, package: MyPackage, namespace: MyNamespace, credentials: creds, hasResult: HasResult, parameters: nil, urlSession: session, baseUrl: baseUrl)
        
        
        navigationItem.title = "Upload Photo"
    }
    
    
    @IBAction func whiskButtonPressed(sender: AnyObject) {
        // Set latitude and longitude parameters.
        imgPicker =  UIImagePickerController()
        imgPicker.delegate = self
        
        self.cameraClick()
    }
    

    func cameraClick() {
        if(UIImagePickerController.isSourceTypeAvailable(UIImagePickerControllerSourceType.camera)) {
            imgPicker = UIImagePickerController()
            imgPicker.sourceType = .camera
            imgPicker.allowsEditing = false
            present(imgPicker, animated: true, completion: nil)
        } else {
            imgPicker.allowsEditing = false
            imgPicker.sourceType = .photoLibrary
            present(imgPicker, animated: true, completion: nil)
        }
    }

    func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [String : Any]) {
        imgPicker.dismiss(animated: true, completion: nil)
        ImagePicker.image = info[UIImagePickerControllerOriginalImage] as? UIImage
        
        whiskButton.invokeAction(parameters: nil, actionCallback: { reply, error in
            if let error = error {
                print("Oh no! \(error)")
                if case let WhiskError.httpError(description, statusCode) = error {
                    print("HttpError: \(description) statusCode:\(statusCode)")
                }
            } else if let reply = reply {
                
                
                let str = "\(reply)"
                print("reply: \(str)")
                
                if let img = self.ImagePicker.image {
                    self.imgData = UIImageJPEGRepresentation(img, 0.25)! as NSData
                }
        
                if let result = reply["result"] as? [String:AnyObject] {
                    
                    let base64String = self.imgData.base64EncodedString(options: NSData.Base64EncodingOptions.lineLength64Characters)
                    let newImage = ["image" : base64String, "timestamp" : result["date"] as! String] as [String : Any]
                     ref.child("photos").childByAutoId().setValue(newImage)
                }
            } else {
                print("Success")
            }
        })

    }
    
    func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
        dismiss(animated: true, completion: nil)
    }

    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    // Convert string timestamp to a display format
    func reformatDate(dateStr: String) -> String {
        
        var newDateStr = dateStr
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss.SSSZ"
        
        formatter.timeZone = TimeZone(abbreviation: "UTC") //NSTimeZone(name: "UTC")
        
        if let date = formatter.date(from: dateStr) {
            formatter.dateFormat = "MMM dd EEEE yyyy HH:mm"
            formatter.timeZone = TimeZone(abbreviation: "UTC")
            newDateStr = formatter.string(from: date)
        }
        
        return newDateStr
    }
    
    
}

