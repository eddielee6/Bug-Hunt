//
//  GameStartScreen.swift
//  SpriteKitSimpleGame
//
//  Created by Eddie Lee on 15/01/2016.
//  Copyright © 2016 Eddie Lee. All rights reserved.
//

import Foundation
import SpriteKit

class GameStartScene: SKScene {
    
    var screenSize: CGSize;
    
    override init(size: CGSize) {
        screenSize = size
        
        super.init(size: screenSize)
        backgroundColor = SKColor.blackColor()
        
        let startLabel = SKLabelNode(fontNamed: "SanFrancisco")
        startLabel.text = "Tap to Start"
        startLabel.fontSize = 50
        startLabel.verticalAlignmentMode = .Center
        startLabel.fontColor = SKColor.whiteColor()
        startLabel.position = CGPoint(x: size.width/2, y: size.height/2)
        addChild(startLabel)
        
        let growAction = SKAction.scaleBy(1.2, duration: 0.4)
        let shrinkAction = SKAction.scaleBy(0.8333, duration: 0.4)
        let growAndShrink = SKAction.sequence([growAction, shrinkAction])
        startLabel.runAction(SKAction.repeatActionForever(growAndShrink))
    }
    
    override func touchesEnded(touches: Set<UITouch>, withEvent event: UIEvent?) {
        runAction(SKAction.runBlock() {
            let reveal = SKTransition.doorwayWithDuration(0.5)
            let scene = GameScene(size: self.screenSize)
            self.view?.presentScene(scene, transition:reveal)
        })
    }
    
    required init(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}