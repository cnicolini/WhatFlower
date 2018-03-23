//
//  ViewController.swift
//  WhatFlower
//
//  Created by cn on 3/10/18.
//  Copyright © 2018 nicolinihome. All rights reserved.
//

import UIKit
import CoreML
import Vision
import Alamofire
import SwiftyJSON
import SDWebImage
import ChameleonFramework

class ViewController: UIViewController, UIImagePickerControllerDelegate, UINavigationControllerDelegate  {
    
    @IBOutlet weak var cameraButton: UIBarButtonItem!
    
    @IBOutlet weak var imageSelected: UIImageView!
    
    @IBOutlet weak var wikiLabel: UILabel!
    
    let imagePicker = UIImagePickerController()
    
    //MARK: - Wikipedia API
    // Request Sample: https://en.wikipedia.org/w/api.php?action=query&format=json&titles=Sunflower&prop=extracts&exintro=&explaintext=&indexpageids=&redirects=1
    
    let wikipediaURl = "https://en.wikipedia.org/w/api.php"
    
    var wikipediaParams : [String:String] = [
        "format" : "json",
        "action" : "query",
        "prop" : "extracts|pageimages",
        "exintro" : "",
        "explaintext" : "",
        "indexpageids" : "",
        "redirects" : "1",
        "pithumbsize" : "500"
    ]
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        imagePicker.delegate = self
        imagePicker.allowsEditing = true
        
        if UIImagePickerController.isSourceTypeAvailable(.camera) {
            imagePicker.sourceType = .camera
        }
        else {
            imagePicker.sourceType = .photoLibrary
        }
    }
    
    @IBAction func cameraTapped(_ sender: UIBarButtonItem) {
        
        present(imagePicker, animated: true, completion: nil)
        
    }
    
    func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [String : Any]) {
        
        if let image = info[UIImagePickerControllerEditedImage] as? UIImage {
            imageSelected.image = nil
            
            guard let ciimage = CIImage(image: image) else { fatalError("Error converting image to CIImage.") }
            
            detect(ciimage)
            
        }
        
        imagePicker.dismiss(animated: true, completion: nil)
        
    }
    
    func detect(_ image: CIImage) {
        
        guard let model = try? VNCoreMLModel(for: FlowerClassifier().model) else { fatalError("Error loading CoreML model.") }
        
        let request = VNCoreMLRequest(model: model) { (request, error) in
            
            var flowerName: String?
            var errorStr: String?
            
            if error != nil {
                errorStr = error.debugDescription
            }
            else {
                guard let results = request.results as? [VNClassificationObservation] else { fatalError("Model failed to process the image.") }
                
                print(results)
                
                if let result = results.first {
                    flowerName = result.identifier.capitalized
                }
                else {
                    errorStr = "Could not identify image."
                }
            }
            self.updateUI(title: flowerName, errorStr: errorStr)
        }
        
        let handler = VNImageRequestHandler(ciImage: image)
        
        do {
            try handler.perform([request])
        }
        catch {
            print("Error handling request \(error).")
        }
        
    }
    
    func updateUI(title: String?, errorStr: String?) {
        
        DispatchQueue.main.async {
            self.navigationItem.title = title ?? errorStr
            
        }
        
        if title == nil {
            return
        }
        
        
        getWikiData(title: title!)
        
    }
    
    func getWikiData(title: String) {
        
        wikipediaParams["titles"] = title
        
        Alamofire.request(wikipediaURl, method: .get, parameters: wikipediaParams).responseJSON {
            response in
            if response.result.isSuccess {
                print("Success! Got the wikipedia doc.")
                
                let wikiJSON : JSON = JSON(response.result.value!)
                print(wikiJSON)
                
                let pageId = wikiJSON["query"]["pageids"][0].stringValue
                
                let wikiExtract = wikiJSON["query"]["pages"][pageId]["extract"].stringValue
                self.wikiLabel.text = wikiExtract
                
                let flowerImageURL = wikiJSON["query"]["pages"][pageId]["thumbnail"]["source"].stringValue
                self.imageSelected.sd_setImage(with: URL(string: flowerImageURL), completed: { (uiImage, _, _, _) in
                    
                    let imageColor = UIColor(averageColorFrom: uiImage!)
                    self.navigationController?.navigationBar.barTintColor = imageColor
                    self.navigationController?.navigationBar.tintColor = ContrastColorOf(imageColor, returnFlat: true)
                    self.navigationController?.navigationBar.titleTextAttributes = [NSAttributedStringKey.foregroundColor : ContrastColorOf(imageColor, returnFlat: true)]
                    self.view.backgroundColor = imageColor.lighten(byPercentage: 0.2)
                    self.wikiLabel.textColor = ContrastColorOf(imageColor, returnFlat: true)
                })
                
            }
            else {
                self.wikiLabel.text = "Error \(response.result.error!)"
            }
        }
        
    }
    
}

