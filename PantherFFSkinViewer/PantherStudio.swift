import Foundation
import SceneKit
import UIKit

enum PantherStudio {
    static let hairColors: [UIColor] = [.black, .brown, .darkGray, UIColor(red:0.77,green:0.48,blue:0.18,alpha:1), .purple, .systemRed]
    static let clothColors: [UIColor] = [.systemBlue, .systemRed, .systemGreen, .systemPurple, .white, .black, .systemOrange, .systemTeal]
    static let skinColors: [UIColor] = [
        UIColor(red:0.90,green:0.67,blue:0.48,alpha:1),
        UIColor(red:0.65,green:0.42,blue:0.29,alpha:1),
        UIColor(red:0.37,green:0.23,blue:0.17,alpha:1),
        UIColor(red:0.98,green:0.79,blue:0.63,alpha:1)
    ]
    static func make(character: Int, hair: Int, top: Int, pants: Int, shoes: Int) -> SCNScene {
        let scene = SCNScene()
        let root = SCNNode()
        root.name = "Panther Original Character"
        scene.rootNode.addChildNode(root)
        let skin = skinColors[abs(character) % skinColors.count]
        let hairColor = hairColors[abs(hair) % hairColors.count]
        let shirt = clothColors[abs(top) % clothColors.count]
        let trousers = clothColors[abs(pants) % clothColors.count]
        let footwear = clothColors[abs(shoes) % clothColors.count]
        func add(_ geometry: SCNGeometry, _ name: String, _ color: UIColor, _ x: Float, _ y: Float, _ z: Float) {
            let material = SCNMaterial()
            material.diffuse.contents = color
            material.lightingModel = .physicallyBased
            geometry.materials = [material]
            let node = SCNNode(geometry: geometry)
            node.name = name
            node.position = SCNVector3(x,y,z)
            root.addChildNode(node)
        }
        add(SCNCapsule(capRadius:0.29, height:0.75), "Cabeza", skin, 0, 2.45, 0)
        add(SCNSphere(radius:0.305), "Cabello", hairColor, 0, 2.70, -0.025)
        add(SCNCapsule(capRadius:0.34, height:1.04), "Camiseta", shirt, 0, 1.67, 0)
        add(SCNBox(width:0.66,height:0.34,length:0.36,chamferRadius:0.10), "Cintura", trousers, 0, 1.12, 0)
        for side: Float in [-1,1] {
            add(SCNCapsule(capRadius:0.13,height:0.85), "Brazo", skin, side*0.48, 1.70, 0)
            add(SCNCapsule(capRadius:0.16,height:0.92), "Pantalon", trousers, side*0.19, 0.65, 0)
            add(SCNBox(width:0.30,height:0.19,length:0.52,chamferRadius:0.07), "Zapato", footwear, side*0.19, 0.12, 0.12)
            add(SCNSphere(radius:0.035), "Ojo", .black, side*0.115, 2.48, 0.275)
        }
        let floor = SCNFloor()
        floor.reflectivity = 0.04
        add(floor, "Suelo", UIColor(red:0.12,green:0.13,blue:0.19,alpha:1), 0, 0, 0)
        let camera = SCNCamera()
        camera.fieldOfView = 42
        let cameraNode = SCNNode()
        cameraNode.camera = camera
        cameraNode.position = SCNVector3(0,1.65,6.5)
        scene.rootNode.addChildNode(cameraNode)
        let light = SCNLight()
        light.type = .omni
        light.intensity = 950
        let lightNode = SCNNode()
        lightNode.light = light
        lightNode.position = SCNVector3(2,5,5)
        scene.rootNode.addChildNode(lightNode)
        return scene
    }
    static func export(_ scene: SCNScene) throws -> URL {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("Panther-Personaje-\(UUID().uuidString.prefix(8)).scn")
        guard scene.write(to: url, options: nil, delegate: nil, progressHandler: nil) else {
            throw CocoaError(.fileWriteUnknown)
        }
        return url
    }
}
